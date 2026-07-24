import SwiftUI

// MARK: - Zen Shore

struct ZenView: View {
    @ObservedObject var store: GameStore
    @ObservedObject var router: AppRouter
    @State private var breathe = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SSScreenHeader(title: "Zen Shore",
                               subtitle: "An endless calm lake. Just you and the water.")

                // Breathing rings over misty-lake artwork
                ZStack {
                    Image(ShoreArt.zen)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .overlay(Color.black.opacity(0.08))
                    ForEach(0..<3, id: \.self) { i in
                        Ellipse()
                            .stroke(Color.white.opacity(0.55 - Double(i) * 0.15), lineWidth: 2)
                            .frame(width: 90 + CGFloat(i) * 70, height: 34 + CGFloat(i) * 26)
                            .scaleEffect(breathe ? 1.08 : 0.94)
                            .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(Double(i) * 0.4),
                                       value: breathe)
                    }
                    Ellipse()
                        .fill(SS.hex(0x7C7468))
                        .frame(width: 40, height: 27)
                }
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .onAppear { breathe = true }

                SSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's water")
                            .font(SSFont.display(17))
                            .foregroundColor(SS.ink)
                        Text("The Zen lake is re-dealt every morning - same gentle water for everyone, all day. No throws to count, no goals to chase. Skip until your shoulders drop.")
                            .font(SSFont.body(13))
                            .foregroundColor(SS.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 22) {
                            StatBlock(label: "best drift",
                                      value: store.state.zenBestDistance > 0
                                      ? String(format: "%.1f m", store.state.zenBestDistance) : "-")
                            StatBlock(label: "skip record",
                                      value: store.state.zenBestSkips > 0 ? "\(store.state.zenBestSkips)" : "-")
                            StatBlock(label: "throws", value: "\(store.state.zenThrows)")
                        }
                    }
                }
                .padding(.horizontal, 16)

                SSPrimaryButton(title: "Wade In") {
                    router.play(.zen)
                }
                .padding(.horizontal, 16)

                Color.clear.frame(height: 24)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Daily Throw

struct DailyView: View {
    @ObservedObject var store: GameStore
    @ObservedObject var router: AppRouter

    private var todayKey: String { SSDaily.dateKey() }
    private var playedToday: Bool { store.playedDaily(todayKey) }
    private var todayLevel: LevelSpec { SSDaily.makeLevel(for: todayKey) }

    private var sortedHistory: [DailyRecord] {
        store.state.dailyRecords.sorted { $0.score > $1.score }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                SSScreenHeader(title: "Daily Throw",
                               subtitle: "One dated lake, three throws. Same for every morning visitor.")

                Image(ShoreArt.daily)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()
                    .overlay(
                        LinearGradient(colors: [Color.black.opacity(0.05),
                                                Color.black.opacity(0.0),
                                                Color.black.opacity(0.32)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)

                SSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayDate)
                                    .font(SSFont.display(19))
                                    .foregroundColor(SS.ink)
                                Text("streak \(store.state.dailyStreak) day\(store.state.dailyStreak == 1 ? "" : "s")")
                                    .font(SSFont.body(12, .semibold))
                                    .foregroundColor(SS.accent)
                            }
                            Spacer()
                            DailyTabIcon(size: 34, color: SS.goldDeep)
                        }

                        // Conditions preview
                        HStack(spacing: 10) {
                            conditionChip(label: String(format: "%.0f m lake", todayLevel.sceneLength))
                            if abs(todayLevel.windBase) > 0.05 || todayLevel.gustPower > 0.05 {
                                conditionChip(label: windText)
                            }
                            if !todayLevel.rings.isEmpty {
                                conditionChip(label: "\(todayLevel.rings.count) rings")
                            }
                            if !todayLevel.wood.isEmpty || !todayLevel.buoys.isEmpty {
                                conditionChip(label: "hazards")
                            }
                        }

                        if playedToday, let rec = store.state.dailyRecords.first(where: { $0.date == todayKey }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("today's score")
                                    .font(SSFont.body(11, .semibold))
                                    .foregroundColor(SS.inkSoft)
                                Text("\(rec.score)")
                                    .font(SSFont.num(30))
                                    .foregroundColor(SS.goldDeep)
                                if let rank = rankOfToday {
                                    Text(rank)
                                        .font(SSFont.body(12, .medium))
                                        .foregroundColor(SS.inkSoft)
                                }
                            }
                        }

                        SSPrimaryButton(title: playedToday ? "Throw Again (best counts)" : "Take Today's Throws",
                                        color: SS.goldDeep) {
                            router.play(.daily)
                        }
                    }
                }
                .padding(.horizontal, 16)

                if !sortedHistory.isEmpty {
                    SSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your ledger")
                                .font(SSFont.display(17))
                                .foregroundColor(SS.ink)
                            ForEach(Array(sortedHistory.prefix(10).enumerated()), id: \.element.date) { pair in
                                HStack(spacing: 10) {
                                    Text("#\(pair.offset + 1)")
                                        .font(SSFont.num(12))
                                        .foregroundColor(pair.offset == 0 ? SS.goldDeep : SS.inkSoft)
                                        .frame(width: 30, alignment: .leading)
                                    Text(pair.element.date)
                                        .font(SSFont.body(13, pair.element.date == todayKey ? .bold : .regular))
                                        .foregroundColor(SS.ink)
                                    Spacer()
                                    Text(String(format: "%.0f m", pair.element.distance))
                                        .font(SSFont.num(11))
                                        .foregroundColor(SS.inkSoft)
                                    Text("\(pair.element.score)")
                                        .font(SSFont.num(13))
                                        .foregroundColor(SS.ink)
                                        .frame(width: 56, alignment: .trailing)
                                }
                                .padding(.vertical, 2)
                                if pair.offset < min(9, sortedHistory.count - 1) {
                                    Rectangle().fill(SS.cardEdge.opacity(0.6)).frame(height: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 24)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var displayDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    private var windText: String {
        let w = todayLevel.windBase
        if abs(w) < 0.3 { return "gusty" }
        return w > 0 ? "tailwind" : "headwind"
    }

    private var rankOfToday: String? {
        guard let idx = sortedHistory.firstIndex(where: { $0.date == todayKey }) else { return nil }
        let total = sortedHistory.count
        guard total > 1 else { return "Your first entry in the ledger." }
        return "Ranked #\(idx + 1) of \(total) mornings you have played."
    }

    private func conditionChip(label: String) -> some View {
        Text(label)
            .font(SSFont.body(11, .semibold))
            .foregroundColor(SS.ink.opacity(0.75))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(SS.paper))
            .overlay(Capsule().stroke(SS.cardEdge, lineWidth: 1))
    }
}
