//
//  SupabaseConfig.swift
//  gameday
//

import Foundation

/// Connection details for the GameDay AI Supabase project.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://bnvkdexyzgficwepzjss.supabase.co")!

    /// The `anon` public key. Safe to ship in a client (Row Level Security is the
    /// real gate), but kept out of source where possible: set `SUPABASE_ANON_KEY`
    /// in the run scheme, otherwise fill in `fallbackAnonKey`.
    static var anonKey: String {
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !key.isEmpty {
            return key
        }
        return fallbackAnonKey
    }

    private static let fallbackAnonKey = "sb_publishable__f7_qNHZdxVQcJXCgH-6CQ_4JJI3OhN"

    static var isConfigured: Bool {
        !anonKey.isEmpty && anonKey != "YOUR_SUPABASE_ANON_KEY"
    }

    static var restURL: URL { projectURL.appending(path: "rest/v1") }
    static var functionsURL: URL { projectURL.appending(path: "functions/v1") }
}
