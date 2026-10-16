//
//  LeagueModelStore.swift
//  gameday
//
//  Local persistence for a fitted goal model, one JSON file per league in
//  Application Support. Replaces the Supabase `predictions` table — the thing
//  being cached is now the *fit* (attack/defence/home advantage), not
//  per-fixture predictions, since those are cheap to recompute from the fit
//  at read time.
//

import Foundation

struct StoredLeagueFit: Codable, Equatable {
    /// Team name, indexed the same way `attack`/`defence` are.
    let teamNames: [String]
    let attack: [Double]
    let defence: [Double]
    let homeAdvantage: Double
    let generatedAt: Date
}

actor LeagueModelStore {
    private let directory: URL
    private let maxAge: TimeInterval

    init(maxAge: TimeInterval = 24 * 3600) {
        self.maxAge = maxAge
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.directory = support.appending(path: "GamedayEngine", directoryHint: .isDirectory)
    }

    /// Whether `leagueID` has no cached fit, or one older than `maxAge`.
    func isStale(leagueID: String, now: Date = .now) -> Bool {
        guard let fit = load(leagueID: leagueID) else { return true }
        return now.timeIntervalSince(fit.generatedAt) > maxAge
    }

    func load(leagueID: String) -> StoredLeagueFit? {
        guard let data = try? Data(contentsOf: fileURL(for: leagueID)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StoredLeagueFit.self, from: data)
    }

    func save(_ fit: StoredLeagueFit, leagueID: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(fit)
        try data.write(to: fileURL(for: leagueID), options: .atomic)
    }

    private func fileURL(for leagueID: String) -> URL {
        directory.appending(path: "\(leagueID).json")
    }
}
