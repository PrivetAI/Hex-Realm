import SwiftUI

// ============================================================================
// Core hexagon geometry. Pointy-top hexagons are used for the map; flat-top
// hexagons are used as decorative/icon motifs. All icons here are pure Shapes
// (no SF Symbols, no emoji, no system images).
// ============================================================================

/// A pointy-top regular hexagon inscribed in the given rect.
struct PointyHexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY
        let r = min(w, h) / 2
        for i in 0..<6 {
            let angle = CGFloat.pi / 180 * (60 * CGFloat(i) - 90)
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A flat-top regular hexagon inscribed in the given rect (icon motif).
struct FlatHexShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            let angle = CGFloat.pi / 180 * (60 * CGFloat(i))
            let pt = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// ---------------------------------------------------------------------------
// Tab bar icons
// ---------------------------------------------------------------------------

struct HexCampaignIcon: View {
    var color: Color
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            FlatHexShape().stroke(color, lineWidth: size * 0.09)
                .frame(width: size, height: size)
            FlatHexShape().fill(color.opacity(0.25))
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
    }
}

struct HexSkirmishIcon: View {
    var color: Color
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            // crossed swords abstract
            Capsule().fill(color)
                .frame(width: size * 0.12, height: size)
                .rotationEffect(.degrees(45))
            Capsule().fill(color)
                .frame(width: size * 0.12, height: size)
                .rotationEffect(.degrees(-45))
            Circle().fill(color.opacity(0.3))
                .frame(width: size * 0.34, height: size * 0.34)
        }
        .frame(width: size, height: size)
    }
}

struct HexAwardsIcon: View {
    var color: Color
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.09)
                .frame(width: size * 0.66, height: size * 0.66)
                .offset(y: -size * 0.08)
            StarShape(points: 5)
                .fill(color)
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(y: -size * 0.08)
            // ribbon
            Path { p in
                p.move(to: CGPoint(x: size * 0.36, y: size * 0.55))
                p.addLine(to: CGPoint(x: size * 0.30, y: size * 0.95))
                p.addLine(to: CGPoint(x: size * 0.50, y: size * 0.80))
                p.addLine(to: CGPoint(x: size * 0.70, y: size * 0.95))
                p.addLine(to: CGPoint(x: size * 0.64, y: size * 0.55))
                p.closeSubpath()
            }
            .fill(color.opacity(0.7))
        }
        .frame(width: size, height: size)
    }
}

struct HexMoreIcon: View {
    var color: Color
    var size: CGFloat = 24
    var body: some View {
        VStack(spacing: size * 0.18) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule().fill(color)
                    .frame(width: size * 0.86, height: size * 0.13)
            }
        }
        .frame(width: size, height: size)
    }
}

// ---------------------------------------------------------------------------
// Generic glyph shapes
// ---------------------------------------------------------------------------

struct StarShape: Shape {
    var points: Int = 5
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        let step = CGFloat.pi / CGFloat(points)
        var angle = -CGFloat.pi / 2
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outer : inner
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            angle += step
        }
        p.closeSubpath()
        return p
    }
}

/// Gold coin icon (resource).
struct CoinGlyph: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            Circle().fill(HexPalette.gold)
            Circle().stroke(HexPalette.goldDeep, lineWidth: size * 0.08)
            FlatHexShape().fill(HexPalette.goldDeep.opacity(0.55))
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
    }
}

/// Army / shield strength icon.
struct ArmyGlyph: View {
    var color: Color = HexPalette.crimson
    var size: CGFloat = 18
    var body: some View {
        ShieldShape()
            .fill(color)
            .overlay(
                ShieldShape().stroke(Color.white.opacity(0.6), lineWidth: size * 0.06)
            )
            .frame(width: size, height: size)
    }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.18))
        p.addLine(to: CGPoint(x: w, y: h * 0.55))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h),
                       control: CGPoint(x: w * 0.92, y: h * 0.88))
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.55),
                       control: CGPoint(x: w * 0.08, y: h * 0.88))
        p.addLine(to: CGPoint(x: 0, y: h * 0.18))
        p.closeSubpath()
        return p
    }
}

/// Research / lab beaker icon (abstract).
struct ResearchGlyph: View {
    var color: Color = HexPalette.research
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            FlatHexShape().stroke(color, lineWidth: size * 0.1)
            Circle().fill(color)
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .frame(width: size, height: size)
    }
}

/// Crown / capital marker.
struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.25))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.1))
        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.55))
        p.addLine(to: CGPoint(x: w, y: h * 0.25))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

/// Medal for achievements.
struct HexMedalShape: View {
    var color: Color
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            FlatHexShape()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                     startPoint: .top, endPoint: .bottom))
            FlatHexShape()
                .stroke(Color.white.opacity(0.55), lineWidth: size * 0.05)
            StarShape(points: 6)
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.46, height: size * 0.46)
        }
        .frame(width: size, height: size)
    }
}

/// Lock icon for gated content.
struct LockGlyph: View {
    var color: Color = HexPalette.lock
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(color)
                .frame(width: size * 0.8, height: size * 0.58)
                .offset(y: size * 0.16)
            Path { p in
                let w = size
                p.addArc(center: CGPoint(x: w * 0.5, y: size * 0.34),
                         radius: size * 0.24,
                         startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            }
            .stroke(color, lineWidth: size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

/// Chevron used for list rows / navigation.
struct ChevronGlyph: View {
    var color: Color = HexPalette.textMuted
    var size: CGFloat = 14
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: size * 0.35, y: size * 0.2))
            p.addLine(to: CGPoint(x: size * 0.7, y: size * 0.5))
            p.addLine(to: CGPoint(x: size * 0.35, y: size * 0.8))
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// Small terrain glyph drawn inside hexes / legends.
struct TerrainGlyph: View {
    let terrain: HexTerrain
    var size: CGFloat = 16
    var body: some View {
        Group {
            switch terrain {
            case .plains:
                Path { p in
                    p.move(to: CGPoint(x: size * 0.15, y: size * 0.62))
                    p.addQuadCurve(to: CGPoint(x: size * 0.85, y: size * 0.62),
                                   control: CGPoint(x: size * 0.5, y: size * 0.4))
                }.stroke(HexPalette.textPrimary.opacity(0.4),
                         style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
            case .forest:
                Path { p in
                    p.move(to: CGPoint(x: size * 0.5, y: size * 0.15))
                    p.addLine(to: CGPoint(x: size * 0.78, y: size * 0.7))
                    p.addLine(to: CGPoint(x: size * 0.22, y: size * 0.7))
                    p.closeSubpath()
                }.fill(HexPalette.textPrimary.opacity(0.35))
            case .hills:
                Path { p in
                    p.move(to: CGPoint(x: size * 0.1, y: size * 0.7))
                    p.addQuadCurve(to: CGPoint(x: size * 0.5, y: size * 0.7),
                                   control: CGPoint(x: size * 0.3, y: size * 0.4))
                    p.addQuadCurve(to: CGPoint(x: size * 0.9, y: size * 0.7),
                                   control: CGPoint(x: size * 0.7, y: size * 0.35))
                }.fill(HexPalette.textPrimary.opacity(0.3))
            case .mountain:
                Path { p in
                    p.move(to: CGPoint(x: size * 0.1, y: size * 0.75))
                    p.addLine(to: CGPoint(x: size * 0.4, y: size * 0.25))
                    p.addLine(to: CGPoint(x: size * 0.6, y: size * 0.55))
                    p.addLine(to: CGPoint(x: size * 0.75, y: size * 0.35))
                    p.addLine(to: CGPoint(x: size * 0.9, y: size * 0.75))
                    p.closeSubpath()
                }.fill(HexPalette.textPrimary.opacity(0.4))
            case .water:
                Path { p in
                    for row in 0..<2 {
                        let y = size * (0.45 + CGFloat(row) * 0.22)
                        p.move(to: CGPoint(x: size * 0.15, y: y))
                        p.addQuadCurve(to: CGPoint(x: size * 0.5, y: y),
                                       control: CGPoint(x: size * 0.32, y: y - size * 0.1))
                        p.addQuadCurve(to: CGPoint(x: size * 0.85, y: y),
                                       control: CGPoint(x: size * 0.68, y: y + size * 0.1))
                    }
                }.stroke(HexPalette.textPrimary.opacity(0.35),
                         style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}
