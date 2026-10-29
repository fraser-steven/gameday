//
//  ResultBar.swift
//  gameday
//

import SwiftUI

/// A 1X2 (home/draw/away) probability bar. Used full-size with labels in
/// `MatchTipView`, and compact without labels inline on `FixtureCard`.
struct ResultBar: View {
    let prediction: Prediction
    let accentColor: Color
    var showsLabels: Bool = true
    var height: CGFloat = 10

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(width: geo.size.width, fraction: prediction.probHome, color: accentColor)
                    segment(width: geo.size.width, fraction: prediction.probDraw, color: .gray)
                    segment(width: geo.size.width, fraction: prediction.probAway, color: accentColor.opacity(0.5))
                }
            }
            .frame(height: height)
            .clipShape(.capsule)

            if showsLabels {
                HStack {
                    outcomeLabel("Home", prediction.probHome)
                    Spacer()
                    outcomeLabel("Draw", prediction.probDraw)
                    Spacer()
                    outcomeLabel("Away", prediction.probAway)
                }
            }
        }
    }

    private func segment(width: CGFloat, fraction: Double, color: Color) -> some View {
        color.frame(width: max(2, width * fraction))
    }

    private func outcomeLabel(_ title: String, _ probability: Double) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("\(Int((probability * 100).rounded()))%").font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}
