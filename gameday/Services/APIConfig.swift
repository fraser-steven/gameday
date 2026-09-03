//
//  APIConfig.swift
//  gameday
//

import Foundation

/// Configuration for TheSportsDB (https://www.thesportsdb.com/free_sports_api).
enum APIConfig {
    static let baseURL = URL(string: "https://www.thesportsdb.com/api/v1/json")!

    /// TheSportsDB API key.
    ///
    /// `"3"` is the shared free test key — fine for development. For production,
    /// get your own key (TheSportsDB Patreon) and set it via the
    /// `THESPORTSDB_KEY` environment variable in the run scheme, or replace
    /// `fallbackKey` and move it to a git-ignored config before shipping.
    static var apiKey: String {
        if let key = ProcessInfo.processInfo.environment["THESPORTSDB_KEY"], !key.isEmpty {
            return key
        }
        return fallbackKey
    }

    private static let fallbackKey = "3"

    /// Leagues shown on the Home screen (TheSportsDB league IDs).
    static let leagueIDs = [MatchLeague.premierLeagueID, MatchLeague.laLigaID]
}