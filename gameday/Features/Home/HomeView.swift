//
//  HomeView.swift
//  gameday
//

import SwiftUI

struct HomeView: View {
    @State private var model = HomeViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("GameDay AI")
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading fixtures…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let matches):
            fixtureList(matches)

        case .empty:
            ContentUnavailableView(
                "No Fixtures",
                systemImage: "calendar",
                description: Text("No upcoming Premier League or La Liga matches were found.")
            )

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t Load Fixtures", systemImage: "wifi.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func fixtureList(_ matches: [Match]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(matches) { match in
                    FixtureCard(match: match)
                }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }
}

#Preview {
    HomeView()
}