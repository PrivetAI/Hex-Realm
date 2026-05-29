import SwiftUI

// ============================================================================
// Result overlay shown when a match ends.
// ============================================================================
struct ResultOverlay: View {
    let state: MatchState
    let onContinue: () -> Void
    let onRetry: () -> Void
    @State private var appear = false

    private var isWin: Bool { state.outcome == .victory }
    private var starCount: Int {
        guard isWin, state.isCampaign, let def = Campaign.map(state.campaignMapId) else { return 0 }
        return MatchEngine.stars(turn: state.turn, par: def.parTurns, good: def.goodTurns)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    FlatHexShape()
                        .fill(isWin ? HexPalette.gold : HexPalette.lock)
                        .frame(width: 86, height: 86)
                    if isWin {
                        CrownShape().fill(.white).frame(width: 44, height: 30)
                    } else {
                        ShieldShape().fill(.white.opacity(0.85)).frame(width: 38, height: 44)
                    }
                }
                .scaleEffect(appear ? 1 : 0.5)

                Text(isWin ? "VICTORY" : "DEFEAT")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(isWin ? HexPalette.crimsonDeep : HexPalette.textSecondary)

                if state.isCampaign && isWin {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            StarShape(points: 5)
                                .fill(i < starCount ? HexPalette.gold : HexPalette.track)
                                .frame(width: 34, height: 34)
                        }
                    }
                }

                VStack(spacing: 6) {
                    statRow("Turns Taken", "\(state.turn)")
                    statRow("Land Controlled", "\(Int(state.controlPct(0) * 100))%")
                    statRow("Armies Fielded", "\(state.totalArmies(0))")
                    statRow("Difficulty", state.difficulty.label)
                }
                .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    HexPrimaryButton(title: isWin ? "Continue" : "Back to Menu",
                                     color: isWin ? HexPalette.crimson : HexPalette.textSecondary) {
                        onContinue()
                    }
                    Button(action: onRetry) {
                        Text("Retry Map")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(HexPalette.crimsonDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 13)
                                            .stroke(HexPalette.crimson, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(HexPalette.panel))
            .padding(.horizontal, 28)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { appear = true } }
    }

    private func statRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(HexPalette.textSecondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(HexPalette.textPrimary)
        }
    }
}

// ============================================================================
// Upgrade / Tech panel — spend gold on persistent (this-match) upgrades.
// ============================================================================
struct UpgradePanel: View {
    @EnvironmentObject var store: HexRealmStore
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                HexBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        if let m = store.activeMatch {
                            HStack(spacing: 6) {
                                CoinGlyph(size: 20)
                                Text("\(m.players[0].gold) gold")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundColor(HexPalette.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                            ForEach(UpgradeKind.allCases) { kind in
                                upgradeCard(kind, m)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationBarTitle("Tech Tree", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(HexPalette.crimsonDeep))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func upgradeCard(_ kind: UpgradeKind, _ m: MatchState) -> some View {
        let owned = m.players[0].hasUpgrade(kind)
        let canAfford = m.players[0].gold >= kind.cost
        return HStack(spacing: 12) {
            ResearchGlyph(color: owned ? HexPalette.success : HexPalette.research, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(kind.detail).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            if owned {
                Text("OWNED").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(HexPalette.success)
            } else {
                Button(action: { buy(kind) }) {
                    HStack(spacing: 3) {
                        CoinGlyph(size: 13)
                        Text("\(kind.cost)").font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(canAfford ? HexPalette.crimson : HexPalette.lock))
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)
            }
        }
        .padding(12)
        .hexCard()
    }

    private func buy(_ kind: UpgradeKind) {
        store.mutate { st in
            guard !st.players[0].hasUpgrade(kind), st.players[0].gold >= kind.cost else { return }
            st.players[0].gold -= kind.cost
            st.players[0].upgrades.append(kind.rawValue)
            if kind == .extraAction { st.actionsRemaining += 1 }
        }
        store.recordUpgrade()
    }
}

// ============================================================================
// Build panel — construct a building on the selected owned hex.
// ============================================================================
struct BuildPanel: View {
    let coord: HexCoord
    @EnvironmentObject var store: HexRealmStore
    @Environment(\.presentationMode) private var presentationMode

    private let options: [BuildingKind] = [.farm, .barracks, .fort]

    var body: some View {
        NavigationView {
            ZStack {
                HexBackground()
                VStack(spacing: 12) {
                    if let m = store.activeMatch {
                        HStack(spacing: 6) {
                            CoinGlyph(size: 20)
                            Text("\(m.players[0].gold) gold")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(HexPalette.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(options, id: \.rawValue) { b in
                            buildCard(b, m)
                        }
                        Spacer()
                    }
                }
                .padding(16)
            }
            .navigationBarTitle("Construct", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(HexPalette.crimsonDeep))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func buildCard(_ b: BuildingKind, _ m: MatchState) -> some View {
        let canAfford = m.players[0].gold >= b.cost
        return HStack(spacing: 12) {
            FlatHexShape().fill(HexPalette.gold.opacity(0.3))
                .frame(width: 30, height: 30)
                .overlay(FlatHexShape().stroke(HexPalette.goldDeep, lineWidth: 1.5).frame(width: 30, height: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text(b.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(b.detail).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            Button(action: { build(b) }) {
                HStack(spacing: 3) {
                    CoinGlyph(size: 13)
                    Text("\(b.cost)").font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(canAfford ? HexPalette.crimson : HexPalette.lock))
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
        .padding(12)
        .hexCard()
    }

    private func build(_ b: BuildingKind) {
        var built = false
        store.mutate { st in
            guard let idx = st.tileIndex(coord), st.tiles[idx].owner == 0,
                  st.tiles[idx].building == .none, st.players[0].gold >= b.cost else { return }
            st.tiles[idx].building = b
            st.players[0].gold -= b.cost
            built = true
        }
        if built { store.recordBuilding() }
        presentationMode.wrappedValue.dismiss()
    }
}
