//
//  Match.swift
//  gameday
//

import Foundation

/// A single fixture, decoded from one TheSportsDB event.
///
/// TheSportsDB returns every field as a string (or `null`), with a flat key
/// layout, so decoding is done by hand here.
struct Match: Identifiable, Hashable {
    let id: String
    let league: MatchLeague
    let homeTeam: MatchTeam
    let awayTeam: MatchTeam
    let kickoff: Date
    let round: Int?
    let venue: String?
    let status: MatchStatus
    let homeScore: Int?
    let awayScore: Int?

    var hasScore: Bool { homeScore != nil && awayScore != nil }
}

extension Match: Decodable {
    private enum CodingKeys: String, CodingKey {
        case idEvent, strTimestamp, dateEvent, strTime
        case idLeague, strLeague, strLeagueBadge
        case strHomeTeam, strAwayTeam, strHomeTeamBadge, strAwayTeamBadge
        case intHomeScore, intAwayScore, intRound
        case strVenue, strStatus, strPostponed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func string(_ key: CodingKeys) -> String? {
            if let value = try? c.decodeIfPresent(String.self, forKey: key) {
                return value.isEmpty ? nil : value
            }
            if let value = try? c.decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            return nil
        }
        func int(_ key: CodingKeys) -> Int? {
            string(key).flatMap { Int($0) }
        }

        id = string(.idEvent) ?? UUID().uuidString

        league = MatchLeague(
            id: string(.idLeague) ?? "",
            name: string(.strLeague) ?? "",
            badge: string(.strLeagueBadge)
        )
        homeTeam = MatchTeam(name: string(.strHomeTeam) ?? "TBD", badge: string(.strHomeTeamBadge))
        awayTeam = MatchTeam(name: string(.strAwayTeam) ?? "TBD", badge: string(.strAwayTeamBadge))

        kickoff = Self.parseKickoff(
            timestamp: string(.strTimestamp),
            date: string(.dateEvent),
            time: string(.strTime)
        ) ?? .distantFuture

        round = int(.intRound)
        venue = string(.strVenue)
        status = MatchStatus(rawStatus: string(.strStatus), postponed: string(.strPostponed))
        homeScore = int(.intHomeScore)
        awayScore = int(.intAwayScore)
    }

    /// TheSportsDB timestamps are UTC with no offset ("2026-09-03T19:00:00").
    private static func parseKickoff(timestamp: String?, date: String?, time: String?) -> Date? {
        let utc = TimeZone(identifier: "UTC")

        if let timestamp {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = utc
            for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"] {
                formatter.dateFormat = format
                if let parsed = formatter.date(from: timestamp) { return parsed }
            }
        }

        if let date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = utc
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.date(from: "\(date) \(time ?? "00:00:00")")
        }

        return nil
    }
}

/// Envelope for the `eventsnextleague` / `eventspastleague` endpoints.
struct LeagueEventsResponse: Decodable {
    let events: [Match]?
}