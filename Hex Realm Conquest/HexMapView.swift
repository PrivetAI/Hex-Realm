import SwiftUI

// ============================================================================
// HexMapView renders the hex grid with a Canvas. CRITICAL (per the SwiftUI
// Canvas size pitfall): ALL layout / camera math uses the parent-passed
// `screenSize` from an OUTER GeometryReader, NEVER the Canvas closure `size`.
// Tap hit-testing converts a tap point into the nearest hex coord using the
// same camera transform.
// ============================================================================

struct HexMapView: View {
    let state: MatchState
    let screenSize: CGSize          // passed from the parent GeometryReader
    let selected: HexCoord?
    let reachable: Set<HexCoord>    // adjacent legal targets to highlight
    let onTapHex: (HexCoord) -> Void

    var body: some View {
        // Compute the camera (scale + origin) once from screenSize, not Canvas size.
        let cam = HexCamera(state: state, screenSize: screenSize)
        Canvas { ctx, _ in
            // Draw every tile.
            for t in state.tiles {
                let center = cam.center(of: t.coord)
                let hexPath = cam.hexPath(at: center)

                // terrain fill
                ctx.fill(hexPath, with: .color(t.terrain.fill))

                // owner tint overlay
                if t.owner >= 0 {
                    let oc = Factions.color(t.owner)
                    ctx.fill(hexPath, with: .color(oc.opacity(0.55)))
                } else if t.terrain.isPassable {
                    ctx.fill(hexPath, with: .color(HexPalette.neutralFill.opacity(0.30)))
                }

                // border
                let isSel = (t.coord == selected)
                let isReach = reachable.contains(t.coord)
                if isSel {
                    ctx.stroke(hexPath, with: .color(.white), lineWidth: cam.hexSize * 0.16)
                    ctx.stroke(hexPath, with: .color(HexPalette.crimsonDeep), lineWidth: cam.hexSize * 0.08)
                } else if isReach {
                    ctx.stroke(hexPath, with: .color(HexPalette.gold), lineWidth: cam.hexSize * 0.12)
                } else {
                    ctx.stroke(hexPath, with: .color(HexPalette.hexStroke.opacity(0.5)),
                               lineWidth: max(1, cam.hexSize * 0.03))
                }

                // capital marker (crown drawn as a small path)
                if t.isCapital {
                    let cw = cam.hexSize * 0.5
                    let crownRect = CGRect(x: center.x - cw / 2,
                                           y: center.y - cam.hexSize * 0.62,
                                           width: cw, height: cw * 0.6)
                    var crown = Path()
                    let w = crownRect.width, h = crownRect.height
                    let ox = crownRect.minX, oy = crownRect.minY
                    crown.move(to: CGPoint(x: ox, y: oy + h))
                    crown.addLine(to: CGPoint(x: ox, y: oy + h * 0.25))
                    crown.addLine(to: CGPoint(x: ox + w * 0.25, y: oy + h * 0.55))
                    crown.addLine(to: CGPoint(x: ox + w * 0.5, y: oy + h * 0.1))
                    crown.addLine(to: CGPoint(x: ox + w * 0.75, y: oy + h * 0.55))
                    crown.addLine(to: CGPoint(x: ox + w, y: oy + h * 0.25))
                    crown.addLine(to: CGPoint(x: ox + w, y: oy + h))
                    crown.closeSubpath()
                    ctx.fill(crown, with: .color(HexPalette.gold))
                    ctx.stroke(crown, with: .color(HexPalette.goldDeep), lineWidth: 1)
                }

                // army count badge
                if t.armies > 0 && t.owner >= 0 {
                    let txt = Text("\(t.armies)")
                        .font(.system(size: cam.hexSize * 0.45, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    let resolved = ctx.resolve(txt)
                    // soft dark disc behind for legibility
                    let discR = cam.hexSize * 0.42
                    let discRect = CGRect(x: center.x - discR, y: center.y - discR,
                                          width: discR * 2, height: discR * 2)
                    ctx.fill(Path(ellipseIn: discRect), with: .color(.black.opacity(0.32)))
                    ctx.draw(resolved, at: center)
                } else if t.armies > 0 {
                    // neutral garrison count, muted
                    let txt = Text("\(t.armies)")
                        .font(.system(size: cam.hexSize * 0.4, weight: .bold, design: .rounded))
                        .foregroundColor(HexPalette.textPrimary.opacity(0.7))
                    ctx.draw(ctx.resolve(txt), at: center)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if let c = cam.hex(at: value.location) {
                        onTapHex(c)
                    }
                }
        )
    }
}

/// Camera/transform derived ONLY from the parent screenSize. Pointy-top axial.
struct HexCamera {
    let hexSize: CGFloat      // circumradius
    let origin: CGPoint       // pixel position of axial (0,0)
    let screenSize: CGSize

    init(state: MatchState, screenSize: CGSize) {
        self.screenSize = screenSize
        let radius = state.size.radius
        // For pointy-top: width = sqrt(3)*size, height = 2*size; horizontal
        // spacing = sqrt(3)*size, vertical spacing = 1.5*size.
        // Total axial span across the hex map: roughly (2*radius+1) wide.
        let cols = CGFloat(2 * radius + 1)
        let rows = CGFloat(2 * radius + 1)
        // available area with margin
        let availW = screenSize.width - 24
        let availH = screenSize.height - 24
        // size constrained by width: sqrt(3)*size*cols <= availW
        let sizeByW = availW / (1.732 * cols)
        // size constrained by height: 1.5*size*rows + 0.5*size <= availH
        let sizeByH = availH / (1.5 * rows + 0.5)
        let s = max(8, min(sizeByW, sizeByH))
        hexSize = s
        // center the map: axial (0,0) is the map center, so origin = screen center.
        origin = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
    }

    func center(of c: HexCoord) -> CGPoint {
        let x = origin.x + hexSize * 1.732 * (CGFloat(c.q) + CGFloat(c.r) / 2)
        let y = origin.y + hexSize * 1.5 * CGFloat(c.r)
        return CGPoint(x: x, y: y)
    }

    func hexPath(at center: CGPoint) -> Path {
        var p = Path()
        for i in 0..<6 {
            let angle = CGFloat.pi / 180 * (60 * CGFloat(i) - 90)
            let pt = CGPoint(x: center.x + hexSize * cos(angle),
                             y: center.y + hexSize * sin(angle))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Convert a pixel tap to the nearest axial coord (pixel -> fractional axial -> round).
    func hex(at point: CGPoint) -> HexCoord? {
        let px = point.x - origin.x
        let py = point.y - origin.y
        let qf = (px / (hexSize * 1.732)) - (py / (hexSize * 3.0))
        let rf = py / (hexSize * 1.5)
        return Self.roundAxial(q: qf, r: rf)
    }

    static func roundAxial(q: CGFloat, r: CGFloat) -> HexCoord {
        let x = q
        let z = r
        let y = -x - z
        var rx = (x).rounded()
        var ry = (y).rounded()
        var rz = (z).rounded()
        let dx = abs(rx - x), dy = abs(ry - y), dz = abs(rz - z)
        if dx > dy && dx > dz {
            rx = -ry - rz
        } else if dy > dz {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }
        return HexCoord(q: Int(rx), r: Int(rz))
    }
}
