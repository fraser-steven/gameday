//
//  HomeViewModel.swift
//  gameday
//

import Foundation

@MainActor
@Observable
final class HomeViewModel {
    enum ViewState {
        case loading
        case loaded([Match])
        case empty
        case failed(String)
    }

    private(set) var state: ViewState = .loading
    private(set) var predictions: [String: Prediction] = [:]
    /// The week's single highest-confidence tip, regardless of any league
    /// filter the Home list is showing — used for the hero card.
    private(set) var featuredTip: Tip?

    private let service: FootballService
    private let predictionService: PredictionService
    private let leagueIDs: [String]
    private var predictionRefetch: Task<Void, Never>?
    private var hasLoadedOnce = false

    init(
        service: FootballService = FootballService(),
        predictionService: PredictionService = PredictionService(),
        leagueIDs: [String] = APIConfig.leagueIDs
    ) {
        self.service = service
        self.predictionService = predictionService
        self.leagueIDs = leagueIDs
    }

    func prediction(for match: Match) -> Prediction? {
        predictions[match.id]
    }

    /// Called from `.task`, which SwiftUI can re-run every time the view
    /// reappears (e.g. switching tabs away and back). Without this guard
    /// that refetches on every visit, and a transient TheSportsDB hiccup
    /// mid-refetch would replace a good, crest-bearing match list with the
    /// openfootball fallback's crest-less one — the reported "logos
    /// disappear after visiting Tips" bug. `load()` itself stays available
    /// for pull-to-refresh, which should always hit the network again.
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        if case .failed = state { state = .loading }

        // Nudge the on-device fit to refresh; it no-ops per league if still fresh.
        Task { await predictionService.triggerRefresh() }

        do {
            let matches = try await service.matchesThisWeek(leagueIDs: leagueIDs)
            state = matches.isEmpty ? .empty : .loaded(matches)
            await refreshPredictions(for: matches)
            schedulePredictionRefetch(matches: matches)
        } catch is CancellationError {
            // View went away; leave state as-is.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// A cold fit takes a few seconds to land on disk; look the same fixtures
    /// up again shortly after so the first launch doesn't need a manual
    /// relaunch. Reuses the fixture list from `load()` rather than re-fetching
    /// it — this is a local file read + the C model, not a network call.
    private func schedulePredictionRefetch(matches: [Match]) {
        predictionRefetch?.cancel()
        predictionRefetch = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            await self?.refreshPredictions(for: matches)
        }
    }

    private func refreshPredictions(for matches: [Match]) async {
        let fresh = await predictionService.predictions(for: matches)
        predictions = fresh
        featuredTip = Tip.ranked(matches: matches, predictions: fresh).first
    }
}
