// The tree (pre-stage, stage, three ambers, green, red for each lane) and,
// under it, a top-down staging view with both cars and the two beams.

import SwiftUI

extension RGB {
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct TreeCanvas: View {
    let state: TreeDrawState

    var body: some View {
        Canvas { context, size in
            TreeCanvas.draw(state, in: &context, size: size)
        }
    }

    private static let rows = 7.0        // pre-stage, stage, amber x3, green, red
    private static let labelH = 22.0
    private static let trackFrac = 0.30  // share of the height used for the staging view
    private static let viewBackIn = -36.0 // track window, inches relative to the pre-stage beam
    private static let viewFwdIn = 22.0

    private static func ellipse(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private static func rect(_ l: Double, _ t: Double, _ r: Double, _ b: Double) -> CGRect {
        CGRect(x: l, y: t, width: r - l, height: b - t)
    }

    private static func bulb(_ ctx: inout GraphicsContext, _ cx: Double, _ cy: Double,
                             _ radius: Double, _ color: RGB, _ lit: Bool) {
        if lit {
            // soft glow, then the lens, then a highlight
            ctx.fill(ellipse(cx, cy, radius * 1.6), with: .color(color.color.opacity(0.12)))
            ctx.fill(ellipse(cx, cy, radius * 1.25), with: .color(color.color.opacity(0.25)))
            ctx.fill(ellipse(cx, cy, radius), with: .color(color.color))
            ctx.fill(Path(ellipseIn: rect(cx - radius * 0.55, cy - radius * 0.6,
                                          cx - radius * 0.05, cy - radius * 0.15)),
                     with: .color(Color.white.opacity(0.55)))
        } else {
            ctx.fill(ellipse(cx, cy, radius), with: .color(color.dimmed(0.16).color))
        }
        ctx.stroke(ellipse(cx, cy, radius), with: .color(Palette.rim.color),
                   lineWidth: max(2.0, radius * 0.12))
    }

    private static func label(_ ctx: inout GraphicsContext, _ text: String,
                              center: CGPoint, _ color: RGB, _ size: Double) {
        ctx.draw(Text(text).font(.system(size: size, weight: .bold)).foregroundColor(color.color),
                 at: center)
    }

    static func draw(_ s: TreeDrawState, in ctx: inout GraphicsContext, size: CGSize) {
        let w = Double(size.width)
        let h = Double(size.height)
        if w < 40 || h < 80 { return }

        let treeH = h * (1 - trackFrac)
        let rowH = (treeH - labelH - 12) / rows
        let laneX = [w * 0.31, w * 0.69]
        let laneW = w * 0.36
        let r = min(w * 0.13, rowH * 0.42)
        let smallR = r * 0.42

        func rowY(_ row: Int) -> Double { labelH + 6 + rowH * (Double(row) + 0.5) }

        // ----- tree -----
        ctx.fill(Path(rect(w * 0.5 - 6, labelH, w * 0.5 + 6, treeH)),
                 with: .color(Palette.housing.color))

        for lane in 0...1 {
            let x = laneX[lane]
            // lane label: YOU in blue over your lane
            if lane == s.userLane {
                label(&ctx, "YOU", center: CGPoint(x: x, y: labelH / 2), Palette.you, 15)
            } else {
                label(&ctx, "OTHER LANE", center: CGPoint(x: x, y: labelH / 2), Palette.subtle, 11)
            }

            let housing = Path(roundedRect: rect(x - r * 1.6, labelH + 2, x + r * 1.6, treeH - 2),
                               cornerRadius: r * 0.6)
            ctx.fill(housing, with: .color(Palette.housing.color))
            if lane == s.userLane {
                ctx.stroke(housing, with: .color(Palette.you.color), lineWidth: 2)
            }

            // pre-stage and stage are pairs of small bulbs
            bulb(&ctx, x - smallR * 1.3, rowY(0), smallR, Palette.stage, s.preStageLit[lane])
            bulb(&ctx, x + smallR * 1.3, rowY(0), smallR, Palette.stage, s.preStageLit[lane])
            bulb(&ctx, x - smallR * 1.3, rowY(1), smallR, Palette.stage, s.stageLit[lane])
            bulb(&ctx, x + smallR * 1.3, rowY(1), smallR, Palette.stage, s.stageLit[lane])

            for i in 0...2 {
                bulb(&ctx, x, rowY(2 + i), r, Palette.amber, s.amberLit[i])
            }
            bulb(&ctx, x, rowY(5), r, Palette.green, s.greenLit[lane])
            bulb(&ctx, x, rowY(6), r, Palette.red, lane == s.userLane && s.redLit)
        }

        // ----- staging view -----
        let trackTop = treeH + 8
        let trackBottom = h
        let scale = (trackBottom - trackTop) / (viewFwdIn - viewBackIn)

        func inchY(_ inches: Double) -> Double {
            trackBottom - (inches - viewBackIn) * scale
        }

        var track = ctx
        track.clip(to: Path(rect(0, trackTop, w, trackBottom)))
        for lane in 0...1 {
            let cx = laneX[lane]
            track.fill(Path(rect(cx - laneW * 0.5, trackTop, cx + laneW * 0.5, trackBottom)),
                       with: .color(Palette.track.color))
            // "too far" zone past the stage beam
            track.fill(Path(rect(cx - laneW * 0.5, inchY(viewFwdIn),
                                 cx + laneW * 0.5, inchY(TreeModel.tooFarIn))),
                       with: .color(Palette.red.color.opacity(0.18)))

            func beam(_ inches: Double, _ lit: Bool, _ name: String) {
                let y = inchY(inches)
                var line = Path()
                line.move(to: CGPoint(x: cx - laneW * 0.48, y: y))
                line.addLine(to: CGPoint(x: cx + laneW * 0.48, y: y))
                track.stroke(line, with: .color(lit ? Palette.stage.color : Palette.beamOff.color),
                             lineWidth: 2)
                if lane == 0 {
                    label(&track, name, center: CGPoint(x: (cx - laneW * 0.48) / 2, y: y),
                          Palette.subtle, 10)
                }
            }
            beam(0, s.preStageLit[lane], "PRE")
            beam(TreeModel.stageBeamIn, s.stageLit[lane], "STAGE")

            // top-down car pointing up the track; pos is the front tyre edge
            let body = lane == s.userLane ? Palette.you : Palette.opponent
            let frontY = inchY(s.carPos[lane])
            let halfW = laneW * 0.30
            let tyreW = halfW * 0.35
            let tyreL = 26 * scale
            // nose ahead of the front tyres, body running back off the view
            track.fill(Path(roundedRect: rect(cx - halfW * 0.45, frontY - 14 * scale,
                                              cx + halfW * 0.45, frontY + 200 * scale),
                            cornerRadius: halfW * 0.3),
                       with: .color(body.color))
            track.fill(Path(roundedRect: rect(cx - halfW * 0.75, frontY + tyreL * 0.5,
                                              cx + halfW * 0.75, frontY + 200 * scale),
                            cornerRadius: 4),
                       with: .color(body.color))
            // front tyres
            track.fill(Path(roundedRect: rect(cx - halfW, frontY, cx - halfW + tyreW, frontY + tyreL),
                            cornerRadius: 2),
                       with: .color(Palette.tyre.color))
            track.fill(Path(roundedRect: rect(cx + halfW - tyreW, frontY, cx + halfW, frontY + tyreL),
                            cornerRadius: 2),
                       with: .color(Palette.tyre.color))
        }
    }
}
