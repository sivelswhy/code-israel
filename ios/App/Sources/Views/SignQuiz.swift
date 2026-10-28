import CodeIsraelKit
import SwiftUI

/// Recognise the signs: a picture, four meanings, ten rounds. Each right answer earns an XP.
struct SignQuizView: View {
    let close: () -> Void
    @Environment(AppModel.self) private var app
    @State private var rounds: [Round] = []
    @State private var index = 0
    @State private var chosen: String?
    @State private var correct = 0
    @State private var paid = false

    struct Round { let sign: Sign; let options: [Sign] }

    private var finished: Bool { !rounds.isEmpty && index >= rounds.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: close) { Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary).frame(width: 32, height: 32) }
                    .buttonStyle(.plain).accessibilityLabel("Fermer").keyboardShortcut(.cancelAction)
                ProgressBar(value: rounds.isEmpty ? 0 : Double(index) / Double(rounds.count), color: .ringOrange)
                SoundToggle()
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if rounds.isEmpty {
                        Text("Pas assez de panneaux illustrés pour ce quiz.").foregroundStyle(.secondary)
                    } else if finished {
                        VStack(spacing: 14) {
                            TalkingMascot(mascot: .rouli, mood: correct >= 8 ? .cheer : .happy, size: 96, message: correct >= 8 ? "Quels yeux de lynx !" : "Continuez, ça vient !")
                            Text("\(correct) / \(rounds.count)").font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                            Label("+\(correct) XP", systemImage: "bolt.fill").font(.title3.weight(.bold)).foregroundStyle(Color.ringOrange)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        let round = rounds[index]
                        Text("Que signifie ce panneau ?").font(.title2.weight(.bold))
                        SignImage(sign: round.sign, number: round.sign.n, size: 150)
                            .frame(maxWidth: .infinity).padding(16).background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBackground))
                            .accessibilityLabel("Panneau \(round.sign.n)")
                        ForEach(Array(round.options.enumerated()), id: \.element.n) { n, option in
                            AnswerButton(letter: ["A", "B", "C", "D"][n], question: Question.placeholder, text: option.fr, state: state(of: option, in: round)) {
                                guard chosen == nil else { return }
                                chosen = option.n
                                let ok = option.n == round.sign.n
                                if ok { correct += 1 }
                                Haptics.answer(ok)
                                (ok ? Sound.right : Sound.wrong).play()
                            }
                            .disabled(chosen != nil)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.groupedBackground)
        // The button is an inset of the screen, so that it stays in view.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if finished || chosen != nil {
                Button { advance() } label: { Text(finished ? "Terminer" : "Continuer").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
                    .frame(maxWidth: 680).frame(maxWidth: .infinity)
                    .background(alignment: .bottom) { Color.groupedBackground.padding(.bottom, -200) }
            }
        }
        .onAppear { if rounds.isEmpty { rounds = Self.makeRounds(app.library.signs) } }
    }

    private func state(of option: Sign, in round: Round) -> AnswerButton.State {
        guard let chosen else { return .normal }
        return option.n == round.sign.n ? .correct : option.n == chosen ? .wrong : .dimmed
    }

    private func advance() {
        if finished {
            if !paid { paid = true; app.finishSignQuiz(correct: correct) }
            close()
        } else {
            chosen = nil
            index += 1
            if index >= rounds.count {
                Sound.complete.play()
            }
        }
    }

    /// Ten signs with a picture; for each, three other meanings from the same family.
    static func makeRounds(_ signs: [Sign]) -> [Round] {
        let illustrated = signs.filter { $0.asset != nil && PlatformImage.inCatalog($0.asset!) }
        return illustrated.shuffled().prefix(10).map { sign in
            var seen: Set<String> = [sign.fr]
            let others = signs.filter { $0.cat == sign.cat && $0.n != sign.n }.shuffled().filter { seen.insert($0.fr).inserted }.prefix(3)
            return Round(sign: sign, options: ([sign] + others).shuffled())
        }
    }
}

extension Question {
    /// For answer buttons that are not about a question: no picture, no sign numbers to detect.
    static let placeholder = Question(id: "", q: "", a: [], c: 0, lic: [], cat: .signs)
}
