import SwiftUI

// Splash shown while the launch check runs. Animated hexagon motif.
struct HexRealmLoadingScreen: View {
    @State private var spin = false
    @State private var pulse = false
    @State private var ring = false

    var body: some View {
        ZStack {
            HexBackground()
            VStack(spacing: 28) {
                ZStack {
                    FlatHexShape()
                        .fill(HexPalette.panel)
                        .frame(width: 138, height: 138)
                        .overlay(FlatHexShape().stroke(HexPalette.panelRaised, lineWidth: 2)
                                    .frame(width: 138, height: 138))
                    // rotating outer hex ring
                    FlatHexShape()
                        .stroke(HexPalette.crimson.opacity(0.35),
                                style: StrokeStyle(lineWidth: 6, dash: [10, 8]))
                        .frame(width: 116, height: 116)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                    // cluster of three small hexes
                    ZStack {
                        FlatHexShape().fill(HexPalette.crimson)
                            .frame(width: 38, height: 38).offset(y: -22)
                        FlatHexShape().fill(HexPalette.gold)
                            .frame(width: 38, height: 38).offset(x: -20, y: 12)
                        FlatHexShape().fill(HexPalette.research)
                            .frame(width: 38, height: 38).offset(x: 20, y: 12)
                    }
                    .scaleEffect(pulse ? 1.06 : 0.94)
                }
                Text("HEX REALM CONQUEST")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(HexPalette.textPrimary)
                Text("Mustering the banners…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(HexPalette.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
            ring = true
        }
    }
}
