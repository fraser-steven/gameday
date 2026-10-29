//
//  FixtureCard.swift
//  gameday
//

import SwiftUI

/// A single match shown on the Home screen.
struct FixtureCard: View {
    let match: Match
    var prediction: Prediction? = nil

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(match.league.accentColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 8) {
                    team(match.homeTeam)
                    centre
                    team(match.awayTeam)
                }

                if let prediction {
                    insightRow(prediction)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary)
        .clipShape(.rect(cornerRadius: 18))
        .compositingGroup()
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(prediction != nil ? "Double tap for the match insight" : "")
    }

    private var header: some View {
        HStack {
            Text(match.league.shortName)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(match.league.accentColor, in: .capsule)

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch match.status {
        case .scheduled:
            VStack(alignment: .trailing, spacing: 2) {
                Text(match.kickoff, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                Text(match.kickoff, format: .dateTime.hour().minute())
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .live(let detail):
            Label(detail.uppercased(), systemImage: "dot.radiowaves.left.and.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
        case .finished:
            Text("Full time")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        case .postponed:
            Text("Postponed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }

    private var centre: some View {
        Group {
            if match.hasScore {
                Text("\(match.homeScore ?? 0) – \(match.awayScore ?? 0)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.fill.secondary, in: .capsule)
            } else {
                Text("vs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 52)
        .multilineTextAlignment(.center)
    }

    private func team(_ team: MatchTeam) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: team.badgeURL) { image in
                image.resizable().scaledToFit().padding(7)
            } placeholder: {
                Image(systemName: "shield.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 44, height: 44)
            .background(.fill.quinary, in: .circle)

            Text(team.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightRow(_ prediction: Prediction) -> some View {
        VStack(spacing: 10) {
            Divider()
            ResultBar(prediction: prediction, accentColor: match.league.accentColor, showsLabels: false, height: 6)
            HStack {
                Label("Match Insight", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(match.league.accentColor)
                Spacer()
                Text("\(Int((prediction.pickProbability * 100).rounded()))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var accessibilityLabel: String {
        let teams = "\(match.homeTeam.name) versus \(match.awayTeam.name)"
        let when: String
        switch match.status {
        case .scheduled:
            when = match.kickoff.formatted(date: .abbreviated, time: .shortened)
        case .finished where match.hasScore:
            when = "Full time, \(match.homeScore ?? 0) \(match.awayScore ?? 0)"
        case .finished:
            when = "Full time"
        case .live(let detail):
            when = "Live, \(detail)"
        case .postponed:
            when = "Postponed"
        }
        return "\(match.league.shortName). \(teams). \(when)."
    }
}

#Preview {
    let json = """
    {
      "idEvent": "2506226",
      "strTimestamp": "2026-09-03T19:00:00",
      "idLeague": "4335", "strLeague": "Spanish La Liga", "strLeagueBadge": null,
      "strHomeTeam": "Real Sociedad", "strAwayTeam": "Celta Vigo",
      "strHomeTeamBadge": null, "strAwayTeamBadge": null,
      "intHomeScore": null, "intAwayScore": null,
      "intRound": "6", "strVenue": "Reale Arena", "strStatus": "NS", "strPostponed": "no"
    }
    """.data(using: .utf8)!
    let match = try! JSONDecoder().decode(Match.self, from: json)

    let prediction = Prediction(
        fixtureID: match.id, homeTeam: match.homeTeam.name, awayTeam: match.awayTeam.name,
        kickoff: match.kickoff, probHome: 0.48, probDraw: 0.28, probAway: 0.24, probBTTSYes: 0.57,
        pick: .home, confidence: .medium, rationale: nil, modelVersion: "preview", generatedAt: .now
    )

    return ScrollView {
        VStack(spacing: 12) {
            FixtureCard(match: match, prediction: prediction)
            FixtureCard(match: match)
        }
        .padding()
    }
}
