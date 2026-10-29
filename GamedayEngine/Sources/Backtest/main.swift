//
//  main.swift
//  Backtest
//
//  A standalone CLI that measures the real-world accuracy of GamedayEngine's
//  Dixon-Coles model: for each league, fit on 3 prior openfootball seasons
//  (the same window and time-decay weighting PredictionService uses), then
//  predict every match of a later, already-finished season and check the
//  1X2 pick against what actually happened. Pure out-of-sample — the model
//  never sees a season's results before "predicting" it.
//
//  Run with: swift run -c release Backtest
//

import Foundation
import GamedayEngine

// MARK: - Config

/// Same half-life as PredictionService.
let timeDecay = 0.0018

struct LeagueConfig {
    let name: String
    let code: String // openfootball league file, e.g. "en.1"
}

let leagues = [
    LeagueConfig(name: "Premier League", code: "en.1"),
    LeagueConfig(name: "La Liga", code: "es.1"),
    LeagueConfig(name: "Bundesliga", code: "de.1"),
    LeagueConfig(name: "Serie A", code: "it.1"),
]

/// (holdout season, 3 training seasons immediately preceding it).
let backtestWindows: [(holdout: String, training: [String])] = [
    ("2023-24", ["2020-21", "2021-22", "2022-23"]),
    ("2024-25", ["2021-22", "2022-23", "2023-24"]),
    ("2025-26", ["2022-23", "2023-24", "2024-25"]),
]

// MARK: - openfootball fetch + decode (mirrors OpenfootballClient)

struct HistMatch {
    let date: Date
    let home: String
    let away: String
    let homeGoals: Int
    let awayGoals: Int
}

struct OpenfootballSeason: Decodable { let matches: [OpenfootballMatch] }

struct OpenfootballMatch: Decodable {
    let date: String?
    let time: String?
    let team1: String?
    let team2: String?
    let score: OpenfootballScore?
}

struct OpenfootballScore: Decodable {
    let homeGoals: Int?
    let awayGoals: Int?

    private enum CodingKeys: String, CodingKey { case ft }

    init(from decoder: Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode([Int].self), bare.count == 2 {
            homeGoals = bare[0]; awayGoals = bare[1]; return
        }
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let ft = try? container.decodeIfPresent([Int].self, forKey: .ft), ft.count == 2 {
            homeGoals = ft[0]; awayGoals = ft[1]; return
        }
        homeGoals = nil; awayGoals = nil
    }
}

nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func fetchSeason(code: String, season: String) -> [HistMatch] {
    let url = URL(string: "https://raw.githubusercontent.com/openfootball/football.json/master/\(season)/\(code).json")!
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Data?
    URLSession.shared.dataTask(with: url) { data, response, _ in
        if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
            result = data
        }
        semaphore.signal()
    }.resume()
    semaphore.wait()

    guard let data = result,
          let payload = try? JSONDecoder().decode(OpenfootballSeason.self, from: data)
    else { return [] }

    return payload.matches.compactMap { m -> HistMatch? in
        guard let date = m.date, let team1 = m.team1, let team2 = m.team2,
              let hg = m.score?.homeGoals, let ag = m.score?.awayGoals
        else { return nil }
        let time = (m.time?.isEmpty == false) ? m.time! : "12:00"
        guard let parsed = isoFormatter.date(from: "\(date)T\(time):00Z") else { return nil }
        return HistMatch(date: parsed, home: team1, away: team2, homeGoals: hg, awayGoals: ag)
    }
}

// MARK: - Backtest

enum Result1X2 { case home, draw, away }

func actual(_ m: HistMatch) -> Result1X2 {
    if m.homeGoals > m.awayGoals { return .home }
    if m.homeGoals < m.awayGoals { return .away }
    return .draw
}

struct LeagueSeasonResult {
    let league: String
    let season: String
    var correct = 0
    var total = 0
    var homeBaselineCorrect = 0
}

var allResults: [LeagueSeasonResult] = []

for league in leagues {
    for window in backtestWindows {
        let trainingMatches = window.training.flatMap { fetchSeason(code: league.code, season: $0) }
        let holdoutMatches = fetchSeason(code: league.code, season: window.holdout)
        guard !trainingMatches.isEmpty, !holdoutMatches.isEmpty else { continue }

        let teamNames = Array(Set(trainingMatches.flatMap { [$0.home, $0.away] })).sorted()
        let indexOf = Dictionary(uniqueKeysWithValues: teamNames.enumerated().map { ($1, Int32($0)) })

        // Weight as of the holdout season's kickoff — i.e. "what the model
        // would have looked like right before this season started".
        let asOf = holdoutMatches.map(\.date).min() ?? Date()

        var homeIdx: [Int32] = [], awayIdx: [Int32] = []
        var homeGoals: [Int32] = [], awayGoals: [Int32] = []
        var weights: [Double] = []
        for m in trainingMatches {
            guard let h = indexOf[m.home], let a = indexOf[m.away] else { continue }
            let ageDays = asOf.timeIntervalSince(m.date) / 86_400
            guard ageDays >= 0 else { continue }
            homeIdx.append(h); awayIdx.append(a)
            homeGoals.append(Int32(m.homeGoals)); awayGoals.append(Int32(m.awayGoals))
            weights.append(exp(-timeDecay * ageDays))
        }

        guard let fit = Engine.fit(
            homeIndex: homeIdx, awayIndex: awayIdx,
            homeGoals: homeGoals, awayGoals: awayGoals,
            weight: weights, teamCount: teamNames.count
        ) else { continue }

        var seasonResult = LeagueSeasonResult(league: league.name, season: window.holdout)

        for m in holdoutMatches {
            guard let hi = indexOf[m.home], let ai = indexOf[m.away] else { continue } // promoted team, no fit
            let lambdaHome = fit.attack[Int(hi)] * fit.defence[Int(ai)] * fit.homeAdvantage
            let lambdaAway = fit.attack[Int(ai)] * fit.defence[Int(hi)]
            guard let markets = Engine.markets(lambdaHome: lambdaHome, lambdaAway: lambdaAway) else { continue }

            let top = max(markets.home, markets.draw, markets.away)
            let pick: Result1X2 = top == markets.home ? .home : (top == markets.draw ? .draw : .away)
            let result = actual(m)

            seasonResult.total += 1
            if pick == result { seasonResult.correct += 1 }
            if result == .home { seasonResult.homeBaselineCorrect += 1 }
        }

        allResults.append(seasonResult)
    }
}

// MARK: - Report

func pct(_ n: Int, _ d: Int) -> String {
    guard d > 0 else { return "—" }
    return String(format: "%.1f%%", Double(n) / Double(d) * 100)
}

print("\n| League | Season | Matches | Model correct | Model accuracy | \"Always home win\" accuracy |")
print("|---|---|---|---|---|---|")
for r in allResults {
    print("| \(r.league) | \(r.season) | \(r.total) | \(r.correct) | \(pct(r.correct, r.total)) | \(pct(r.homeBaselineCorrect, r.total)) |")
}

let totalMatches = allResults.reduce(0) { $0 + $1.total }
let totalCorrect = allResults.reduce(0) { $0 + $1.correct }
let totalHomeBaseline = allResults.reduce(0) { $0 + $1.homeBaselineCorrect }
print("| **Overall** | 2023-24 → 2025-26 | **\(totalMatches)** | **\(totalCorrect)** | **\(pct(totalCorrect, totalMatches))** | \(pct(totalHomeBaseline, totalMatches)) |\n")

print("Per-league overall:")
for league in leagues {
    let rows = allResults.filter { $0.league == league.name }
    let t = rows.reduce(0) { $0 + $1.total }
    let c = rows.reduce(0) { $0 + $1.correct }
    print("  \(league.name): \(c)/\(t) (\(pct(c, t)))")
}
