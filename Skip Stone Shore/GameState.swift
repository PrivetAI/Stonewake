import Foundation
import SwiftUI

// MARK: - Persisted records

struct LevelResult: Codable {
    var goalsMet: [Bool]
    var bestDistance: Double
    var bestSkips: Int
    var plays: Int

    init(goalsMet: [Bool] = [false, false, false], bestDistance: Double = 0, bestSkips: Int = 0, plays: Int = 0) {
        self.goalsMet = goalsMet
        self.bestDistance = bestDistance
        self.bestSkips = bestSkips
        self.plays = plays
    }

    enum CodingKeys: String, CodingKey { case goalsMet, bestDistance, bestSkips, plays }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goalsMet = (try c.decodeIfPresent([Bool].self, forKey: .goalsMet)) ?? [false, false, false]
        bestDistance = (try c.decodeIfPresent(Double.self, forKey: .bestDistance)) ?? 0
        bestSkips = (try c.decodeIfPresent(Int.self, forKey: .bestSkips)) ?? 0
        plays = (try c.decodeIfPresent(Int.self, forKey: .plays)) ?? 0
    }

    var stars: Int { goalsMet.filter { $0 }.count }
}

struct DailyRecord: Codable {
    var date: String
    var score: Int
    var distance: Double
    var skips: Int

    init(date: String, score: Int, distance: Double, skips: Int) {
        self.date = date
        self.score = score
        self.distance = distance
        self.skips = skips
    }

    enum CodingKeys: String, CodingKey { case date, score, distance, skips }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = (try c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        score = (try c.decodeIfPresent(Int.self, forKey: .score)) ?? 0
        distance = (try c.decodeIfPresent(Double.self, forKey: .distance)) ?? 0
        skips = (try c.decodeIfPresent(Int.self, forKey: .skips)) ?? 0
    }
}

struct SSPersist: Codable {
    var levelResults: [Int: LevelResult] = [:]
    var totalSkips: Int = 0
    var totalThrows: Int = 0
    var perfectTaps: Int = 0
    var stonesSunk: Int = 0
    var ringsTotal: Int = 0
    var padsTotal: Int = 0
    var longestThrow: Double = 0
    var zenBestDistance: Double = 0
    var zenBestSkips: Int = 0
    var zenThrows: Int = 0
    var dailyRecords: [DailyRecord] = []
    var dailyStreak: Int = 0
    var bestDailyStreak: Int = 0
    var lastDailyDate: String = ""
    var selectedStone: String = "river_flat"
    var earnedAchievements: [String] = []
    var seenAchievements: [String] = []
    var onboardingDone: Bool = false
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    var leftHanded: Bool = false
    var ghosts: [String: [Double]] = [:]

    init() {}

    enum CodingKeys: String, CodingKey {
        case levelResults, totalSkips, totalThrows, perfectTaps, stonesSunk,
             ringsTotal, padsTotal, longestThrow, zenBestDistance, zenBestSkips, zenThrows,
             dailyRecords, dailyStreak, bestDailyStreak, lastDailyDate, selectedStone,
             earnedAchievements, seenAchievements, onboardingDone, soundOn, hapticsOn,
             leftHanded, ghosts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        levelResults = (try c.decodeIfPresent([Int: LevelResult].self, forKey: .levelResults)) ?? [:]
        totalSkips = (try c.decodeIfPresent(Int.self, forKey: .totalSkips)) ?? 0
        totalThrows = (try c.decodeIfPresent(Int.self, forKey: .totalThrows)) ?? 0
        perfectTaps = (try c.decodeIfPresent(Int.self, forKey: .perfectTaps)) ?? 0
        stonesSunk = (try c.decodeIfPresent(Int.self, forKey: .stonesSunk)) ?? 0
        ringsTotal = (try c.decodeIfPresent(Int.self, forKey: .ringsTotal)) ?? 0
        padsTotal = (try c.decodeIfPresent(Int.self, forKey: .padsTotal)) ?? 0
        longestThrow = (try c.decodeIfPresent(Double.self, forKey: .longestThrow)) ?? 0
        zenBestDistance = (try c.decodeIfPresent(Double.self, forKey: .zenBestDistance)) ?? 0
        zenBestSkips = (try c.decodeIfPresent(Int.self, forKey: .zenBestSkips)) ?? 0
        zenThrows = (try c.decodeIfPresent(Int.self, forKey: .zenThrows)) ?? 0
        dailyRecords = (try c.decodeIfPresent([DailyRecord].self, forKey: .dailyRecords)) ?? []
        dailyStreak = (try c.decodeIfPresent(Int.self, forKey: .dailyStreak)) ?? 0
        bestDailyStreak = (try c.decodeIfPresent(Int.self, forKey: .bestDailyStreak)) ?? 0
        lastDailyDate = (try c.decodeIfPresent(String.self, forKey: .lastDailyDate)) ?? ""
        selectedStone = (try c.decodeIfPresent(String.self, forKey: .selectedStone)) ?? "river_flat"
        earnedAchievements = (try c.decodeIfPresent([String].self, forKey: .earnedAchievements)) ?? []
        seenAchievements = (try c.decodeIfPresent([String].self, forKey: .seenAchievements)) ?? []
        onboardingDone = (try c.decodeIfPresent(Bool.self, forKey: .onboardingDone)) ?? false
        soundOn = (try c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        hapticsOn = (try c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        leftHanded = (try c.decodeIfPresent(Bool.self, forKey: .leftHanded)) ?? false
        ghosts = (try c.decodeIfPresent([String: [Double]].self, forKey: .ghosts)) ?? [:]
    }
}

// MARK: - Store

final class GameStore: ObservableObject {
    static let saveKey = "sss.state.v1"

    @Published var state: SSPersist
    @Published var toastAchievements: [AchievementSpec] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: GameStore.saveKey),
           let decoded = try? JSONDecoder().decode(SSPersist.self, from: data) {
            state = decoded
        } else {
            state = SSPersist()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: GameStore.saveKey)
        }
    }

    func resetAll() {
        state = SSPersist()
        UserDefaults.standard.removeObject(forKey: GameStore.saveKey)
    }

    // MARK: derived

    var totalStars: Int {
        state.levelResults.values.reduce(0) { $0 + $1.stars }
    }

    func stars(levelID: Int) -> Int {
        state.levelResults[levelID]?.stars ?? 0
    }

    func shoreStars(_ shore: Int) -> Int {
        ShoreData.levels(for: shore).reduce(0) { $0 + stars(levelID: $1.id) }
    }

    func shoreCleared(_ shore: Int) -> Bool {
        ShoreData.levels(for: shore).allSatisfy { stars(levelID: $0.id) >= 1 }
    }

    func isLevelUnlocked(_ level: LevelSpec) -> Bool {
        if level.index == 1 { return level.shore == 0 || shoreUnlocked(level.shore) }
        guard let prev = ShoreData.levels(for: level.shore).first(where: { $0.index == level.index - 1 }) else {
            return true
        }
        return stars(levelID: prev.id) >= 1
    }

    func shoreUnlocked(_ shore: Int) -> Bool {
        if shore == 0 { return true }
        let need = [0, 8, 18, 30, 44][min(shore, 4)]
        return totalStars >= need
    }

    static let shoreStarRequirement: [Int] = [0, 8, 18, 30, 44]

    func isStoneUnlocked(_ stone: StoneSpec) -> Bool {
        switch stone.unlock {
        case .start: return true
        case .stars(let n): return totalStars >= n
        case .streak(let n): return state.dailyStreak >= n || bestStreakEver >= n
        case .longestThrow(let d): return state.longestThrow >= d
        case .zenBest(let d): return state.zenBestDistance >= d
        case .perfects(let n): return state.perfectTaps >= n
        }
    }

    var bestStreakEver: Int { max(state.bestDailyStreak, state.dailyStreak) }

    var unlockedStoneCount: Int {
        StoneData.stones.filter { isStoneUnlocked($0) }.count
    }

    var selectedStoneSpec: StoneSpec {
        let s = StoneData.stone(id: state.selectedStone)
        return isStoneUnlocked(s) ? s : StoneData.stones[0]
    }

    // MARK: recording results

    func recordThrow(_ outcome: ThrowOutcome) {
        state.totalThrows += 1
        state.totalSkips += outcome.skips
        state.perfectTaps += outcome.perfects
        state.ringsTotal += outcome.ringsCollected.count
        state.padsTotal += outcome.padHits
        if outcome.end == .sank || outcome.end == .blocked { state.stonesSunk += 1 }
        if outcome.distance > state.longestThrow { state.longestThrow = outcome.distance }
        checkAchievements(throwOutcome: outcome)
    }

    /// Returns stars newly earned for the level.
    @discardableResult
    func recordLevelFinish(level: LevelSpec, throwOutcomes: [ThrowOutcome]) -> Int {
        var result = state.levelResults[level.id] ?? LevelResult()
        let before = result.stars
        for (i, goal) in level.goals.enumerated() where i < 3 {
            if throwOutcomes.contains(where: { goalMet(goal, by: $0) }) {
                result.goalsMet[i] = true
            }
        }
        let bestDist = throwOutcomes.map { $0.distance }.max() ?? 0
        let bestSkips = throwOutcomes.map { $0.skips }.max() ?? 0
        if bestDist > result.bestDistance { result.bestDistance = bestDist }
        if bestSkips > result.bestSkips { result.bestSkips = bestSkips }
        result.plays += 1
        state.levelResults[level.id] = result
        checkAchievements(throwOutcome: nil)
        save()
        return result.stars - before
    }

    func recordZenThrow(_ outcome: ThrowOutcome) {
        state.zenThrows += 1
        if outcome.distance > state.zenBestDistance { state.zenBestDistance = outcome.distance }
        if outcome.skips > state.zenBestSkips { state.zenBestSkips = outcome.skips }
        checkAchievements(throwOutcome: nil)
        save()
    }

    func recordDailyFinish(dateKey: String, bestOutcome: ThrowOutcome, score: Int) {
        if let idx = state.dailyRecords.firstIndex(where: { $0.date == dateKey }) {
            if score > state.dailyRecords[idx].score {
                state.dailyRecords[idx] = DailyRecord(date: dateKey, score: score,
                                                      distance: bestOutcome.distance, skips: bestOutcome.skips)
            }
        } else {
            state.dailyRecords.append(DailyRecord(date: dateKey, score: score,
                                                  distance: bestOutcome.distance, skips: bestOutcome.skips))
            if let prev = SSDaily.previousDayKey(of: dateKey), state.lastDailyDate == prev {
                state.dailyStreak += 1
            } else if state.lastDailyDate != dateKey {
                state.dailyStreak = 1
            }
            state.lastDailyDate = dateKey
            state.bestDailyStreak = max(state.bestDailyStreak, state.dailyStreak)
        }
        checkAchievements(throwOutcome: nil)
        save()
    }

    func playedDaily(_ dateKey: String) -> Bool {
        state.dailyRecords.contains { $0.date == dateKey }
    }

    // MARK: ghosts

    func ghost(for key: String) -> [CGPoint] {
        guard let flat = state.ghosts[key], flat.count >= 4 else { return [] }
        var pts: [CGPoint] = []
        var i = 0
        while i + 1 < flat.count {
            pts.append(CGPoint(x: flat[i], y: flat[i + 1]))
            i += 2
        }
        return pts
    }

    func storeGhostIfBest(key: String, distance: Double, previousBest: Double, trajectory: [CGPoint]) {
        guard distance > previousBest, !trajectory.isEmpty else { return }
        let stride = max(1, trajectory.count / 110)
        var flat: [Double] = []
        var i = 0
        while i < trajectory.count {
            flat.append(Double(trajectory[i].x))
            flat.append(Double(trajectory[i].y))
            i += stride
        }
        state.ghosts[key] = flat
    }

    // MARK: achievements

    func checkAchievements(throwOutcome: ThrowOutcome?) {
        var newly: [AchievementSpec] = []
        for spec in AchievementData.all where !state.earnedAchievements.contains(spec.id) {
            if achievementMet(spec.metric, throwOutcome: throwOutcome) {
                state.earnedAchievements.append(spec.id)
                newly.append(spec)
            }
        }
        if !newly.isEmpty {
            toastAchievements.append(contentsOf: newly)
        }
    }

    private func achievementMet(_ metric: AchievementMetric, throwOutcome: ThrowOutcome?) -> Bool {
        switch metric {
        case .totalSkips(let n): return state.totalSkips >= n
        case .skipsInOneThrow(let n):
            if let o = throwOutcome, o.skips >= n { return true }
            return state.levelResults.values.contains { $0.bestSkips >= n } || state.zenBestSkips >= n
        case .perfectsTotal(let n): return state.perfectTaps >= n
        case .ringsTotal(let n): return state.ringsTotal >= n
        case .padsTotal(let n): return state.padsTotal >= n
        case .sunkTotal(let n): return state.stonesSunk >= n
        case .longestThrow(let d): return state.longestThrow >= d
        case .shoreCleared(let s): return shoreCleared(s)
        case .starsTotal(let n): return totalStars >= n
        case .zenBest(let d): return state.zenBestDistance >= d
        case .dailyStreak(let n): return state.dailyStreak >= n
        }
    }

    var achievementCount: Int { state.earnedAchievements.count }
}
