//
//  PredictionService.swift
//  gameday
//
//  Computes match predictions entirely on-device: fits a Dixon-Coles-style
//  goal model per league from openfootball history (via GamedayEngine's C
//  iterative-proportional-fitting engine), caches the fit locally, and turns
//  it into 1X2 + BTTS probabilities for whichever fixtures the caller asks
//  about. Reading predictions is a pure local file-read + C computation — no
//  network call — so a flaky fixture-list fetch elsewhere can never wipe
//  already-computed predictions out from under the UI.
//

import Foundation
import GamedayEngine

actor PredictionService {
    /// Recent-form weighting — same half-life as the (retired) edge function.
    private static let timeDecay = 0.0018

    private let historyFetcher: HistoryFetcher
    private let modelStore: LeagueModelStore

    private var refitsInFlight: Set<String> = []

    init(
        historyFetcher: HistoryFetcher = HistoryFetcher(),
        modelStore: LeagueModelStore = LeagueModelStore()
    ) {
        self.historyFetcher = historyFetcher
        self.modelStore = modelStore
    }

    /// Refits any modelled league whose cached fit is missing or stale.
    /// Fire-and-forget and safe to call repeatedly (e.g. every app launch) —
    /// leagues already refitting or still fresh are skipped.
    func triggerRefresh() async {
        for leagueID in APIConfig.leagueIDs {
            guard await modelStore.isStale(leagueID: leagueID), !refitsInFlight.contains(leagueID) else {
                continue
            }
            refitsInFlight.insert(leagueID)
            Task { [weak self] in
                await self?.refit(leagueID: leagueID)
            }
        }
    }

    /// A prediction for each of `matches`, computed from the currently cached
    /// fit for its league. `matches` is supplied by the caller (who already
    /// fetched it to display) rather than fetched here, so this never makes a
    /// network call. Fixtures whose league has no fit yet, or whose team
    /// isn't recognised within it, are simply omitted (the UI already treats
    /// "no prediction" as a normal state).
    func predictions(for matches: [Match]) async -> [String: Prediction] {
        var result: [String: Prediction] = [:]
        for match in matches {
            guard let fit = await modelStore.load(leagueID: match.league.id) else { continue }
            guard
                let homeName = TeamNameMatcher.match(match.homeTeam.name, among: fit.teamNames),
                let homeIndex = fit.teamNames.firstIndex(of: homeName),
                let awayName = TeamNameMatcher.match(match.awayTeam.name, among: fit.teamNames),
                let awayIndex = fit.teamNames.firstIndex(of: awayName)
            else { continue }

            let lambdaHome = fit.attack[homeIndex] * fit.defence[awayIndex] * fit.homeAdvantage
            let lambdaAway = fit.attack[awayIndex] * fit.defence[homeIndex]
            guard let markets = Engine.markets(lambdaHome: lambdaHome, lambdaAway: lambdaAway) else { continue }

            let (pick, confidence) = Self.pickAndConfidence(markets)
            result[match.id] = Prediction(
                fixtureID: match.id,
                homeTeam: match.homeTeam.name,
                awayTeam: match.awayTeam.name,
                kickoff: match.kickoff,
                probHome: markets.home,
                probDraw: markets.draw,
                probAway: markets.away,
                probBTTSYes: markets.bttsYes,
                pick: pick,
                confidence: confidence,
                rationale: nil,
                modelVersion: "ondevice-ipf-v1",
                generatedAt: fit.generatedAt
            )
        }
        return result
    }

    // MARK: - Fitting

    private func refit(leagueID: String) async {
        defer { refitsInFlight.remove(leagueID) }

        let history = await historyFetcher.history(forLeagueID: leagueID)
        guard !history.isEmpty else { return }

        let teamNames = Array(Set(history.flatMap { [$0.home, $0.away] })).sorted()
        guard (2...64).contains(teamNames.count) else { return }
        let indexOf = Dictionary(uniqueKeysWithValues: teamNames.enumerated().map { ($1, Int32($0)) })

        let now = Date()
        var homeIndex: [Int32] = []
        var awayIndex: [Int32] = []
        var homeGoals: [Int32] = []
        var awayGoals: [Int32] = []
        var weights: [Double] = []

        for match in history {
            guard let h = indexOf[match.home], let a = indexOf[match.away] else { continue }
            let ageDays = now.timeIntervalSince(match.date) / 86_400
            guard ageDays >= 0 else { continue }

            homeIndex.append(h)
            awayIndex.append(a)
            homeGoals.append(Int32(match.homeGoals))
            awayGoals.append(Int32(match.awayGoals))
            weights.append(exp(-Self.timeDecay * ageDays))
        }

        guard !homeIndex.isEmpty, let fit = Engine.fit(
            homeIndex: homeIndex, awayIndex: awayIndex,
            homeGoals: homeGoals, awayGoals: awayGoals,
            weight: weights, teamCount: teamNames.count
        ) else { return }

        let stored = StoredLeagueFit(
            teamNames: teamNames,
            attack: fit.attack,
            defence: fit.defence,
            homeAdvantage: fit.homeAdvantage,
            generatedAt: now
        )
        try? await modelStore.save(stored, leagueID: leagueID)
    }

    private static func pickAndConfidence(_ markets: MarketProbabilities) -> (Prediction.Outcome, Prediction.Confidence) {
        let top = max(markets.home, markets.draw, markets.away)
        let pick: Prediction.Outcome = switch top {
        case markets.home: .home
        case markets.draw: .draw
        default: .away
        }
        let confidence: Prediction.Confidence = top >= 0.55 ? .high : (top >= 0.4 ? .medium : .low)
        return (pick, confidence)
    }
}
