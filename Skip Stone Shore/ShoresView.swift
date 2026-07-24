import SwiftUI

struct ShoresView: View {
    @ObservedObject var store: GameStore
    @ObservedObject var router: AppRouter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                SSScreenHeader(title: "Skip Stone Shore",
                               subtitle: "Five waters. Sixty throws worth taking.")

                HStack(spacing: 8) {
                    StarShape().fill(SS.gold)
                        .overlay(StarShape().stroke(SS.goldDeep, lineWidth: 1))
                        .frame(width: 18, height: 18)
                    Text("\(store.totalStars) / 180 stars")
                        .font(SSFont.num(14))
                        .foregroundColor(SS.ink)
                    Spacer()
                    StoneMiniIcon(size: 20,
                                  body1: SS.hex(store.selectedStoneSpec.bodyHex),
                                  sheen: SS.hex(store.selectedStoneSpec.sheenHex))
                    Text(store.selectedStoneSpec.name)
                        .font(SSFont.body(13, .semibold))
                        .foregroundColor(SS.inkSoft)
                }
                .padding(.horizontal, 22)

                ForEach(ShoreData.shores) { shore in
                    ShoreCard(shore: shore, store: store, router: router)
                        .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 24)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct ShoreCard: View {
    let shore: ShoreSpec
    @ObservedObject var store: GameStore
    @ObservedObject var router: AppRouter

    private var unlocked: Bool { store.shoreUnlocked(shore.id) }
    private var starsHere: Int { store.shoreStars(shore.id) }
    private var palette: ShorePalette { ShorePalettes.forShore(shore.id) }

    var body: some View {
        Group {
            if unlocked {
                NavigationLink(destination: LevelListView(shore: shore, store: store, router: router)) {
                    cardBody
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        ZStack(alignment: .bottomLeading) {
            // Painterly banner artwork
            Image(ShoreArt.shore(shore.id))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 118)
                .clipped()
                .overlay(
                    LinearGradient(colors: [Color.black.opacity(0.05),
                                            Color.black.opacity(0.0),
                                            Color.black.opacity(0.52)],
                                   startPoint: .top, endPoint: .bottom)
                )

            // Text panel
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shore.name)
                        .font(SSFont.display(21))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    Text(shore.tagline)
                        .font(SSFont.body(12, .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                Spacer()
                if unlocked {
                    HStack(spacing: 4) {
                        StarShape().fill(SS.gold)
                            .frame(width: 13, height: 13)
                        Text("\(starsHere)/36")
                            .font(SSFont.num(12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                } else {
                    HStack(spacing: 5) {
                        LockShape()
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                            .frame(width: 13, height: 13)
                        Text("\(GameStore.shoreStarRequirement[shore.id]) stars")
                            .font(SSFont.num(12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SS.cardEdge, lineWidth: 1)
        )
        .shadow(color: SS.ink.opacity(0.1), radius: 8, x: 0, y: 4)
        .saturation(unlocked ? 1.0 : 0.35)
        .opacity(unlocked ? 1.0 : 0.8)
    }
}

struct HillBanner: View {
    let color: Color
    let seed: Double
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width
                let h = geo.size.height
                p.move(to: CGPoint(x: 0, y: h))
                let steps = 24
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let x = w * CGFloat(t)
                    let y = h * CGFloat(0.55 - 0.35 * sin(t * 6.1 + seed) * sin(t * 2.3 + seed * 0.7))
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Level list

struct LevelListView: View {
    let shore: ShoreSpec
    @ObservedObject var store: GameStore
    @ObservedObject var router: AppRouter

    private var palette: ShorePalette { ShorePalettes.forShore(shore.id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(shore.name)
                        .font(SSFont.display(28))
                        .foregroundColor(SS.ink)
                    Text(shore.blurb)
                        .font(SSFont.body(14))
                        .foregroundColor(SS.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ForEach(ShoreData.levels(for: shore.id)) { level in
                    LevelRow(level: level, store: store, palette: palette) {
                        router.play(.level(level.id))
                    }
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 24)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }
}

struct LevelRow: View {
    let level: LevelSpec
    @ObservedObject var store: GameStore
    let palette: ShorePalette
    let onPlay: () -> Void

    private var unlocked: Bool { store.isLevelUnlocked(level) }
    private var result: LevelResult? { store.state.levelResults[level.id] }

    var body: some View {
        Button(action: {
            if unlocked { onPlay() }
        }) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(unlocked ? palette.accent.opacity(0.16) : SS.cardEdge.opacity(0.5))
                    if unlocked {
                        Text("\(level.index)")
                            .font(SSFont.num(17))
                            .foregroundColor(palette.accent)
                    } else {
                        LockShape()
                            .stroke(SS.inkSoft, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                            .frame(width: 16, height: 16)
                    }
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.name)
                        .font(SSFont.body(15, .bold))
                        .foregroundColor(unlocked ? SS.ink : SS.inkSoft)
                    HStack(spacing: 8) {
                        featureIcons
                        if let r = result, r.bestDistance > 0 {
                            Text(String(format: "best %.0f m", r.bestDistance))
                                .font(SSFont.num(10))
                                .foregroundColor(SS.inkSoft)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        let lit = (result?.goalsMet.indices.contains(i) ?? false) && (result?.goalsMet[i] ?? false)
                        StarShape()
                            .fill(lit ? SS.gold : SS.cardEdge)
                            .frame(width: 15, height: 15)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(SS.card)
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(SS.cardEdge, lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(unlocked ? 1 : 0.72)
    }

    @ViewBuilder
    private var featureIcons: some View {
        HStack(spacing: 5) {
            if !level.rings.isEmpty { RingTargetIcon(size: 12) }
            if !level.pads.isEmpty { LilyPadIcon(size: 13) }
            if !level.buoys.isEmpty { BuoyIcon(size: 12) }
            if !level.wood.isEmpty { DriftwoodIcon(size: 12) }
            if abs(level.windBase) > 0.05 || level.gustPower > 0.05 {
                WindIconShape()
                    .stroke(SS.inkSoft, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                    .frame(width: 11, height: 11)
            }
        }
    }
}
