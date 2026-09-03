//
//  MatchTeam.swift
//  gameday
//

import Foundation

/// One club in a match.
struct MatchTeam: Hashable {
    let name: String
    let badge: String?

    var badgeURL: URL? { badge.flatMap(URL.init(string:)) }
}