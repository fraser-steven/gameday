//
//  HeroTipCard.swift
//  gameday
//

import SwiftUI

/// The week's single highest-confidence tip, shown big at the top of Home.
struct HeroTipCard: View {
    let tip: Tip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("This Week's Top Pick", systemImage: "star.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 20) {
                crest(tip.match.homeTeam)

                VStack(spacing: 2) {
                    Text("\(Int((tip.probability * 100).rounded()))%")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("likely")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)

                crest(tip.match.awayTeam)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(tip.match.homeTeam.name) v \(tip.match.awayTeam.name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text(tip.selectionText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tip.match.league.accentColor, tip.match.league.accentColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 24))
        .compositingGroup()
        .shadow(color: tip.match.league.accentColor.opacity(0.35), radius: 16, x: 0, y: 8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "This week's top pick. \(tip.match.league.shortName). \(tip.selectionText). "
            + "\(Int((tip.probability * 100).rounded())) percent likely."
        )
    }

    private func crest(_ team: MatchTeam) -> some View {
        AsyncImage(url: team.badgeURL) { image in
            image.resizable().scaledToFit().padding(10)
        } placeholder: {
            Image(systemName: "shield.fill")
                .font(.title)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 60, height: 60)
        .background(.white.opacity(0.15), in: .circle)
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

    return HeroTipCard(tip: Tip(
        id: "preview", match: match, market: .matchResult(.home),
        selectionText: "Arsenal to win", probability: 0.74, confidence: .high
    ))
    .padding()
}
