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
}

