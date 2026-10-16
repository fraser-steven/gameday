//
//  HistoryFetcher.swift
//  gameday
//
//  Historical results for the on-device goal model, from
//  openfootball/football.json on GitHub — hosted on raw.githubusercontent.com
//  so there's no WAF, no rate limit, no User-Agent games. (football-data.co.uk
//  was tried first and is blocked; bulk TheSportsDB fetching hits HTTP 429
//  after ~30 calls — see supabase/functions/refresh-predictions/sources.ts,
//  which this is a Swift port of the relevant half of.)
//

import Foundation

struct HistMatch: Equatable {
    let date: Date
    let home: String
    let away: String
    let homeGoals: Int
    let awayGoals: Int
}

actor HistoryFetcher {
    private static let base = URL(string: "https://raw.githubusercontent.com/openfootball/football.json/master")!
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The openfootball league file for a TheSportsDB league ID this app models.
    static func openfootballCode(forLeagueID leagueID: String) -> String? {
        switch leagueID {
        case MatchLeague.premierLeagueID: "en.1"
        case MatchLeague.laLigaID: "es.1"
        case MatchLeague.bundesligaID: "de.1"
        case MatchLeague.serieAID: "it.1"
        default: nil
        }
    }

    /// The last `count` openfootball season folders (e.g. "2026-27"), current
    /// season first. openfootball's football calendar runs roughly July-June.
    static func recentSeasonFolders(count: Int = 3, now: Date = .now) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let startYear = month >= 7 ? year : year - 1

        return (0..<count).map { back in
            let y = startYear - back
            return "\(y)-\(String(format: "%02d", (y + 1) % 100))"
        }
    }

    /// Finished results for a league across its last 3 openfootball seasons.
    /// Missing/unreachable season files are skipped rather than failing the
    /// whole fetch.
    func history(forLeagueID leagueID: String) async -> [HistMatch] {
        guard let code = Self.openfootballCode(forLeagueID: leagueID) else { return [] }

        var all: [HistMatch] = []
        for season in Self.recentSeasonFolders() {
            all += await matches(season: season, code: code)
        }
        return all
    }

    private func matches(season: String, code: String) async -> [HistMatch] {
        let url = Self.base.appending(path: season).appending(path: "\(code).json")
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let payload = try? decoder.decode(OpenfootballSeason.self, from: data)
        else { return [] }

        return payload.matches.compactMap { $0.histMatch(isoFormatter: Self.isoFormatter) }
    }
}

private struct OpenfootballSeason: Decodable {
    let matches: [OpenfootballMatch]
}

private struct OpenfootballMatch: Decodable {
    let date: String?
    let time: String?
    let team1: String?
    let team2: String?
    let score: OpenfootballScore?

    func histMatch(isoFormatter: ISO8601DateFormatter) -> HistMatch? {
        guard let date, let team1, let team2,
              let home = score?.homeGoals, let away = score?.awayGoals
        else { return nil }

        let time = (time?.isEmpty == false) ? time! : "12:00"
        guard let parsed = isoFormatter.date(from: "\(date)T\(time):00Z") else { return nil }

        return HistMatch(date: parsed, home: team1, away: team2, homeGoals: home, awayGoals: away)
    }
}

/// openfootball is inconsistent: usually `{"ft": [h, a]}`, sometimes a bare
/// `[h, a]`. Both decode into this; `nil` goals mean the match hasn't been
/// played (or the shape didn't match either case).
private struct OpenfootballScore: Decodable {
    let homeGoals: Int?
    let awayGoals: Int?

    private enum CodingKeys: String, CodingKey { case ft }

    init(from decoder: Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode([Int].self), bare.count == 2 {
            homeGoals = bare[0]
            awayGoals = bare[1]
            return
        }
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let ft = try? container.decodeIfPresent([Int].self, forKey: .ft),
           ft.count == 2 {
            homeGoals = ft[0]
            awayGoals = ft[1]
            return
        }
        homeGoals = nil
        awayGoals = nil
    }
}
