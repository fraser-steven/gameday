//
//  MatchTipView.swift
//  gameday
//
//  The model's lean on a match: the result and both-teams-to-score, or a
//  "check back later" state. Presentation-agnostic — HomeView pushes this
//  as a navigation destination (with a zoom transition from the tapped
//  card), so it owns no NavigationStack or dismiss chrome of its own.
//

import SwiftUI

struct MatchTipView: View {
    let match: Match
    let prediction: Prediction?

    /// A tip is only shown within this window of kick-off; further out we show a
    /// countdown instead, so users see the freshest read.
    private static let leadTime: TimeInterval = 72 * 3600

    private var isWithinLeadTime: Bool {
        match.kickoff.timeIntervalSinceNow <= Self.leadTime
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                matchHeader

                if let prediction, isWithinLeadTime {
                    tip(prediction)
                } else if !isWithinLeadTime {
                    comeBackLater
                } else {
                    unavailable
                }
            }
            .padding()
        }
        .navigationTitle("Match Insight")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var matchHeader: some View {
        VStack(spacing: 6) {
            Text(match.league.shortName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(match.league.accentColor, in: .capsule)

            Text("\(match.homeTeam.name) v \(match.awayTeam.name)")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(match.kickoff, format: .dateTime.weekday(.wide).day().month().hour().minute())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tip

    private func tip(_ prediction: Prediction) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(prediction.headline(homeName: match.homeTeam.name, awayName: match.awayTeam.name))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    confidenceBadge(prediction.confidence)
                    Text("\(percent(prediction.pickProbability)) likely")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ResultBar(prediction: prediction, accentColor: match.league.accentColor)

            bttsRow(prediction)

            if let rationale = prediction.rationale, !rationale.isEmpty {
                Text(rationale)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.fill.quinary, in: .rect(cornerRadius: 12))
            }

            footer(prediction)
        }
    }

    private func bttsRow(_ prediction: Prediction) -> some View {
        HStack {
            Text("Both teams to score")
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("Yes \(prediction.bttsYesPercent)%  ·  No \(prediction.bttsNoPercent)%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
    }

    private func confidenceBadge(_ confidence: Prediction.Confidence) -> some View {
        let (label, color): (String, Color) = switch confidence {
        case .high: ("High confidence", .green)
        case .medium: ("Medium confidence", .orange)
        case .low: ("Low confidence", .secondary)
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private func footer(_ prediction: Prediction) -> some View {
        Text("Updated \(prediction.generatedAtRelative) · Model insight, not betting advice. 18+")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Empty states

    private var comeBackLater: some View {
        ContentUnavailableView {
            Label("Check Back Closer to Kick-off", systemImage: "clock")
        } description: {
            Text("The insight for this match will be ready about 3 days before kick-off — \(availableFrom).")
        }
    }

    private var unavailable: some View {
        ContentUnavailableView(
            "No Insight Yet",
            systemImage: "sparkles",
            description: Text("We couldn't generate an insight for this match. Check back soon.")
        )
    }

    private var availableFrom: String {
        let date = match.kickoff.addingTimeInterval(-Self.leadTime)
        return date.formatted(.relative(presentation: .named))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
