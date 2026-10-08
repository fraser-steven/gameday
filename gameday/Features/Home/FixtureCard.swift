//
//  FixtureCard.swift
//  gameday
//

import SwiftUI

/// A single match shown on the Home screen.
struct FixtureCard: View {
    let match: Match
    var hasTip: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 12) {
                team(match.homeTeam)
                centre
                team(match.awayTeam)
            }

            if hasTip {
                Label("View insight", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(match.league.accentColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quinary, in: .rect(cornerRadius: 16))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(hasTip ? "Double tap for the match insight" : "")
    }

    private var header: some View {
        HStack {
            Text(match.league.shortName)
                .font(.caption.weight(.semibold))
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
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .live(let detail):
            Text(detail.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
        case .finished:
            Text("Full time")
                .font(.caption)
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
            } else {
                Text("vs")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 44)
    }

    private func team(_ team: MatchTeam) -> some View {
        VStack(spacing: 8) {
            AsyncImage(url: team.badgeURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 36, height: 36)

            Text(team.name)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
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

    return FixtureCard(match: try! JSONDecoder().decode(Match.self, from: json))
        .padding()
}