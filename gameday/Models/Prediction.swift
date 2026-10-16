//
//  Prediction.swift
//  gameday
//
//  A computed prediction for one fixture. Built in-memory by
//  PredictionService (on-device), not decoded from JSON.
//

import Foundation

struct Prediction: Hashable {
    enum Outcome: String {
        case home, draw, away
    }

    enum Confidence: String {
        case low, medium, high
    }

    let fixtureID: String
    let homeTeam: String
    let awayTeam: String
    let kickoff: Date

    let probHome: Double
    let probDraw: Double
    let probAway: Double
    let probBTTSYes: Double

    let pick: Outcome
    let confidence: Confidence
    let rationale: String?
    let modelVersion: String
    let generatedAt: Date
}

extension Prediction {
    var pickProbability: Double {
        switch pick {
        case .home: probHome
        case .draw: probDraw
        case .away: probAway
        }
    }

    /// e.g. "Arsenal to win", "Draw".
    func headline(homeName: String, awayName: String) -> String {
        switch pick {
        case .home: "\(homeName) to win"
        case .away: "\(awayName) to win"
        case .draw: "Draw"
        }
    }

    var bttsYesPercent: Int { Int((probBTTSYes * 100).rounded()) }
    var bttsNoPercent: Int { 100 - bttsYesPercent }

    var generatedAtRelative: String {
        generatedAt.formatted(.relative(presentation: .named))
    }
}
