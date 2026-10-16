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

    private let service: FootballService
    private let predictionService: PredictionService
    private let leagueIDs: [String]
    private var predictionRefetch: Task<Void, Never>?

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

    func load() async {
        if case .failed = state { state = .loading }

        // Nudge the on-device fit to refresh; it no-ops per league if still fresh.
        Task { await predictionService.triggerRefresh() }

        do {
            let matches = try await service.matchesThisWeek(leagueIDs: leagueIDs)
            state = matches.isEmpty ? .empty : .loaded(matches)
            predictions = await predictionService.predictions(for: matches)
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
        predictionRefetch = Task { [predictionService] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            predictions = await predictionService.predictions(for: matches)
        }
    }
}
