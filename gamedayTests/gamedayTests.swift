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

/// Offline checks for the prediction layer.
struct PredictionTests {

    @Test
    func decodesAPredictionRow() throws {
        let json = """
        [{
          "fixture_id": "2494027",
          "league_id": "4328",
          "season": "2026-2027",
          "home_team": "Arsenal",
          "away_team": "Liverpool",
          "kickoff": "2026-09-13T15:30:00+00:00",
          "prob_home": 0.47,
          "prob_draw": 0.27,
          "prob_away": 0.26,
          "prob_btts_yes": 0.58,
          "pick": "home",
          "confidence": "medium",
          "rationale": "Arsenal's home form gives them the edge.",
          "model_version": "poisson-dc-v1",
          "generated_at": "2026-09-11T02:00:00.123456+00:00"
        }]
        """.data(using: .utf8)!

        let rows = try PredictionService.makeDecoder().decode([Prediction].self, from: json)
        let prediction = try #require(rows.first)

        #expect(prediction.fixtureID == "2494027")
        #expect(prediction.pick == .home)
        #expect(prediction.confidence == .medium)
        #expect(prediction.bttsYesPercent == 58)
        #expect(prediction.pickProbability == 0.47)
        #expect(prediction.headline(homeName: "Arsenal", awayName: "Liverpool") == "Arsenal to win")
        // Fractional seconds in the timestamp must not break decoding.
        #expect(prediction.generatedAt.timeIntervalSince1970 > 0)
    }

    @Test
    func decodesANullRationale() throws {
        let json = """
        {"fixture_id":"1","league_id":"4331","season":null,"home_team":"A","away_team":"B",
         "kickoff":"2026-09-13T19:00:00+00:00","prob_home":0.4,"prob_draw":0.3,"prob_away":0.3,
         "prob_btts_yes":0.54,"pick":"home","confidence":"medium","rationale":null,
         "model_version":"poisson-dc-v1","generated_at":"2026-09-11T02:00:00+00:00"}
        """.data(using: .utf8)!

        let prediction = try PredictionService.makeDecoder().decode(Prediction.self, from: json)
        #expect(prediction.rationale == nil)
        #expect(prediction.pick == .home)
    }

    @Test
    func parsesTimestampsWithAndWithoutFractionalSeconds() {
        #expect(PredictionService.parseTimestamp("2026-09-13T15:30:00+00:00") != nil)
        #expect(PredictionService.parseTimestamp("2026-09-11T02:00:00.123456+00:00") != nil)
        #expect(PredictionService.parseTimestamp("not a date") == nil)
    }
}
