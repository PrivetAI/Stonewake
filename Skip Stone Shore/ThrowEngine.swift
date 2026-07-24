import Foundation
import CoreGraphics
import Combine

// Fixed-step stone-skipping integrator. 120 Hz steps fed by a 60 Hz render timer
// through an accumulator. Deterministic for a given level + stone + attempt index
// + launch input: gusts are pre-seeded per attempt, waves are analytic in time.

enum EnginePhase {
    case ready      // stone waiting on the hand, aiming allowed
    case flying
    case finished
}

enum GameEvent {
    case launched
    case skip(TapQuality)
    case ring(Int)
    case pad
    case buoy
    case wood
    case sank
    case settled
    case landed
}

struct GustSpec {
    let start: Double
    let duration: Double
    let strength: Double
}

struct SplashFX: Identifiable {
    let id: Int
    let x: Double
    let y: Double
    let born: Double
    let kind: TapQuality
    let big: Bool
}

final class ThrowEngine: ObservableObject {

    // Tuning constants
    static let fixedStep: Double = 1.0 / 120.0
    static let gravity: Double = 9.8
    static let baseMaxSpeed: Double = 20.0
    static let minAngle: Double = 4.0 * .pi / 180.0
    static let maxAngle: Double = 32.0 * .pi / 180.0
    static let launchHeight: Double = 1.1
    static let ringRadius: Double = 1.15
    static let padRadius: Double = 1.0
    static let buoyRadius: Double = 0.65
    static let ringLead: Double = 0.6      // seconds before contact the timing ring appears

    let level: LevelSpec
    let stone: StoneSpec
    private(set) var attemptIndex: Int

    // Published tick drives SwiftUI invalidation; state is read directly.
    @Published private(set) var tick: Int = 0

    private(set) var phase: EnginePhase = .ready
    private(set) var time: Double = 0
    private(set) var x: Double = 0
    private(set) var y: Double = ThrowEngine.launchHeight
    private(set) var vx: Double = 0
    private(set) var vy: Double = 0
    private(set) var spin: Double = 1.0
    private(set) var rotation: Double = 0
    private(set) var outcome = ThrowOutcome()
    private(set) var fx: [SplashFX] = []
    private(set) var lastQuality: TapQuality? = nil
    private(set) var lastQualityAt: Double = -10

    // Timing beat
    private(set) var predictedContactTime: Double? = nil
    private(set) var predictedContactX: Double = 0
    private(set) var predictedContactY: Double = 0
    private var lastTapTime: Double = -100
    private var tapFlashAt: Double = -10

    private var accumulator: Double = 0
    private var gusts: [GustSpec] = []
    private var fxCounter = 0
    private var buoyStunned = false
    private var trajectorySampleCounter = 0

    var onEvent: ((GameEvent) -> Void)?

    init(level: LevelSpec, stone: StoneSpec, attemptIndex: Int) {
        self.level = level
        self.stone = stone
        self.attemptIndex = attemptIndex
        seedGusts()
    }

    // MARK: - Setup

    private func seedGusts() {
        gusts = []
        guard level.gustPower > 0.01 else { return }
        var rng = SeededRNG(seed: UInt64(level.id) &* 7919 &+ UInt64(attemptIndex + 1) &* 104729)
        let count = rng.int(3, 6)
        var t = rng.range(0.8, 2.0)
        for _ in 0..<count {
            let dur = rng.range(0.8, 1.8)
            let str = rng.range(0.35, 1.0) * level.gustPower * (rng.double01() > 0.35 ? 1.0 : -0.7)
            gusts.append(GustSpec(start: t, duration: dur, strength: str))
            t += dur + rng.range(0.6, 1.6)
        }
    }

    func resetForNextThrow(attemptIndex: Int) {
        self.attemptIndex = attemptIndex
        phase = .ready
        time = 0
        x = 0
        y = ThrowEngine.launchHeight
        vx = 0
        vy = 0
        spin = 1.0
        rotation = 0
        outcome = ThrowOutcome()
        fx = []
        lastQuality = nil
        lastQualityAt = -10
        predictedContactTime = nil
        lastTapTime = -100
        accumulator = 0
        buoyStunned = false
        trajectorySampleCounter = 0
        seedGusts()
        tick &+= 1
    }

    // MARK: - Environment sampling

    func waveHeight(atX px: Double, t: Double) -> Double {
        var h = 0.0
        for wv in level.waves {
            h += wv.amplitude * sin(px / wv.wavelength * 2 * .pi + wv.phase + wv.speed * t)
        }
        return h
    }

    func windAt(_ t: Double) -> Double {
        var wnd = level.windBase
        for g in gusts {
            if t >= g.start && t <= g.start + g.duration {
                let f = (t - g.start) / g.duration
                wnd += g.strength * sin(f * .pi)
            }
        }
        return wnd
    }

    func buoyX(_ b: BuoySpec, t: Double) -> Double {
        guard b.sway > 0.01 else { return b.x }
        return b.x + b.sway * sin(2 * .pi * t / b.period)
    }

    // MARK: - Input

    func launch(angle: Double, power: Double) {
        guard phase == .ready else { return }
        let a = min(max(angle, ThrowEngine.minAngle), ThrowEngine.maxAngle)
        let p = min(max(power, 0.08), 1.0)
        let speed = ThrowEngine.baseMaxSpeed * stone.weight * (0.38 + 0.62 * p)
        vx = cos(a) * speed
        vy = sin(a) * speed
        phase = .flying
        outcome = ThrowOutcome()
        onEvent?(.launched)
        tick &+= 1
    }

    func tap() {
        guard phase == .flying else { return }
        lastTapTime = time
        tapFlashAt = time
        tick &+= 1
    }

    // MARK: - Main loop

    func advance(realDt: Double) {
        guard phase == .flying else { return }
        accumulator += min(realDt, 0.12)
        while accumulator >= ThrowEngine.fixedStep && phase == .flying {
            stepOnce()
            accumulator -= ThrowEngine.fixedStep
        }
        if phase == .flying { predictContact() }
        pruneFX()
        tick &+= 1
    }

    private func stepOnce() {
        let dt = ThrowEngine.fixedStep
        time += dt

        // Wind + gravity + drag
        vx += windAt(time) * 0.55 * dt
        vy -= ThrowEngine.gravity * dt
        let speed = max(0.001, sqrt(vx * vx + vy * vy))
        let drag = 0.008 * speed
        vx -= drag * vx * dt
        vy -= drag * vy * dt

        let prevX = x
        x += vx * dt
        y += vy * dt

        spin = max(0, spin - 0.04 * dt)
        rotation += (4.0 + spin * 9.0) * dt

        sampleTrajectory()
        checkRings()
        checkBuoys()
        if checkWood(prevX: prevX) { return }

        // Far shore ramp
        if x >= level.shoreRampStart {
            if y <= shoreGroundHeight(at: x) || x >= level.sceneLength {
                land()
                return
            }
        } else {
            let surf = waveHeight(atX: x, t: time)
            if vy < 0 && y <= surf {
                resolveContact(surface: surf)
            }
        }

        if y < -3 { finish(reason: .sank) }
    }

    func shoreGroundHeight(at px: Double) -> Double {
        guard px >= level.shoreRampStart else { return -10 }
        let f = min(1.0, (px - level.shoreRampStart) / 7.0)
        return -0.15 + f * f * 1.6
    }

    private func sampleTrajectory() {
        trajectorySampleCounter += 1
        if trajectorySampleCounter % 5 == 0 {
            outcome.trajectory.append(CGPoint(x: x, y: y))
        }
    }

    // MARK: - Targets

    private func checkRings() {
        for (i, ring) in level.rings.enumerated() {
            guard !outcome.ringsCollected.contains(i) else { continue }
            let dx = x - ring.x
            let dy = y - ring.height
            if dx * dx + dy * dy < ThrowEngine.ringRadius * ThrowEngine.ringRadius {
                outcome.ringsCollected.insert(i)
                spawnFX(kind: .perfect, big: false, atY: y)
                onEvent?(.ring(i))
            }
        }
    }

    private func checkBuoys() {
        guard !buoyStunned else { return }
        for b in level.buoys {
            let bx = buoyX(b, t: time)
            if abs(x - bx) < ThrowEngine.buoyRadius && y < 1.05 && y > -0.4 {
                buoyStunned = true
                outcome.buoyHits += 1
                vx *= 0.12
                vy = min(vy, 0.5)
                spin = 0
                spawnFX(kind: .miss, big: false, atY: y)
                onEvent?(.buoy)
                return
            }
        }
    }

    private func checkWood(prevX: Double) -> Bool {
        for wd in level.wood {
            if prevX < wd.x && x >= wd.x && y < wd.height {
                x = wd.x - 0.1
                spawnFX(kind: .miss, big: true, atY: 0)
                onEvent?(.wood)
                finish(reason: .blocked)
                return true
            }
        }
        return false
    }

    // MARK: - Contact resolution

    private var timingWindowScale: Double {
        stone.window * level.timingScale * (0.6 + 0.4 * min(1.0, spin))
    }

    private func gradeTap() -> TapQuality {
        let delta = time - lastTapTime
        lastTapTime = -100
        let ws = timingWindowScale
        if delta <= 0.11 * ws { return .perfect }
        if delta <= 0.26 * ws { return .good }
        if delta <= 0.46 * ws { return .late }
        return .miss
    }

    private func resolveContact(surface: Double) {
        // Lily pad: guaranteed strong skip, no tap needed
        if level.pads.contains(where: { abs($0.x - x) < ThrowEngine.padRadius }) {
            vy = abs(vy) * 0.92 * stone.lift
            vx *= 0.98
            y = surface + 0.02
            outcome.skips += 1
            outcome.padHits += 1
            lastQuality = .pad
            lastQualityAt = time
            spin = min(1.0, spin + 0.15)
            spawnFX(kind: .pad, big: false, atY: surface)
            onEvent?(.pad)
            onEvent?(.skip(.pad))
            return
        }

        if buoyStunned {
            spawnFX(kind: .miss, big: true, atY: surface)
            finish(reason: .blocked)
            return
        }

        let q = gradeTap()
        lastQuality = q
        lastQualityAt = time

        switch q {
        case .perfect:
            vy = abs(vy) * 0.85 * stone.lift
            vx *= 0.95
        case .good:
            vy = abs(vy) * 0.65 * stone.lift
            vx *= 0.9
        case .late:
            vy = abs(vy) * 0.35 * stone.lift
            vx *= 0.78
        case .miss, .pad:
            spawnFX(kind: .miss, big: true, atY: surface)
            onEvent?(.skip(.miss))
            finish(reason: .sank)
            return
        }

        y = surface + 0.02
        spin = max(0, spin - 0.16)
        outcome.skips += 1
        if q == .perfect { outcome.perfects += 1 }
        spawnFX(kind: q, big: false, atY: surface)
        onEvent?(.skip(q))

        // Out of speed: the stone settles into the water
        if vy < 0.55 || vx < 1.1 {
            finish(reason: .settled)
        }
    }

    private func land() {
        spawnFX(kind: .good, big: false, atY: y)
        finish(reason: .landed)
    }

    private func finish(reason: ThrowEndReason) {
        outcome.end = reason
        outcome.distance = max(0, x)
        outcome.trajectory.append(CGPoint(x: x, y: y))
        phase = .finished
        predictedContactTime = nil
        switch reason {
        case .sank, .blocked: onEvent?(.sank)
        case .settled: onEvent?(.settled)
        case .landed: onEvent?(.landed)
        }
        tick &+= 1
    }

    // MARK: - Contact prediction (for the shrinking timing ring)

    private func predictContact() {
        guard phase == .flying, !buoyStunned else {
            predictedContactTime = nil
            return
        }
        var px = x, py = y, pvx = vx, pvy = vy
        var pt = time
        let dt = 1.0 / 60.0
        var found = false
        for _ in 0..<120 {
            pvy -= ThrowEngine.gravity * dt
            px += pvx * dt
            py += pvy * dt
            pt += dt
            if px >= level.shoreRampStart { break }
            if pvy < 0 && py <= waveHeight(atX: px, t: pt) {
                found = true
                break
            }
        }
        if found {
            predictedContactTime = pt
            predictedContactX = px
            predictedContactY = waveHeight(atX: px, t: pt)
        } else {
            predictedContactTime = nil
        }
    }

    /// 1.0 when the ring first appears, 0.0 at contact. nil = hidden.
    var timingRingProgress: Double? {
        guard phase == .flying, let ct = predictedContactTime else { return nil }
        let remain = ct - time
        guard remain >= 0 && remain <= ThrowEngine.ringLead else { return nil }
        return remain / ThrowEngine.ringLead
    }

    var tapFlashActive: Bool {
        time - tapFlashAt < 0.18
    }

    // MARK: - FX

    private func spawnFX(kind: TapQuality, big: Bool, atY: Double) {
        fxCounter += 1
        fx.append(SplashFX(id: fxCounter, x: x, y: atY, born: time, kind: kind, big: big))
    }

    private func pruneFX() {
        if fx.count > 24 { fx.removeFirst(fx.count - 24) }
    }

    // Keeps ambient water animation flowing while aiming or finished.
    func advanceAmbient(realDt: Double) {
        time += min(realDt, 0.12)
        tick &+= 1
    }
}
