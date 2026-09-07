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
                .navigationTitle("This Week")
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
                "No Fixtures This Week",
                systemImage: "calendar",
                description: Text("No Premier League, La Liga or Champions League matches are scheduled between now and Sunday.")
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
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                ForEach(groupedByDay(matches), id: \.day) { group in
                    Section {
                        ForEach(group.matches) { match in
                            FixtureCard(match: match)
                        }
                    } header: {
                        Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .background(.background)
                    }
                }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }

    private func groupedByDay(_ matches: [Match]) -> [(day: Date, matches: [Match])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.kickoff) }
        return groups
            .map { (day: $0.key, matches: $0.value.sorted { $0.kickoff < $1.kickoff }) }
            .sorted { $0.day < $1.day }
    }
}

#Preview {
    HomeView()
}
