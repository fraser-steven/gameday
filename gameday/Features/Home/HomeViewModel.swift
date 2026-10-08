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

        // Nudge the backend to regenerate predictions; it no-ops if still fresh.
        Task { await predictionService.triggerRefresh() }

        async let fixtures = service.matchesThisWeek(leagueIDs: leagueIDs)
        async let cached = predictionService.predictions()

        predictions = (try? await cached) ?? predictions

        do {
            let matches = try await fixtures
            state = matches.isEmpty ? .empty : .loaded(matches)
        } catch is CancellationError {
            // View went away; leave state as-is.
        } catch {
            state = .failed(error.localizedDescription)
        }

        schedulePredictionRefetch()
    }

    /// A cold backend run takes a few seconds to populate; pick the rows up once
    /// more shortly after so the first launch doesn't need a manual relaunch.
    private func schedulePredictionRefetch() {
        predictionRefetch?.cancel()
        predictionRefetch = Task { [predictionService] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let fresh = try? await predictionService.predictions() else { return }
            predictions = fresh
        }
    }
}
