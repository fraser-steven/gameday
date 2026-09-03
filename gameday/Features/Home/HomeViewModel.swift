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

    private let service: FootballService
    private let leagueIDs: [String]

    init(
        service: FootballService = FootballService(),
        leagueIDs: [String] = APIConfig.leagueIDs
    ) {
        self.service = service
        self.leagueIDs = leagueIDs
    }

    func load() async {
        if case .failed = state { state = .loading }

        do {
            let matches = try await service.upcomingMatches(leagueIDs: leagueIDs)
            state = matches.isEmpty ? .empty : .loaded(matches)
        } catch is CancellationError {
            // View went away; leave state as-is.
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}