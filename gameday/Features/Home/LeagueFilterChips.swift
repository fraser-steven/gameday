//
//  LeagueFilterChips.swift
//  gameday
//

import SwiftUI

/// "All" + one chip per modelled league, for filtering the Home fixture list.
struct LeagueFilterChips: View {
    let leagueIDs: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", color: .primary, isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(leagueIDs, id: \.self) { id in
                    let league = MatchLeague(id: id, name: id, badge: nil)
                    chip(label: league.shortName, color: league.accentColor, isSelected: selected == id) {
                        selected = id
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()
    }

    private func chip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : color)
                .background(isSelected ? color : color.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
    }
}

#Preview {
    @Previewable @State var selected: String? = MatchLeague.premierLeagueID
    return LeagueFilterChips(leagueIDs: [
        MatchLeague.premierLeagueID, MatchLeague.laLigaID,
        MatchLeague.bundesligaID, MatchLeague.serieAID,
    ], selected: $selected)
    .padding()
}
