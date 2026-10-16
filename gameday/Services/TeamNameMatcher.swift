//
//  TeamNameMatcher.swift
//  gameday
//
//  Loose team-name matching between TheSportsDB (short names, "Bayern Munich")
//  and openfootball (long official names, "FC Bayern München"). Swift port of
//  supabase/functions/refresh-predictions/aliases.ts's `matchName` — same
//  algorithm, already validated at 100% match rate across all four modelled
//  leagues, just re-hosted on-device.
//

import Foundation

enum TeamNameMatcher {
    private static let dropTokens: Set<String> = [
        // legal-form / prefix noise
        "fc", "afc", "cf", "cd", "ca", "ac", "as", "ss", "ssc", "us", "sc", "sv", "sg",
        "sd", "rc", "rcd", "rb", "bc", "cfc", "acf", "bv", "vfb", "vfl", "tsg", "fsv",
        "the", "de", "do", "e",
        // descriptive words
        "club", "calcio", "balompie", "futbol", "football", "verein", "and",
    ]

    // normalized short name (fixture side) -> a token guaranteed to appear in
    // the openfootball name (checked before token matching). For cross-language
    // cases the token/prefix rules can't catch (München≠Munich, Internazionale≠Inter).
    private static let aliases: [String: String] = [
        "bayern munich": "bayern",
        "inter milan": "internazionale",
        "inter": "internazionale",
        "ac milan": "milan",
        "cologne": "koln",
    ]

    /// Two tokens match if equal, or one is a ≥4-char prefix of the other
    /// ("athen" ~ "athens").
    private static func tokensMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let (short, long) = a.count <= b.count ? (a, b) : (b, a)
        return short.count >= 4 && long.hasPrefix(short)
    }

    private static func normalize(_ name: String) -> String {
        name
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
    }

    private static func tokenize(_ name: String) -> [String] {
        let replaced = normalize(name)
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        return replaced
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { !$0.isEmpty && !dropTokens.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    /// Best match for `name` among `candidates`: an alias hint, then exact
    /// token-set equality, then the smaller token set being a subset of the
    /// larger, then ≥2 shared significant tokens. Returns `nil` if nothing
    /// qualifies.
    static func match(_ name: String, among candidates: some Collection<String>) -> String? {
        let normalized = normalize(name)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        if let aliasToken = aliases[normalized],
           let hit = candidates.first(where: { tokenize($0).contains(aliasToken) }) {
            return hit
        }

        let target = tokenize(name)
        guard !target.isEmpty else { return nil }

        var subsetHit: String?
        var bestOverlap: (name: String, shared: Int)?

        for candidate in candidates {
            let tokens = tokenize(candidate)
            guard !tokens.isEmpty else { continue }

            let (small, big) = target.count <= tokens.count ? (target, tokens) : (tokens, target)
            let sharedInSmall = small.filter { t in big.contains { tokensMatch(t, $0) } }.count

            if sharedInSmall == small.count {
                if small.count == big.count { return candidate } // token-set equality
                if subsetHit == nil { subsetHit = candidate }
                continue
            }

            if sharedInSmall >= 2, bestOverlap == nil || sharedInSmall > bestOverlap!.shared {
                bestOverlap = (candidate, sharedInSmall)
            }
        }

        return subsetHit ?? bestOverlap?.name
    }
}
