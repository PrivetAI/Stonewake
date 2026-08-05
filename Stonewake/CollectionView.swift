import SwiftUI

struct CollectionView: View {
    @ObservedObject var store: GameStore
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            SWScreenHeader(title: "The Collection",
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
        .ssRegularMaxWidth(SWLayout.gridWidth)
        .background(SW.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func segButton(_ i: Int, _ label: String) -> some View {
        Button(action: { section = i }) {
            Text(label)
                .font(SWFont.body(13, .bold))
                .foregroundColor(section == i ? .white : SW.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(section == i ? SW.accent : SW.card)
                        .overlay(Capsule().stroke(section == i ? SW.accent : SW.cardEdge, lineWidth: 1))
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
                .font(SWFont.body(13, .semibold))
                .foregroundColor(SW.inkSoft)

            SWAdaptiveGrid(StoneData.stones, spacing: 10, regularColumns: 2) { stone in
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
                        .fill(unlocked ? SW.hex(stone.bodyHex).opacity(0.14) : SW.cardEdge.opacity(0.4))
                        .frame(width: 54, height: 54)
                    if unlocked {
                        StoneArtView(stone: stone, size: 40)
                    } else {
                        LockShape()
                            .stroke(SW.inkSoft, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                            .frame(width: 18, height: 18)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(stone.name)
                            .font(SWFont.body(15, .bold))
                            .foregroundColor(unlocked ? SW.ink : SW.inkSoft)
                        if selected {
                            Text("IN HAND")
                                .font(SWFont.num(8))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SW.accent))
                        }
                    }
                    if unlocked {
                        Text(stone.statLine)
                            .font(SWFont.num(9))
                            .foregroundColor(SW.accent)
                        Text(stone.blurb)
                            .font(SWFont.body(11))
                            .foregroundColor(SW.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(stone.unlock.text)
                            .font(SWFont.body(12, .medium))
                            .foregroundColor(SW.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(SW.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(selected ? SW.accent.opacity(0.6) : SW.cardEdge,
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
                .fill(SW.hex(stone.bodyHex))
                .frame(width: size, height: size * 0.7)
            Ellipse()
                .fill(SW.hex(stone.sheenHex).opacity(0.7))
                .frame(width: size * 0.42, height: size * 0.17)
                .offset(x: -size * 0.13, y: -size * 0.15)
            Circle()
                .fill(SW.hex(stone.speckHex).opacity(0.8))
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.16, y: size * 0.08)
            Circle()
                .fill(SW.hex(stone.speckHex).opacity(0.55))
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
                .font(SWFont.body(13, .semibold))
                .foregroundColor(SW.inkSoft)

            SWAdaptiveGrid(AchievementData.all, spacing: 10, regularColumns: 2) { spec in
                let earned = store.state.earnedAchievements.contains(spec.id)
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(earned ? SW.gold.opacity(0.18) : SW.cardEdge.opacity(0.4))
                            .frame(width: 46, height: 46)
                        TrophyIcon(size: 26, color: earned ? SW.gold : SW.inkSoft.opacity(0.45))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spec.name)
                            .font(SWFont.body(14, .bold))
                            .foregroundColor(earned ? SW.ink : SW.inkSoft)
                        Text(spec.detail)
                            .font(SWFont.body(11))
                            .foregroundColor(SW.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if earned {
                        CheckShape()
                            .stroke(SW.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                            .frame(width: 15, height: 15)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(SW.card)
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(earned ? SW.gold.opacity(0.4) : SW.cardEdge, lineWidth: 1))
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
        // Label/value rows read badly when stretched to a full iPad width.
        .ssRegularMaxWidth(SWLayout.readingWidth)
    }

    private func statCard(rows: [(String, String)], title: String) -> some View {
        SWCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(SWFont.display(16))
                    .foregroundColor(SW.ink)
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .font(SWFont.body(13))
                            .foregroundColor(SW.inkSoft)
                        Spacer()
                        Text(row.1)
                            .font(SWFont.num(13))
                            .foregroundColor(SW.ink)
                    }
                }
            }
        }
    }
}
