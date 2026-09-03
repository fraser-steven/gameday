//
//  FootballService.swift
//  gameday
//
//  Async wrapper around TheSportsDB's league event endpoints.
//

import Foundation

actor FootballService {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Upcoming fixtures for a single league (TheSportsDB returns the next 15).
    func upcomingMatches(leagueID: String) async throws -> [Match] {
        try await events(path: "eventsnextleague.php", leagueID: leagueID)
    }

    /// Recent results for a single league (TheSportsDB returns the last 15).
    func recentMatches(leagueID: String) async throws -> [Match] {
        try await events(path: "eventspastleague.php", leagueID: leagueID)
    }

    /// Upcoming fixtures across several leagues, fetched concurrently, combined
    /// and sorted by kick-off time (soonest first).
    func upcomingMatches(leagueIDs: [String]) async throws -> [Match] {
        try await withThrowingTaskGroup(of: [Match].self) { group in
            for id in leagueIDs {
                group.addTask { try await self.upcomingMatches(leagueID: id) }
            }

            var combined: [Match] = []
            for try await batch in group {
                combined.append(contentsOf: batch)
            }
            return combined.sorted { $0.kickoff < $1.kickoff }
        }
    }

    // MARK: - Request

    private func events(path: String, leagueID: String) async throws -> [Match] {
        let endpoint = APIConfig.baseURL
            .appending(path: APIConfig.apiKey)
            .appending(path: path)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: leagueID)]
        guard let url = components?.url else { throw FootballError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse else { throw FootballError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FootballError.httpStatus(http.statusCode) }

        // TheSportsDB sends `{"events": null}` when there's nothing to return.
        return try decoder.decode(LeagueEventsResponse.self, from: data).events ?? []
    }
}