import SwiftUI

// MARK: - Game mode

enum GameConfig: Equatable {
    case level(Int)          // level id
    case zen
    case daily

    static func == (lhs: GameConfig, rhs: GameConfig) -> Bool {
        switch (lhs, rhs) {
        case (.level(let a), .level(let b)): return a == b
        case (.zen, .zen), (.daily, .daily): return true
        default: return false
        }
    }
}

enum GamePhase {
    case playing
    case throwEnded
    case levelDone
    case paused
}

// MARK: - View model

final class GameVM: ObservableObject {
    let mode: GameConfig
    let level: LevelSpec
    let store: GameStore
    let engine: ThrowEngine
    let palette: ShorePalette
    let dateKey: String

    @Published var phase: GamePhase = .playing
    @Published var outcomes: [ThrowOutcome] = []
    @Published var aim = AimState()
    @Published var starsAfter = 0
    @Published var newStars = 0
    @Published var dailyScore = 0
    @Published var goalNowMet: [Bool] = [false, false, false]

    private var timer: Timer?
    private var lastTickAt: CFTimeInterval = 0

    var throwsAllowed: Int {
        if case .zen = mode { return 1 }
        return 3
    }

    var ghostKey: String {
        switch mode {
        case .level(let id): return "L\(id)"
        case .daily: return "D"
        case .zen: return "Z"
        }
    }

    init(mode: GameConfig, store: GameStore) {
        self.mode = mode
        self.store = store
        self.dateKey = SSDaily.dateKey()
        switch mode {
        case .level(let id):
            let spec = ShoreData.level(id: id) ?? ShoreData.allLevels[0]
            level = spec
            palette = ShorePalettes.forShore(spec.shore)
        case .zen:
            level = SSZen.makeLevel(dayKey: SSDaily.dateKey())
            palette = ShorePalettes.zen
        case .daily:
            level = SSDaily.makeLevel(for: SSDaily.dateKey())
            palette = ShorePalettes.daily
        }
        engine = ThrowEngine(level: level, stone: store.selectedStoneSpec, attemptIndex: 0)
        wireEvents()
    }

    private func wireEvents() {
        engine.onEvent = { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .launched:
                SoundBox.shared.play("whoosh")
                HapticBox.shared.tapMedium()
            case .skip(let q):
                switch q {
                case .perfect:
                    SoundBox.shared.play("plinkHigh")
                    HapticBox.shared.tapLight()
                case .good:
                    SoundBox.shared.play("plink")
                    HapticBox.shared.tapLight()
                case .late:
                    SoundBox.shared.play("plink")
                case .pad:
                    SoundBox.shared.play("chime")
                    HapticBox.shared.tapLight()
                case .miss:
                    break
                }
            case .ring:
                SoundBox.shared.play("chime")
                HapticBox.shared.tapLight()
            case .pad:
                break
            case .buoy:
                SoundBox.shared.play("thud")
                HapticBox.shared.warning()
            case .wood:
                SoundBox.shared.play("thud")
                HapticBox.shared.warning()
            case .sank:
                SoundBox.shared.play("plunk")
                SoundBox.shared.play("splash")
                HapticBox.shared.tapHeavy()
                self.handleThrowEnd()
            case .settled:
                SoundBox.shared.play("splash")
                self.handleThrowEnd()
            case .landed:
                SoundBox.shared.play("chime")
                HapticBox.shared.success()
                self.handleThrowEnd()
            }
        }
    }

    // MARK: lifecycle

    func start() {
        SoundBox.shared.enabled = store.state.soundOn
        HapticBox.shared.enabled = store.state.hapticsOn
        lastTickAt = CACurrentMediaTime()
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
        t.tolerance = 1.0 / 240.0
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tickTimer() {
        let now = CACurrentMediaTime()
        let dt = now - lastTickAt
        lastTickAt = now
        guard phase != .paused else { return }
        if engine.phase == .flying {
            engine.advance(realDt: dt)
        } else {
            engine.advanceAmbient(realDt: dt)
        }
    }

    // MARK: input

    /// `powerReference` is the drag length, in points, that means full power.
    /// 150 on every phone-sized viewport (the shipped value); longer on iPad,
    /// where 150pt is a much smaller share of the screen and the aim would
    /// otherwise feel twitchy.
    func updateAim(start: CGPoint, current: CGPoint, powerReference: Double = 150) {
        guard phase == .playing, engine.phase == .ready else { return }
        var dx = Double(start.x - current.x)
        let sdy = Double(start.y - current.y)
        if store.state.leftHanded { dx = -dx }
        let wy = -sdy
        let len = sqrt(dx * dx + sdy * sdy)
        guard len > 6 else {
            aim = AimState(isAiming: false, angle: aim.angle, power: 0)
            return
        }
        var ang = atan2(wy, dx)
        ang = min(max(ang, ThrowEngine.minAngle), ThrowEngine.maxAngle)
        let pow = min(1.0, len / max(1.0, powerReference))
        aim = AimState(isAiming: true, angle: ang, power: pow)
    }

    func releaseThrow() {
        guard phase == .playing, engine.phase == .ready else { return }
        guard aim.isAiming, aim.power > 0.08 else {
            aim.isAiming = false
            return
        }
        engine.launch(angle: aim.angle, power: aim.power)
        aim.isAiming = false
    }

    func tapBeat() {
        guard phase == .playing, engine.phase == .flying else { return }
        engine.tap()
    }

    // MARK: flow

    private func handleThrowEnd() {
        let outcome = engine.outcome
        outcomes.append(outcome)
        store.recordThrow(outcome)
        if case .zen = mode {
            store.recordZenThrow(outcome)
        }
        // live goal progress
        for (i, goal) in level.goals.enumerated() where i < 3 {
            if goalMet(goal, by: outcome) { goalNowMet[i] = true }
        }
        if outcomes.count >= throwsAllowed, case .zen = mode {
            phase = .throwEnded
        } else if outcomes.count >= throwsAllowed {
            finishLevel()
        } else {
            phase = .throwEnded
        }
        store.save()
    }

    func nextThrow() {
        guard outcomes.count < throwsAllowed else { return }
        engine.resetForNextThrow(attemptIndex: outcomes.count)
        phase = .playing
    }

    func zenAgain() {
        outcomes = []
        goalNowMet = [false, false, false]
        engine.resetForNextThrow(attemptIndex: store.state.zenThrows)
        phase = .playing
    }

    private func finishLevel() {
        let bestOutcome = outcomes.max { $0.distance < $1.distance } ?? ThrowOutcome()
        switch mode {
        case .level(let id):
            let prevBest = store.state.levelResults[id]?.bestDistance ?? 0
            store.storeGhostIfBest(key: ghostKey, distance: bestOutcome.distance,
                                   previousBest: prevBest, trajectory: bestOutcome.trajectory)
            newStars = store.recordLevelFinish(level: level, throwOutcomes: outcomes)
            starsAfter = store.stars(levelID: id)
        case .daily:
            dailyScore = outcomes.map { SSDaily.score(for: $0) }.max() ?? 0
            store.recordDailyFinish(dateKey: dateKey, bestOutcome: bestOutcome, score: dailyScore)
        case .zen:
            break
        }
        phase = .levelDone
    }

    func restartLevel() {
        outcomes = []
        goalNowMet = [false, false, false]
        newStars = 0
        engine.resetForNextThrow(attemptIndex: 0)
        phase = .playing
    }

    var nextLevelID: Int? {
        guard case .level(let id) = mode else { return nil }
        guard let next = ShoreData.level(id: id + 1) else { return nil }
        return store.isLevelUnlocked(next) && store.shoreUnlocked(next.shore) ? next.id : nil
    }

    var bestDistance: Double { outcomes.map { $0.distance }.max() ?? 0 }
    var bestSkips: Int { outcomes.map { $0.skips }.max() ?? 0 }
}

// MARK: - Game container

struct GameContainer: View {
    let config: GameConfig
    let onExit: () -> Void
    let onPlayLevel: (Int) -> Void
    @ObservedObject var store: GameStore
    @StateObject private var vm: GameVM
    @State private var touchDown = false
    @Environment(\.horizontalSizeClass) private var hSize

    init(config: GameConfig, store: GameStore,
         onExit: @escaping () -> Void, onPlayLevel: @escaping (Int) -> Void) {
        self.config = config
        self.store = store
        self.onExit = onExit
        self.onPlayLevel = onPlayLevel
        _vm = StateObject(wrappedValue: GameVM(mode: config, store: store))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                vm.palette.waterDeep.ignoresSafeArea()

                LakeSceneView(engine: vm.engine, palette: vm.palette,
                              screenSize: geo.size, aim: vm.aim,
                              ghost: store.ghost(for: vm.ghostKey))
                    .ignoresSafeArea()

                // Input layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                if vm.engine.phase == .ready {
                                    vm.updateAim(start: g.startLocation, current: g.location,
                                                 powerReference: powerReference(geo.size))
                                } else if vm.engine.phase == .flying && !touchDown {
                                    touchDown = true
                                    vm.tapBeat()
                                }
                            }
                            .onEnded { _ in
                                touchDown = false
                                if vm.engine.phase == .ready { vm.releaseThrow() }
                            }
                    )
                    .allowsHitTesting(vm.phase == .playing)

                GameHUD(vm: vm, scale: GameContainer.hudScale(geo.size),
                        onPause: { vm.phase = .paused })

                if vm.phase == .throwEnded {
                    if vm.isZen {
                        ZenThrowOverlay(vm: vm, onExit: exitGame)
                    } else {
                        ThrowEndOverlay(vm: vm, onExit: exitGame)
                    }
                }
                if vm.phase == .levelDone {
                    LevelDoneOverlay(vm: vm, store: store, onExit: exitGame, onNext: { id in
                        exitToLevel(id)
                    })
                }
                if vm.phase == .paused {
                    PauseOverlay(vm: vm, store: store, onExit: exitGame)
                }
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    /// Full-power drag length. The `max(150, ...)` floor means every phone -
    /// including a Pro Max in landscape, which also reports regular width -
    /// keeps the shipped 150pt feel; only genuine iPad viewports stretch it.
    private func powerReference(_ size: CGSize) -> Double {
        guard hSize == .regular else { return 150 }
        return max(150, Double(min(size.width, size.height)) * 0.28)
    }

    /// HUD chrome scale. Deliberately keyed off the viewport, not the size
    /// class, so it matches `LakeSceneView.uiScale` exactly: every phone
    /// (short side well under 500pt, in either orientation) stays at 1.0 and
    /// only true iPad viewports grow the 40pt buttons and 11-21pt type.
    static func hudScale(_ size: CGSize) -> CGFloat {
        let shortSide = min(size.width, size.height)
        guard shortSide >= 500 else { return 1.0 }
        return min(1.45, max(1.15, shortSide / 620))
    }

    private func exitGame() {
        vm.stop()
        store.save()
        onExit()
    }

    private func exitToLevel(_ id: Int) {
        vm.stop()
        store.save()
        onPlayLevel(id)
    }
}

extension GameVM {
    var isZen: Bool {
        if case .zen = mode { return true }
        return false
    }
}

// MARK: - HUD

struct GameHUD: View {
    @ObservedObject var vm: GameVM
    /// 1.0 on every phone viewport, so the shipped HUD is untouched; a modest
    /// bump on iPad, where 40pt chrome floats in a 1000pt-tall scene.
    var scale: CGFloat = 1.0
    let onPause: () -> Void

    private var s: CGFloat { scale }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onPause) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                        PauseIconShape()
                            .fill(Color.white)
                            .frame(width: 18 * s, height: 18 * s)
                    }
                    .frame(width: 40 * s, height: 40 * s)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                VStack(spacing: 1) {
                    Text(String(format: "%.1f m", max(0, vm.engine.phase == .ready ? vm.bestDistance : vm.engine.x)))
                        .font(SSFont.num(21 * s))
                        .foregroundColor(.white)
                    Text("skips \(vm.engine.phase == .ready ? vm.bestSkips : vm.engine.outcome.skips)")
                        .font(SSFont.body(12 * s, .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14 * s)
                .padding(.vertical, 6 * s)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 5) {
                        ForEach(0..<vm.throwsAllowed, id: \.self) { i in
                            Ellipse()
                                .fill(i < vm.outcomes.count
                                      ? Color.white.opacity(0.28)
                                      : Color.white.opacity(0.9))
                                .frame(width: 14 * s, height: 10 * s)
                        }
                    }
                    .padding(.horizontal, 10 * s)
                    .padding(.vertical, 8 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                    )
                    if abs(vm.level.windBase) > 0.05 || vm.level.gustPower > 0.05 {
                        WindChip(vm: vm, scale: s)
                    }
                }
            }
            .padding(.horizontal, 14)
            .ssRegularMaxWidth(SSLayout.hudWidth)

            GoalChips(vm: vm, scale: s)
                .padding(.horizontal, 14)
                .ssRegularMaxWidth(SSLayout.hudWidth)

            Spacer()

            if vm.phase == .playing {
                Text(hintText)
                    .font(SSFont.body(13 * s, .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 14 * s)
                    .padding(.vertical, 7 * s)
                    .background(Capsule().fill(Color.black.opacity(0.25)))
                    .padding(.bottom, 18 * s)
                    .opacity(vm.engine.phase == .ready ? 1 : (vm.engine.timingRingProgress != nil ? 1 : 0))
                    .animation(.easeInOut(duration: 0.2), value: vm.engine.phase == .ready)
            }
        }
        .padding(.top, 8)
        .allowsHitTesting(true)
    }

    private var hintText: String {
        if vm.engine.phase == .ready {
            let side = vm.store.state.leftHanded ? "down-right" : "down-left"
            return "Drag \(side) to aim, release to throw"
        }
        return "Tap as the ring closes"
    }
}

struct WindChip: View {
    @ObservedObject var vm: GameVM
    var scale: CGFloat = 1.0
    private var s: CGFloat { scale }

    var body: some View {
        let wind = vm.engine.windAt(vm.engine.time)
        HStack(spacing: 5) {
            WindIconShape()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 14 * s, height: 14 * s)
                .scaleEffect(x: wind >= 0 ? 1 : -1)
            Text(String(format: "%@%.1f", wind >= 0 ? "+" : "", wind))
                .font(SSFont.num(11 * s))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9 * s)
        .padding(.vertical, 5 * s)
        .background(Capsule().fill(Color.black.opacity(0.28)))
    }
}

struct GoalChips: View {
    @ObservedObject var vm: GameVM
    var scale: CGFloat = 1.0
    private var s: CGFloat { scale }

    var body: some View {
        HStack(spacing: 6 * s) {
            ForEach(0..<min(3, vm.level.goals.count), id: \.self) { i in
                let met = vm.goalNowMet[i]
                HStack(spacing: 5) {
                    if met {
                        CheckShape()
                            .stroke(SS.gold, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .frame(width: 11 * s, height: 11 * s)
                    } else {
                        StarShape()
                            .stroke(Color.white.opacity(0.7), lineWidth: 1.4)
                            .frame(width: 11 * s, height: 11 * s)
                    }
                    Text(shortGoal(vm.level.goals[i]))
                        .font(SSFont.body(11 * s, .semibold))
                        .foregroundColor(met ? SS.gold : .white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 5 * s)
                .background(Capsule().fill(Color.black.opacity(met ? 0.38 : 0.22)))
            }
            Spacer()
        }
    }

    private func shortGoal(_ g: GoalSpec) -> String {
        switch g {
        case .distance(let d): return "\(Int(d)) m"
        case .rings(let n): return "\(n) ring\(n == 1 ? "" : "s")"
        case .skips(let n): return "\(n) skips"
        case .perfects(let n): return "\(n) perfect"
        case .pads(let n): return "\(n) pad\(n == 1 ? "" : "s")"
        case .reachShore: return "far shore"
        }
    }
}

// MARK: - Overlays

struct OverlayScrim<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            content
                .padding(22)
                .frame(maxWidth: hSize == .regular ? SSLayout.overlayWidth : 420)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SS.paper)
                        .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 8)
                )
                .padding(.horizontal, 28)
        }
    }
}

struct ThrowEndOverlay: View {
    @ObservedObject var vm: GameVM
    let onExit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 14) {
                Text(endTitle)
                    .font(SSFont.display(24))
                    .foregroundColor(SS.ink)
                Text("Throw \(vm.outcomes.count) of \(vm.throwsAllowed)")
                    .font(SSFont.body(13, .semibold))
                    .foregroundColor(SS.inkSoft)

                if let last = vm.outcomes.last {
                    HStack(spacing: 20) {
                        StatBlock(label: "distance", value: String(format: "%.1f m", last.distance))
                        StatBlock(label: "skips", value: "\(last.skips)")
                        StatBlock(label: "perfect", value: "\(last.perfects)")
                    }
                }

                SSPrimaryButton(title: "Next Throw") { vm.nextThrow() }
                HStack(spacing: 10) {
                    SSGhostButton(title: "Restart") { vm.restartLevel() }
                    SSGhostButton(title: "Leave", color: SS.inkSoft) { onExit() }
                }
            }
        }
    }

    private var endTitle: String {
        guard let last = vm.outcomes.last else { return "Splash" }
        switch last.end {
        case .sank: return "Plunk."
        case .settled: return "Out of Speed"
        case .landed: return "Far Shore!"
        case .blocked: return "Blocked!"
        }
    }
}

struct ZenThrowOverlay: View {
    @ObservedObject var vm: GameVM
    let onExit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 14) {
                Text("The Water Rests")
                    .font(SSFont.display(24))
                    .foregroundColor(SS.ink)
                if let last = vm.outcomes.last {
                    HStack(spacing: 20) {
                        StatBlock(label: "distance", value: String(format: "%.1f m", last.distance))
                        StatBlock(label: "skips", value: "\(last.skips)")
                    }
                    VStack(spacing: 3) {
                        Text("personal best")
                            .font(SSFont.body(11, .semibold))
                            .foregroundColor(SS.inkSoft)
                        Text(String(format: "%.1f m  |  %d skips",
                                    vm.store.state.zenBestDistance, vm.store.state.zenBestSkips))
                            .font(SSFont.num(15))
                            .foregroundColor(SS.accent)
                    }
                }
                SSPrimaryButton(title: "Throw Again") { vm.zenAgain() }
                SSGhostButton(title: "Back to Shore", color: SS.inkSoft) { onExit() }
            }
        }
    }
}

struct LevelDoneOverlay: View {
    @ObservedObject var vm: GameVM
    @ObservedObject var store: GameStore
    let onExit: () -> Void
    let onNext: (Int) -> Void
    @State private var starPop = false

    var body: some View {
        OverlayScrim {
            VStack(spacing: 14) {
                Text(isDaily ? "Daily Throw Done" : vm.level.name)
                    .font(SSFont.display(24))
                    .foregroundColor(SS.ink)
                    .multilineTextAlignment(.center)

                if isDaily {
                    VStack(spacing: 4) {
                        Text("score")
                            .font(SSFont.body(12, .semibold))
                            .foregroundColor(SS.inkSoft)
                        Text("\(vm.dailyScore)")
                            .font(SSFont.num(34))
                            .foregroundColor(SS.goldDeep)
                        Text("streak \(store.state.dailyStreak) day\(store.state.dailyStreak == 1 ? "" : "s")")
                            .font(SSFont.body(13, .semibold))
                            .foregroundColor(SS.accent)
                    }
                } else {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { i in
                            let lit = currentGoalsMet.indices.contains(i) && currentGoalsMet[i]
                            StarShape()
                                .fill(lit ? SS.gold : SS.cardEdge)
                                .overlay(StarShape().stroke(lit ? SS.goldDeep : SS.inkSoft.opacity(0.3), lineWidth: 1.5))
                                .frame(width: 44, height: 44)
                                .scaleEffect(starPop ? 1.0 : 0.4)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.12), value: starPop)
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(0..<min(3, vm.level.goals.count), id: \.self) { i in
                            let lit = currentGoalsMet.indices.contains(i) && currentGoalsMet[i]
                            HStack(spacing: 8) {
                                if lit {
                                    CheckShape()
                                        .stroke(SS.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                                        .frame(width: 13, height: 13)
                                } else {
                                    Circle()
                                        .stroke(SS.inkSoft.opacity(0.4), lineWidth: 1.6)
                                        .frame(width: 13, height: 13)
                                }
                                Text(vm.level.goals[i].text)
                                    .font(SSFont.body(13, lit ? .semibold : .regular))
                                    .foregroundColor(lit ? SS.ink : SS.inkSoft)
                            }
                        }
                    }
                }

                HStack(spacing: 20) {
                    StatBlock(label: "best distance", value: String(format: "%.1f m", vm.bestDistance))
                    StatBlock(label: "most skips", value: "\(vm.bestSkips)")
                }

                if let next = vm.nextLevelID {
                    SSPrimaryButton(title: "Next Level") { onNext(next) }
                }
                HStack(spacing: 10) {
                    SSGhostButton(title: "Retry") { vm.restartLevel() }
                    SSGhostButton(title: "Leave", color: SS.inkSoft) { onExit() }
                }
            }
        }
        .onAppear { starPop = true }
    }

    private var isDaily: Bool {
        if case .daily = vm.mode { return true }
        return false
    }

    private var currentGoalsMet: [Bool] {
        if case .level(let id) = vm.mode {
            return store.state.levelResults[id]?.goalsMet ?? vm.goalNowMet
        }
        return vm.goalNowMet
    }
}

struct PauseOverlay: View {
    @ObservedObject var vm: GameVM
    @ObservedObject var store: GameStore
    let onExit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 14) {
                Text("Paused")
                    .font(SSFont.display(26))
                    .foregroundColor(SS.ink)
                Text(vm.level.name)
                    .font(SSFont.body(14, .medium))
                    .foregroundColor(SS.inkSoft)

                HStack(spacing: 12) {
                    ToggleChip(label: "Sound", isOn: store.state.soundOn) {
                        store.state.soundOn.toggle()
                        SoundBox.shared.enabled = store.state.soundOn
                        store.save()
                    }
                    ToggleChip(label: "Haptics", isOn: store.state.hapticsOn) {
                        store.state.hapticsOn.toggle()
                        HapticBox.shared.enabled = store.state.hapticsOn
                        store.save()
                    }
                }

                SSPrimaryButton(title: "Resume") { vm.phase = .playing }
                HStack(spacing: 10) {
                    SSGhostButton(title: "Restart") {
                        vm.restartLevel()
                    }
                    SSGhostButton(title: "Leave", color: SS.inkSoft) { onExit() }
                }
            }
        }
    }
}

struct ToggleChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? SS.accent : SS.cardEdge)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(SSFont.body(13, .semibold))
                    .foregroundColor(isOn ? SS.ink : SS.inkSoft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().stroke(isOn ? SS.accent.opacity(0.5) : SS.cardEdge, lineWidth: 1.4))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(SSFont.num(17))
                .foregroundColor(SS.ink)
            Text(label)
                .font(SSFont.body(11, .medium))
                .foregroundColor(SS.inkSoft)
        }
    }
}
