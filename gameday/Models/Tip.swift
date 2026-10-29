import Foundation

struct Tip: Identifiable {
    let id: String                  // "<fixtureID>-1x2" or "<fixtureID>-btts" — keep both IDs unique
    let match: Match                 // gives you league color/badge, crests, kickoff
    let market: Market
    let selectionText: String        // what the card displays, e.g. "Arsenal to win"
    let probability: Double          // 0...1 — THIS is what you sort by
    let confidence: Prediction.Confidence

    enum Market {
        case matchResult(Prediction.Outcome)
        case bothTeamsToScore(yes: Bool)
    }

    static func candidates(match: Match, prediction: Prediction) -> [Tip] {
    let matchResultTip = Tip(
        id: "\(prediction.fixtureID)-1x2",
        match: match,
        market: .matchResult(prediction.pick),
        selectionText: prediction.headline(homeName: match.homeTeam.name, awayName: match.awayTeam.name),
        probability: prediction.pickProbability,
        confidence: prediction.confidence
    )

    let bttsYes = prediction.probBTTSYes > 0.5
    let bttsProbability = bttsYes ? prediction.probBTTSYes : (1 - prediction.probBTTSYes)
    let bttsTip = Tip(
        id: "\(prediction.fixtureID)-btts",
        match: match,
        market: .bothTeamsToScore(yes: bttsYes),
        selectionText: bttsYes ? "Both teams to score" : "Both teams not to score",
        probability: bttsProbability,
        confidence: /* see note below */ prediction.confidence
    )

    return [matchResultTip, bttsTip]
}

    /// Every win/BTTS candidate across `matches`, restricted to fixtures
    /// within `leadTime` of kickoff, ranked most-confident first.
    static func ranked(
        matches: [Match],
        predictions: [String: Prediction],
        leadTime: TimeInterval = 72 * 3600
    ) -> [Tip] {
        var candidates: [Tip] = []
        for match in matches {
            guard let prediction = predictions[match.id] else { continue }
            guard match.kickoff.timeIntervalSinceNow <= leadTime else { continue }
            candidates += Tip.candidates(match: match, prediction: prediction)
        }
        return candidates.sorted { $0.probability > $1.probability }
    }
}

