import SwiftUI

/// The cast of the Parcours, drawn in SwiftUI (nothing to download).
enum Mascot {
    /// A little car: the guide.
    case rouli
    /// A traffic light: its lit colour shows how the day is going.
    case feo
    /// A stop sign: shows up when something went wrong.
    case stoppy

    var name: String {
        switch self {
        case .rouli: "Rouli"
        case .feo: "Féo"
        case .stoppy: "Stoppy"
        }
    }
}

enum Mood {
    case idle, happy, cheer, sad, thinking
}

private let ink = Color(white: 0.13)

/// A character that moves: it breathes, blinks, and bounces, droops or wonders according to its mood.
struct MascotView: View {
    let mascot: Mascot
    var mood: Mood = .idle
    var size: CGFloat = 100
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Figure(mascot: mascot, mood: mood, t: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate, size: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(mascot.name)
    }
}

private struct Figure: View {
    let mascot: Mascot
    let mood: Mood
    let t: Double
    let size: CGFloat

    /// How the whole body moves: vertical jump, tilt, squash.
    private var motion: (dy: Double, tilt: Double, squash: Double) {
        switch mood {
        case .idle: (sin(t * 2.2) * 0.012, sin(t * 1.1) * 1.2, 1 + sin(t * 2.2) * 0.006)
        case .happy: (-abs(sin(t * 4.5)) * 0.07, sin(t * 4.5) * 3, 1)
        case .cheer: (-abs(sin(t * 6.5)) * 0.16, sin(t * 6.5) * 7, 1 + 0.04 * cos(t * 13))
        case .sad: (0.03, -5 + sin(t * 1.4) * 1.5, 0.97)
        case .thinking: (sin(t * 2) * 0.01, sin(t * 1.5) * 3.5, 1)
        }
    }

    /// Eyes shut for a moment every few seconds.
    private var eyesOpen: Double { t.truncatingRemainder(dividingBy: 3.6) < 0.16 ? 0.1 : 1 }

    var body: some View {
        let s = Double(size)
        let m = motion
        ZStack {
            switch mascot {
            case .rouli: Car(mood: mood, t: t, s: s, open: eyesOpen)
            case .feo: TrafficLight(mood: mood, t: t, s: s, open: eyesOpen)
            case .stoppy: StopSign(mood: mood, t: t, s: s, open: eyesOpen)
            }
            if mood == .happy || mood == .cheer { Sparkles(t: t, s: s) }
            if mood == .sad { Tear(t: t, s: s) }
        }
        .frame(width: size, height: size)
        .scaleEffect(m.squash, anchor: .bottom)
        .rotationEffect(.degrees(m.tilt), anchor: .bottom)
        .offset(y: m.dy * s)
    }
}

// MARK: Face

private struct Eyes: View {
    let mood: Mood
    let t: Double
    /// Width of the pair of eyes.
    let w: Double
    let open: Double

    var body: some View {
        HStack(spacing: w * 0.18) { eye; eye }
    }

    @ViewBuilder private var eye: some View {
        let d = w * 0.36
        if mood == .happy || mood == .cheer {
            // Happy eyes: a small arch.
            Path { p in
                p.move(to: CGPoint(x: 0, y: d * 0.55))
                p.addQuadCurve(to: CGPoint(x: d, y: d * 0.55), control: CGPoint(x: d / 2, y: -d * 0.25))
            }
            .stroke(ink, style: StrokeStyle(lineWidth: w * 0.07, lineCap: .round))
            .frame(width: d, height: d * 0.7)
        } else {
            let look: CGSize = switch mood {
            case .thinking: CGSize(width: 0.07, height: -0.08)
            case .sad: CGSize(width: 0, height: 0.07)
            default: CGSize(width: sin(t * 0.7) * 0.05, height: 0)
            }
            ZStack {
                Ellipse().fill(.white).frame(width: d, height: d * 1.15 * open)
                Circle().fill(ink).frame(width: d * 0.5).offset(x: look.width * d * 2, y: look.height * d * 2)
                    .opacity(open > 0.5 ? 1 : 0)
            }
            .frame(width: d, height: d * 1.15)
            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        }
    }
}

private struct Mouth: View {
    let mood: Mood
    let t: Double
    let w: Double
    var color: Color = ink

    var body: some View {
        let h = w * 0.5
        Group {
            switch mood {
            case .idle:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.3))
                    p.addQuadCurve(to: CGPoint(x: w, y: h * 0.3), control: CGPoint(x: w / 2, y: h * 0.95))
                }
                .stroke(color, style: StrokeStyle(lineWidth: w * 0.1, lineCap: .round))
            case .happy, .cheer:
                // An open smile; when cheering, the mouth opens and closes like someone shouting hooray.
                let open = mood == .cheer ? 1.1 + 0.35 * sin(t * 13) : 1.2
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.1))
                    p.addQuadCurve(to: CGPoint(x: w, y: h * 0.1), control: CGPoint(x: w / 2, y: h * open * 1.5))
                    p.closeSubpath()
                }
                .fill(color == .white ? Color(white: 0.2) : color)
                .overlay(alignment: .bottom) {
                    Capsule().fill(Color(red: 1, green: 0.45, blue: 0.5)).frame(width: w * 0.5, height: h * 0.22).offset(y: -h * 0.04)
                }
            case .sad:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.75))
                    p.addQuadCurve(to: CGPoint(x: w, y: h * 0.75), control: CGPoint(x: w / 2, y: -h * 0.1))
                }
                .stroke(color, style: StrokeStyle(lineWidth: w * 0.1, lineCap: .round))
            case .thinking:
                Circle().stroke(color, lineWidth: w * 0.09).frame(width: w * 0.3, height: w * 0.3)
                    .frame(width: w, height: h, alignment: .center).offset(x: w * 0.15)
            }
        }
        .frame(width: w, height: h)
    }
}

private struct Cheeks: View {
    let w: Double
    var body: some View {
        HStack(spacing: w * 0.95) {
            Circle().fill(Color(red: 1, green: 0.5, blue: 0.55).opacity(0.5)).frame(width: w * 0.2)
            Circle().fill(Color(red: 1, green: 0.5, blue: 0.55).opacity(0.5)).frame(width: w * 0.2)
        }
    }
}

// MARK: Bodies

private struct Car: View {
    let mood: Mood
    let t: Double
    let s: Double
    let open: Double

    var body: some View {
        let glow = mood == .cheer ? 0.55 + 0.45 * sin(t * 13) : mood == .sad ? 0.25 : 0.85
        ZStack {
            // Wheels.
            HStack {
                RoundedRectangle(cornerRadius: s * 0.04).fill(ink).frame(width: s * 0.14, height: s * 0.2)
                Spacer()
                RoundedRectangle(cornerRadius: s * 0.04).fill(ink).frame(width: s * 0.14, height: s * 0.2)
            }
            .frame(width: s * 0.82).offset(y: s * 0.33)
            // Body.
            RoundedRectangle(cornerRadius: s * 0.22)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 1), Color(red: 0.05, green: 0.33, blue: 0.85)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.92, height: s * 0.64).offset(y: s * 0.08)
                .shadow(color: .black.opacity(0.18), radius: s * 0.03, y: s * 0.02)
            // Windscreen, where the eyes are.
            RoundedRectangle(cornerRadius: s * 0.17)
                .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.95, blue: 1), Color(red: 0.62, green: 0.82, blue: 0.98)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.72, height: s * 0.34).offset(y: -s * 0.06)
            Eyes(mood: mood, t: t, w: s * 0.5, open: open).offset(y: -s * 0.06)
            if mood == .happy || mood == .cheer { Cheeks(w: s * 0.5).offset(y: s * 0.1) }
            Mouth(mood: mood, t: t, w: s * 0.26).offset(y: s * 0.22)
            // Headlights.
            Circle().fill(Color.yellow.opacity(glow)).frame(width: s * 0.12).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: s * 0.01))
                .offset(x: -s * 0.34, y: s * 0.2)
            Circle().fill(Color.yellow.opacity(glow)).frame(width: s * 0.12).overlay(Circle().stroke(.white.opacity(0.7), lineWidth: s * 0.01))
                .offset(x: s * 0.34, y: s * 0.2)
        }
    }
}

private struct TrafficLight: View {
    let mood: Mood
    let t: Double
    let s: Double
    let open: Double

    /// 0 red, 1 orange, 2 green: how the day is going.
    private var lit: Int {
        switch mood {
        case .sad: 0
        case .happy, .cheer: 2
        default: 1
        }
    }

    var body: some View {
        let colors = [Color(red: 0.95, green: 0.22, blue: 0.2), Color(red: 1, green: 0.62, blue: 0.1), Color(red: 0.2, green: 0.78, blue: 0.35)]
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.2).fill(Color(white: 0.2)).frame(width: s * 0.58, height: s * 0.94)
                .shadow(color: .black.opacity(0.18), radius: s * 0.03, y: s * 0.02)
            RoundedRectangle(cornerRadius: s * 0.2).stroke(Color(white: 0.32), lineWidth: s * 0.02).frame(width: s * 0.58, height: s * 0.94)
            ForEach(0..<3, id: \.self) { i in
                let on = i == lit
                let d = on ? s * 0.42 : s * 0.2
                let y = (Double(i) - 1) * s * 0.3
                ZStack {
                    Circle().fill(colors[i].opacity(on ? 1 : 0.28)).frame(width: d, height: d)
                        .shadow(color: on ? colors[i].opacity(0.7) : .clear, radius: s * 0.06)
                    if on {
                        VStack(spacing: d * 0.04) {
                            Eyes(mood: mood, t: t, w: d * 0.82, open: open)
                            Mouth(mood: mood, t: t, w: d * 0.36)
                        }
                        .offset(y: d * 0.02)
                    }
                }
                .offset(y: y + (i == 0 && lit != 0 ? -s * 0.03 : i == 2 && lit != 2 ? s * 0.03 : 0))
            }
        }
    }
}

private struct StopSign: View {
    let mood: Mood
    let t: Double
    let s: Double
    let open: Double

    var body: some View {
        ZStack {
            StopOctagon().fill(LinearGradient(colors: [Color(red: 0.95, green: 0.27, blue: 0.25), Color(red: 0.78, green: 0.1, blue: 0.12)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.92, height: s * 0.92)
                .shadow(color: .black.opacity(0.18), radius: s * 0.03, y: s * 0.02)
            StopOctagon().stroke(.white, lineWidth: s * 0.035).frame(width: s * 0.8, height: s * 0.8)
            VStack(spacing: s * 0.03) {
                Eyes(mood: mood, t: t, w: s * 0.5, open: open)
                Mouth(mood: mood, t: t, w: s * 0.24, color: .white)
                if s >= 70 { Text("STOP").font(.system(size: s * 0.13, weight: .heavy)).foregroundStyle(.white) }
            }
            .offset(y: s * 0.01)
        }
    }
}

private struct StopOctagon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = rect.width * 0.29
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}

// MARK: Effects

private struct Sparkles: View {
    let t: Double
    let s: Double

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = t * 2.4 + Double(i) * 2.1
                Image(systemName: "sparkle")
                    .font(.system(size: s * (0.14 + 0.05 * Double(i % 2))))
                    .foregroundStyle(Color.yellow)
                    .scaleEffect(0.6 + 0.5 * abs(sin(phase)))
                    .opacity(0.5 + 0.5 * abs(sin(phase)))
                    .offset(x: s * [-0.42, 0.42, 0.05][i], y: -s * [0.2, 0.3, 0.46][i])
            }
        }
    }
}

private struct Tear: View {
    let t: Double
    let s: Double

    var body: some View {
        let f = (t * 0.6).truncatingRemainder(dividingBy: 1)
        Image(systemName: "drop.fill")
            .font(.system(size: s * 0.09))
            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1))
            .opacity(1 - f * f)
            .offset(x: -s * 0.2, y: -s * 0.02 + f * s * 0.26)
    }
}

// MARK: Speech

/// A speech bubble whose tail points down to the left, towards the character that speaks.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12), lineWidth: 1.5))
            .overlay(alignment: .bottomLeading) {
                Rectangle().fill(Color.cardBackground).frame(width: 12, height: 12).rotationEffect(.degrees(45))
                    .overlay(Rectangle().stroke(Color.primary.opacity(0.12), lineWidth: 1.5).rotationEffect(.degrees(45)).mask(alignment: .bottom) { Rectangle().frame(height: 9) })
                    .offset(x: 22, y: 6)
            }
            .frame(maxWidth: 280, alignment: .leading)
    }
}

/// A character you can tap: it reacts, then tells something taken from the official explanations.
struct TalkingMascot: View {
    let mascot: Mascot
    var mood: Mood = .idle
    var size: CGFloat = 90
    /// What it says on its own.
    var message: String?
    /// True when the bubble must not take any room: it floats above the character instead of pushing the layout
    /// around (on the path, a tip would otherwise change the spacing between the lesson buttons).
    var floating = false
    var bubbleAlignment: Alignment = .topLeading
    @Environment(AppModel.self) private var app
    @State private var reaction: Mood?
    @State private var tip: String?
    @State private var reset: Task<Void, Never>?

    var body: some View {
        let text = tip ?? message
        Group {
            if floating {
                character
                    .overlay(alignment: bubbleAlignment) {
                        if let text {
                            SpeechBubble(text: text)
                                .frame(width: 190, alignment: bubbleAlignment == .topTrailing ? .trailing : .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                // The bubble sits just above the character.
                                .alignmentGuide(.top) { $0[.bottom] + 6 }
                                .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
                                .id(text)
                        }
                    }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let text {
                        SpeechBubble(text: text)
                            .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
                            .id(text)
                    }
                    character
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: text)
    }

    private var character: some View {
        Button(action: poke) { MascotView(mascot: mascot, mood: reaction ?? mood, size: size) }
            .buttonStyle(.plain)
            .accessibilityHint("Touchez pour une astuce")
    }

    private func poke() {
        Haptics.answer(true)
        Sound.tap.play()
        reaction = .cheer
        tip = app.tip()
        reset?.cancel()
        reset = Task {
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { reaction = nil }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { tip = nil }
        }
    }
}

/// Every character in every mood. Shown instead of the app with `-mascotGallery 1` on the command line.
struct MascotGallery: View {
    private let moods: [(String, Mood)] = [("Au repos", .idle), ("Content", .happy), ("Ravi", .cheer), ("Triste", .sad), ("Réfléchit", .thinking)]

    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 28, verticalSpacing: 18) {
                GridRow {
                    Text("")
                    ForEach([Mascot.rouli, .feo, .stoppy], id: \.name) { Text($0.name).font(.title3.weight(.bold)) }
                }
                ForEach(moods, id: \.0) { label, mood in
                    GridRow {
                        Text(label).font(.subheadline).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                        MascotView(mascot: .rouli, mood: mood, size: 120)
                        MascotView(mascot: .feo, mood: mood, size: 120)
                        MascotView(mascot: .stoppy, mood: mood, size: 120)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.groupedBackground)
    }
}
