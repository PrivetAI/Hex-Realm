import SwiftUI

// 5-step skippable tutorial, UserDefaults-gated (handled in ContentView).
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var step = 0

    private struct Page {
        let title: String
        let body: String
    }
    private let pages: [Page] = [
        Page(title: "Welcome, Commander",
             body: "Hex Realm Conquest is a turn-based strategy game. You lead a faction to conquer a hex map, one territory at a time."),
        Page(title: "Grow Your Realm",
             body: "Each hex you own produces gold and grows its army every turn. Stronger terrain like hills and mountains defends better."),
        Page(title: "Select, Then Strike",
             body: "Tap an owned hex with armies, then tap a glowing neighbor to reinforce it (if yours) or attack it (if enemy or neutral)."),
        Page(title: "End Your Turn",
             body: "When your actions run out or you are satisfied, end your turn. The AI factions will then make their moves."),
        Page(title: "Claim Victory",
             body: "Take every enemy capital or seize enough land to win. Earn stars on campaign maps and unlock achievements along the way.")
    ]

    var body: some View {
        ZStack {
            HexBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onFinish) {
                        Text("Skip")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(HexPalette.textMuted)
                            .padding(12)
                    }
                }
                Spacer()
                ZStack {
                    FlatHexShape().fill(HexPalette.crimson.opacity(0.12)).frame(width: 150, height: 150)
                    FlatHexShape().stroke(HexPalette.crimson.opacity(0.4),
                                          style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                        .frame(width: 128, height: 128)
                    stepGlyph
                }
                .padding(.bottom, 24)

                Text(pages[step].title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(HexPalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(pages[step].body)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? HexPalette.crimson : HexPalette.track)
                            .frame(width: i == step ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 20)

                HexPrimaryButton(title: step == pages.count - 1 ? "Start Playing" : "Next",
                                 color: HexPalette.crimson) {
                    if step == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder private var stepGlyph: some View {
        switch step {
        case 0:
            ZStack {
                FlatHexShape().fill(HexPalette.crimson).frame(width: 34, height: 34).offset(y: -14)
                FlatHexShape().fill(HexPalette.gold).frame(width: 34, height: 34).offset(x: -14, y: 9)
                FlatHexShape().fill(HexPalette.research).frame(width: 34, height: 34).offset(x: 14, y: 9)
            }
        case 1: CoinGlyph(size: 56)
        case 2: PointyHexShape().stroke(HexPalette.crimson, lineWidth: 5).frame(width: 64, height: 64)
        case 3: HexCampaignIcon(color: HexPalette.success, size: 64)
        default: StarShape(points: 5).fill(HexPalette.gold).frame(width: 64, height: 64)
        }
    }
}
