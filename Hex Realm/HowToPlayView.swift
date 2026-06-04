import SwiftUI

struct HowToPlayView: View {
    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 14) {
                    section(num: 1, title: "Your Realm",
                            body: "You command a faction on a hex map. Every hex you own produces gold and grows its army stack each turn. Your CAPITAL (marked with a crown) is your lifeline — lose it and the match is over.",
                            icon: AnyView(CrownShape().fill(HexPalette.gold).frame(width: 30, height: 22)))

                    section(num: 2, title: "Select & Target",
                            body: "Tap one of your hexes that has at least 2 armies. Its legal neighbors are highlighted in gold. Tap a highlighted hex to act on it.",
                            icon: AnyView(PointyHexShape().stroke(HexPalette.crimson, lineWidth: 3).frame(width: 28, height: 28)))

                    section(num: 3, title: "Reinforce or Attack",
                            body: "Tap an adjacent OWNED hex to reinforce it (moves your stack, costs a little gold). Tap an adjacent ENEMY or NEUTRAL hex to attack it.",
                            icon: AnyView(ArmyGlyph(color: HexPalette.crimson, size: 28)))

                    section(num: 4, title: "Combat Resolution",
                            body: "Attack strength is your moving armies times faction and upgrade bonuses. Defense adds the terrain bonus (hills and mountains are tough), buildings, and a capital bonus. A bounded random roll decides the edge. Win and your survivors take the hex; one army always stays behind to hold the origin.",
                            icon: AnyView(ShieldShape().fill(HexPalette.research).frame(width: 26, height: 30)))

                    section(num: 5, title: "End Turn",
                            body: "You have a limited number of actions per turn. When you are done, press End Turn. Each AI faction then expands and defends. A new turn begins with fresh production and actions.",
                            icon: AnyView(HexCampaignIcon(color: HexPalette.success, size: 28)))

                    section(num: 6, title: "Winning",
                            body: "Win by capturing every enemy capital, or by controlling the target percentage of the land. Build farms, barracks, and forts, and spend gold in the Tech tree for lasting edges. Clear campaign maps fast and with high control to earn up to 3 stars.",
                            icon: AnyView(StarShape(points: 5).fill(HexPalette.gold).frame(width: 28, height: 28)))

                    legendCard
                    Spacer(minLength: 12)
                }
                .padding(16)
            }
        }
        .navigationBarTitle("How To Play", displayMode: .inline)
    }

    private func section(num: Int, title: String, body: String, icon: AnyView) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                FlatHexShape().fill(HexPalette.crimson.opacity(0.15)).frame(width: 46, height: 46)
                icon.frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(num). \(title)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(body)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .hexCard()
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terrain Legend")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(HexPalette.textPrimary)
            ForEach(HexTerrain.allCases, id: \.rawValue) { t in
                HStack(spacing: 10) {
                    ZStack {
                        PointyHexShape().fill(t.fill).frame(width: 26, height: 26)
                        TerrainGlyph(terrain: t, size: 16)
                    }
                    Text(t.name).font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                    Spacer()
                    Text(t.isPassable ? "Gold +\(t.goldYield) • Def x\(String(format: "%.2f", t.defenseBonus))" : "Impassable water")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                }
            }
        }
        .padding(14)
        .hexCard()
    }
}
