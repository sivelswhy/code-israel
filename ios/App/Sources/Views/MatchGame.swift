import CodeIsraelKit
import SwiftUI

/// A round of the sign matching game: pick a sign, then its meaning. Five pairs, no penalty but the mistakes counted.
struct MatchGame: View {
    let seed: Int
    let close: () -> Void
    @Environment(AppModel.self) private var app
    @State private var pairs: [Sign] = []
    @State private var meanings: [Sign] = []
    @State private var picked: String?
    @State private var matched = Set<String>()
    @State private var wrong: String?
    @State private var mistakes = 0
    @State private var paid = false

    private var finished: Bool { !pairs.isEmpty && matched.count == pairs.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) { Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary).frame(width: 32, height: 32) }
                    .buttonStyle(.plain).accessibilityLabel("Fermer").keyboardShortcut(.cancelAction)
                ProgressBar(value: pairs.isEmpty ? 0 : Double(matched.count) / Double(pairs.count), color: .ringGreen)
                SoundToggle()
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TalkingMascot(mascot: .rouli, mood: finished ? .cheer : mistakes > 0 ? .thinking : .happy, size: 72,
                                  message: finished ? "Bravo ! Tous les panneaux sont associés." : "Touchez un panneau, puis son sens.")
                    Text("Associez chaque panneau à son sens").font(.title2.weight(.bold))
                    if pairs.isEmpty {
                        Text("Pas assez de panneaux illustrés pour ce jeu.").foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 10) { ForEach(pairs) { signTile($0) } }
                            .frame(width: 92)
                        VStack(spacing: 10) { ForEach(meanings) { meaningTile($0) } }
                    }
                    if finished {
                        Label("+\(JourneyRules.xpMatch) XP", systemImage: "bolt.fill").font(.title3.weight(.bold)).foregroundStyle(Color.ringOrange)
                        if mistakes > 0 { Text("\(mistakes) erreur\(mistakes > 1 ? "s" : "") : le jeu ne retire rien.").font(.footnote).foregroundStyle(.secondary) }
                        Button(action: close) { Text("Continuer").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.groupedBackground)
        .onAppear {
            pairs = app.matchRound(seed: seed)
            meanings = pairs.shuffled()
        }
    }

    private func signTile(_ sign: Sign) -> some View {
        let done = matched.contains(sign.n)
        return Button {
            guard !done else { return }
            picked = sign.n
            Sound.tap.play()
        } label: {
            SignImage(sign: sign, number: sign.n, size: 66)
                .frame(maxWidth: .infinity).padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(picked == sign.n ? Color.accentColor.opacity(0.15) : Color.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(done ? Color.ringGreen : picked == sign.n ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 2))
                .opacity(done ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Panneau \(sign.n)")
        .accessibilityAddTraits(picked == sign.n ? .isSelected : [])
    }

    private func meaningTile(_ sign: Sign) -> some View {
        let done = matched.contains(sign.n)
        let isWrong = wrong == sign.n
        return Button {
            guard !done, let current = picked else { return }
            if current == sign.n {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { _ = matched.insert(sign.n) }
                picked = nil
                if matched.count == pairs.count {
                    Sound.complete.play()
                    if !paid { paid = true; app.finishMatch() }
                } else {
                    Sound.star.play()
                }
            } else {
                mistakes += 1
                wrong = sign.n
                Sound.wrong.play()
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    wrong = nil
                }
            }
        } label: {
            HStack {
                Text(sign.fr).font(.subheadline).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ringGreen) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(isWrong ? Color.signRed.opacity(0.12) : Color.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isWrong ? Color.signRed : done ? Color.ringGreen : Color.primary.opacity(0.08), lineWidth: 2))
            .opacity(done ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }
}
