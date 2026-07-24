import SwiftUI

struct CollectionView: View {
    @ObservedObject var store: GameStore
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            SSScreenHeader(title: "The Collection",
                           subtitle: "Stones earned, honors kept, numbers told.")

            HStack(spacing: 8) {
                segButton(0, "Stones")
                segButton(1, "Honors")
                segButton(2, "Numbers")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    switch section {
                    case 0: StonesSection(store: store)
                    case 1: AchievementsSection(store: store)
                    default: StatsSection(store: store)
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.top, 12)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func segButton(_ i: Int, _ label: String) -> some View {
        Button(action: { section = i }) {
            Text(label)
                .font(SSFont.body(13, .bold))
                .foregroundColor(section == i ? .white : SS.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(section == i ? SS.accent : SS.card)
                        .overlay(Capsule().stroke(section == i ? SS.accent : SS.cardEdge, lineWidth: 1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stones

struct StonesSection: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 10) {
            Text("\(store.unlockedStoneCount) of \(StoneData.stones.count) stones found")
                .font(SSFont.body(13, .semibold))
                .foregroundColor(SS.inkSoft)

            ForEach(StoneData.stones) { stone in
                StoneRow(stone: stone, store: store)
                    .padding(.horizontal, 16)
            }
        }
    }
}

struct StoneRow: View {
    let stone: StoneSpec
    @ObservedObject var store: GameStore

    private var unlocked: Bool { store.isStoneUnlocked(stone) }
    private var selected: Bool { store.selectedStoneSpec.id == stone.id }

    var body: some View {
        Button(action: {
            guard unlocked else { return }
            store.state.selectedStone = stone.id
            store.save()
            HapticBox.shared.tapLight()
        }) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(unlocked ? SS.hex(stone.bodyHex).opacity(0.14) : SS.cardEdge.opacity(0.4))
                        .frame(width: 54, height: 54)
                    if unlocked {
                        StoneArtView(stone: stone, size: 40)
                    } else {
                        LockShape()
                            .stroke(SS.inkSoft, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                            .frame(width: 18, height: 18)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(stone.name)
                            .font(SSFont.body(15, .bold))
                            .foregroundColor(unlocked ? SS.ink : SS.inkSoft)
                        if selected {
                            Text("IN HAND")
                                .font(SSFont.num(8))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SS.accent))
                        }
                    }
                    if unlocked {
                        Text(stone.statLine)
                            .font(SSFont.num(9))
                            .foregroundColor(SS.accent)
                        Text(stone.blurb)
                            .font(SSFont.body(11))
                            .foregroundColor(SS.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(stone.unlock.text)
                            .font(SSFont.body(12, .medium))
                            .foregroundColor(SS.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(SS.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(selected ? SS.accent.opacity(0.6) : SS.cardEdge,
                                    lineWidth: selected ? 1.8 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(unlocked ? 1 : 0.75)
    }
}

struct StoneArtView: View {
    let stone: StoneSpec
    let size: CGFloat
    var body: some View {
        ZStack {
            Ellipse()
                .fill(SS.hex(stone.bodyHex))
                .frame(width: size, height: size * 0.7)
            Ellipse()
                .fill(SS.hex(stone.sheenHex).opacity(0.7))
                .frame(width: size * 0.42, height: size * 0.17)
                .offset(x: -size * 0.13, y: -size * 0.15)
            Circle()
                .fill(SS.hex(stone.speckHex).opacity(0.8))
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.16, y: size * 0.08)
            Circle()
                .fill(SS.hex(stone.speckHex).opacity(0.55))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -size * 0.02, y: size * 0.14)
        }
    }
}

// MARK: - Achievements

struct AchievementsSection: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 10) {
            Text("\(store.achievementCount) of \(AchievementData.all.count) honors earned")
                .font(SSFont.body(13, .semibold))
                .foregroundColor(SS.inkSoft)

            ForEach(AchievementData.all) { spec in
                let earned = store.state.earnedAchievements.contains(spec.id)
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(earned ? SS.gold.opacity(0.18) : SS.cardEdge.opacity(0.4))
                            .frame(width: 46, height: 46)
                        TrophyIcon(size: 26, color: earned ? SS.gold : SS.inkSoft.opacity(0.45))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spec.name)
                            .font(SSFont.body(14, .bold))
                            .foregroundColor(earned ? SS.ink : SS.inkSoft)
                        Text(spec.detail)
                            .font(SSFont.body(11))
                            .foregroundColor(SS.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if earned {
                        CheckShape()
                            .stroke(SS.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 15, height: 15)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(SS.card)
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(earned ? SS.gold.opacity(0.4) : SS.cardEdge, lineWidth: 1))
                )
                .padding(.horizontal, 16)
                .opacity(earned ? 1 : 0.8)
            }
        }
    }
}

// MARK: - Stats

struct StatsSection: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 10) {
            statCard(rows: [
                ("Total throws", "\(store.state.totalThrows)"),
                ("Total skips", "\(store.state.totalSkips)"),
                ("Perfect taps", "\(store.state.perfectTaps)"),
                ("Stones sunk", "\(store.state.stonesSunk)")
            ], title: "The Hand")
            statCard(rows: [
                ("Longest throw", store.state.longestThrow > 0
                 ? String(format: "%.1f m", store.state.longestThrow) : "-"),
                ("Rings collected", "\(store.state.ringsTotal)"),
                ("Lily pad bounces", "\(store.state.padsTotal)"),
                ("Stars gathered", "\(store.totalStars) / 180")
            ], title: "The Water")
            statCard(rows: [
                ("Zen best drift", store.state.zenBestDistance > 0
                 ? String(format: "%.1f m", store.state.zenBestDistance) : "-"),
                ("Zen skip record", store.state.zenBestSkips > 0 ? "\(store.state.zenBestSkips)" : "-"),
                ("Daily streak", "\(store.state.dailyStreak) days"),
                ("Daily mornings", "\(store.state.dailyRecords.count)")
            ], title: "The Rituals")
        }
        .padding(.horizontal, 16)
    }

    private func statCard(rows: [(String, String)], title: String) -> some View {
        SSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(SSFont.display(16))
                    .foregroundColor(SS.ink)
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .font(SSFont.body(13))
                            .foregroundColor(SS.inkSoft)
                        Spacer()
                        Text(row.1)
                            .font(SSFont.num(13))
                            .foregroundColor(SS.ink)
                    }
                }
            }
        }
    }
}
