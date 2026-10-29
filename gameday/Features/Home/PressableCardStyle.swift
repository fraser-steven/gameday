//
//  PressableCardStyle.swift
//  gameday
//

import SwiftUI

/// A small scale-down-on-press effect for tappable cards (fixture cards, the
/// hero card) — replaces `.plain`, which gives no tactile feedback at all.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
