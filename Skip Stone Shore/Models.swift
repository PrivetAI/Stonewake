import Foundation
import CoreGraphics

// MARK: - Deterministic RNG (SplitMix64)

struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func double01() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + double01() * (hi - lo)
    }
    mutating func int(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        return lo + Int(next() % UInt64(hi - lo + 1))
    }
}

// MARK: - Level data model

struct WaveComponent {
    let amplitude: Double   // meters
    let wavelength: Double  // meters
    let speed: Double       // rad/s phase speed
    let phase: Double       // rad
}

struct RingSpec {
    let x: Double       // meters from launch
    let height: Double  // ring center height above waterline, meters
}

struct PadSpec {
    let x: Double
}

struct BuoySpec {
    let x: Double
    let sway: Double    // horizontal oscillation amplitude, meters (0 = static)
    let period: Double  // oscillation period, seconds
}

struct WoodSpec {
    let x: Double
    let height: Double  // barrier height above water, meters
}

enum GoalSpec {
    case distance(Double)
    case rings(Int)
    case skips(Int)
    case perfects(Int)
    case pads(Int)
    case reachShore

    var text: String {
        switch self {
        case .distance(let d): return "Reach \(Int(d)) m in one throw"
        case .rings(let n): return n == 1 ? "Pass through 1 ring" : "Pass through \(n) rings in one throw"
        case .skips(let n): return "Skip \(n) times in one throw"
        case .perfects(let n): return n == 1 ? "Land 1 perfect skip" : "Land \(n) perfect skips in one throw"
        case .pads(let n): return n == 1 ? "Bounce off 1 lily pad" : "Bounce off \(n) lily pads in one throw"
        case .reachShore: return "Land on the far shore"
        }
    }
}

struct LevelSpec: Identifiable {
    let id: Int          // 1...60
    let shore: Int       // 0...4
    let index: Int       // 1...12 within shore
    let name: String
    let sceneLength: Double   // meters to the far shore
    let windBase: Double      // m/s^2-ish steady push (+ tailwind, - headwind)
    let gustPower: Double     // peak gust strength
    let waves: [WaveComponent]
    let rings: [RingSpec]
    let pads: [PadSpec]
    let buoys: [BuoySpec]
    let wood: [WoodSpec]
    let goals: [GoalSpec]
    let parSkips: Int
    let timingScale: Double   // multiplies timing windows (smaller = harder)

    var shoreRampStart: Double { sceneLength - 7 }
}

struct ShoreSpec: Identifiable {
    let id: Int
    let name: String
    let tagline: String
    let blurb: String
}

// MARK: - Stones

enum StoneUnlock {
    case start
    case stars(Int)
    case streak(Int)
    case longestThrow(Double)
    case zenBest(Double)
    case perfects(Int)

    var text: String {
        switch self {
        case .start: return "Yours from the first morning"
        case .stars(let n): return "Earn \(n) stars"
        case .streak(let n): return "Keep a \(n)-day Daily Throw streak"
        case .longestThrow(let d): return "Throw \(Int(d)) m in a single throw"
        case .zenBest(let d): return "Drift \(Int(d)) m on the Zen Shore"
        case .perfects(let n): return "Land \(n) perfect skips in total"
        }
    }
}

struct StoneSpec: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let weight: Double      // launch speed factor (1.0 = neutral)
    let lift: Double        // restitution factor (1.0 = neutral)
    let window: Double      // timing window factor (1.0 = neutral)
    let bodyHex: UInt32
    let sheenHex: UInt32
    let speckHex: UInt32
    let unlock: StoneUnlock

    var statLine: String {
        func fmt(_ v: Double) -> String {
            let pct = Int(round((v - 1.0) * 100))
            if pct == 0 { return "even" }
            return pct > 0 ? "+\(pct)%" : "\(pct)%"
        }
        return "Throw \(fmt(weight)) | Lift \(fmt(lift)) | Window \(fmt(window))"
    }
}

// MARK: - Achievements

enum AchievementMetric {
    case totalSkips(Int)
    case skipsInOneThrow(Int)
    case perfectsTotal(Int)
    case ringsTotal(Int)
    case padsTotal(Int)
    case sunkTotal(Int)
    case longestThrow(Double)
    case shoreCleared(Int)   // shore index, every level >= 1 star
    case starsTotal(Int)
    case zenBest(Double)
    case dailyStreak(Int)
}

struct AchievementSpec: Identifiable {
    let id: String
    let name: String
    let detail: String
    let metric: AchievementMetric
}

// MARK: - Tap grading

enum TapQuality {
    case perfect, good, late, miss, pad

    var label: String {
        switch self {
        case .perfect: return "Perfect"
        case .good: return "Good"
        case .late: return "Late"
        case .miss: return "Sunk"
        case .pad: return "Pad Bounce"
        }
    }
}

enum ThrowEndReason: Equatable {
    case sank        // missed the timing beat
    case settled     // ran out of speed, glided to rest
    case landed      // reached the far shore
    case blocked     // stopped by driftwood or buoy then sank
}

struct ThrowOutcome {
    var distance: Double = 0
    var skips: Int = 0
    var perfects: Int = 0
    var ringsCollected: Set<Int> = []
    var padHits: Int = 0
    var buoyHits: Int = 0
    var end: ThrowEndReason = .sank
    var trajectory: [CGPoint] = []

    var landedOnShore: Bool { end == .landed }
}

// MARK: - Goal evaluation

func goalMet(_ goal: GoalSpec, by outcome: ThrowOutcome) -> Bool {
    switch goal {
    case .distance(let d): return outcome.distance >= d
    case .rings(let n): return outcome.ringsCollected.count >= n
    case .skips(let n): return outcome.skips >= n
    case .perfects(let n): return outcome.perfects >= n
    case .pads(let n): return outcome.padHits >= n
    case .reachShore: return outcome.landedOnShore
    }
}

// MARK: - Daily helpers

enum SSDaily {
    static func dateKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    static func seed(for key: String) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for b in key.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001B3
        }
        return h
    }

    static func previousDayKey(of key: String) -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        guard let d = f.date(from: key),
              let prev = Calendar.current.date(byAdding: .day, value: -1, to: d) else { return nil }
        return f.string(from: prev)
    }

    /// Deterministic daily level from the date seed. Parameters stay inside validated ranges.
    static func makeLevel(for key: String) -> LevelSpec {
        var rng = SeededRNG(seed: seed(for: key))
        let len = rng.range(95, 150)
        let windBase = rng.range(-1.4, 1.8)
        let gust = rng.range(0.0, 1.8)
        let waveCount = rng.int(2, 3)
        var waves: [WaveComponent] = []
        for _ in 0..<waveCount {
            waves.append(WaveComponent(amplitude: rng.range(0.05, 0.3),
                                       wavelength: rng.range(6, 22),
                                       speed: rng.range(0.4, 1.4),
                                       phase: rng.range(0, 6.28)))
        }
        var rings: [RingSpec] = []
        let ringCount = rng.int(2, 4)
        for i in 0..<ringCount {
            let x = rng.range(18 + Double(i) * 22, 30 + Double(i) * 22)
            rings.append(RingSpec(x: min(x, len - 12), height: rng.range(0.8, 2.0)))
        }
        var pads: [PadSpec] = []
        if rng.double01() > 0.35 {
            pads.append(PadSpec(x: rng.range(30, len - 25)))
        }
        var buoys: [BuoySpec] = []
        if rng.double01() > 0.45 {
            buoys.append(BuoySpec(x: rng.range(35, len - 20), sway: rng.range(0, 2.5), period: rng.range(3, 6)))
        }
        var wood: [WoodSpec] = []
        if rng.double01() > 0.55 {
            wood.append(WoodSpec(x: rng.range(20, len - 30), height: rng.range(0.4, 0.7)))
        }
        let distGoal = min(len - 12, rng.range(55, 95))
        return LevelSpec(
            id: 1000, shore: 5, index: 0, name: "Daily Throw",
            sceneLength: len, windBase: windBase, gustPower: gust,
            waves: waves, rings: rings, pads: pads, buoys: buoys, wood: wood,
            goals: [.distance(distGoal), .rings(min(2, rings.count)), .skips(rng.int(5, 7))],
            parSkips: 6, timingScale: rng.range(0.85, 1.1)
        )
    }

    static func score(for outcome: ThrowOutcome) -> Int {
        var s = Int(outcome.distance * 10)
        s += outcome.skips * 45
        s += outcome.perfects * 70
        s += outcome.ringsCollected.count * 180
        s += outcome.padHits * 60
        if outcome.landedOnShore { s += 400 }
        return s
    }
}

// MARK: - Zen helpers

enum SSZen {
    /// Endless calm lake, re-seeded daily; pads and rings scattered far out.
    static func makeLevel(dayKey: String) -> LevelSpec {
        var rng = SeededRNG(seed: SSDaily.seed(for: "zen-" + dayKey))
        var waves: [WaveComponent] = []
        for _ in 0..<2 {
            waves.append(WaveComponent(amplitude: rng.range(0.03, 0.09),
                                       wavelength: rng.range(9, 20),
                                       speed: rng.range(0.3, 0.7),
                                       phase: rng.range(0, 6.28)))
        }
        var pads: [PadSpec] = []
        var x = rng.range(26, 40)
        while x < 560 {
            pads.append(PadSpec(x: x))
            x += rng.range(24, 46)
        }
        var rings: [RingSpec] = []
        var rx = rng.range(20, 34)
        while rx < 560 {
            rings.append(RingSpec(x: rx, height: rng.range(0.7, 1.8)))
            rx += rng.range(30, 55)
        }
        return LevelSpec(
            id: 2000, shore: 6, index: 0, name: "Zen Shore",
            sceneLength: 600, windBase: 0, gustPower: 0,
            waves: waves, rings: rings, pads: pads, buoys: [], wood: [],
            goals: [.distance(60), .skips(6), .rings(2)],
            parSkips: 6, timingScale: 1.1
        )
    }
}
