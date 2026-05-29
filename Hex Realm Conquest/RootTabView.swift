import SwiftUI

/// App shell: a custom HStack tab bar (NOT a TabView) over a `switch` on the
/// selected tab. Each tab hosts its own NavigationView so navigation state is
/// isolated per tab. The match/battle screen is pushed full-screen from within.
struct RootTabView: View {
    @EnvironmentObject var store: HexRealmStore
    @State private var selectedTab = 0
    @State private var toastTitle: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationView { CampaignView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { SkirmishView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { AwardsView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { MoreView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }

            if let title = toastTitle {
                unlockToast(title)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(30)
            }
        }
        .onChange(of: store.lastUnlocked) { ids in
            guard let first = ids.first,
                  let ach = HexAchievements.def(first) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                toastTitle = ach.title
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) { toastTitle = nil }
                store.lastUnlocked = []
            }
        }
    }

    private func unlockToast(_ title: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                HexMedalShape(color: HexPalette.gold, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Achievement Unlocked")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(HexPalette.textMuted)
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(HexPalette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(HexPalette.gold.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Campaign", AnyView(HexCampaignIcon(color: tint(0), size: 24)))
            tabButton(1, "Skirmish", AnyView(HexSkirmishIcon(color: tint(1), size: 24)))
            tabButton(2, "Awards", AnyView(HexAwardsIcon(color: tint(2), size: 24)))
            tabButton(3, "More", AnyView(HexMoreIcon(color: tint(3), size: 24)))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(HexPalette.panel.edgesIgnoringSafeArea(.bottom))
        .overlay(
            Rectangle().fill(HexPalette.panelRaised).frame(height: 1),
            alignment: .top
        )
    }

    private func tint(_ i: Int) -> Color { selectedTab == i ? HexPalette.crimsonDeep : HexPalette.textMuted }

    private func tabButton(_ i: Int, _ label: String, _ icon: AnyView) -> some View {
        Button {
            selectedTab = i
        } label: {
            VStack(spacing: 3) {
                icon.frame(height: 26)
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(tint(i))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
