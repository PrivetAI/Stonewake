import SwiftUI

// MARK: - Color helpers + UI chrome palette

enum SW {
    static func hex(_ v: UInt32) -> Color {
        Color(
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0
        )
    }

    // Cream UI chrome, consistent across all shores
    static let paper = hex(0xF7F1E4)
    static let card = hex(0xFFFDF6)
    static let cardEdge = hex(0xE8DFCB)
    static let ink = hex(0x3B352C)
    static let inkSoft = hex(0x877E6C)
    static let accent = hex(0x2E7D74)      // lake teal
    static let accentWarm = hex(0xC97B4A)  // sunset clay
    static let gold = hex(0xE0A93E)
    static let goldDeep = hex(0xB8842A)
    static let danger = hex(0xB5543E)
    static let padGreen = hex(0x5E8C4A)
}

// MARK: - Fonts

enum SWFont {
    static func display(_ s: CGFloat) -> Font { .custom("Georgia-Bold", size: s) }
    static func displayItalic(_ s: CGFloat) -> Font { .custom("Georgia-BoldItalic", size: s) }
    static func serif(_ s: CGFloat) -> Font { .custom("Georgia", size: s) }
    static func body(_ s: CGFloat, _ w: Font.Weight = .regular) -> Font {
        .system(size: s, weight: w, design: .rounded)
    }
    static func num(_ s: CGFloat) -> Font { .custom("Menlo-Bold", size: s) }
    static func numLight(_ s: CGFloat) -> Font { .custom("Menlo", size: s) }
}

// MARK: - Shore scene palettes

struct ShorePalette {
    let skyTop: Color
    let skyMid: Color
    let skyLow: Color
    let sun: Color
    let sunGlow: Color
    let hillFar: Color
    let hillNear: Color
    let waterTop: Color
    let waterDeep: Color
    let shimmer: Color
    let reed: Color
    let sand: Color
    let accent: Color
}

enum ShorePalettes {
    static let dawn = ShorePalette(
        skyTop: SW.hex(0xF9D8BC), skyMid: SW.hex(0xF6C3A6), skyLow: SW.hex(0xF2AE97),
        sun: SW.hex(0xFFEBC4), sunGlow: SW.hex(0xFFD9A0),
        hillFar: SW.hex(0xD99C86), hillNear: SW.hex(0xB57A6E),
        waterTop: SW.hex(0xE9B49B), waterDeep: SW.hex(0x8E6B75),
        shimmer: SW.hex(0xFFE9CE), reed: SW.hex(0x7A5B52), sand: SW.hex(0xE5C9A4),
        accent: SW.hex(0xC97B4A)
    )
    static let willow = ShorePalette(
        skyTop: SW.hex(0xDCEBC8), skyMid: SW.hex(0xC3DEB1), skyLow: SW.hex(0xA8CD9C),
        sun: SW.hex(0xF8F3D4), sunGlow: SW.hex(0xDDE8AF),
        hillFar: SW.hex(0x89AE7C), hillNear: SW.hex(0x5F8A58),
        waterTop: SW.hex(0x9DC4A6), waterDeep: SW.hex(0x3F6B55),
        shimmer: SW.hex(0xEAF5D8), reed: SW.hex(0x3E5C38), sand: SW.hex(0xCBC391),
        accent: SW.hex(0x4C7D45)
    )
    static let fjord = ShorePalette(
        skyTop: SW.hex(0xC7D5DE), skyMid: SW.hex(0xA9BECD), skyLow: SW.hex(0x8CA6BA),
        sun: SW.hex(0xEFF3F2), sunGlow: SW.hex(0xC2D4DA),
        hillFar: SW.hex(0x7A93A6), hillNear: SW.hex(0x4F6B80),
        waterTop: SW.hex(0x7FA0B2), waterDeep: SW.hex(0x2F4B60),
        shimmer: SW.hex(0xDCE9EC), reed: SW.hex(0x415B66), sand: SW.hex(0xA9AD9E),
        accent: SW.hex(0x3E6E85)
    )
    static let lagoon = ShorePalette(
        skyTop: SW.hex(0x394A78), skyMid: SW.hex(0x4A5C90), skyLow: SW.hex(0x6D6F9F),
        sun: SW.hex(0xEDEBFF), sunGlow: SW.hex(0x9C95D6),
        hillFar: SW.hex(0x4D4E80), hillNear: SW.hex(0x33355E),
        waterTop: SW.hex(0x585F9E), waterDeep: SW.hex(0x1E2247),
        shimmer: SW.hex(0xB9BFF2), reed: SW.hex(0x2A2C50), sand: SW.hex(0x6E6C96),
        accent: SW.hex(0x8F87E8)
    )
    static let sunset = ShorePalette(
        skyTop: SW.hex(0xF4B183), skyMid: SW.hex(0xEF9166), skyLow: SW.hex(0xD96D57),
        sun: SW.hex(0xFFE3A9), sunGlow: SW.hex(0xFFB870),
        hillFar: SW.hex(0xB56A55), hillNear: SW.hex(0x7E4A45),
        waterTop: SW.hex(0xE0855F), waterDeep: SW.hex(0x5D3A52),
        shimmer: SW.hex(0xFFD9A3), reed: SW.hex(0x5C3A38), sand: SW.hex(0xD9AE7E),
        accent: SW.hex(0xD96D3F)
    )
    static let zen = ShorePalette(
        skyTop: SW.hex(0xD9E8E3), skyMid: SW.hex(0xC2DCD3), skyLow: SW.hex(0xA8CDC4),
        sun: SW.hex(0xF6F7EA), sunGlow: SW.hex(0xD5E6D3),
        hillFar: SW.hex(0x8FB3A6), hillNear: SW.hex(0x62897E),
        waterTop: SW.hex(0x93BFB4), waterDeep: SW.hex(0x39605C),
        shimmer: SW.hex(0xEAF6EE), reed: SW.hex(0x48685E), sand: SW.hex(0xCFC7A3),
        accent: SW.hex(0x2E7D74)
    )
    static let daily = ShorePalette(
        skyTop: SW.hex(0xF3D9A8), skyMid: SW.hex(0xEFC48E), skyLow: SW.hex(0xDDA579),
        sun: SW.hex(0xFFF0C8), sunGlow: SW.hex(0xF6CE8B),
        hillFar: SW.hex(0xC29470), hillNear: SW.hex(0x8E6A54),
        waterTop: SW.hex(0xD9A97E), waterDeep: SW.hex(0x6D5364),
        shimmer: SW.hex(0xFFEBc2), reed: SW.hex(0x6B5044), sand: SW.hex(0xE2C193),
        accent: SW.hex(0xC08A3E)
    )

    static func forShore(_ index: Int) -> ShorePalette {
        switch index {
        case 0: return dawn
        case 1: return willow
        case 2: return fjord
        case 3: return lagoon
        case 4: return sunset
        default: return zen
        }
    }
}

// MARK: - Painterly artwork asset names

enum ShoreArt {
    static func shore(_ index: Int) -> String {
        switch index {
        case 0: return "art_dawn"
        case 1: return "art_willow"
        case 2: return "art_fjord"
        case 3: return "art_lagoon"
        case 4: return "art_sunset"
        default: return "art_dawn"
        }
    }
    static let zen = "art_zen"
    static let daily = "art_daily"
}

// MARK: - Adaptive layout (iPhone + iPad)

/// Content widths used once the horizontal size class turns `.regular`
/// (an iPad in either orientation). Every value is a *cap*: the content is
/// centred inside the full-width screen instead of being stretched, which is
/// what keeps a 13-inch iPad from looking like a blown-up phone.
enum SWLayout {
    /// Prose and settings - a single readable column.
    static let readingWidth: CGFloat = 720
    /// Multi-column runs of cards (shores, levels, stones, honors, codex).
    static let gridWidth: CGFloat = 920
    /// The custom HStack tab bar.
    static let tabBarWidth: CGFloat = 640
    /// The in-game HUD row, so the corner clusters do not drift to the bezels.
    static let hudWidth: CGFloat = 760
    /// Modal cards over the lake.
    static let overlayWidth: CGFloat = 520
    /// Toast banners.
    static let toastWidth: CGFloat = 520

    /// True only for the iPad layout. The idiom half of this test is
    /// deliberate: a Plus/Max iPhone in LANDSCAPE also reports a `.regular`
    /// horizontal size class, and the phone layout must not move in any
    /// orientation. Requiring `.pad` as well means
    ///
    ///     iPhone, any orientation        -> false (phone layout, verbatim)
    ///     iPad full screen / half split  -> true  (adaptive layout)
    ///     iPad narrow split / Slide Over -> false (phone layout, correct:
    ///                                             the slot is ~320-390pt)
    static func isRegular(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }
}

/// Caps and centres a view on regular width. On compact width it returns the
/// view completely untouched, so the shipped iPhone layout is unchanged.
private struct SWRegularMaxWidth: ViewModifier {
    let width: CGFloat
    @Environment(\.horizontalSizeClass) private var hSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if SWLayout.isRegular(hSize) {
            content
                .frame(maxWidth: width)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// No-op on iPhone; on iPad caps the width and centres.
    func ssRegularMaxWidth(_ width: CGFloat) -> some View {
        modifier(SWRegularMaxWidth(width: width))
    }
}

/// A vertical run of cards on iPhone, the same cards spread over
/// `regularColumns` columns on iPad. On compact width the body is exactly the
/// `VStack(spacing:) { ForEach }` it replaces, so nothing about the iPhone
/// layout moves.
struct SWAdaptiveGrid<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let spacing: CGFloat
    private let regularColumns: Int
    private let content: (Item) -> Content

    @Environment(\.horizontalSizeClass) private var hSize

    init(_ items: [Item], spacing: CGFloat, regularColumns: Int = 2,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.regularColumns = regularColumns
        self.content = content
    }

    var body: some View {
        if SWLayout.isRegular(hSize) && regularColumns > 1 {
            // Cells carry their own horizontal padding (as they do on iPhone),
            // so grid spacing stays 0 and the gutter comes from that padding.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .top),
                                     count: regularColumns),
                      spacing: spacing) {
                ForEach(items) { item in content(item) }
            }
        } else {
            VStack(spacing: spacing) {
                ForEach(items) { item in content(item) }
            }
        }
    }
}

// MARK: - Shared UI components

struct SWCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SW.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(SW.cardEdge, lineWidth: 1)
                    )
                    .shadow(color: SW.ink.opacity(0.06), radius: 8, x: 0, y: 3)
            )
    }
}

struct SWScreenHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(SWFont.display(30))
                .foregroundColor(SW.ink)
            Text(subtitle)
                .font(SWFont.body(14, .medium))
                .foregroundColor(SW.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
}

struct SWPrimaryButton: View {
    let title: String
    var color: Color = SW.accent
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SWFont.body(17, .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color)
                        .shadow(color: color.opacity(0.35), radius: 6, x: 0, y: 3)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SWGhostButton: View {
    let title: String
    var color: Color = SW.ink
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SWFont.body(16, .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.35), lineWidth: 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
