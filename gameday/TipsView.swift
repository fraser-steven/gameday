//
//  TipsView.swift
//  gameday
//
//  Created by Fraser Steven on 22/05/2026.
//

import SwiftUI

import SwiftUI

struct TipsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Today's AI Tips")) {
                    Text("AI Predictions will appear here")
                        .foregroundStyle(.secondary)
                }
                
                Section(header: Text("Recommended Accumulators")) {
                    Text("Accumulator suggestions will go here")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tips")
        }
    }
}

#Preview {
    TipsView()
}
