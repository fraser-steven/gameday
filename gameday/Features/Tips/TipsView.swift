import SwiftUI

struct TipsView: View {
    @State private var model = TipsViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Tips")
        }
        .task { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView("Finding this week's best tips…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let tips):
            tipsList(tips)

        case .empty:
            ContentUnavailableView(
                "No Tips Yet",
                systemImage: "sparkles",
                description: Text("Check back closer to kick-off once this week's insights are ready.")
            )

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t Load Tips", systemImage: "wifi.slash")
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

    private func tipsList(_ tips: [Tip]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Today's AI Tips", systemImage: "sparkles")
                    ForEach(Array(tips.enumerated()), id: \.element.id) { index, tip in
                        TipCard(rank: index + 1, tip: tip)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Recommended Accumulator", systemImage: "list.number")
                    accaPlaceholder
                }
            }
            .padding()
        }
        .refreshable { await model.load() }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }

    private var accaPlaceholder: some View {
        Text("Accumulator suggestions will go here")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.fill.quinary, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    TipsView()
}
