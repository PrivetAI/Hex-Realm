import SwiftUI

struct SkirmishView: View {
    @EnvironmentObject var store: HexRealmStore
    @State private var size: MapSize = .medium
    @State private var aiCount = 2
    @State private var difficulty: Difficulty = .normal
    @State private var showPicker = false
    @State private var goToMatch = false

    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 16) {
                    Text("Custom Battle")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                        .padding(.top, 4)

                    resumeBanner

                    optionGroup(title: "Map Size") {
                        segmented(["Small", "Medium", "Large"],
                                  selected: size.rawValue) { idx in
                            size = MapSize(rawValue: idx) ?? .medium
                        }
                    }

                    optionGroup(title: "Opponents") {
                        segmented(["1 AI", "2 AI", "3 AI"], selected: aiCount - 1) { idx in
                            aiCount = idx + 1
                        }
                    }

                    optionGroup(title: "Difficulty") {
                        segmented(["Easy", "Normal", "Hard"],
                                  selected: difficulty.rawValue) { idx in
                            difficulty = Difficulty(rawValue: idx) ?? .normal
                        }
                    }

                    VStack(spacing: 6) {
                        Text("Configuration")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        summaryRow("Map", "\(size.label) (radius \(size.radius))")
                        summaryRow("Factions", "You + \(aiCount) AI")
                        summaryRow("Difficulty", difficulty.label)
                        summaryRow("Win at", "100% capitals or 85% land")
                    }
                    .padding(12).hexCard()

                    HexPrimaryButton(title: "Pick Faction & Start", color: HexPalette.crimson) {
                        showPicker = true
                    }
                    Spacer(minLength: 12)
                }
                .padding(16)
            }

            NavigationLink(destination: MatchView().environmentObject(store),
                           isActive: $goToMatch) { EmptyView() }.hidden()
        }
        .navigationBarTitle("Skirmish", displayMode: .inline)
        .sheet(isPresented: $showPicker) {
            FactionPicker(title: "Skirmish",
                          subtitle: "\(size.label) • \(difficulty.label) • \(aiCount) AI") { fid in
                store.startSkirmish(size: size, aiCount: aiCount, difficulty: difficulty, factionId: fid)
                showPicker = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { goToMatch = true }
            }
        }
    }

    @ViewBuilder private var resumeBanner: some View {
        if let m = store.activeMatch, !store.activeIsCampaign, m.outcome == .ongoing {
            Button(action: { goToMatch = true }) {
                HStack(spacing: 10) {
                    PauseGlyph(color: .white, size: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Resume Skirmish")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("Turn \(m.turn) • \(m.size.label) • \(m.difficulty.label)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    ChevronGlyph(color: .white, size: 16)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(HexPalette.crimson))
            }
            .buttonStyle(.plain)
        }
    }

    private func optionGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(HexPalette.textMuted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmented(_ labels: [String], selected: Int, onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { i in
                Button(action: { onSelect(i) }) {
                    Text(labels[i])
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(selected == i ? .white : HexPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(selected == i ? HexPalette.crimson : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(HexPalette.panelSunken))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HexPalette.panelRaised, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(HexPalette.textSecondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(HexPalette.textPrimary)
        }
    }
}
