import SwiftUI

final class AppRouter: ObservableObject {
    @Published var activeGame: GameConfig? = nil
    @Published var gameToken = 0

    func play(_ config: GameConfig) {
        activeGame = nil
        gameToken += 1
        DispatchQueue.main.async { [weak self] in
            self?.activeGame = config
        }
    }

    func closeGame() {
        activeGame = nil
    }
}

struct RootView: View {
    @StateObject private var store = GameStore()
    @StateObject private var router = AppRouter()
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SW.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationView { ShoresView(store: store, router: router) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { ZenView(store: store, router: router) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { DailyView(store: store, router: router) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 3:
                        NavigationView { CollectionView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { MoreView(store: store) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }

            if let config = router.activeGame {
                GameContainer(config: config, store: store,
                              onExit: { router.closeGame() },
                              onPlayLevel: { id in router.play(.level(id)) })
                    .id(router.gameToken)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if !store.state.onboardingDone {
                OnboardingView(store: store)
                    .zIndex(20)
            }

            AchievementToastLayer(store: store)
                .zIndex(30)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                store.save()
            }
        }
        .onAppear {
            SoundBox.shared.enabled = store.state.soundOn
            HapticBox.shared.enabled = store.state.hapticsOn
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Shores", AnyView(ShoreTabIcon(size: 24, color: tabColor(0))))
            tabButton(1, "Zen", AnyView(ZenTabIcon(size: 24, color: tabColor(1))))
            tabButton(2, "Daily", AnyView(DailyTabIcon(size: 24, color: tabColor(2))))
            tabButton(3, "Stones", AnyView(CollectionTabIcon(size: 24, color: tabColor(3))))
            tabButton(4, "More", AnyView(MoreTabIcon(size: 24, color: tabColor(4))))
        }
        // On iPad the five buttons would spread across the whole bezel; cap and
        // centre them. The card band behind still runs edge to edge.
        .ssRegularMaxWidth(SWLayout.tabBarWidth)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            SW.card
                .overlay(Rectangle().fill(SW.cardEdge).frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabColor(_ i: Int) -> Color {
        selectedTab == i ? SW.accent : SW.inkSoft.opacity(0.55)
    }

    private func tabButton(_ index: Int, _ label: String, _ icon: AnyView) -> some View {
        Button(action: {
            selectedTab = index
            HapticBox.shared.tapLight()
        }) {
            VStack(spacing: 3) {
                icon
                Text(label)
                    .font(SWFont.body(10, .semibold))
                    .foregroundColor(tabColor(index))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Achievement toasts

struct AchievementToastLayer: View {
    @ObservedObject var store: GameStore
    @State private var visible = false

    var body: some View {
        VStack {
            if let spec = store.toastAchievements.first, visible {
                HStack(spacing: 12) {
                    TrophyIcon(size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Achievement")
                            .font(SWFont.body(11, .semibold))
                            .foregroundColor(SW.goldDeep)
                        Text(spec.name)
                            .font(SWFont.display(16))
                            .foregroundColor(SW.ink)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(SW.card)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(SW.gold.opacity(0.6), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal, 24)
                .ssRegularMaxWidth(SWLayout.toastWidth)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .onChange(of: store.toastAchievements.count) { _ in
            showNextIfNeeded()
        }
        .onAppear { showNextIfNeeded() }
    }

    private func showNextIfNeeded() {
        guard !visible, !store.toastAchievements.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { visible = true }
        SoundBox.shared.play("chime")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeIn(duration: 0.3)) { visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if !store.toastAchievements.isEmpty {
                    store.toastAchievements.removeFirst()
                }
                showNextIfNeeded()
            }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject var store: GameStore
    @State private var page = 0
    @Environment(\.horizontalSizeClass) private var hSize

    private var wide: Bool { SWLayout.isRegular(hSize) }

    private let titles = [
        "Pull Back",
        "Let It Fly",
        "Tap the Beat",
        "Gather Stars"
    ]
    private let bodies = [
        "Touch the water and drag down and away from the stone. The dotted arc shows your throw - farther pull, harder throw.",
        "Release to send the stone skimming. Wind and waves will bend its path, so watch the arrow on windy shores.",
        "Each time the stone falls toward the water a ring closes in. Tap just as it meets the mark - a perfect tap keeps the speed alive.",
        "Every level holds three goals worth a star each. Stars unlock new shores and new stones with real character."
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [SW.hex(0xF9D8BC), SW.hex(0xF2AE97), SW.hex(0x8E6B75)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Centers when it fits, scrolls when it doesn't - in landscape the fixed
            // stack is taller than the screen and used to push the button off-screen.
            GeometryReader { geo in
                let compact = geo.size.height < 520

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: compact ? 14 : 0)

                        illustration
                            // The walk-through art is built from fixed-size
                            // shapes, so on iPad it has to be scaled, not just
                            // given a taller box.
                            .scaleEffect(compact ? 1.0 : (wide ? 1.35 : 1.0))
                            .frame(height: compact ? 108 : (wide ? 240 : 180))

                        Text(titles[page])
                            .font(SWFont.display(compact ? 24 : (wide ? 38 : 30)))
                            .foregroundColor(SW.hex(0x3E3830))
                            .padding(.top, compact ? 14 : 26)

                        Text(bodies[page])
                            .font(SWFont.body(compact ? 15 : (wide ? 17 : 15)))
                            .foregroundColor(SW.hex(0x3E3830).opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                            .frame(minHeight: compact ? 0 : 100, alignment: .top)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { i in
                                Circle()
                                    .fill(i == page ? SW.hex(0x3E3830) : SW.hex(0x3E3830).opacity(0.25))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, compact ? 12 : 6)

                        Spacer(minLength: compact ? 16 : 0)

                        VStack(spacing: 10) {
                            SWPrimaryButton(title: page == 3 ? "To the Shore" : "Next", color: SW.accentWarm) {
                                if page < 3 {
                                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                                } else {
                                    finish()
                                }
                            }
                            if page < 3 {
                                Button(action: finish) {
                                    Text("Skip the walk-through")
                                        .font(SWFont.body(13, .medium))
                                        .foregroundColor(SW.hex(0x3E3830).opacity(0.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 36)
                        .padding(.top, compact ? 6 : 0)
                        .padding(.bottom, compact ? 20 : 40)
                    }
                    // iPad: keep the walk-through a single readable column
                    // instead of a full-bleed 1366pt line of body copy. The
                    // scroll wrapper above is untouched.
                    .ssRegularMaxWidth(560)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
    }

    private func finish() {
        store.state.onboardingDone = true
        store.save()
    }

    @ViewBuilder
    private var illustration: some View {
        switch page {
        case 0: OnboardDragArt()
        case 1: OnboardArcArt()
        case 2: OnboardRingArt()
        default: OnboardStarsArt()
        }
    }
}

struct OnboardDragArt: View {
    var body: some View {
        ZStack {
            Ellipse().fill(SW.hex(0x7C7468))
                .frame(width: 54, height: 36)
                .offset(x: -50, y: -30)
            Path { p in
                p.move(to: CGPoint(x: 110, y: 60))
                p.addQuadCurve(to: CGPoint(x: 175, y: 135), control: CGPoint(x: 128, y: 118))
            }
            .stroke(SW.hex(0x3E3830).opacity(0.6),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 10]))
            .frame(width: 240, height: 170)
            HandDragIcon(size: 62, color: SW.hex(0x3E3830))
                .offset(x: 52, y: 50)
        }
    }
}

struct OnboardArcArt: View {
    var body: some View {
        ZStack {
            WavePathShape(crests: 3, amp: 0.08, yFrac: 0.8)
                .stroke(Color.white.opacity(0.7), lineWidth: 3)
                .frame(width: 260, height: 160)
            Path { p in
                p.move(to: CGPoint(x: 10, y: 110))
                p.addQuadCurve(to: CGPoint(x: 120, y: 108), control: CGPoint(x: 65, y: 30))
                p.addQuadCurve(to: CGPoint(x: 200, y: 106), control: CGPoint(x: 160, y: 55))
                p.addQuadCurve(to: CGPoint(x: 250, y: 104), control: CGPoint(x: 226, y: 72))
            }
            .stroke(SW.hex(0x3E3830).opacity(0.65),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 11]))
            .frame(width: 260, height: 160)
            Ellipse().fill(SW.hex(0x7C7468))
                .frame(width: 40, height: 27)
                .offset(x: -55, y: -35)
                .rotationEffect(.degrees(-14))
        }
    }
}

struct OnboardRingArt: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            WavePathShape(crests: 3, amp: 0.08, yFrac: 0.62)
                .stroke(Color.white.opacity(0.7), lineWidth: 3)
                .frame(width: 260, height: 160)
            Circle()
                .stroke(Color.white, lineWidth: 3.4)
                .frame(width: 46, height: 46)
            Circle()
                .stroke(SW.gold, lineWidth: 3.4)
                .frame(width: 110, height: 110)
                .scaleEffect(pulse ? 0.42 : 1.0)
                .opacity(pulse ? 1.0 : 0.5)
                .animation(.easeIn(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
            Ellipse().fill(SW.hex(0x7C7468))
                .frame(width: 34, height: 23)
                .offset(x: 62, y: -58)
                .rotationEffect(.degrees(18))
        }
        .onAppear { pulse = true }
    }
}

struct OnboardStarsArt: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { i in
                StarShape()
                    .fill(SW.gold)
                    .overlay(StarShape().stroke(SW.goldDeep, lineWidth: 2))
                    .frame(width: i == 1 ? 74 : 54, height: i == 1 ? 74 : 54)
                    .offset(y: i == 1 ? -12 : 6)
            }
        }
    }
}
