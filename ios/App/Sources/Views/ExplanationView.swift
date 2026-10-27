import CodeIsraelKit
import SwiftUI

/// Why the right answer is right: our explanation, the signs of the question and what the law says.
struct ExplanationView: View {
    let question: Question
    var chosen: Int?
    var startsOpen = false
    @State private var open = false
    @Environment(AppModel.self) private var app
    @Environment(\.askAssistant) private var ask

    private var wrong: Bool { chosen.map { $0 != question.c } ?? false }

    var body: some View {
        let cited = question.citedSigns(app.signs)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0)) { open.toggle() }
            } label: {
                HStack {
                    Text(wrong ? "Pourquoi ce n’est pas la bonne réponse" : "Explication et texte de loi")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).font(.footnote.weight(.semibold))
                }
                .contentShape(Rectangle())
                .padding(14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(wrong ? Color.signRed : .primary)
            .accessibilityHint(open ? "Masquer" : "Afficher")

            if open {
                VStack(alignment: .leading, spacing: 14) {
                    if wrong, let chosen {
                        VStack(alignment: .leading, spacing: 8) {
                            Label { Text(question.a[chosen]) } icon: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.signRed) }
                            Label { Text(question.correct) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ringGreen) }
                        }
                        .font(.subheadline)
                    }
                    if let e = question.e {
                        Text(e).font(.body)
                    } else if cited.isEmpty {
                        Text("Explication en cours de rédaction pour cette question.").foregroundStyle(.secondary)
                    }
                    if !cited.isEmpty {
                        Text("Les panneaux de la question").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        ForEach(cited, id: \.self) { SignRow(number: $0, sign: app.signs[$0]) }
                    }
                    if let refs = question.r, !refs.isEmpty {
                        Text("Ce que dit la loi").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        ForEach(refs, id: \.self) { ref in
                            if let excerpt = app.law[ref] { LawCard(excerpt: excerpt) } else { Text(ref).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                    if let ask {
                        Button {
                            ask(AssistantTopic(question: question, chosen: chosen))
                        } label: {
                            Label("Poser une question à l’assistant", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding([.horizontal, .bottom], 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(wrong ? Color.signRed.opacity(0.07) : Color(.secondarySystemGroupedBackground)))
        .onAppear { open = startsOpen }
    }
}

/// A law excerpt: French rendering, with the official Hebrew text on demand.
struct LawCard: View {
    let excerpt: LawExcerpt
    @State private var showHebrew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(excerpt.l).font(.subheadline.weight(.semibold))
            if let f = excerpt.f {
                Text(f).font(.callout).foregroundStyle(.primary.opacity(0.85))
            }
            Button(showHebrew ? "Masquer le texte officiel" : "Texte officiel en hébreu") {
                withAnimation { showHebrew.toggle() }
            }
            .font(.footnote)
            if showHebrew {
                Text(excerpt.x)
                    .font(.callout)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                if let url = URL(string: excerpt.u) {
                    Link("\(excerpt.src) — texte complet", destination: url).font(.footnote)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
    }
}

/// The authoritative Hebrew wording of the question.
struct HebrewOriginal: View {
    let question: Question
    var revealed: Bool
    @State private var open = false
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(open ? "Masquer l’original en hébreu" : "Afficher l’original en hébreu (texte officiel)") {
                withAnimation { open.toggle() }
            }
            .font(.footnote)
            if open {
                if let he = app.hebrew(question.id) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(he.q).font(.callout.weight(.semibold))
                        ForEach(Array(he.a.enumerated()), id: \.offset) { i, a in
                            Text("• \(a)").font(.callout)
                                .foregroundStyle(revealed && i == he.c ? Color.ringGreen : .secondary)
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                } else {
                    Text("Pas de version hébraïque pour cette question.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Opens the assistant about a question, from anywhere in the app.
private struct AskAssistantKey: EnvironmentKey {
    static let defaultValue: ((AssistantTopic) -> Void)? = nil
}

extension EnvironmentValues {
    var askAssistant: ((AssistantTopic) -> Void)? {
        get { self[AskAssistantKey.self] }
        set { self[AskAssistantKey.self] = newValue }
    }
}
