import SwiftUI

// Hex Realm palette — a parchment / map-table aesthetic with a crimson accent.
// Warm sand background, deep ink text, and saturated faction colors that read
// clearly on the hex grid. Forced light scheme at the scene root.
enum HexPalette {
    static let background = Color(red: 0.96, green: 0.93, blue: 0.86)      // parchment
    static let backgroundDeep = Color(red: 0.91, green: 0.86, blue: 0.76)  // aged map
    static let panel = Color(red: 0.99, green: 0.97, blue: 0.92)           // card
    static let panelRaised = Color(red: 0.86, green: 0.80, blue: 0.68)     // card edge
    static let panelSunken = Color(red: 0.93, green: 0.89, blue: 0.80)

    static let crimson = Color(red: 0.78, green: 0.20, blue: 0.20)         // accent
    static let crimsonDeep = Color(red: 0.60, green: 0.13, blue: 0.13)
    static let crimsonLight = Color(red: 0.90, green: 0.45, blue: 0.40)

    static let gold = Color(red: 0.85, green: 0.66, blue: 0.24)            // resource gold
    static let goldDeep = Color(red: 0.68, green: 0.50, blue: 0.12)
    static let goldLight = Color(red: 0.96, green: 0.82, blue: 0.45)

    static let research = Color(red: 0.36, green: 0.50, blue: 0.74)        // research/blue

    static let accent = HexPalette.crimson
    static let accentDeep = HexPalette.crimsonDeep

    static let textPrimary = Color(red: 0.18, green: 0.14, blue: 0.10)     // ink
    static let textSecondary = Color(red: 0.38, green: 0.32, blue: 0.24)
    static let textMuted = Color(red: 0.56, green: 0.50, blue: 0.42)

    static let success = Color(red: 0.27, green: 0.62, blue: 0.36)
    static let danger = Color(red: 0.80, green: 0.28, blue: 0.24)
    static let lock = Color(red: 0.72, green: 0.67, blue: 0.58)
    static let track = Color(red: 0.86, green: 0.80, blue: 0.69)

    // Terrain fills for the hex map.
    static let terrainPlains = Color(red: 0.78, green: 0.80, blue: 0.52)
    static let terrainForest = Color(red: 0.42, green: 0.58, blue: 0.36)
    static let terrainHills = Color(red: 0.72, green: 0.60, blue: 0.40)
    static let terrainMountain = Color(red: 0.56, green: 0.54, blue: 0.52)
    static let terrainWater = Color(red: 0.44, green: 0.62, blue: 0.74)

    static let neutralFill = Color(red: 0.80, green: 0.76, blue: 0.68)
    static let hexStroke = Color(red: 0.30, green: 0.25, blue: 0.18)
}

enum HexMetrics {
    static let corner: CGFloat = 16
    static let cornerSmall: CGFloat = 10
}

// Reusable raised card background.
struct HexCard: ViewModifier {
    var corner: CGFloat = HexMetrics.corner
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(HexPalette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(HexPalette.panelRaised, lineWidth: 1)
                    )
                    .shadow(color: HexPalette.crimsonDeep.opacity(0.05), radius: 7, x: 0, y: 3)
            )
    }
}

extension View {
    func hexCard(corner: CGFloat = HexMetrics.corner) -> some View {
        modifier(HexCard(corner: corner))
    }
}

// Background gradient used across screens.
struct HexBackground: View {
    var body: some View {
        LinearGradient(
            colors: [HexPalette.background, HexPalette.backgroundDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// Primary call-to-action button style used throughout.
struct HexPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var color: Color = HexPalette.crimson
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(enabled ? color : HexPalette.lock)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
