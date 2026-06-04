import SwiftUI

struct MoreView: View {
    @EnvironmentObject var store: HexRealmStore

    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 14) {
                    // banner
                    VStack(spacing: 10) {
                        ZStack {
                            FlatHexShape().fill(HexPalette.crimson).frame(width: 40, height: 40).offset(y: -16)
                            FlatHexShape().fill(HexPalette.gold).frame(width: 40, height: 40).offset(x: -16, y: 10)
                            FlatHexShape().fill(HexPalette.research).frame(width: 40, height: 40).offset(x: 16, y: 10)
                        }
                        .frame(height: 70)
                        Text("Hex Realm")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(HexPalette.textPrimary)
                        Text("Turn-based territory strategy")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(HexPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .hexCard()

                    NavigationLink(destination: HowToPlayView()) {
                        rowCard(title: "How To Play",
                                subtitle: "Learn the conquest loop",
                                icon: AnyView(HexCampaignIcon(color: HexPalette.crimson, size: 24)))
                    }.buttonStyle(.plain)

                    NavigationLink(destination: SettingsView().environmentObject(store)) {
                        rowCard(title: "Settings",
                                subtitle: "Sound, haptics, privacy, reset",
                                icon: AnyView(SettingsGlyph(color: HexPalette.research, size: 24)))
                    }.buttonStyle(.plain)

                    VStack(spacing: 4) {
                        Text("Version 1.0").font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                        Text("All maps are offline and local.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 12)
                }
                .padding(16)
            }
        }
        .navigationBarTitle("More", displayMode: .inline)
    }

    private func rowCard(title: String, subtitle: String, icon: AnyView) -> some View {
        HStack(spacing: 12) {
            icon.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                Text(subtitle).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            ChevronGlyph(color: HexPalette.textMuted, size: 16)
        }
        .padding(14)
        .hexCard()
    }
}

struct SettingsGlyph: View {
    var color: Color
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            FlatHexShape().stroke(color, lineWidth: size * 0.08).frame(width: size, height: size)
            Circle().fill(color).frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}
