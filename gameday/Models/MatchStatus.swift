//
//  MatchStatus.swift
//  gameday
//

import Foundation

/// Where a match is in its lifecycle, normalised from TheSportsDB's `strStatus`.
enum MatchStatus: Hashable {
    case scheduled
    case live(detail: String)
    case finished
    case postponed

    init(rawStatus: String?, postponed: String?) {
        if postponed?.lowercased() == "yes" {
            self = .postponed
            return
        }

        switch rawStatus?.uppercased() {
        case nil, "", "NS", "TBD", "SCHEDULED":
            self = .scheduled
        case "FT", "AET", "PEN", "MATCH FINISHED", "FINISHED":
            self = .finished
        case "PST", "POSTPONED":
            self = .postponed
        case let other?:
            self = .live(detail: other)
        }
    }

    var isFinished: Bool {
        if case .finished = self { return true }
        return false
    }
}