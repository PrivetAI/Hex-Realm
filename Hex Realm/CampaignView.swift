import SwiftUI

struct CampaignView: View {
    @EnvironmentObject var store: HexRealmStore
    @State private var pendingMap: CampaignMapDef? = nil
    @State private var goToMatch = false

    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    resumeBanner
                    ForEach(Campaign.maps) { def in
                        mapCard(def)
                    }
                    Spacer(minLength: 12)
                }
                .padding(16)
            }

            // hidden navigation link driver
            NavigationLink(destination: MatchView().environmentObject(store),
                           isActive: $goToMatch) { EmptyView() }
                .hidden()
        }
        .navigationBarTitle("Campaign", displayMode: .inline)
        .sheet(item: $pendingMap) { def in
            FactionPicker(title: def.name,
                          subtitle: "\(def.tier) • \(def.difficulty.label) • \(def.aiCount) AI") { fid in
                store.startCampaign(def, factionId: fid)
                pendingMap = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { goToMatch = true }
            }
        }
    }

    private var header: some View {
        let cleared = Campaign.maps.filter { store.isCleared($0.id) }.count
        let totalStars = Campaign.maps.reduce(0) { $0 + store.stars(for: $1.id) }
        return VStack(spacing: 6) {
            Text("Conquer the Realm")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(HexPalette.textPrimary)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    HexCampaignIcon(color: HexPalette.crimson, size: 16)
                    Text("\(cleared)/\(Campaign.maps.count) cleared")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                }
                HStack(spacing: 4) {
                    StarShape(points: 5).fill(HexPalette.gold).frame(width: 14, height: 14)
                    Text("\(totalStars)/\(Campaign.maps.count * 3) stars")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    @ViewBuilder private var resumeBanner: some View {
        if let m = store.activeMatch, store.activeIsCampaign, m.outcome == .ongoing {
            Button(action: { goToMatch = true }) {
                HStack(spacing: 10) {
                    PauseGlyph(color: .white, size: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Resume Match")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(Campaign.map(m.campaignMapId)?.name ?? "Battle") • Turn \(m.turn)")
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

    private func mapCard(_ def: CampaignMapDef) -> some View {
        let unlocked = store.isUnlocked(def.id)
        let stars = store.stars(for: def.id)
        return Button(action: {
            if unlocked { pendingMap = def }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    FlatHexShape()
                        .fill(unlocked ? tierColor(def.tier).opacity(0.25) : HexPalette.track)
                        .frame(width: 50, height: 50)
                    if unlocked {
                        Text("\(def.id + 1)")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(tierColor(def.tier))
                    } else {
                        LockGlyph(color: HexPalette.lock, size: 22)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(def.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(unlocked ? HexPalette.textPrimary : HexPalette.textMuted)
                    Text("\(def.tier) • \(def.size.label) • \(def.difficulty.label)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            StarShape(points: 5)
                                .fill(i < stars ? HexPalette.gold : HexPalette.track)
                                .frame(width: 13, height: 13)
                        }
                        Text("• \(def.aiCount) AI • \(Int(def.targetControlPct * 100))% goal")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                    }
                }
                Spacer()
                if unlocked { ChevronGlyph(color: HexPalette.textMuted, size: 16) }
            }
            .padding(12)
            .hexCard()
            .opacity(unlocked ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "Borderlands": return HexPalette.success
        case "Heartlands": return HexPalette.research
        case "Conquest": return HexPalette.goldDeep
        default: return HexPalette.crimson
        }
    }
}

// Shared faction selection sheet.
struct FactionPicker: View {
    let title: String
    let subtitle: String
    let onStart: (Int) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var selected = 0

    var body: some View {
        NavigationView {
            ZStack {
                HexBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 3) {
                            Text(title).font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(HexPalette.textPrimary)
                            Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(HexPalette.textSecondary)
                        }
                        .padding(.top, 4)

                        Text("Choose Your Faction")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(Factions.all, id: \.id) { f in
                            factionCard(f)
                        }

                        HexPrimaryButton(title: "Begin Battle", color: HexPalette.crimson) {
                            onStart(selected)
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitle("New Battle", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(HexPalette.crimsonDeep))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func factionCard(_ f: FactionDef) -> some View {
        Button(action: { selected = f.id }) {
            HStack(spacing: 12) {
                ZStack {
                    ShieldShape().fill(f.color).frame(width: 34, height: 38)
                    ShieldShape().stroke(.white.opacity(0.7), lineWidth: 2).frame(width: 34, height: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                    Text(f.blurb).font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                }
                Spacer()
                Circle()
                    .stroke(selected == f.id ? HexPalette.crimson : HexPalette.track, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().fill(selected == f.id ? HexPalette.crimson : .clear)
                                .frame(width: 12, height: 12))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14)
                            .fill(HexPalette.panel)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected == f.id ? HexPalette.crimson : HexPalette.panelRaised,
                                                lineWidth: selected == f.id ? 2 : 1)))
        }
        .buttonStyle(.plain)
    }
}
