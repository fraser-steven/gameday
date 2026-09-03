//
//  gamedayTests.swift
//  gamedayTests
//
//  Created by Fraser Steven on 22/05/2026.
//

import Testing
import Foundation
@testable import gameday

/// Live integration checks against TheSportsDB. These hit the network.
struct APIConnectionTests {

    /// The raw endpoint responds and returns events for the Premier League.
    @Test
    func premierLeagueEndpointResponds() async throws {
        let url = APIConfig.baseURL
            .appending(path: "\(APIConfig.apiKey)/eventsnextleague.php")
            .appending(queryItems: [.init(name: "id", value: MatchLeague.premierLeagueID)])

        let (data, response) = try await URLSession.shared.data(from: url)

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)

        let decoded = try JSONDecoder().decode(LeagueEventsResponse.self, from: data)
        let events = try #require(decoded.events, "TheSportsDB returned no events array.")
        #expect(!events.isEmpty)

        print("TheSportsDB OK — \(events.count) upcoming Premier League fixtures")
    }

    /// The app's own service fetches, combines and sorts both leagues.
    @Test
    func serviceFetchesAndSortsBothLeagues() async throws {
        let service = FootballService()
        let matches = try await service.upcomingMatches(leagueIDs: APIConfig.leagueIDs)

        #expect(!matches.isEmpty, "No upcoming matches for either league.")

        let leagues = Set(matches.map(\.league.id))
        #expect(leagues.contains(MatchLeague.premierLeagueID))
        #expect(leagues.contains(MatchLeague.laLigaID))

        #expect(
            matches == matches.sorted { $0.kickoff < $1.kickoff },
            "Matches should be sorted by kick-off, soonest first."
        )

        // Sanity-check that decoding produced real data, not fallbacks.
        let first = try #require(matches.first)
        #expect(!first.homeTeam.name.isEmpty && first.homeTeam.name != "TBD")
        #expect(first.kickoff != .distantFuture)
    }
}