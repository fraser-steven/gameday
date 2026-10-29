import Foundation

@MainActor @Observable
final class TipsViewModel {
    enum ViewState { case loading, loaded([Tip]), empty, failed(String) }
    private(set) var state: ViewState = .loading

    private let footballService: FootballService
    private let predictionService: PredictionService
    private var hasLoadedOnce = false

    init(
        footballService: FootballService = FootballService(),
        predictionService: PredictionService = PredictionService()
    ) {
        self.footballService = footballService
        self.predictionService = predictionService
    }

    /// See `HomeViewModel.loadIfNeeded()` — `.task` can re-run on every tab
    /// revisit, so this avoids an unnecessary refetch each time. `load()`
    /// stays available for pull-to-refresh and the "Try Again" button.
    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await load()
    }

    func load() async {
        do {
            let matches = try await footballService.matchesThisWeek(leagueIDs: APIConfig.leagueIDs)
            let predictions = await predictionService.predictions(for: matches)

            let top5 = Array(Tip.ranked(matches: matches, predictions: predictions).prefix(5))
            state = top5.isEmpty ? .empty : .loaded(top5)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
