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

/// Offline checks for team-name reconciliation between TheSportsDB (short
/// names) and openfootball (long official names).
struct TeamNameMatcherTests {

    @Test
    func matchesBayernMunichViaAlias() {
        let names = ["FC Bayern München", "Borussia Dortmund", "RB Leipzig"]
        #expect(TeamNameMatcher.match("Bayern Munich", among: names) == "FC Bayern München")
    }

    @Test
    func distinguishesInterMilanFromACMilan() {
        let names = ["FC Internazionale Milano", "AC Milan", "Juventus FC"]
        #expect(TeamNameMatcher.match("Inter Milan", among: names) == "FC Internazionale Milano")
        #expect(TeamNameMatcher.match("AC Milan", among: names) == "AC Milan")
    }

    @Test
    func matchesByTokenSubset() {
        let names = ["Real Madrid CF", "FC Barcelona"]
        #expect(TeamNameMatcher.match("Real Madrid", among: names) == "Real Madrid CF")
    }

    @Test
    func matchesByPrefix() {
        // "athen" is a 5-char prefix of "athens" — not an exact token match,
        // but close enough to resolve.
        let names = ["AEK Athen", "PAOK Saloniki"]
        #expect(TeamNameMatcher.match("AEK Athens", among: names) == "AEK Athen")
    }

    @Test
    func returnsNilWhenNothingQualifies() {
        let names = ["Real Madrid CF", "FC Barcelona"]
        #expect(TeamNameMatcher.match("Manchester United", among: names) == nil)
    }
}

/// Live integration check for the on-device prediction pipeline (history
/// fetch -> IPF fit -> cached -> read back as predictions). Hits the network.
struct PredictionServiceTests {

    @Test
    func predictionsBecomeAvailableAfterTriggerRefresh() async throws {
        let service = PredictionService()
        await service.triggerRefresh()

        let matches = try await FootballService().matchesThisWeek(leagueIDs: APIConfig.leagueIDs)
        try #require(!matches.isEmpty, "No fixtures this week to predict against.")

        var predictions: [String: Prediction] = [:]
        for _ in 0..<15 {
            predictions = await service.predictions(for: matches)
            if !predictions.isEmpty { break }
            try await Task.sleep(for: .seconds(2))
        }

        #expect(!predictions.isEmpty, "No predictions appeared within the polling window.")

        if let first = predictions.values.first {
            let total = first.probHome + first.probDraw + first.probAway
            #expect(total > 0.97 && total < 1.03)
            #expect((0...1).contains(first.probBTTSYes))
            #expect(first.modelVersion == "ondevice-ipf-v1")
        }
    }
}
