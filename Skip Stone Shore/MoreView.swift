import SwiftUI

struct MoreView: View {
    @ObservedObject var store: GameStore
    @State private var showPrivacy = false
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                SSScreenHeader(title: "The Boathouse",
                               subtitle: "Field notes, preferences, quiet corners.")

                // Codex
                SSCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            BookIcon(size: 22, color: SS.accent)
                            Text("Shore Codex")
                                .font(SSFont.display(17))
                                .foregroundColor(SS.ink)
                        }
                        Text("What the water throws at you, and how to answer.")
                            .font(SSFont.body(12))
                            .foregroundColor(SS.inkSoft)
                    }
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    ForEach(CodexData.entries) { entry in
                        CodexRow(entry: entry)
                    }
                }
                .padding(.horizontal, 16)

                // Settings
                SSCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Settings")
                            .font(SSFont.display(17))
                            .foregroundColor(SS.ink)

                        settingToggle(icon: AnyView(SpeakerIcon(size: 20, color: SS.accent)),
                                      label: "Sound",
                                      detail: "Plinks, plunks and chimes",
                                      isOn: store.state.soundOn) {
                            store.state.soundOn.toggle()
                            SoundBox.shared.enabled = store.state.soundOn
                            store.save()
                        }
                        settingToggle(icon: AnyView(HapticIcon(size: 20, color: SS.accent)),
                                      label: "Haptics",
                                      detail: "Feel each skip in your palm",
                                      isOn: store.state.hapticsOn) {
                            store.state.hapticsOn.toggle()
                            HapticBox.shared.enabled = store.state.hapticsOn
                            store.save()
                        }
                        settingToggle(icon: AnyView(HandDragIcon(size: 20, color: SS.accent)),
                                      label: "Left-handed throws",
                                      detail: "Pull down-right instead of down-left",
                                      isOn: store.state.leftHanded) {
                            store.state.leftHanded.toggle()
                            store.save()
                        }

                        Rectangle().fill(SS.cardEdge).frame(height: 1)

                        Button(action: { showPrivacy = true }) {
                            HStack(spacing: 11) {
                                ShieldIcon(size: 20, color: SS.accent)
                                Text("Privacy Policy")
                                    .font(SSFont.body(14, .semibold))
                                    .foregroundColor(SS.ink)
                                Spacer()
                                ChevronShape()
                                    .stroke(SS.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showResetConfirm = true }) {
                            HStack(spacing: 11) {
                                ResetIcon(size: 20, color: SS.danger)
                                Text("Reset all progress")
                                    .font(SSFont.body(14, .semibold))
                                    .foregroundColor(SS.danger)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)

                Text("Skip Stone Shore 1.0")
                    .font(SSFont.body(11, .medium))
                    .foregroundColor(SS.inkSoft.opacity(0.7))
                    .padding(.top, 4)

                Color.clear.frame(height: 24)
            }
        }
        .background(SS.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showPrivacy) {
            SkipStoneWebPanel(urlString: "https://example.com")
        }
        .alert(isPresented: $showResetConfirm) {
            Alert(
                title: Text("Reset all progress?"),
                message: Text("Stars, stones, honors, ledgers and ghosts will all wash away. This cannot be undone."),
                primaryButton: .destructive(Text("Reset")) {
                    store.resetAll()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func settingToggle(icon: AnyView, label: String, detail: String,
                               isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                icon
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(SSFont.body(14, .semibold))
                        .foregroundColor(SS.ink)
                    Text(detail)
                        .font(SSFont.body(11))
                        .foregroundColor(SS.inkSoft)
                }
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? SS.accent : SS.cardEdge)
                        .frame(width: 46, height: 27)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 21, height: 21)
                        .padding(3)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Codex

struct CodexEntry: Identifiable {
    let id: String
    let title: String
    let text: String
    let iconKind: String
}

enum CodexData {
    static let entries: [CodexEntry] = [
        CodexEntry(id: "throw", title: "The Throw",
                   text: "Drag back from the stone to set angle and power - the dotted arc is your promise to the water. Low, fast throws skip best. You get three throws per level; only your best matters.",
                   iconKind: "throw"),
        CodexEntry(id: "beat", title: "The Timing Beat",
                   text: "As the stone falls, a ring tightens around the landing point. Tap when it closes on the mark. Perfect keeps most of your speed and adds lift; good keeps some; late barely saves it; silence sinks the stone.",
                   iconKind: "beat"),
        CodexEntry(id: "spin", title: "Spin",
                   text: "A fresh throw carries spin that steadies the stone and widens the timing windows. Spin fades with every skip - late throws demand sharper taps.",
                   iconKind: "spin"),
        CodexEntry(id: "rings", title: "Floating Rings",
                   text: "Golden hoops standing over the water. Fly through the hoop - not under it - to collect. Many level goals ask for rings in a single throw.",
                   iconKind: "ring"),
        CodexEntry(id: "pads", title: "Lily Pads",
                   text: "Nature's trampolines. Land on one and the stone springs on with no tap needed - a guaranteed strong skip that even restores a little spin.",
                   iconKind: "pad"),
        CodexEntry(id: "buoys", title: "Buoys",
                   text: "Painted keep-away markers. Clip one and the stone staggers - its speed dies, and the next touch of water swallows it. On the Sunset Sea they drift on their anchors.",
                   iconKind: "buoy"),
        CodexEntry(id: "wood", title: "Driftwood",
                   text: "Low logs lying across the lane. Your stone must be above them when it crosses, or the run ends with a thud. Skip early, fly over, or aim higher.",
                   iconKind: "wood"),
        CodexEntry(id: "wind", title: "Wind and Gusts",
                   text: "Steady wind pushes every meter of flight - the chip in the corner shows its live strength. Gusts come and go in seeded bursts; each of your three throws meets its own weather.",
                   iconKind: "wind"),
        CodexEntry(id: "waves", title: "Waves",
                   text: "The surface is a braid of rolling sines. Tall waves lift and drop the contact point, bending the beat. Glass water is honest; fjord water is not.",
                   iconKind: "wave"),
        CodexEntry(id: "shore", title: "The Far Shore",
                   text: "Some levels end on a sandy bank with a flag. Carry the stone all the way and it lands - counted as a triumph, no final tap required.",
                   iconKind: "flag"),
        CodexEntry(id: "stones", title: "Stones",
                   text: "Every stone in the collection throws differently: weight drives launch speed, lift feeds the bounce, window stretches the timing beat. Pick the stone that fits the shore.",
                   iconKind: "stone"),
        CodexEntry(id: "ghost", title: "Ghosts",
                   text: "Your best throw on each level lingers as a faint dotted arc. Chase it, pass it, and it becomes the new ghost.",
                   iconKind: "ghost")
    ]
}

struct CodexRow: View {
    let entry: CodexEntry
    @State private var open = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { open.toggle() }
        }) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 11) {
                    codexIcon
                        .frame(width: 26, height: 26)
                    Text(entry.title)
                        .font(SSFont.body(14, .bold))
                        .foregroundColor(SS.ink)
                    Spacer()
                    ChevronShape()
                        .stroke(SS.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 11, height: 11)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                if open {
                    Text(entry.text)
                        .font(SSFont.body(13))
                        .foregroundColor(SS.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(SS.card)
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(SS.cardEdge, lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var codexIcon: some View {
        switch entry.iconKind {
        case "ring": RingTargetIcon(size: 22)
        case "pad": LilyPadIcon(size: 24)
        case "buoy": BuoyIcon(size: 22)
        case "wood": DriftwoodIcon(size: 22)
        case "wind": WindIconShape()
                .stroke(SS.accent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        case "wave": WavePathShape(crests: 2, amp: 0.22, yFrac: 0.5)
                .stroke(SS.accent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case "flag": FlagIcon(size: 22, color: SS.accent)
        case "stone": StoneMiniIcon(size: 22, body1: SS.hex(0x8B8378), sheen: SS.hex(0xC9C2B4))
        case "beat": RingTargetIcon(size: 22, color: SS.accent)
        case "spin": ResetIcon(size: 22, color: SS.accent)
        case "ghost": ZStack {
                Circle().stroke(SS.inkSoft.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
            }
        default: HandDragIcon(size: 22, color: SS.accent)
        }
    }
}
