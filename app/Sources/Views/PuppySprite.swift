import SwiftUI

// Tafuta's mascot — a cute golden-retriever puppy that lives beside the search bar and makes the
// app feel alive. Pure SwiftUI vector (no assets), so the same artwork scales to the app icon.
// Idle: breathes, blinks, wags its tail, ears sway, head tilts. Perks up (ears + eyes) on hover.
struct PuppySprite: View {
    var size: CGFloat = 92

    @State private var breathe = false
    @State private var wag = false
    @State private var sway = false
    @State private var tilt = false
    @State private var blinkClosed = false
    @State private var perk = false
    @State private var blinkTimer: Timer?

    // Palette (golden retriever).
    private let gold   = Color(red: 0.922, green: 0.753, blue: 0.471) // #EBC078
    private let cream  = Color(red: 0.965, green: 0.878, blue: 0.706) // #F6E0B4
    private let earG   = Color(red: 0.788, green: 0.573, blue: 0.302) // #C9924D
    private let eyeC   = Color(red: 0.165, green: 0.125, blue: 0.094) // #2A2018
    private let noseC  = Color(red: 0.227, green: 0.165, blue: 0.133) // #3A2A22
    private let tongue = Color(red: 0.941, green: 0.565, blue: 0.549) // #F0908C

    private var wagAngle: Double { wag ? 18 : -20 }
    private var swayL: Double { (sway ? 3 : -4) + (perk ? -26 : 0) }
    private var swayR: Double { (sway ? -3 : 4) + (perk ? 26 : 0) }
    private var tiltAngle: Double { tilt ? 4 : -5 }
    private var eyeBlink: CGFloat { blinkClosed ? 0.08 : 1 }
    private var eyeWiden: CGFloat { perk ? 1.12 : 1 }

    var body: some View {
        ZStack {
            // Tail (behind everything), wagging.
            shape(.tail).fill(earG)
                .rotationEffect(.degrees(wagAngle), anchor: UnitPoint(x: 0.74, y: 0.71))

            // Body + head, gentle breathing.
            ZStack {
                shape(.body).fill(gold)
                shape(.chest).fill(cream)
                shape(.pawL).fill(cream)
                shape(.pawR).fill(cream)

                // Head group, gentle tilt.
                ZStack {
                    shape(.earL).fill(earG)
                        .rotationEffect(.degrees(swayL), anchor: UnitPoint(x: 0.31, y: 0.29))
                    shape(.earR).fill(earG)
                        .rotationEffect(.degrees(swayR), anchor: UnitPoint(x: 0.69, y: 0.29))

                    shape(.head).fill(gold)
                    shape(.muzzle).fill(cream)

                    // Eyes (blink + widen around their own line).
                    ZStack {
                        shape(.eyeL).fill(eyeC)
                        shape(.eyeR).fill(eyeC)
                        shape(.hlL).fill(.white)
                        shape(.hlR).fill(.white)
                    }
                    .scaleEffect(x: 1, y: eyeBlink, anchor: UnitPoint(x: 0.5, y: 0.41))
                    .scaleEffect(eyeWiden, anchor: UnitPoint(x: 0.5, y: 0.41))

                    shape(.nose).fill(noseC)
                    shape(.mouth).stroke(noseC, style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round))
                    if perk { shape(.tongue).fill(tongue).transition(.opacity) }
                }
                .rotationEffect(.degrees(tiltAngle), anchor: UnitPoint(x: 0.5, y: 0.667))
            }
            .scaleEffect(x: 1, y: breathe ? 1.03 : 1, anchor: .bottom)
        }
        .frame(width: size, height: size * 210 / 200)
        .offset(y: perk ? -3 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.6), value: perk)
        .contentShape(Rectangle())
        .onHover { perk = $0 }
        .accessibilityHidden(true)
        .onAppear(perform: startIdle)
        .onDisappear { blinkTimer?.invalidate() }
    }

    private func startIdle() {
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { wag = true }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { sway = true }
        withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) { tilt = true }
        blinkTimer?.invalidate()
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 3.8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.08)) { blinkClosed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.10)) { blinkClosed = false }
            }
        }
    }

    private func shape(_ part: Part) -> PuppyPath { PuppyPath(part: part) }
}

// MARK: - Geometry (drawn in a 200×210 design space, scaled to the view).

private enum Part {
    case tail, body, chest, pawL, pawR, earL, earR, head, muzzle
    case eyeL, eyeR, hlL, hlR, nose, mouth, tongue
}

private struct PuppyPath: Shape {
    let part: Part

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 200 * rect.width, y: rect.minY + y / 210 * rect.height)
        }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
            Path { $0.addEllipse(in: CGRect(x: rect.minX + (cx - rx) / 200 * rect.width,
                                            y: rect.minY + (cy - ry) / 210 * rect.height,
                                            width: 2 * rx / 200 * rect.width,
                                            height: 2 * ry / 210 * rect.height)) }
        }
        var path = Path()
        switch part {
        case .tail:
            path.move(to: p(150, 150))
            path.addQuadCurve(to: p(180, 110), control: p(184, 144))
            path.addQuadCurve(to: p(164, 96),  control: p(178, 94))
            path.addQuadCurve(to: p(164, 122), control: p(174, 108))
            path.addQuadCurve(to: p(138, 136), control: p(156, 134))
            path.closeSubpath()
        case .body:
            path.move(to: p(58, 200))
            path.addQuadCurve(to: p(100, 130), control: p(52, 136))
            path.addQuadCurve(to: p(142, 200), control: p(148, 136))
            path.closeSubpath()
        case .chest:
            path.move(to: p(82, 200))
            path.addQuadCurve(to: p(100, 154), control: p(80, 158))
            path.addQuadCurve(to: p(118, 200), control: p(120, 158))
            path.closeSubpath()
        case .pawL: return ellipse(80, 196, 13, 9)
        case .pawR: return ellipse(120, 196, 13, 9)
        case .earL:
            path.move(to: p(62, 60))
            path.addQuadCurve(to: p(38, 116), control: p(32, 66))
            path.addQuadCurve(to: p(62, 134), control: p(42, 138))
            path.addQuadCurve(to: p(74, 72),  control: p(54, 94))
            path.closeSubpath()
        case .earR:
            path.move(to: p(138, 60))
            path.addQuadCurve(to: p(162, 116), control: p(168, 66))
            path.addQuadCurve(to: p(138, 134), control: p(158, 138))
            path.addQuadCurve(to: p(126, 72),  control: p(146, 94))
            path.closeSubpath()
        case .head:   return ellipse(100, 92, 46, 46)
        case .muzzle: return ellipse(100, 112, 30, 24)
        case .eyeL:   return ellipse(82, 86, 7.5, 9.5)
        case .eyeR:   return ellipse(118, 86, 7.5, 9.5)
        case .hlL:    return ellipse(84.5, 82.5, 2.6, 2.6)
        case .hlR:    return ellipse(120.5, 82.5, 2.6, 2.6)
        case .nose:
            path.move(to: p(100, 100))
            path.addQuadCurve(to: p(91, 107),  control: p(91, 100))
            path.addQuadCurve(to: p(100, 115), control: p(91, 114))
            path.addQuadCurve(to: p(109, 107), control: p(109, 114))
            path.addQuadCurve(to: p(100, 100), control: p(109, 100))
            path.closeSubpath()
        case .mouth:
            path.move(to: p(100, 115)); path.addQuadCurve(to: p(85, 119), control: p(93, 123))
            path.move(to: p(100, 115)); path.addQuadCurve(to: p(115, 119), control: p(107, 123))
        case .tongue:
            path.move(to: p(93, 117))
            path.addQuadCurve(to: p(107, 117), control: p(100, 133))
            path.closeSubpath()
        }
        return path
    }
}
