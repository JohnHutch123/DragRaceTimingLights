// The pedal pads at the bottom of the screen.
//
// The pads are drawn in SwiftUI. Input comes from a transparent view laid over
// them: on iPhone a UIKit view with multi-touch, so clutch, brake and throttle
// can be held with separate fingers at once; on the Mac an AppKit view for the
// mouse (brake only). Both compute the same pad rectangles as the drawing and
// pass the event's own timestamp on, so a release is timed to when the finger
// actually lifted.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

let padGap: CGFloat = 8

/// The pads side by side with equal widths, left to right.
func padRects(count: Int, in bounds: CGRect) -> [CGRect] {
    guard count > 0 else { return [] }
    let w = (bounds.width - padGap * CGFloat(count - 1)) / CGFloat(count)
    return (0..<count).map { i in
        CGRect(x: bounds.minX + CGFloat(i) * (w + padGap), y: bounds.minY, width: w, height: bounds.height)
    }
}

func pedals(at points: [CGPoint], pads: [Pedal], in bounds: CGRect) -> Set<Pedal> {
    let rects = padRects(count: pads.count, in: bounds)
    var result = Set<Pedal>()
    for p in points {
        for (i, r) in rects.enumerated() where r.contains(p) {
            result.insert(pads[i])
        }
    }
    return result
}

struct PedalPads: View {
    @ObservedObject var model: TreeModel

    var body: some View {
        let pads = model.usedPedals
        ZStack {
            HStack(spacing: padGap) {
                ForEach(pads, id: \.self) { p in
                    let down = model.pressed.contains(p)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(down ? Palette.pedal(p).dimmed(0.75).color : Palette.padIdle.color)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Palette.pedal(p).color, lineWidth: 2))
                        .overlay(Text(p.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Palette.text.color))
                }
            }
            PedalInput(pads: pads, model: model)
        }
    }
}

#if os(iOS)
struct PedalInput: UIViewRepresentable {
    let pads: [Pedal]
    let model: TreeModel

    func makeUIView(context: Context) -> PedalTouchView {
        let v = PedalTouchView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: PedalTouchView, context: Context) {
        v.pads = pads
        v.model = model
    }
}

final class PedalTouchView: UIView {
    var pads: [Pedal] = []
    weak var model: TreeModel?
    private var active: [ObjectIdentifier: CGPoint] = [:]   // every finger that is down

    private func report(_ touches: Set<UITouch>, _ event: UIEvent?) {
        let stamp = event?.timestamp ?? touches.first?.timestamp ?? ProcessInfo.processInfo.systemUptime
        let under = pedals(at: Array(active.values), pads: pads, in: bounds)
        model?.setTouchPedals(under, at: stamp)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { active[ObjectIdentifier(t)] = t.location(in: self) }
        report(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { active[ObjectIdentifier(t)] = t.location(in: self) }
        report(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { active[ObjectIdentifier(t)] = nil }
        report(touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { active[ObjectIdentifier(t)] = nil }
        report(touches, event)
    }
}

#elseif os(macOS)
struct PedalInput: NSViewRepresentable {
    let pads: [Pedal]
    let model: TreeModel

    func makeNSView(context: Context) -> PedalMouseView {
        PedalMouseView()
    }

    func updateNSView(_ v: PedalMouseView, context: Context) {
        v.pads = pads
        v.model = model
    }
}

final class PedalMouseView: NSView {
    var pads: [Pedal] = []
    weak var model: TreeModel?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func report(_ event: NSEvent, down: Bool) {
        let p = convert(event.locationInWindow, from: nil)
        // dragging off a pad lets it go
        let under: Set<Pedal> = down ? pedals(at: [p], pads: pads, in: bounds) : []
        model?.setMousePedals(under, at: event.timestamp)
    }

    override func mouseDown(with event: NSEvent) { report(event, down: true) }
    override func mouseDragged(with event: NSEvent) { report(event, down: true) }
    override func mouseUp(with event: NSEvent) { report(event, down: false) }
}

/// Space is the brake, Return starts a run.
final class KeyMonitor: ObservableObject {
    private var monitor: Any?

    func install(_ model: TreeModel) {
        if monitor != nil { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak model] e in
            guard let model = model, !model.showingSettings else { return e }
            switch e.keyCode {
            case 49: // space
                if !(e.type == .keyDown && e.isARepeat) {
                    model.setKeyBrake(e.type == .keyDown, at: e.timestamp)
                }
                return nil
            case 36, 76: // return, keypad enter
                if e.type == .keyDown && !e.isARepeat { model.startRun() }
                return nil
            default:
                return e
            }
        }
    }

    func remove() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
#endif
