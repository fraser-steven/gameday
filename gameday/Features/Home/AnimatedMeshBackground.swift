//
//  AnimatedMeshBackground.swift
//  gameday
//

import SwiftUI

/// A slow, softly-drifting mesh gradient behind the Home screen, cycling
/// through the four league accent colors. Heavily blurred and low-opacity so
/// it reads as atmosphere, not a distraction — content on top stays fully
/// legible. Driven at ~12fps via `.periodic`, not `.animation`, since a slow
/// drift doesn't need (and shouldn't pay for) full frame-rate redraws.
struct AnimatedMeshBackground: View {
    private static let colors: [Color] = [
        MatchLeague(id: MatchLeague.premierLeagueID, name: "", badge: nil).accentColor,
        MatchLeague(id: MatchLeague.laLigaID, name: "", badge: nil).accentColor,
        MatchLeague(id: MatchLeague.bundesligaID, name: "", badge: nil).accentColor,
        MatchLeague(id: MatchLeague.serieAID, name: "", badge: nil).accentColor,
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: meshPoints(t: t), colors: meshColors)
                .opacity(0.18)
                .blur(radius: 40)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var meshColors: [Color] {
        let c = Self.colors
        return [
            c[0], c[1], c[2],
            c[3], c[0], c[1],
            c[2], c[3], c[0],
        ]
    }

    /// 3×3 grid; corners stay anchored so the gradient doesn't tear at the
    /// screen edges, the 5 interior/edge points drift gently.
    private func meshPoints(t: Double) -> [SIMD2<Float>] {
        func wiggle(_ base: SIMD2<Float>, seed: Double, amount: Float = 0.12) -> SIMD2<Float> {
            let dx = Float(sin(t * 0.3 + seed)) * amount
            let dy = Float(cos(t * 0.25 + seed * 1.3)) * amount
            return SIMD2(min(max(base.x + dx, 0), 1), min(max(base.y + dy, 0), 1))
        }

        return [
            SIMD2(0, 0), wiggle(SIMD2(0.5, 0), seed: 1), SIMD2(1, 0),
            wiggle(SIMD2(0, 0.5), seed: 2), wiggle(SIMD2(0.5, 0.5), seed: 3), wiggle(SIMD2(1, 0.5), seed: 4),
            SIMD2(0, 1), wiggle(SIMD2(0.5, 1), seed: 5), SIMD2(1, 1),
        ]
    }
}

#Preview {
    AnimatedMeshBackground()
}
