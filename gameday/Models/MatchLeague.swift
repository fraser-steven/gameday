//
//  MatchLeague.swift
//  gameday
//

import SwiftUI

/// The competition a match belongs to.
struct MatchLeague: Hashable {
    let id: String
    let name: String
    let badge: String?

    var badgeURL: URL? { badge.flatMap(URL.init(string:)) }

    /// TheSportsDB league IDs the app fetches.
    static let premierLeagueID = "4328"
    static let laLigaID = "4335"

    /// Short display name, tidying up TheSportsDB's verbose names.
    var shortName: String {
        switch id {
        case Self.premierLeagueID: "Premier League"
        case Self.laLigaID:        "La Liga"
        default:                    name
        }
    }

    /// Accent colour for the league badge on a card.
    var accentColor: Color {
        switch id {
        case Self.premierLeagueID: Color(red: 0.22, green: 0.00, blue: 0.47) // PL purple
        case Self.laLigaID:        Color(red: 0.90, green: 0.11, blue: 0.20) // La Liga red
        default:                    .accentColor
        }
    }
}