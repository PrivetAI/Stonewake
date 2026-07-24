import SwiftUI

// Custom Shape-based icons. No SF Symbols, no emoji anywhere in the app.

// MARK: - Tab icons

struct ShoreTabIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            WavePathShape(crests: 2, amp: 0.16, yFrac: 0.68)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
            Circle()
                .fill(color)
                .frame(width: size * 0.30, height: size * 0.30)
                .offset(x: -size * 0.05, y: -size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

struct ZenTabIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.45), lineWidth: size * 0.07)
            Circle().stroke(color, lineWidth: size * 0.08)
                .frame(width: size * 0.62, height: size * 0.62)
            Circle().fill(color)
                .frame(width: size * 0.2, height: size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

struct DailyTabIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.08, height: size * 0.2)
                    .offset(y: -size * 0.38)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle()
                .stroke(color, lineWidth: size * 0.09)
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .frame(width: size, height: size)
    }
}

struct CollectionTabIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Ellipse()
                .fill(color.opacity(0.4))
                .frame(width: size * 0.9, height: size * 0.42)
                .offset(y: size * 0.26)
            Ellipse()
                .fill(color)
                .frame(width: size * 0.68, height: size * 0.5)
                .offset(y: -size * 0.06)
            Ellipse()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.22, height: size * 0.1)
                .offset(x: -size * 0.1, y: -size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

struct MoreTabIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        VStack(spacing: size * 0.16) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: size * (0.8 - Double(i) * 0.18), height: size * 0.11)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: size * 0.8, height: size * 0.62)
        .frame(width: size, height: size)
    }
}

// MARK: - Shape primitives

struct WavePathShape: Shape {
    var crests: CGFloat = 3
    var amp: CGFloat = 0.12
    var yFrac: CGFloat = 0.5
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.height * yFrac
        p.move(to: CGPoint(x: 0, y: midY))
        let steps = 36
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.width * t
            let y = midY + sin(t * .pi * 2 * crests) * rect.height * amp
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

struct StarShape: Shape {
    var points: Int = 5
    var innerRatio: CGFloat = 0.45
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOuter = min(rect.width, rect.height) / 2
        let rInner = rOuter * innerRatio
        var p = Path()
        for i in 0..<(points * 2) {
            let angle = (CGFloat(i) / CGFloat(points * 2)) * 2 * .pi - .pi / 2
            let r = i % 2 == 0 ? rOuter : rInner
            let pt = CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct ChevronShape: Shape {
    var pointRight = true
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointRight {
            p.move(to: CGPoint(x: rect.width * 0.3, y: 0))
            p.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height / 2))
            p.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height))
        } else {
            p.move(to: CGPoint(x: rect.width * 0.7, y: 0))
            p.addLine(to: CGPoint(x: rect.width * 0.25, y: rect.height / 2))
            p.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height))
        }
        return p
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.82))
        p.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.2))
        return p
    }
}

struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.82))
        p.move(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.82))
        return p
    }
}

struct LockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bodyRect = CGRect(x: rect.width * 0.18, y: rect.height * 0.45,
                              width: rect.width * 0.64, height: rect.height * 0.48)
        p.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: 4, height: 4))
        p.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.32))
        p.addArc(center: CGPoint(x: rect.width * 0.5, y: rect.height * 0.32),
                 radius: rect.width * 0.2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.45))
        return p
    }
}

struct PauseIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: rect.width * 0.22, y: rect.height * 0.15,
                                    width: rect.width * 0.18, height: rect.height * 0.7),
                         cornerSize: CGSize(width: 2, height: 2))
        p.addRoundedRect(in: CGRect(x: rect.width * 0.6, y: rect.height * 0.15,
                                    width: rect.width * 0.18, height: rect.height * 0.7),
                         cornerSize: CGSize(width: 2, height: 2))
        return p
    }
}

struct PlayIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.5))
        p.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.82))
        p.closeSubpath()
        return p
    }
}

struct WindIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (i, y) in [0.28, 0.5, 0.72].enumerated() {
            let w = [0.85, 0.65, 0.75][i]
            p.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * y))
            p.addLine(to: CGPoint(x: rect.width * w, y: rect.height * y))
            p.move(to: CGPoint(x: rect.width * (w - 0.12), y: rect.height * (y - 0.08)))
            p.addLine(to: CGPoint(x: rect.width * w, y: rect.height * y))
            p.addLine(to: CGPoint(x: rect.width * (w - 0.12), y: rect.height * (y + 0.08)))
        }
        return p
    }
}

// MARK: - Target icons (codex, HUD)

struct RingTargetIcon: View {
    let size: CGFloat
    var color: Color = SS.gold
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.12)
            Circle().stroke(color.opacity(0.35), lineWidth: size * 0.05)
                .frame(width: size * 0.68, height: size * 0.68)
        }
        .frame(width: size, height: size)
    }
}

struct LilyPadIcon: View {
    let size: CGFloat
    var color: Color = SS.padGreen
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.06, to: 0.98)
                .fill(color)
                .rotationEffect(.degrees(-25))
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.12, y: -size * 0.12)
        }
        .frame(width: size, height: size)
        .scaleEffect(y: 0.62)
    }
}

struct BuoyIcon: View {
    let size: CGFloat
    var color: Color = SS.danger
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(color)
                .frame(width: size * 0.16, height: size * 0.3)
            Ellipse().fill(color)
                .frame(width: size * 0.6, height: size * 0.52)
                .overlay(
                    Rectangle().fill(Color.white.opacity(0.65))
                        .frame(height: size * 0.1)
                )
                .clipShape(Ellipse())
        }
        .frame(width: size, height: size)
    }
}

struct DriftwoodIcon: View {
    let size: CGFloat
    var color: Color = SS.hex(0x8A6444)
    var body: some View {
        ZStack {
            Capsule().fill(color)
                .frame(width: size * 0.95, height: size * 0.3)
            Capsule().fill(color.opacity(0.7))
                .frame(width: size * 0.35, height: size * 0.14)
                .rotationEffect(.degrees(-35))
                .offset(x: size * 0.2, y: -size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

struct StoneMiniIcon: View {
    let size: CGFloat
    let body1: Color
    let sheen: Color
    var body: some View {
        ZStack {
            Ellipse().fill(body1)
            Ellipse()
                .fill(sheen.opacity(0.55))
                .frame(width: size * 0.4, height: size * 0.16)
                .offset(x: -size * 0.14, y: -size * 0.16)
        }
        .frame(width: size, height: size * 0.72)
    }
}

struct TrophyIcon: View {
    let size: CGFloat
    var color: Color = SS.gold
    var body: some View {
        VStack(spacing: size * 0.03) {
            ZStack {
                UnevenCupShape().fill(color)
            }
            .frame(width: size * 0.6, height: size * 0.48)
            Rectangle().fill(color).frame(width: size * 0.12, height: size * 0.12)
            RoundedRectangle(cornerRadius: size * 0.04)
                .fill(color)
                .frame(width: size * 0.45, height: size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

struct UnevenCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addCurve(to: CGPoint(x: rect.width * 0.5, y: rect.height),
                   control1: CGPoint(x: rect.width * 0.95, y: rect.height * 0.85),
                   control2: CGPoint(x: rect.width * 0.72, y: rect.height))
        p.addCurve(to: CGPoint(x: 0, y: 0),
                   control1: CGPoint(x: rect.width * 0.28, y: rect.height),
                   control2: CGPoint(x: rect.width * 0.05, y: rect.height * 0.85))
        p.closeSubpath()
        return p
    }
}

struct HandDragIcon: View {
    let size: CGFloat
    var color: Color = SS.ink
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
            Circle()
                .stroke(color, lineWidth: size * 0.06)
                .frame(width: size * 0.4, height: size * 0.4)
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.3))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.08))
                p.move(to: CGPoint(x: size * 0.42, y: size * 0.16))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.06))
                p.addLine(to: CGPoint(x: size * 0.58, y: size * 0.16))
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct SpeakerIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: size * 0.12, y: size * 0.38))
                p.addLine(to: CGPoint(x: size * 0.3, y: size * 0.38))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.18))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.82))
                p.addLine(to: CGPoint(x: size * 0.3, y: size * 0.62))
                p.addLine(to: CGPoint(x: size * 0.12, y: size * 0.62))
                p.closeSubpath()
            }
            .fill(color)
            Path { p in
                p.addArc(center: CGPoint(x: size * 0.55, y: size * 0.5), radius: size * 0.18,
                         startAngle: .degrees(-55), endAngle: .degrees(55), clockwise: false)
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
            Path { p in
                p.addArc(center: CGPoint(x: size * 0.55, y: size * 0.5), radius: size * 0.3,
                         startAngle: .degrees(-50), endAngle: .degrees(50), clockwise: false)
            }
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

struct HapticIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .stroke(color, lineWidth: size * 0.07)
                .frame(width: size * 0.42, height: size * 0.72)
            ForEach(0..<2, id: \.self) { i in
                Path { p in
                    let x = size * (0.76 + Double(i) * 0.12)
                    p.move(to: CGPoint(x: x, y: size * (0.34 - Double(i) * 0.06)))
                    p.addLine(to: CGPoint(x: x, y: size * (0.66 + Double(i) * 0.06)))
                }
                .stroke(color.opacity(1.0 - Double(i) * 0.4),
                        style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

struct BookIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.2))
                p.addCurve(to: CGPoint(x: size * 0.1, y: size * 0.18),
                           control1: CGPoint(x: size * 0.38, y: size * 0.1),
                           control2: CGPoint(x: size * 0.2, y: size * 0.1))
                p.addLine(to: CGPoint(x: size * 0.1, y: size * 0.78))
                p.addCurve(to: CGPoint(x: size * 0.5, y: size * 0.84),
                           control1: CGPoint(x: size * 0.2, y: size * 0.7),
                           control2: CGPoint(x: size * 0.38, y: size * 0.72))
                p.addCurve(to: CGPoint(x: size * 0.9, y: size * 0.78),
                           control1: CGPoint(x: size * 0.62, y: size * 0.72),
                           control2: CGPoint(x: size * 0.8, y: size * 0.7))
                p.addLine(to: CGPoint(x: size * 0.9, y: size * 0.18))
                p.addCurve(to: CGPoint(x: size * 0.5, y: size * 0.2),
                           control1: CGPoint(x: size * 0.8, y: size * 0.1),
                           control2: CGPoint(x: size * 0.62, y: size * 0.1))
                p.closeSubpath()
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.06, lineJoin: .round))
            Path { p in
                p.move(to: CGPoint(x: size * 0.5, y: size * 0.2))
                p.addLine(to: CGPoint(x: size * 0.5, y: size * 0.84))
            }
            .stroke(color.opacity(0.6), lineWidth: size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

struct ResetIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Path { p in
                p.addArc(center: CGPoint(x: size * 0.5, y: size * 0.5), radius: size * 0.32,
                         startAngle: .degrees(30), endAngle: .degrees(300), clockwise: false)
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            Path { p in
                p.move(to: CGPoint(x: size * 0.86, y: size * 0.28))
                p.addLine(to: CGPoint(x: size * 0.78, y: size * 0.52))
                p.addLine(to: CGPoint(x: size * 0.58, y: size * 0.38))
                p.closeSubpath()
            }
            .fill(color)
        }
        .frame(width: size, height: size)
    }
}

struct ShieldIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: size * 0.5, y: size * 0.08))
            p.addLine(to: CGPoint(x: size * 0.85, y: size * 0.22))
            p.addLine(to: CGPoint(x: size * 0.85, y: size * 0.52))
            p.addCurve(to: CGPoint(x: size * 0.5, y: size * 0.92),
                       control1: CGPoint(x: size * 0.85, y: size * 0.74),
                       control2: CGPoint(x: size * 0.68, y: size * 0.86))
            p.addCurve(to: CGPoint(x: size * 0.15, y: size * 0.52),
                       control1: CGPoint(x: size * 0.32, y: size * 0.86),
                       control2: CGPoint(x: size * 0.15, y: size * 0.74))
            p.addLine(to: CGPoint(x: size * 0.15, y: size * 0.22))
            p.closeSubpath()
        }
        .stroke(color, style: StrokeStyle(lineWidth: size * 0.065, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

struct FlagIcon: View {
    let size: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: size * 0.22, y: size * 0.08))
                p.addLine(to: CGPoint(x: size * 0.22, y: size * 0.92))
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
            Path { p in
                p.move(to: CGPoint(x: size * 0.26, y: size * 0.12))
                p.addLine(to: CGPoint(x: size * 0.82, y: size * 0.24))
                p.addLine(to: CGPoint(x: size * 0.26, y: size * 0.44))
                p.closeSubpath()
            }
            .fill(color)
        }
        .frame(width: size, height: size)
    }
}
