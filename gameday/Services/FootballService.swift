//
//  FootballService.swift
//  gameday
//
//  Async wrapper around TheSportsDB's league event endpoints.
//
//  Note on the free API: `eventsday` / `eventsseason` are hard-capped to a
//  handful of rows on the free keys, but `eventsround` returns a complete
//  match-round, so the week view is assembled from rounds.
//

import Foundation

actor FootballService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let calendar: Calendar

    init(session: URLSession = .shared) {
        self.session = session

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        self.calendar = calendar
    }

    // MARK: - Public

    /// Every fixture across the given leagues that kicks off during the current
    /// week — Monday 00:00 through Sunday 23:59 in the device's time zone —
    /// de-duplicated and sorted by kick-off (soonest first).
    func matchesThisWeek(leagueIDs: [String], now: Date = .now) async throws -> [Match] {
        let week = weekInterval(containing: now)

        let collected = try await withThrowingTaskGroup(of: [Match].self) { group in
            for id in leagueIDs {
                group.addTask { try await self.matches(in: week, leagueID: id) }
            }
            var all: [Match] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }

        let unique = Dictionary(collected.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return unique.values.sorted { $0.kickoff < $1.kickoff }
    }

    /// Upcoming fixtures for a single league (TheSportsDB returns the next 15).
    func upcomingMatches(leagueID: String) async throws -> [Match] {
        try await events(path: "eventsnextleague.php", query: [URLQueryItem(name: "id", value: leagueID)])
    }

    // MARK: - Per-league week assembly

    private func matches(in week: DateInterval, leagueID: String) async throws -> [Match] {
        // The next/past feeds are cheap, usually cover a normal league week on
        // their own, and tell us which round is currently in play.
        async let nextFeed = events(path: "eventsnextleague.php", query: [URLQueryItem(name: "id", value: leagueID)])
        async let pastFeed = events(path: "eventspastleague.php", query: [URLQueryItem(name: "id", value: leagueID)])
        let next = (try? await nextFeed) ?? []
        let past = (try? await pastFeed) ?? []

        let pivot = next.compactMap(\.round).min()
            ?? past.compactMap(\.round).max()
            ?? 1

        // Pull the surrounding rounds in full — needed for big midweek slates
        // (a Champions League round is ~18 games) and weeks that straddle two
        // rounds.
        let rounds = ((pivot - 1)...(pivot + 1)).filter { $0 >= 1 }
        let roundMatches = try await withThrowingTaskGroup(of: [Match].self) { group in
            for round in rounds {
                group.addTask { (try? await self.round(round, leagueID: leagueID)) ?? [] }
            }
            var all: [Match] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }

        return (next + past + roundMatches).filter { week.contains($0.kickoff) }
    }

    private func round(_ round: Int, leagueID: String) async throws -> [Match] {
        try await events(path: "eventsround.php", query: [
            URLQueryItem(name: "id", value: leagueID),
            URLQueryItem(name: "r", value: String(round)),
            URLQueryItem(name: "s", value: APIConfig.currentSeason),
        ])
    }

    // MARK: - Request

    private func events(path: String, query: [URLQueryItem]) async throws -> [Match] {
        let endpoint = APIConfig.baseURL
            .appending(path: APIConfig.apiKey)
            .appending(path: path)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else { throw FootballError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse else { throw FootballError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw FootballError.httpStatus(http.statusCode) }

        // TheSportsDB sends `{"events": null}` when there's nothing to return.
        return try decoder.decode(LeagueEventsResponse.self, from: data).events ?? []
    }

    // MARK: - Dates

    private func weekInterval(containing date: Date) -> DateInterval {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: DateComponents(day: 7, second: -1), to: start) ?? date
        return DateInterval(start: start, end: end)
    }
}
