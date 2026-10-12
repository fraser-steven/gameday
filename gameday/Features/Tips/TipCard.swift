import SwiftUI

/// A single ranked tip shown on the Tips screen.
struct TipCard: View {
    let rank: Int
    let tip: Tip

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rankBadge

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    leagueBadge
                    marketBadge
                }

                matchupRow

                Text(tip.selectionText)
                    .font(.headline)
            }

            Spacer(minLength: 4)

            VStack(spacing: 6) {
                Text("\(Int((tip.probability * 100).rounded()))%")
                    .font(.title2.weight(.bold).monospacedDigit())
                confidencePill
            }
        }
        .padding(16)
        .background(.fill.quinary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rank \(rank). \(tip.match.league.shortName). \(tip.selectionText). "
            + "\(Int((tip.probability * 100).rounded())) percent, \(confidenceLabel.lowercased()) confidence."
        )
    }

    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor.opacity(0.18))
                .frame(width: 34, height: 34)
            Text("\(rank)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(rankColor)
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: Color(red: 0.80, green: 0.64, blue: 0.13) // gold
        case 2: Color(red: 0.60, green: 0.60, blue: 0.64) // silver
        case 3: Color(red: 0.72, green: 0.45, blue: 0.20) // bronze
        default: .secondary
        }
    }

    private var leagueBadge: some View {
        Text(tip.match.league.shortName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tip.match.league.accentColor, in: .capsule)
    }

    private var marketBadge: some View {
        Label(marketLabel, systemImage: marketIcon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var marketLabel: String {
        switch tip.market {
        case .matchResult: "Match Result"
        case .bothTeamsToScore: "BTTS"
        }
    }

    private var marketIcon: String {
        switch tip.market {
        case .matchResult: "trophy.fill"
        case .bothTeamsToScore: "soccerball"
        }
    }

    private var matchupRow: some View {
        HStack(spacing: 6) {
            crest(tip.match.homeTeam.badgeURL)
            Text(tip.match.homeTeam.name).lineLimit(1)
            Text("v").foregroundStyle(.tertiary)
            crest(tip.match.awayTeam.badgeURL)
            Text(tip.match.awayTeam.name).lineLimit(1)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func crest(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "shield.fill").foregroundStyle(.tertiary)
        }
        .frame(width: 16, height: 16)
    }

    private var confidencePill: some View {
        Text(confidenceLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(confidenceColor)
    }

    private var confidenceLabel: String {
        switch tip.confidence {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    private var confidenceColor: Color {
        switch tip.confidence {
        case .high: .green
        case .medium: .orange
        case .low: .secondary
        }
    }
}

#Preview {
    let json = """
    {
      "idEvent": "2506226",
      "strTimestamp": "2026-09-03T19:00:00",
      "idLeague": "4328", "strLeague": "English Premier League", "strLeagueBadge": null,
      "strHomeTeam": "Arsenal", "strAwayTeam": "Chelsea",
      "strHomeTeamBadge": null, "strAwayTeamBadge": null,
      "intHomeScore": null, "intAwayScore": null,
      "intRound": "6", "strVenue": null, "strStatus": "NS", "strPostponed": "no"
    }
    """.data(using: .utf8)!
    let match = try! JSONDecoder().decode(Match.self, from: json)

    return VStack(spacing: 12) {
        TipCard(rank: 1, tip: Tip(
            id: "1", match: match, market: .matchResult(.home),
            selectionText: "Arsenal to win", probability: 0.74, confidence: .high
        ))
        TipCard(rank: 2, tip: Tip(
            id: "2", match: match, market: .bothTeamsToScore(yes: true),
            selectionText: "Both teams to score", probability: 0.61, confidence: .medium
        ))
    }
    .padding()
}
