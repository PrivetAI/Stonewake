import SwiftUI

// Painterly side-view lake scene rendered in a single Canvas.
// IMPORTANT: all camera math uses the parent-passed screenSize, never the
// Canvas closure's own size parameter.

struct AimState {
    var isAiming = false
    var angle: Double = 0.26   // radians
    var power: Double = 0
}

struct LakeSceneView: View {
    @ObservedObject var engine: ThrowEngine
    let palette: ShorePalette
    let screenSize: CGSize
    let aim: AimState
    let ghost: [CGPoint]

    // MARK: - Framing

    /// Metres of sky that must stay above the waterline. The heaviest stone
    /// (weight 1.16) at max power and max angle peaks around 8.8 m, so 11 m
    /// keeps every possible arc on screen with margin.
    private static let minSkyMeters: CGFloat = 11

    /// True only for a genuine iPad viewport. Every iPhone, in either
    /// orientation, has a short side well under 500pt, so the framing and the
    /// gameplay feel on phones stay exactly as shipped.
    private var isLargeViewport: Bool {
        min(screenSize.width, screenSize.height) >= 500
    }

    /// Scale for scene furniture drawn in fixed points (timing ring, distance
    /// ticks, flag, reeds, splash FX). Exactly 1.0 on phone-sized viewports.
    private var uiScale: CGFloat {
        guard isLargeViewport else { return 1.0 }
        return min(1.9, max(1.2, min(screenSize.width, screenSize.height) / 480))
    }

    private var ppm: CGFloat {
        // Phones: the shipped rule, a 24 m window across the width.
        guard isLargeViewport else { return max(12, screenSize.width / 24) }
        // iPad: hold the stone at roughly 25-32pt instead of letting the phone
        // rule blow it up to ~57pt. That frames about 30 m of lake in portrait
        // and 43 m in landscape - more of the throw is readable ahead of the
        // stone, which is what a wide screen should buy you.
        let target = min(32, max(24, min(screenSize.width, screenSize.height) / 30))
        // ...but never so tall that a full-power arc leaves the top of the sky.
        return max(12, min(target, waterlineY / LakeSceneView.minSkyMeters))
    }

    private var waterlineY: CGFloat {
        screenSize.height * 0.62
    }
    private var cameraX: Double {
        let visible = Double(screenSize.width / ppm)
        switch engine.phase {
        case .ready: return -1.2
        default:
            return max(-1.2, engine.x - visible * 0.38)
        }
    }

    private func sx(_ wx: Double) -> CGFloat {
        CGFloat(wx - cameraX) * ppm
    }
    private func sy(_ wy: Double) -> CGFloat {
        waterlineY - CGFloat(wy) * ppm
    }

    var body: some View {
        Canvas { context, _ in
            let W = screenSize.width
            let H = screenSize.height
            let t = engine.time
            let u = uiScale

            drawSky(context, W: W, H: H)
            drawSun(context, W: W, H: H)
            drawHills(context, W: W, factor: 0.12, baseY: waterlineY - 26 * u, height: 60 * u,
                      color: palette.hillFar, seedShift: 0)
            drawHills(context, W: W, factor: 0.28, baseY: waterlineY - 8 * u, height: 42 * u,
                      color: palette.hillNear, seedShift: 40)
            drawWater(context, W: W, H: H, t: t)
            drawDistanceTicks(context, H: H)
            drawFarShore(context, H: H, t: t)
            drawLaunchBank(context, H: H)
            drawWood(context, t: t)
            drawPads(context, t: t)
            drawBuoys(context, t: t)
            drawRings(context, t: t)
            drawGhost(context)
            drawFX(context, t: t)
            if engine.phase == .ready { drawAimPreview(context) }
            drawStone(context)
            drawTimingRing(context)
            drawReedsForeground(context, W: W, H: H)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .clipped()
        .allowsHitTesting(false)
    }

    // MARK: - Backdrop

    private func drawSky(_ c: GraphicsContext, W: CGFloat, H: CGFloat) {
        let rect = CGRect(x: 0, y: 0, width: W, height: waterlineY)
        c.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [palette.skyTop, palette.skyMid, palette.skyLow]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: waterlineY)))
    }

    private func drawSun(_ c: GraphicsContext, W: CGFloat, H: CGFloat) {
        let center = CGPoint(x: W * 0.72, y: waterlineY * 0.34)
        let glowR: CGFloat = W * 0.22
        c.fill(Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR,
                                      width: glowR * 2, height: glowR * 2)),
               with: .radialGradient(
                Gradient(colors: [palette.sunGlow.opacity(0.55), palette.sunGlow.opacity(0)]),
                center: center, startRadius: 0, endRadius: glowR))
        let r: CGFloat = W * 0.075
        c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               with: .color(palette.sun))
    }

    private func hillY(_ wx: Double, seedShift: Double) -> Double {
        let a = sin((wx + seedShift) * 0.055) * 0.55
        let b = sin((wx + seedShift) * 0.021 + 1.7) * 1.0
        let cc = sin((wx + seedShift) * 0.11 + 0.4) * 0.25
        return a + b + cc
    }

    private func drawHills(_ c: GraphicsContext, W: CGFloat, factor: Double, baseY: CGFloat,
                           height: CGFloat, color: Color, seedShift: Double) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: waterlineY))
        let steps = 42
        for i in 0...steps {
            let px = W * CGFloat(i) / CGFloat(steps)
            let wx = cameraX * factor + Double(px / ppm)
            let hy = baseY - height * CGFloat(0.5 + 0.5 * hillY(wx * 6, seedShift: seedShift) / 1.8)
            p.addLine(to: CGPoint(x: px, y: hy))
        }
        p.addLine(to: CGPoint(x: W, y: waterlineY))
        p.closeSubpath()
        c.fill(p, with: .color(color))
    }

    // MARK: - Water

    private func surfacePoint(_ px: CGFloat, t: Double) -> CGPoint {
        let wx = cameraX + Double(px / ppm)
        return CGPoint(x: px, y: sy(engine.waveHeight(atX: wx, t: t)))
    }

    private func drawWater(_ c: GraphicsContext, W: CGFloat, H: CGFloat, t: Double) {
        let u = uiScale
        var p = Path()
        let steps = 56
        p.move(to: surfacePoint(0, t: t))
        for i in 1...steps {
            p.addLine(to: surfacePoint(W * CGFloat(i) / CGFloat(steps), t: t))
        }
        p.addLine(to: CGPoint(x: W, y: H))
        p.addLine(to: CGPoint(x: 0, y: H))
        p.closeSubpath()
        c.fill(p, with: .linearGradient(
            Gradient(colors: [palette.waterTop, palette.waterDeep]),
            startPoint: CGPoint(x: 0, y: waterlineY - 14 * u),
            endPoint: CGPoint(x: 0, y: H)))

        // Shimmer bands. A tall iPad water field needs more of them to avoid a
        // wide dead band along the bottom; phones keep the shipped four.
        let bandCount = isLargeViewport ? 7 : 4
        for band in 0..<bandCount {
            let bandY = waterlineY + (16 + CGFloat(band) * 26) * u
            guard bandY < H else { break }
            var sp = Path()
            var drawing = false
            let phase = t * (0.7 + Double(band) * 0.22) + Double(band) * 2.1
            for i in 0...70 {
                let px = W * CGFloat(i) / 70
                let wx = cameraX + Double(px / ppm)
                let vis = sin(wx * 0.9 + phase) + sin(wx * 0.37 - phase * 0.6)
                if vis > 0.65 {
                    let yy = bandY + CGFloat(sin(wx * 1.7 + phase) * 2.2) * u
                    if drawing { sp.addLine(to: CGPoint(x: px, y: yy)) }
                    else { sp.move(to: CGPoint(x: px, y: yy)); drawing = true }
                } else {
                    drawing = false
                }
            }
            c.stroke(sp, with: .color(palette.shimmer.opacity(0.32 - Double(min(band, 4)) * 0.06)),
                     style: StrokeStyle(lineWidth: 1.6 * u, lineCap: .round))
        }

        // Sun reflection column
        let reflX = W * 0.72
        var rp = Path()
        let reflCount = isLargeViewport ? 14 : 9
        for i in 0..<reflCount {
            let yy = waterlineY + CGFloat(8 + i * 14) * u
            guard yy < H else { break }
            let wobble = CGFloat(sin(t * 1.3 + Double(i) * 1.1) * 7) * u
            let wdt = CGFloat(max(6, 26 - i * 2)) * u
            rp.move(to: CGPoint(x: reflX - wdt / 2 + wobble, y: yy))
            rp.addLine(to: CGPoint(x: reflX + wdt / 2 + wobble, y: yy))
        }
        c.stroke(rp, with: .color(palette.sun.opacity(0.3)),
                 style: StrokeStyle(lineWidth: 2.4 * u, lineCap: .round))
    }

    private func drawDistanceTicks(_ c: GraphicsContext, H: CGFloat) {
        let u = uiScale
        let visible = Double(screenSize.width / ppm)
        let startM = Int(max(0, cameraX / 10) ) * 10
        var m = startM
        while Double(m) < cameraX + visible + 10 {
            let px = sx(Double(m))
            if px > -30 && px < screenSize.width + 30 && m > 0 {
                let yy = waterlineY + 6 * u
                var tp = Path()
                tp.move(to: CGPoint(x: px, y: yy))
                tp.addLine(to: CGPoint(x: px, y: yy + (m % 20 == 0 ? 9 : 5) * u))
                c.stroke(tp, with: .color(Color.white.opacity(0.35)), lineWidth: 1.4 * u)
                if m % 20 == 0 {
                    c.draw(Text("\(m)").font(.custom("Menlo", size: 9 * u)).foregroundColor(.white.opacity(0.5)),
                           at: CGPoint(x: px, y: yy + 17 * u))
                }
            }
            m += 10
        }
    }

    // MARK: - Shores

    private func drawLaunchBank(_ c: GraphicsContext, H: CGFloat) {
        let u = uiScale
        let edge = sx(-0.4)
        guard edge > -60 * u else { return }
        var p = Path()
        p.move(to: CGPoint(x: edge, y: sy(-0.05)))
        p.addLine(to: CGPoint(x: edge - 90 * u, y: sy(0.9)))
        p.addLine(to: CGPoint(x: edge - 90 * u, y: H))
        p.addLine(to: CGPoint(x: edge + 14 * u, y: H))
        p.closeSubpath()
        c.fill(p, with: .color(palette.sand))
    }

    private func drawFarShore(_ c: GraphicsContext, H: CGFloat, t: Double) {
        let u = uiScale
        let startPx = sx(engine.level.shoreRampStart)
        guard startPx < screenSize.width + 80 else { return }
        var p = Path()
        p.move(to: CGPoint(x: startPx, y: sy(-0.15)))
        let steps = 16
        for i in 1...steps {
            let wx = engine.level.shoreRampStart + Double(i) / Double(steps) * 10.0
            p.addLine(to: CGPoint(x: sx(wx), y: sy(engine.shoreGroundHeight(at: min(wx, engine.level.sceneLength)))))
        }
        p.addLine(to: CGPoint(x: sx(engine.level.shoreRampStart + 10), y: H))
        p.addLine(to: CGPoint(x: startPx, y: H))
        p.closeSubpath()
        c.fill(p, with: .color(palette.sand))

        // Landing flag
        let fx = sx(engine.level.sceneLength - 1.2)
        let fy = sy(engine.shoreGroundHeight(at: engine.level.sceneLength - 1.2))
        var pole = Path()
        pole.move(to: CGPoint(x: fx, y: fy))
        pole.addLine(to: CGPoint(x: fx, y: fy - 34 * u))
        c.stroke(pole, with: .color(SS.ink.opacity(0.7)), lineWidth: 2 * u)
        var flag = Path()
        let wave = CGFloat(sin(t * 2.1) * 3) * u
        flag.move(to: CGPoint(x: fx, y: fy - 34 * u))
        flag.addLine(to: CGPoint(x: fx + 20 * u + wave, y: fy - 29 * u))
        flag.addLine(to: CGPoint(x: fx, y: fy - 23 * u))
        flag.closeSubpath()
        c.fill(flag, with: .color(palette.accent))
    }

    // MARK: - Targets

    private func drawRings(_ c: GraphicsContext, t: Double) {
        let u = uiScale
        for (i, ring) in engine.level.rings.enumerated() {
            let px = sx(ring.x)
            guard px > -60 && px < screenSize.width + 60 else { continue }
            let collected = engine.outcome.ringsCollected.contains(i)
            let bob = collected ? 0 : sin(t * 1.2 + Double(i) * 2.2) * 0.06
            let py = sy(ring.height + bob)
            let r = ppm * CGFloat(ThrowEngine.ringRadius) * 0.82
            let color = collected ? SS.gold.opacity(0.25) : SS.gold
            // stem to water
            var stem = Path()
            stem.move(to: CGPoint(x: px, y: py + r))
            stem.addLine(to: CGPoint(x: px, y: sy(engine.waveHeight(atX: ring.x, t: t))))
            c.stroke(stem, with: .color(color.opacity(0.4)),
                     style: StrokeStyle(lineWidth: 2 * u, dash: [4 * u, 4 * u]))
            c.stroke(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .color(color), lineWidth: 4 * u)
            c.stroke(Path(ellipseIn: CGRect(x: px - r * 0.7, y: py - r * 0.7, width: r * 1.4, height: r * 1.4)),
                     with: .color(color.opacity(0.4)), lineWidth: 1.6 * u)
            if collected {
                c.draw(Text("+1").font(.custom("Menlo-Bold", size: 11 * u)).foregroundColor(SS.gold),
                       at: CGPoint(x: px, y: py - r - 10 * u))
            }
        }
    }

    private func drawPads(_ c: GraphicsContext, t: Double) {
        for (i, pad) in engine.level.pads.enumerated() {
            let px = sx(pad.x)
            guard px > -60 && px < screenSize.width + 60 else { continue }
            let py = sy(engine.waveHeight(atX: pad.x, t: t)) - 1.5
            let w = ppm * CGFloat(ThrowEngine.padRadius) * 2 * 0.9
            let h = w * 0.28
            let rect = CGRect(x: px - w / 2, y: py - h / 2, width: w, height: h)
            c.fill(Path(ellipseIn: rect), with: .color(SS.padGreen))
            // notch
            var notch = Path()
            notch.move(to: CGPoint(x: px, y: py))
            notch.addLine(to: CGPoint(x: px + w * 0.45, y: py - h * 0.4))
            notch.addLine(to: CGPoint(x: px + w * 0.28, y: py + h * 0.15))
            notch.closeSubpath()
            c.fill(notch, with: .color(palette.waterTop.opacity(0.7)))
            c.fill(Path(ellipseIn: CGRect(x: px - w * 0.22, y: py - h * 0.32, width: w * 0.3, height: h * 0.3)),
                   with: .color(Color.white.opacity(0.25)))
            let bob = sin(t * 1.6 + Double(i)) * 1.5
            _ = bob
        }
    }

    private func drawBuoys(_ c: GraphicsContext, t: Double) {
        let u = uiScale
        for b in engine.level.buoys {
            let wx = engine.buoyX(b, t: t)
            let px = sx(wx)
            guard px > -60 && px < screenSize.width + 60 else { continue }
            let surf = engine.waveHeight(atX: wx, t: t)
            let py = sy(surf)
            let bodyW = ppm * 0.9
            let bodyH = ppm * 1.0
            let rock = sin(t * 1.8 + b.x) * 0.09
            var ctx = c
            ctx.translateBy(x: px, y: py)
            ctx.rotate(by: .radians(rock))
            // hull
            let hull = CGRect(x: -bodyW / 2, y: -bodyH * 0.55, width: bodyW, height: bodyH * 0.8)
            ctx.fill(Path(ellipseIn: hull), with: .color(SS.danger))
            // stripe
            ctx.fill(Path(CGRect(x: -bodyW / 2, y: -bodyH * 0.28, width: bodyW, height: bodyH * 0.16)),
                     with: .color(Color.white.opacity(0.85)))
            // mast light
            var mast = Path()
            mast.move(to: CGPoint(x: 0, y: -bodyH * 0.55))
            mast.addLine(to: CGPoint(x: 0, y: -bodyH * 0.86))
            ctx.stroke(mast, with: .color(SS.ink.opacity(0.6)), lineWidth: 2 * u)
            ctx.fill(Path(ellipseIn: CGRect(x: -3 * u, y: -bodyH * 0.95, width: 6 * u, height: 6 * u)),
                     with: .color(SS.gold))
        }
    }

    private func drawWood(_ c: GraphicsContext, t: Double) {
        let u = uiScale
        for wd in engine.level.wood {
            let px = sx(wd.x)
            guard px > -80 && px < screenSize.width + 80 else { continue }
            let surf = engine.waveHeight(atX: wd.x, t: t)
            let topY = sy(surf + wd.height)
            let botY = sy(surf - 0.25)
            let w = ppm * 0.55
            let rect = CGRect(x: px - w / 2, y: topY, width: w, height: botY - topY)
            c.fill(Path(roundedRect: rect, cornerRadius: w * 0.4), with: .color(SS.hex(0x7A5738)))
            c.fill(Path(roundedRect: CGRect(x: px - w / 2 + 2 * u, y: topY + 2 * u,
                                            width: w * 0.35, height: max(0, botY - topY - 4 * u)),
                        cornerRadius: w * 0.2),
                   with: .color(SS.hex(0x9A744E).opacity(0.8)))
            // knot
            c.fill(Path(ellipseIn: CGRect(x: px - 3 * u, y: topY + (botY - topY) * 0.3,
                                          width: 6 * u, height: 6 * u)),
                   with: .color(SS.hex(0x5C3F26)))
        }
    }

    // MARK: - Ghost + FX

    private func drawGhost(_ c: GraphicsContext) {
        let u = uiScale
        guard !ghost.isEmpty, engine.phase == .ready || engine.phase == .flying else { return }
        for (i, pt) in ghost.enumerated() {
            let px = sx(Double(pt.x))
            guard px > -20 && px < screenSize.width + 20 else { continue }
            let py = sy(Double(pt.y))
            let fade = 0.42 * (1.0 - Double(i) / Double(max(1, ghost.count)) * 0.5)
            let r = 2 * u
            c.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                   with: .color(Color.white.opacity(fade)))
        }
    }

    private func drawFX(_ c: GraphicsContext, t: Double) {
        let u = uiScale
        for f in engine.fx {
            let age = t - f.born
            guard age >= 0 && age < 2.2 else { continue }
            let px = sx(f.x)
            guard px > -120 && px < screenSize.width + 120 else { continue }
            let py = sy(f.y)

            // Expanding ripple ellipses
            let ringCount = f.big ? 3 : 2
            for r in 0..<ringCount {
                let delay = Double(r) * 0.22
                let a = age - delay
                guard a > 0 else { continue }
                let spread = CGFloat(a) * ppm * (f.big ? 2.6 : 1.9)
                let alpha = max(0, 0.55 - a * 0.3) * (f.big ? 1.0 : 0.85)
                let rw = 14 * u + spread * 2
                let rh = (14 * u + spread * 2) * 0.3
                c.stroke(Path(ellipseIn: CGRect(x: px - rw / 2, y: py - rh / 2, width: rw, height: rh)),
                         with: .color(Color.white.opacity(alpha)),
                         lineWidth: (f.big ? 2.2 : 1.6) * u)
            }

            // Droplets
            if age < 0.7 {
                var rng = SeededRNG(seed: UInt64(f.id) &* 613)
                let n = f.big ? 9 : 5
                for _ in 0..<n {
                    let ang = rng.range(0.35 * .pi, 0.65 * .pi)
                    let spd = rng.range(1.8, f.big ? 4.6 : 3.4)
                    let dx = cos(ang) * spd * age * (rng.double01() > 0.5 ? 1 : -1)
                    let dy = sin(ang) * spd * age - 4.9 * age * age
                    let dpx = px + CGFloat(dx) * ppm * 0.5
                    let dpy = py - CGFloat(dy) * ppm * 0.5
                    let alpha = max(0, 0.8 - age * 1.2)
                    let dr = 1.6 * u
                    c.fill(Path(ellipseIn: CGRect(x: dpx - dr, y: dpy - dr, width: dr * 2, height: dr * 2)),
                           with: .color(Color.white.opacity(alpha)))
                }
            }

            // Quality burst for perfect
            if f.kind == .perfect && age < 0.5 {
                let r = (CGFloat(age) * 46 + 8) * u
                let alpha = max(0, 0.7 - age * 1.5)
                c.stroke(Path(ellipseIn: CGRect(x: px - r, y: py - r - 6 * u, width: r * 2, height: r * 2)),
                         with: .color(SS.gold.opacity(alpha)), lineWidth: 2.4 * u)
            }
        }
    }

    // MARK: - Aim preview

    private func drawAimPreview(_ c: GraphicsContext) {
        let u = uiScale
        guard aim.isAiming, aim.power > 0.04 else { return }
        let speed = ThrowEngine.baseMaxSpeed * engine.stone.weight * (0.38 + 0.62 * min(1, aim.power))
        var pvx = cos(aim.angle) * speed
        var pvy = sin(aim.angle) * speed
        var px = 0.0
        var py = ThrowEngine.launchHeight
        let dt = 0.055
        for i in 0..<18 {
            pvy -= ThrowEngine.gravity * dt
            pvx += engine.level.windBase * 0.55 * dt
            px += pvx * dt
            py += pvy * dt
            if py < engine.waveHeight(atX: px, t: engine.time) { break }
            let alpha = 0.85 - Double(i) * 0.04
            let r: CGFloat = (3.4 - CGFloat(i) * 0.09) * u
            c.fill(Path(ellipseIn: CGRect(x: sx(px) - r, y: sy(py) - r, width: r * 2, height: r * 2)),
                   with: .color(Color.white.opacity(alpha)))
        }
        // Power arc near the stone
        let cx = sx(0), cy = sy(ThrowEngine.launchHeight)
        var arc = Path()
        arc.addArc(center: CGPoint(x: cx, y: cy), radius: 30 * u,
                   startAngle: .degrees(0), endAngle: .degrees(-64), clockwise: true)
        c.stroke(arc, with: .color(Color.white.opacity(0.25)),
                 style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
        var arc2 = Path()
        arc2.addArc(center: CGPoint(x: cx, y: cy), radius: 30 * u,
                    startAngle: .degrees(0), endAngle: .degrees(-64 * aim.power), clockwise: true)
        c.stroke(arc2, with: .color(SS.gold), style: StrokeStyle(lineWidth: 5 * u, lineCap: .round))
    }

    // MARK: - Stone

    private func drawStone(_ c: GraphicsContext) {
        let u = uiScale
        guard engine.phase != .finished || engine.outcome.end == .landed else { return }
        let px = sx(engine.x)
        let py = sy(engine.y)
        let w = ppm * 1.0
        let h = ppm * 0.66
        var ctx = c
        ctx.translateBy(x: px, y: py)
        ctx.rotate(by: .radians(engine.rotation * 0.6))
        let body = StoneData.stone(id: engine.stone.id)
        ctx.fill(Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)),
                 with: .color(SS.hex(body.bodyHex)))
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.3, y: -h * 0.34, width: w * 0.42, height: h * 0.24)),
                 with: .color(SS.hex(body.sheenHex).opacity(0.75)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.06, width: w * 0.14, height: h * 0.14)),
                 with: .color(SS.hex(body.speckHex).opacity(0.8)))
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.22, y: h * 0.12, width: w * 0.1, height: h * 0.1)),
                 with: .color(SS.hex(body.speckHex).opacity(0.6)))

        // Speed trail
        if engine.phase == .flying {
            let sp = sqrt(engine.vx * engine.vx + engine.vy * engine.vy)
            if sp > 6 {
                let trailLen = CGFloat(min(sp / 20, 1)) * ppm * 1.6
                var tp = Path()
                tp.move(to: CGPoint(x: -w / 2 - trailLen, y: 0))
                tp.addLine(to: CGPoint(x: -w / 2 + 4 * u, y: 0))
                ctx.stroke(tp, with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0), Color.white.opacity(0.5)]),
                    startPoint: CGPoint(x: -w / 2 - trailLen, y: 0),
                    endPoint: CGPoint(x: -w / 2 + 4 * u, y: 0)),
                           style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
            }
        }
    }

    // MARK: - Timing ring

    private func drawTimingRing(_ c: GraphicsContext) {
        let u = uiScale
        guard let progress = engine.timingRingProgress else { return }
        let px = sx(engine.predictedContactX)
        let py = sy(engine.predictedContactY)
        guard px > -80 * u && px < screenSize.width + 80 * u else { return }

        // Fixed target ring
        let targetR: CGFloat = 15 * u
        c.stroke(Path(ellipseIn: CGRect(x: px - targetR, y: py - targetR,
                                        width: targetR * 2, height: targetR * 2)),
                 with: .color(Color.white.opacity(0.9)), lineWidth: 2.6 * u)

        // Shrinking ring: tap when it meets the target
        let shrinkR = targetR + CGFloat(progress) * 46 * u
        let near = progress < 0.28
        let ringColor = near ? SS.gold : Color.white.opacity(0.65)
        c.stroke(Path(ellipseIn: CGRect(x: px - shrinkR, y: py - shrinkR,
                                        width: shrinkR * 2, height: shrinkR * 2)),
                 with: .color(ringColor), lineWidth: (near ? 3.4 : 2.2) * u)

        // Contact point marker on the wave
        var cm = Path()
        cm.move(to: CGPoint(x: px - 6 * u, y: py))
        cm.addLine(to: CGPoint(x: px + 6 * u, y: py))
        cm.move(to: CGPoint(x: px, y: py - 6 * u))
        cm.addLine(to: CGPoint(x: px, y: py + 6 * u))
        c.stroke(cm, with: .color(Color.white.opacity(0.8)), lineWidth: 1.4 * u)

        if engine.tapFlashActive {
            let fr = targetR + 4 * u
            c.fill(Path(ellipseIn: CGRect(x: px - fr, y: py - fr, width: fr * 2, height: fr * 2)),
                   with: .color(Color.white.opacity(0.28)))
        }
    }

    // MARK: - Foreground reeds

    private func drawReedsForeground(_ c: GraphicsContext, W: CGFloat, H: CGFloat) {
        let u = uiScale
        let edge = sx(-0.4)
        guard edge > -140 * u else { return }
        var rng = SeededRNG(seed: 777)
        for i in 0..<7 {
            let bx = edge - CGFloat(10 + i * 13) * u + CGFloat(rng.range(-4, 4)) * u
            guard bx > -20 else { continue }
            let baseY = H - CGFloat(rng.range(0, 30)) * u
            let hgt = CGFloat(rng.range(50, 110)) * u
            let sway = CGFloat(sin(engine.time * 0.8 + Double(i) * 1.3)) * 4 * u
            var reed = Path()
            reed.move(to: CGPoint(x: bx, y: baseY))
            reed.addQuadCurve(to: CGPoint(x: bx + sway, y: baseY - hgt),
                              control: CGPoint(x: bx - 3 * u, y: baseY - hgt * 0.55))
            c.stroke(reed, with: .color(palette.reed), lineWidth: CGFloat(rng.range(2.2, 3.6)) * u)
            let headR = CGFloat(rng.range(3, 5)) * u
            c.fill(Path(ellipseIn: CGRect(x: bx + sway - headR, y: baseY - hgt - headR * 2.4,
                                          width: headR * 2, height: headR * 3)),
                   with: .color(palette.reed))
        }
    }
}
