//
//  Prediction.swift
//  gameday
//

import Foundation

/// A stored prediction for one fixture, from the Supabase `predictions` table.
struct Prediction: Decodable, Hashable {
    enum Outcome: String, Decodable {
        case home, draw, away
    }

    enum Confidence: String, Decodable {
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

    private enum CodingKeys: String, CodingKey {
        case fixtureID = "fixture_id"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case kickoff
        case probHome = "prob_home"
        case probDraw = "prob_draw"
        case probAway = "prob_away"
        case probBTTSYes = "prob_btts_yes"
        case pick
        case confidence
        case rationale
        case modelVersion = "model_version"
        case generatedAt = "generated_at"
    }
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
