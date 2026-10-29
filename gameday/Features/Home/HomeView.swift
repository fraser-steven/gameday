//
//  HomeView.swift
//  gameday
//

import SwiftUI

struct HomeView: View {
    @State private var model = HomeViewModel()
    @State private var selectedLeagueID: String?
    @State private var appearedMatchIDs: Set<String> = []
    @Namespace private var cardTransition

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("This Week")
                .navigationDestination(for: Match.self) { match in
                    MatchTipView(match: match, prediction: model.prediction(for: match))
                        .navigationTransition(.zoom(sourceID: match.id, in: cardTransition))
                }
        }
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Loading fixtures…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let matches):
            ZStack {
                AnimatedMeshBackground()
                fixtureList(matches)
            }

        case .empty:
            ContentUnavailableView(
                "No Fixtures This Week",
                systemImage: "calendar",
                description: Text("No Premier League, La Liga, Bundesliga or Serie A matches are scheduled between now and Sunday.")
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
            VStack(alignment: .leading, spacing: 20) {
                if let featuredTip = model.featuredTip {
                    NavigationLink(value: featuredTip.match) {
                        HeroTipCard(tip: featuredTip)
                    }
                    .buttonStyle(PressableCardStyle())
                }

                LeagueFilterChips(leagueIDs: APIConfig.leagueIDs, selected: $selectedLeagueID)

                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                    ForEach(groupedByDay(filtered(matches)), id: \.day) { group in
                        Section {
                            ForEach(Array(group.matches.enumerated()), id: \.element.id) { index, match in
                                NavigationLink(value: match) {
                                    FixtureCard(match: match, prediction: model.prediction(for: match))
                                }
                                .matchedTransitionSource(id: match.id, in: cardTransition)
                                .buttonStyle(PressableCardStyle())
                                .modifier(StaggeredAppear(
                                    id: match.id,
                                    index: index,
                                    appearedIDs: $appearedMatchIDs
                                ))
                            }
                        } header: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(dayLabel(for: group.day))
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text(group.day, format: .dateTime.day().month(.wide))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }

    private func filtered(_ matches: [Match]) -> [Match] {
        guard let selectedLeagueID else { return matches }
        return matches.filter { $0.league.id == selectedLeagueID }
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private func groupedByDay(_ matches: [Match]) -> [(day: Date, matches: [Match])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.kickoff) }
        return groups
            .map { (day: $0.key, matches: $0.value.sorted { $0.kickoff < $1.kickoff }) }
            .sorted { $0.day < $1.day }
    }
}

/// Fades/slides a card in the first time it appears, with a delay based on
/// its position in its day section — a one-shot stagger, not a repeating
/// animation. Cards already marked appeared render at rest immediately (no
/// re-animating already-seen cards on a pull-to-refresh).
private struct StaggeredAppear: ViewModifier {
    let id: String
    let index: Int
    @Binding var appearedIDs: Set<String>

    private var hasAppeared: Bool { appearedIDs.contains(id) }

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)
            .onAppear {
                guard !hasAppeared else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index % 8) * 0.05)) {
                    appearedIDs.insert(id)
                }
            }
    }
}

#Preview {
    HomeView()
}
