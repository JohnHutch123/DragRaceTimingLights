// Drag racing tree reaction time trainer: the run, the timing and the pedals.
// A port of MainForm.pas from the Delphi app.
//
// A run:
//   START -> both cars roll up to the beams. The pre-stage bulb lights when
//            the front tyre breaks the pre-stage beam, the stage bulb when it
//            breaks the stage beam (7 in further on).
//         -> once both lanes are staged and you are holding the car on the
//            brake (and clutch, with a manual gearbox), a random wait
//            (0.8 to 3.0 s)
//         -> countdown:
//              Pro tree:       all three ambers together, green 0.400 s later
//              Sportsman tree: ambers one after another 0.500 s apart,
//                              green 0.500 s after the last amber
// You launch by letting the car go: release the brake (automatic gearbox) or
// release both brake and clutch (manual gearbox).
// Reaction time = release time - time the green is due.
// 0.000 is a perfect light; anything below zero is a red light.
//
// Pedals are on-screen pads used with several fingers at once:
//   BRAKE    always. Hold to stop, ease off to creep (manual staging).
//   CLUTCH   with a manual gearbox. Must be held in to stage.
//   THROTTLE with manual throttle. Hold for full throttle; launching without
//            it bogs the car.
// Without multi-touch (the Mac) only the brake is used, by mouse or the
// space bar.
//
// Rolling right through the stage beam is "too far forward" and ends the run.
//
// All times are milliseconds on the system uptime clock, the same clock
// UITouch.timestamp and NSEvent.timestamp use, so a pedal change is dated to
// the moment the touch or key happened rather than when it was delivered.

import Combine
import Foundation

enum TreeMode: Int, CaseIterable {
    case pro, sportsman
    var name: String { self == .pro ? "Pro" : "Sportsman" }
}

enum AutoManual: Int, CaseIterable {
    case auto, manual
    var name: String { self == .auto ? "Auto" : "Manual" }
}

enum TreePhase {
    case idle, staging, waiting, countdown, green
}

enum Pedal: Int, CaseIterable {
    case clutch, brake, throttle

    var name: String {
        switch self {
        case .clutch: return "CLUTCH"
        case .brake: return "BRAKE"
        case .throttle: return "THROTTLE"
        }
    }
}

let laneNames = ["Left", "Right"]

/// A colour as plain numbers so the model stays free of UI frameworks.
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func dimmed(_ f: Double) -> RGB {
        RGB(r: r * f, g: g * f, b: b * f)
    }
}

enum Palette {
    static let background = RGB(0x121212)
    static let panel = RGB(0x1E1E1E)
    static let housing = RGB(0x262626)
    static let rim = RGB(0x050505)
    static let track = RGB(0x3A3A3A)
    static let stage = RGB(0xFFF4C8)
    static let amber = RGB(0xFFB000)
    static let green = RGB(0x19FF4A)
    static let red = RGB(0xFF2424)
    static let you = RGB(0x3DA5FF)
    static let opponent = RGB(0xB0B0B0)
    static let text = RGB(0xF0F0F0)
    static let subtle = RGB(0x9A9A9A)
    static let padIdle = RGB(0x2C2C2C)
    static let beamOff = RGB(0x8A8A8A)
    static let tyre = RGB(0x0A0A0A)

    static func pedal(_ p: Pedal) -> RGB {
        switch p {
        case .clutch: return RGB(0x3D7BFF)
        case .brake: return RGB(0xE53935)
        case .throttle: return RGB(0x2EBD4E)
        }
    }
}

struct RunResult {
    var reactionMs: Double
    var foul: Bool
    var beforeTree: Bool   // left before the countdown had even started
    var bogged: Bool       // launched with the throttle closed
    var mode: TreeMode
}

struct Car {
    var pos: Double = TreeModel.carStartIn  // inches, see the geometry constants
    var speed: Double = 0                   // inches per second
    var launched = false
    var rollAtMs: Double = 0                // opponent only: when it starts rolling in
    var launchAtMs: Double = 0              // opponent only: when it will leave
}

/// Everything the tree drawing needs, taken at one instant.
struct TreeDrawState {
    var userLane: Int
    var preStageLit: [Bool]
    var stageLit: [Bool]
    var amberLit: [Bool]
    var greenLit: [Bool]
    var redLit: Bool
    var carPos: [Double]
}

func formatSecs(_ ms: Double) -> String {
    String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), ms / 1000)
}

func nowMs() -> Double {
    ProcessInfo.processInfo.systemUptime * 1000
}

final class TreeModel: ObservableObject {
    static let proAmberMs = 400.0    // Pro tree: ambers to green
    static let sportAmberMs = 500.0  // Sportsman tree: gap between each amber and green
    static let autoStartMinMs = 800.0   // random wait after both lanes are staged
    static let autoStartRandMs = 2200.0
    static let historyLines = 20

    // Staging geometry in inches, measured from the pre-stage beam to the
    // leading edge of the front tyre. Positive is forward.
    static let stageBeamIn = 7.0     // stage beam is 7 in past the pre-stage beam
    static let preStageOffIn = 11.0  // deep staging: pre-stage bulb goes out
    static let tooFarIn = 16.0       // tyre has rolled right through the stage beam
    static let autoStageIn = 8.5     // where auto staging stops (shallow stage)
    static let carStartIn = -40.0
    static let offScreenIn = 240.0

    // settings, saved between sessions
    @Published var treeMode: TreeMode { didSet { save() } }
    @Published var userLane: Int { didSet { save() } }   // 0 = left, 1 = right
    @Published var stageMode: AutoManual { didSet { save() } }
    @Published var transMode: AutoManual { didSet { save() } }
    @Published var throttleMode: AutoManual { didSet { save() } }
    @Published var showingSettings = false

    /// false: brake only (the Mac, with a mouse and the space bar)
    let multiTouch: Bool

    @Published private(set) var results: [RunResult] = []
    @Published private(set) var pressed: Set<Pedal> = []   // what the car sees
    @Published private(set) var reactionText = "-.---"
    @Published private(set) var reactionColor = Palette.text
    @Published private(set) var verdict = "Press START to stage"
    @Published private(set) var verdictColor = Palette.subtle
    @Published private(set) var hint = "Press START"
    @Published private(set) var running = false
    @Published private(set) var frame = 0   // bumped every tick to redraw

    private(set) var phase = TreePhase.idle
    private var countdownMs = 0.0           // when the first amber lights
    private var cars = [Car(), Car()]       // indexed by lane
    private var redLit = false              // red bulb in the user's lane
    private var userLaunched = false
    private var lastTickMs = 0.0
    private var timer: Timer?

    private var touchPedals: Set<Pedal> = []   // from multi-touch
    private var mousePedals: Set<Pedal> = []   // from the mouse
    private var keyPedals: Set<Pedal> = []     // from the keyboard

    init(multiTouch: Bool) {
        self.multiTouch = multiTouch
        let d = UserDefaults.standard
        treeMode = TreeMode(rawValue: d.integer(forKey: "Tree")) ?? .pro
        userLane = min(max(d.integer(forKey: "Lane"), 0), 1)
        stageMode = AutoManual(rawValue: d.integer(forKey: "Staging")) ?? .auto
        transMode = AutoManual(rawValue: d.integer(forKey: "Trans")) ?? .auto
        throttleMode = AutoManual(rawValue: d.integer(forKey: "Throttle")) ?? .auto
        resetTree()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(treeMode.rawValue, forKey: "Tree")
        d.set(userLane, forKey: "Lane")
        d.set(stageMode.rawValue, forKey: "Staging")
        d.set(transMode.rawValue, forKey: "Trans")
        d.set(throttleMode.rawValue, forKey: "Throttle")
    }

    // MARK: - tree state

    var oppLane: Int { 1 - userLane }

    var greenDueMs: Double {
        treeMode == .pro
            ? countdownMs + TreeModel.proAmberMs
            : countdownMs + 3 * TreeModel.sportAmberMs
    }

    func preStageLit(_ lane: Int) -> Bool {
        cars[lane].pos >= 0 && cars[lane].pos < TreeModel.preStageOffIn
    }

    func stageLit(_ lane: Int) -> Bool {
        cars[lane].pos >= TreeModel.stageBeamIn && cars[lane].pos < TreeModel.tooFarIn
    }

    private var treeLit: Bool { phase == .countdown || phase == .green }

    func amberLit(_ index: Int, _ t: Double) -> Bool {
        guard treeLit else { return false }
        if treeMode == .pro {
            return t >= countdownMs && t < countdownMs + TreeModel.proAmberMs
        }
        // Sportsman: top to bottom, each one on for 0.5 s
        let start = countdownMs + Double(index) * TreeModel.sportAmberMs
        return t >= start && t < start + TreeModel.sportAmberMs
    }

    func greenLit(_ lane: Int, _ t: Double) -> Bool {
        if lane == userLane && redLit { return false }
        return treeLit && t >= greenDueMs
    }

    func drawState() -> TreeDrawState {
        let t = nowMs()
        return TreeDrawState(
            userLane: userLane,
            preStageLit: [preStageLit(0), preStageLit(1)],
            stageLit: [stageLit(0), stageLit(1)],
            amberLit: [amberLit(0, t), amberLit(1, t), amberLit(2, t)],
            greenLit: [greenLit(0, t), greenLit(1, t)],
            redLit: redLit,
            carPos: [cars[0].pos, cars[1].pos])
    }

    // MARK: - pedals

    var effTrans: AutoManual { multiTouch ? transMode : .auto }
    var effThrottle: AutoManual { multiTouch ? throttleMode : .auto }

    func pedalUsed(_ p: Pedal) -> Bool {
        switch p {
        case .clutch: return effTrans == .manual
        case .throttle: return effThrottle == .manual
        case .brake: return true
        }
    }

    /// The pads on screen, left to right.
    var usedPedals: [Pedal] { Pedal.allCases.filter { pedalUsed($0) } }

    /// The car is held while the brake is on or, with a manual gearbox,
    /// while the clutch is in.
    func carHeld(_ s: Set<Pedal>) -> Bool {
        s.contains(.brake) || (effTrans == .manual && s.contains(.clutch))
    }

    /// Ready to start the tree: on the brake, and clutch in with a manual box.
    func carReady(_ s: Set<Pedal>) -> Bool {
        s.contains(.brake) && (effTrans == .auto || s.contains(.clutch))
    }

    var throttleOpen: Bool { effThrottle == .auto || pressed.contains(.throttle) }

    /// Every pedal under a finger right now. `seconds` is the event timestamp.
    func setTouchPedals(_ s: Set<Pedal>, at seconds: TimeInterval) {
        touchPedals = s
        pedalsChanged(seconds * 1000)
    }

    func setMousePedals(_ s: Set<Pedal>, at seconds: TimeInterval) {
        mousePedals = s
        pedalsChanged(seconds * 1000)
    }

    func setKeyBrake(_ down: Bool, at seconds: TimeInterval) {
        if down { keyPedals.insert(.brake) } else { keyPedals.remove(.brake) }
        pedalsChanged(seconds * 1000)
    }

    private func pedalsChanged(_ t: Double) {
        let old = pressed
        let new = touchPedals.union(mousePedals).union(keyPedals).filter { pedalUsed($0) }
        if new == old { return }
        pressed = new

        // Letting the car go once the tree is running is the launch
        if running && !userLaunched
            && (phase == .waiting || phase == .countdown || phase == .green)
            && carHeld(old) && !carHeld(new) {
            launch(at: t)
        }
        updateHint()
    }

    // MARK: - settings

    var summary: String {
        var s = "\(treeMode.name) tree, \(laneNames[userLane].lowercased()) lane, "
            + "\(stageMode.name.lowercased()) staging"
        if multiTouch {
            s += ", \(effTrans.name.lowercased()) trans, \(effThrottle.name.lowercased()) throttle"
        } else {
            s += ", brake only"
        }
        return s
    }

    func openSettings() {
        if running { return }
        showingSettings = true
    }

    /// The pedal set may have changed.
    func settingsClosed() {
        touchPedals = []
        mousePedals = []
        pressed = []
        resetTree()
    }

    // MARK: - running the tree

    func resetTree() {
        stopTimer()
        phase = .idle
        running = false
        redLit = false
        userLaunched = false
        for lane in 0...1 {
            cars[lane] = Car()
        }
        reactionText = "-.---"
        reactionColor = Palette.text
        setVerdict("Press START to stage", Palette.subtle)
        updateHint()
        frame &+= 1
    }

    func startRun() {
        if showingSettings { return }
        resetTree()
        running = true
        phase = .staging
        // the other car starts rolling a moment later
        let t = nowMs()
        cars[oppLane].rollAtMs = t + 300
        lastTickMs = t
        setVerdict("Staging...", Palette.subtle)
        updateHint()
        startTimer()
    }

    func stopRun(_ msg: String = "Stopped") {
        stopTimer()
        phase = .idle
        running = false
        setVerdict(msg, Palette.subtle)
        updateHint()
        frame &+= 1
    }

    func stopPressed() {
        if running { stopRun() }
    }

    func clearHistory() {
        results.removeAll()
        resetTree()
    }

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func moveCars(_ t: Double, _ dt: Double) {
        let launchAccel = 900.0  // in/s^2, a bit over 2 g
        let bogAccel = 60.0      // throttle closed: barely moving
        let autoRollIn = 40.0    // fast roll-in speed, in/s
        let creepIn = 4.0        // creeping speed near the beams, in/s
        let minSpeed = 2.0

        for lane in 0...1 {
            if cars[lane].launched {
                if cars[lane].pos < TreeModel.offScreenIn {
                    var accel = launchAccel
                    if lane == userLane && !throttleOpen {
                        accel = bogAccel
                    }
                    cars[lane].speed += accel * dt
                    cars[lane].pos += cars[lane].speed * dt
                }
                continue
            }

            if phase != .staging { continue }

            let auto = lane == oppLane || stageMode == .auto
            if auto {
                // the opponent waits a moment before it rolls in
                if lane == oppLane && t < cars[lane].rollAtMs { continue }
                let gap = TreeModel.autoStageIn - cars[lane].pos
                if gap > 0.05 {
                    // fast roll-in, slowing to a creep near the beams
                    let step = min(max(gap * 1.5, minSpeed), autoRollIn) * dt
                    cars[lane].pos = min(TreeModel.autoStageIn, cars[lane].pos + step)
                } else {
                    cars[lane].pos = TreeModel.autoStageIn
                }
            } else if !carHeld(pressed) {
                // manual staging: off the brake the car idles forward
                if cars[lane].pos < -12 {
                    cars[lane].pos += autoRollIn * dt
                } else {
                    cars[lane].pos += creepIn * dt
                }
            }
        }
    }

    private func tick() {
        let t = nowMs()
        let dt = min((t - lastTickMs) / 1000, 0.1)
        lastTickMs = t
        let opp = oppLane

        moveCars(t, dt)

        switch phase {
        case .staging:
            if cars[userLane].pos >= TreeModel.tooFarIn {
                redLit = true
                stopRun("TOO FAR FORWARD - press Reset")
                verdictColor = Palette.red
                return
            }
            if stageLit(userLane) && !preStageLit(userLane) {
                setVerdict("Deep staged", Palette.amber)
            } else if stageLit(userLane) {
                setVerdict("Staged", Palette.subtle)
            } else if preStageLit(userLane) {
                setVerdict("Pre-staged", Palette.subtle)
            }
            // the tree starts once both lanes are staged and you are holding
            // the car ready to go
            if stageLit(userLane) && carReady(pressed)
                && (stageMode == .manual || cars[userLane].pos >= TreeModel.autoStageIn)
                && stageLit(opp) && cars[opp].pos >= TreeModel.autoStageIn {
                phase = .waiting
                countdownMs = t + TreeModel.autoStartMinMs
                    + Double.random(in: 0..<TreeModel.autoStartRandMs)
                cars[opp].launchAtMs = greenDueMs + 120 + Double.random(in: 0..<180)
            }
            updateHint()
        case .waiting:
            if t >= countdownMs { phase = .countdown }
        case .countdown:
            if t >= greenDueMs { phase = .green }
        case .idle, .green:
            break
        }

        // the other lane leaves on its own green
        if phase == .green && !cars[opp].launched && t >= cars[opp].launchAtMs {
            cars[opp].launched = true
        }

        // finished once both cars are away
        if userLaunched && phase == .green
            && cars[userLane].pos >= TreeModel.offScreenIn
            && cars[opp].pos >= TreeModel.offScreenIn {
            stopTimer()
            running = false
            updateHint()
        }

        frame &+= 1
    }

    private func launch(at releaseMs: Double) {
        if !running || userLaunched { return }

        userLaunched = true
        cars[userLane].launched = true
        let reaction = releaseMs - greenDueMs
        let r = RunResult(
            reactionMs: reaction,
            foul: reaction < 0,
            beforeTree: phase == .waiting,
            bogged: !throttleOpen,
            mode: treeMode)

        // A red light lights your red bulb; the tree carries on for the other lane
        if r.foul { redLit = true }

        results.append(r)
        showResult(r)
        updateHint()
        frame &+= 1
    }

    private func showResult(_ r: RunResult) {
        var text: String
        var color: RGB
        if r.foul {
            text = r.beforeTree ? "RED LIGHT - went before the tree" : "RED LIGHT"
            color = Palette.red
        } else {
            color = Palette.green
            if r.reactionMs < 10 {
                text = "PERFECT LIGHT!"
            } else if r.reactionMs < 50 {
                text = "Great light"
            } else if r.reactionMs < 100 {
                text = "Good light"
            } else if r.reactionMs < 200 {
                text = "A bit late"
                color = Palette.amber
            } else {
                text = "Asleep on the tree"
                color = Palette.amber
            }
        }
        if r.bogged { text += " - bogged, no throttle" }
        reactionText = formatSecs(r.reactionMs)
        reactionColor = color
        setVerdict(text, color)
    }

    private func setVerdict(_ text: String, _ color: RGB) {
        if verdict != text { verdict = text }
        if verdictColor != color { verdictColor = color }
    }

    private func updateHint() {
        let need = effTrans == .manual ? "hold BRAKE + CLUTCH" : "hold BRAKE"
        let text: String
        if !running {
            text = userLaunched ? "START for another run" : "Press START"
        } else if userLaunched {
            text = effThrottle == .manual && !throttleOpen ? "Hold THROTTLE!" : ""
        } else if phase == .staging {
            if stageMode == .manual && !stageLit(userLane) {
                text = "Ease off the brake to creep in"
            } else if !carReady(pressed) {
                text = "Staged: " + need
            } else {
                text = "Waiting for the other lane"
            }
        } else if effTrans == .manual {
            text = "Release BRAKE and CLUTCH to launch"
        } else {
            text = "Release BRAKE to launch"
        }
        if hint != text { hint = text }
    }

    // MARK: - stats

    var statsText: String {
        let good = results.filter { !$0.foul }
        let fouls = results.count - good.count
        if good.isEmpty {
            return "Runs \(results.count)   Best -.---   Avg -.---   Red \(fouls)"
        }
        let best = good.map { $0.reactionMs }.min() ?? 0
        let avg = good.map { $0.reactionMs }.reduce(0, +) / Double(good.count)
        return "Runs \(results.count)   Best \(formatSecs(best))   "
            + "Avg \(formatSecs(avg))   Red \(fouls)"
    }

    var historyText: String {
        var lines: [String] = []
        var i = results.count - 1
        while i >= 0 && i >= results.count - TreeModel.historyLines {
            let r = results[i]
            var line = "#\(i + 1)  \(formatSecs(r.reactionMs))"
            if r.mode == .sportsman { line += " S" }
            if r.foul { line += " R" }
            if r.bogged { line += " B" }
            lines.append(line)
            i -= 1
        }
        return lines.joined(separator: "\n")
    }
}
