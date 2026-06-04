import SwiftUI

// ============================================================================
// MatchView — the full-screen battle screen. Pushed via NavigationLink from
// Campaign / Skirmish. Hosts the HUD, the hex map, the selected-hex info panel,
// the End Turn button, the pause menu, build/upgrade sheets, and the result
// overlay (Victory / Defeat with stars + stats).
// ============================================================================

struct MatchView: View {
    @EnvironmentObject var store: HexRealmStore
    @Environment(\.presentationMode) private var presentationMode

    @State private var selected: HexCoord? = nil
    @State private var showPause = false
    @State private var showUpgrades = false
    @State private var showBuild = false
    @State private var resultShown = false
    @State private var lastLogText: String? = nil

    private var match: MatchState? { store.activeMatch }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HexBackground()

                if let m = store.activeMatch {
                    VStack(spacing: 0) {
                        hud(m)
                        // Map area — pass the geometry size (screenSize) into the map.
                        ZStack {
                            HexMapView(state: m,
                                       screenSize: mapAreaSize(geo),
                                       selected: selected,
                                       reachable: reachableTargets(m),
                                       onTapHex: { handleTap($0, m) })
                                .frame(width: mapAreaSize(geo).width,
                                       height: mapAreaSize(geo).height)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        infoPanel(m)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // no active match — pop back
                    Color.clear.onAppear { presentationMode.wrappedValue.dismiss() }
                }

                // toast for latest combat log line
                if let txt = lastLogText {
                    VStack {
                        Spacer().frame(height: 6)
                        Text(txt)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(HexPalette.textPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(HexPalette.panel)
                                            .shadow(color: .black.opacity(0.12), radius: 6, y: 2))
                            .padding(.top, 60)
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(15)
                }

                // result overlay
                if let m = store.activeMatch, m.outcome != .ongoing, resultShown {
                    ResultOverlay(state: m,
                                  onContinue: { exitMatch() },
                                  onRetry: { retry(m) })
                        .zIndex(50)
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: { showPause = true }) {
                HStack(spacing: 6) {
                    PauseGlyph(color: HexPalette.crimsonDeep, size: 16)
                    Text("Menu").font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(HexPalette.crimsonDeep)
                }
            },
            trailing: Button(action: { showUpgrades = true }) {
                HStack(spacing: 6) {
                    ResearchGlyph(color: HexPalette.research, size: 16)
                    Text("Tech").font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(HexPalette.research)
                }
            }
        )
        .sheet(isPresented: $showUpgrades) {
            UpgradePanel().environmentObject(store)
        }
        .sheet(isPresented: $showBuild) {
            if let s = selected { BuildPanel(coord: s).environmentObject(store) }
        }
        .alert(isPresented: $showPause) {
            Alert(title: Text("Paused"),
                  message: Text("Your progress is saved automatically."),
                  primaryButton: .destructive(Text("Resign Match")) { resign() },
                  secondaryButton: .cancel(Text("Resume")))
        }
        .onChange(of: store.activeMatch?.outcome) { outcome in
            if let o = outcome, o != .ongoing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { resultShown = true }
                }
            }
        }
    }

    // -- layout helpers -----------------------------------------------------
    private func mapAreaSize(_ geo: GeometryProxy) -> CGSize {
        // reserve space for HUD (~84) and info panel (~150)
        let h = max(160, geo.size.height - 84 - 150)
        return CGSize(width: geo.size.width, height: h)
    }

    // -- HUD ----------------------------------------------------------------
    private func hud(_ m: MatchState) -> some View {
        let prev = MatchEngine.production(m, owner: 0)
        return HStack(spacing: 10) {
            statChip(icon: AnyView(CoinGlyph(size: 18)),
                     value: "\(m.players[0].gold)", sub: "+\(prev.gold)")
            statChip(icon: AnyView(ArmyGlyph(color: Factions.color(0), size: 18)),
                     value: "\(m.totalArmies(0))", sub: "+\(prev.armies)")
            statChip(icon: AnyView(HexCampaignIcon(color: HexPalette.crimson, size: 18)),
                     value: "\(Int(m.controlPct(0) * 100))%",
                     sub: "of \(Int(m.targetControlPct * 100))%")
            Spacer(minLength: 0)
            VStack(spacing: 1) {
                Text("TURN").font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(HexPalette.textMuted)
                Text("\(m.turn)").font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(HexPalette.panel.opacity(0.92))
        .overlay(Rectangle().fill(HexPalette.panelRaised).frame(height: 1), alignment: .bottom)
    }

    private func statChip(icon: AnyView, value: String, sub: String) -> some View {
        HStack(spacing: 5) {
            icon.frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(sub).font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(HexPalette.textMuted)
            }
        }
    }

    // -- Info panel (selected hex + actions) --------------------------------
    private func infoPanel(_ m: MatchState) -> some View {
        VStack(spacing: 8) {
            if let sel = selected, let t = m.tile(sel) {
                HStack(spacing: 10) {
                    TerrainGlyph(terrain: t.terrain, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(t.terrain.name)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(HexPalette.textPrimary)
                            if t.isCapital {
                                Text("CAPITAL").font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(HexPalette.gold))
                            }
                        }
                        Text(ownerLabel(t)).font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(HexPalette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(spacing: 4) {
                            ArmyGlyph(color: Factions.color(t.owner), size: 14)
                            Text("\(t.armies)").font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(HexPalette.textPrimary)
                        }
                        Text("def x\(String(format: "%.2f", t.terrain.defenseBonus * t.building.defenseBonus))")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                    }
                }
                if t.owner == 0 {
                    HStack(spacing: 8) {
                        Text(t.building == .none ? "No building" : "\(t.building.title): \(t.building.detail)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(HexPalette.textSecondary)
                        Spacer()
                        if t.building == .none {
                            Button(action: { showBuild = true }) {
                                Text("Build").font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(Capsule().fill(HexPalette.research))
                            }.buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("Tap an adjacent owned hex to select, then tap this hex to attack.")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(HexPalette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Select one of your hexes to move or attack from.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Text("Actions: \(m.actionsRemaining)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(m.actionsRemaining > 0 ? HexPalette.success : HexPalette.danger)
                Spacer()
                HexPrimaryButton(title: "End Turn", color: HexPalette.crimson) {
                    endTurn()
                }
                .frame(width: 150)
            }
        }
        .padding(12)
        .background(HexPalette.panel.opacity(0.95))
        .overlay(Rectangle().fill(HexPalette.panelRaised).frame(height: 1), alignment: .top)
    }

    private func ownerLabel(_ t: HexTile) -> String {
        if t.owner < 0 { return "Neutral territory" }
        let f = Factions.def(store.activeMatch!.players[t.owner].factionId)
        return t.owner == 0 ? "\(f.name) (You)" : f.name
    }

    // -- interaction --------------------------------------------------------
    private func reachableTargets(_ m: MatchState) -> Set<HexCoord> {
        guard let sel = selected, let t = m.tile(sel), t.owner == 0, t.armies >= 2 else { return [] }
        var out: Set<HexCoord> = []
        for nc in sel.neighbors() {
            if let nt = m.tile(nc), nt.terrain.isPassable { out.insert(nc) }
        }
        return out
    }

    private func handleTap(_ c: HexCoord, _ m: MatchState) {
        guard m.outcome == .ongoing else { return }
        guard let tapped = m.tile(c) else { return }

        // If we have a selection and tapped an adjacent passable hex -> act.
        if let sel = selected, sel != c, sel.distance(to: c) == 1,
           let from = m.tile(sel), from.owner == 0, from.armies >= 2,
           tapped.terrain.isPassable, m.actionsRemaining > 0 {
            if tapped.owner == 0 {
                // reinforce — costs gold
                let cost = MatchEngine.reinforceCost(m, owner: 0)
                if m.players[0].gold >= cost {
                    store.mutate { st in
                        if MatchEngine.reinforce(&st, from: sel, to: c) {
                            st.players[0].gold -= cost
                            st.actionsRemaining -= 1
                        }
                    }
                    selected = c
                }
            } else {
                // attack
                store.mutate { st in
                    if let entry = MatchEngine.resolveAttack(&st, from: sel, to: c) {
                        st.actionsRemaining -= 1
                        store.combatLog.append(entry)
                        flashLog(entry.text)
                    }
                    MatchEngine.updateOutcome(&st)
                }
                // keep selection on origin (it still holds 1)
            }
            return
        }

        // Otherwise just (re)select.
        if tapped.owner == 0 {
            selected = c
        } else {
            // selecting an enemy/neutral shows info but cannot act from it
            selected = c
        }
    }

    private func flashLog(_ text: String) {
        withAnimation { lastLogText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { lastLogText = nil }
        }
    }

    private func endTurn() {
        guard let m = store.activeMatch, m.outcome == .ongoing else { return }
        selected = nil
        store.mutate { st in
            var log: [CombatLogEntry] = []
            MatchEngine.endPlayerTurn(&st, log: &log)
            store.combatLog.append(contentsOf: log)
        }
        if let last = store.combatLog.last { flashLog(last.text) }
    }

    private func resign() {
        store.mutate { st in
            st.outcome = .defeat
        }
        withAnimation { resultShown = true }
    }

    private func retry(_ m: MatchState) {
        // restart same map / settings
        if m.isCampaign, let def = Campaign.map(m.campaignMapId) {
            store.startCampaign(def, factionId: m.players[0].factionId)
        } else {
            store.startSkirmish(size: m.size,
                                aiCount: m.players.count - 1,
                                difficulty: m.difficulty,
                                factionId: m.players[0].factionId)
        }
        selected = nil
        resultShown = false
    }

    private func exitMatch() {
        store.clearActiveMatch()
        presentationMode.wrappedValue.dismiss()
    }
}

// Small pause (two-bar) glyph.
struct PauseGlyph: View {
    var color: Color
    var size: CGFloat = 16
    var body: some View {
        HStack(spacing: size * 0.22) {
            Capsule().fill(color).frame(width: size * 0.26, height: size)
            Capsule().fill(color).frame(width: size * 0.26, height: size)
        }
        .frame(width: size, height: size)
    }
}
