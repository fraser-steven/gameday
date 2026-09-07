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

    /// The `eventsround` endpoint responds and returns a full match-round.
    @Test
    func premierLeagueRoundEndpointResponds() async throws {
        let url = APIConfig.baseURL
            .appending(path: "\(APIConfig.apiKey)/eventsround.php")
            .appending(queryItems: [
                .init(name: "id", value: MatchLeague.premierLeagueID),
                .init(name: "r", value: "4"),
                .init(name: "s", value: APIConfig.currentSeason),
            ])

        let (data, response) = try await URLSession.shared.data(from: url)

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)

        let decoded = try JSONDecoder().decode(LeagueEventsResponse.self, from: data)
        let events = try #require(decoded.events, "TheSportsDB returned no events array.")
        #expect(!events.isEmpty)

        print("TheSportsDB OK — \(events.count) fixtures in Premier League round 4")
    }

    /// The service assembles this week's fixtures across all three leagues,
    /// keeps them inside the Monday–Sunday window, and sorts them.
    @Test
    func serviceReturnsThisWeekSortedAndInRange() async throws {
        let service = FootballService()
        let matches = try await service.matchesThisWeek(leagueIDs: APIConfig.leagueIDs)

        #expect(!matches.isEmpty, "No matches found for the current week.")

        #expect(
            matches == matches.sorted { $0.kickoff < $1.kickoff },
            "Matches should be sorted by kick-off, soonest first."
        )

        // All kick-offs land within this Monday…Sunday.
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let weekStart = try #require(calendar.dateInterval(of: .weekOfYear, for: .now)?.start)
        let weekEnd = try #require(calendar.date(byAdding: .day, value: 7, to: weekStart))
        for match in matches {
            #expect(match.kickoff >= weekStart && match.kickoff < weekEnd)
        }

        // IDs are unique (rounds overlap, so de-duplication must work).
        #expect(Set(matches.map(\.id)).count == matches.count)

        // Decoding produced real data, not fallbacks.
        let first = try #require(matches.first)
        #expect(!first.homeTeam.name.isEmpty && first.homeTeam.name != "TBD")
        #expect(first.kickoff != .distantFuture)

        let leagues = Set(matches.map(\.league.shortName)).sorted()
        print("This week: \(matches.count) matches across \(leagues.joined(separator: ", "))")
    }
}
