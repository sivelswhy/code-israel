import CodeIsraelKit
import SwiftUI

extension Color {
    static let ringGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let ringBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let ringOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let signRed = Color(red: 0.84, green: 0.11, blue: 0.13)
    static let signBlue = Color(red: 0.0, green: 0.36, blue: 0.75)
}

/// Activity-style concentric progress rings.
struct Rings: View {
    struct Ring: Identifiable {
        let id = UUID()
        let value: Double
        let color: Color
    }

    let rings: [Ring]
    var size: CGFloat = 120
    var stroke: CGFloat = 13
    @State private var shown = false

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.element.id) { i, ring in
                let inset = CGFloat(i) * (stroke + 3)
                Circle()
                    .stroke(ring.color.opacity(0.18), lineWidth: stroke)
                    .padding(inset + stroke / 2)
                Circle()
                    .trim(from: 0, to: shown ? max(ring.value, 0.001) : 0.001)
                    .stroke(ring.color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset + stroke / 2)
                    .animation(.spring(duration: 1.2, bounce: 0).delay(0.1 * Double(i)), value: shown)
            }
        }
        .frame(width: size, height: size)
        .onAppear { shown = true }
        .accessibilityHidden(true)
    }
}

/// Road-sign shaped glyph for each theme (circle = rule, triangle = danger, octagon = sign, car = vehicle).
struct ThemeGlyph: View {
    let category: Category
    var size: CGFloat = 40

    var body: some View {
        Group {
            switch category {
            case .rules:
                Circle().fill(Color.signBlue)
                    .overlay(Image(systemName: "arrow.up").font(.system(size: size * 0.5, weight: .heavy)).foregroundStyle(.white))
            case .safety:
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, Color.signRed)
            case .signs:
                Octagon().fill(Color.signRed)
                    .overlay(Text("STOP").font(.system(size: size * 0.24, weight: .heavy)).foregroundStyle(.white))
            case .vehicle:
                RoundedRectangle(cornerRadius: size * 0.22).fill(Color(white: 0.35))
                    .overlay(Image(systemName: "car.fill").font(.system(size: size * 0.45)).foregroundStyle(.white))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<8 {
            let angle = (Double(i) * 45 + 22.5) * .pi / 180
            let point = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// The official picture of a question; tap to enlarge.
struct QuestionPicture: View {
    let id: String
    @State private var zoomed = false

    static func image(_ id: String) -> PlatformImage? {
        Bundle.main.url(forResource: id, withExtension: "jpg", subdirectory: "Images").flatMap { PlatformImage(contentsOfFile: $0.path) }
    }

    var body: some View {
        if let image = Self.image(id) {
            Button { zoomed = true } label: {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Illustration officielle de la question, toucher pour agrandir")
            .fullScreenCoverCompat(isPresented: $zoomed) { ZoomedPicture(image: image) }
        }
    }
}

private struct ZoomedPicture: View {
    let image: PlatformImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * pinch)
                .gesture(MagnifyGesture().updating($pinch) { v, s, _ in s = v.magnification }.onEnded { scale = min(4, max(1, scale * $0.magnification)) })
                .onTapGesture(count: 2) { withAnimation(.spring) { scale = scale > 1 ? 1 : 2.5 } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.largeTitle).symbolRenderingMode(.hierarchical).foregroundStyle(.white)
            }
            .padding()
            .accessibilityLabel("Fermer")
        }
    }
}

/// A road sign picture, or its number when no picture exists.
struct SignImage: View {
    let sign: Sign?
    let number: String
    var size: CGFloat = 56

    var body: some View {
        if let asset = sign?.asset, PlatformImage.inCatalog(asset) {
            Image(asset).resizable().scaledToFit().frame(width: size, height: size)
                .accessibilityLabel("Panneau \(number)")
        } else {
            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                .overlay(Text(number).font(.caption.monospacedDigit().bold()))
                .frame(width: size, height: size)
        }
    }
}

/// One sign with its official meaning.
struct SignRow: View {
    let number: String
    let sign: Sign?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SignImage(sign: sign, number: number)
            VStack(alignment: .leading, spacing: 3) {
                Text("Panneau \(number)").font(.subheadline.weight(.semibold))
                Text(sign?.fr ?? "Signification non disponible.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// An answer, shown as its sign when the answer is a sign number.
struct AnswerText: View {
    let question: Question
    let text: String
    var revealMeaning: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        if let n = question.sign(inAnswer: text, signs: app.signs) {
            HStack(spacing: 12) {
                SignImage(sign: app.signs[n], number: n, size: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Panneau \(n)").font(.body.monospacedDigit())
                    if revealMeaning, let fr = app.signs[n]?.fr {
                        Text(fr).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text(text)
        }
    }
}



extension Category {
    /// The colour of the theme in the Parcours.
    var color: Color {
        switch self {
        case .rules: Color(red: 0.04, green: 0.35, blue: 0.83)
        case .safety: .signRed
        case .signs: .ringOrange
        case .vehicle: .ringGreen
        }
    }

    var icon: String {
        switch self {
        case .rules: "arrow.up.circle.fill"
        case .safety: "exclamationmark.triangle.fill"
        case .signs: "octagon.fill"
        case .vehicle: "car.fill"
        }
    }
}

/// Chooses between the classic home and the Parcours.
struct ModeSwitcher: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Picker("Mode", selection: $app.mode) {
            ForEach(AppMode.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Mode de l’application")
    }
}

extension Color {
    /// The colour of a lesson played perfectly.
    static let gold = Color(red: 0.96, green: 0.72, blue: 0.1)
}
