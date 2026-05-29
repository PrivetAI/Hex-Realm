import SwiftUI

struct AwardsView: View {
    @EnvironmentObject var store: HexRealmStore

    var body: some View {
        ZStack {
            HexBackground()
            ScrollView {
                VStack(spacing: 14) {
                    statsCard
                    Text("Achievements")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(HexAchievements.all) { ach in
                        achievementRow(ach)
                    }
                    Spacer(minLength: 12)
                }
                .padding(16)
            }
        }
        .navigationBarTitle("Awards", displayMode: .inline)
    }

    private var statsCard: some View {
        let s = store.progress.stats
        let unlocked = store.progress.unlockedAchievements.count
        return VStack(spacing: 12) {
            HStack {
                HexMedalShape(color: HexPalette.gold, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlocked) / \(HexAchievements.all.count)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                    Text("Achievements unlocked")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(HexPalette.textSecondary)
                }
                Spacer()
            }
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile("Wins", "\(s.totalWins)")
                statTile("Matches", "\(s.totalMatches)")
                statTile("Hexes Captured", "\(s.totalCaptures)")
                statTile("Buildings Built", "\(s.buildingsBuilt)")
                statTile("Upgrades Bought", "\(s.upgradesBought)")
                statTile("Factions Won", "\(Set(s.factionsWonWith).count)/\(Factions.all.count)")
            }
        }
        .padding(14)
        .hexCard()
    }

    private func statTile(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(HexPalette.crimsonDeep)
            Text(k).font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(HexPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(HexPalette.panelSunken))
    }

    private func achievementRow(_ ach: HexAchievement) -> some View {
        let unlocked = store.isUnlockedAchievement(ach.id)
        return HStack(spacing: 12) {
            HexMedalShape(color: unlocked ? ach.color : HexPalette.lock, size: 38)
                .opacity(unlocked ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(ach.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(unlocked ? HexPalette.textPrimary : HexPalette.textMuted)
                Text(ach.detail).font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
            Spacer()
            if unlocked {
                StarShape(points: 5).fill(HexPalette.gold).frame(width: 18, height: 18)
            } else {
                LockGlyph(color: HexPalette.lock, size: 18)
            }
        }
        .padding(12)
        .hexCard()
        .opacity(unlocked ? 1 : 0.85)
    }
}
