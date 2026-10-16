import Foundation

@MainActor @Observable
final class TipsViewModel {
    enum ViewState { case loading, loaded([Tip]), empty, failed(String) }
    private(set) var state: ViewState = .loading

    private let footballService: FootballService
    private let predictionService: PredictionService

    init(
        footballService: FootballService = FootballService(),
        predictionService: PredictionService = PredictionService()
    ) {
        self.footballService = footballService
        self.predictionService = predictionService
    }

    func load() async {
        do {
            let matches = try await footballService.matchesThisWeek(leagueIDs: APIConfig.leagueIDs)
            let predictions = await predictionService.predictions(for: matches)

            var candidates: [Tip] = []
            for match in matches {
                guard let prediction = predictions[match.id] else { continue }
                guard match.kickoff.timeIntervalSinceNow <= 72 * 3600 else { continue } 
                candidates += Tip.candidates(match: match, prediction: prediction)
            }

            let top5 = Array(candidates.sorted { $0.probability > $1.probability }.prefix(5))
            state = top5.isEmpty ? .empty : .loaded(top5)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
