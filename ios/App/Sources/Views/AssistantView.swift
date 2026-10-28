import CodeIsraelKit
import SwiftUI

struct AssistantView: View {
    let topic: AssistantTopic?
    @State private var conversation = Conversation()
    @State private var input = ""
    @FocusState private var focused: Bool
    @Environment(AppModel.self) private var app
    @Environment(AIEngines.self) private var engines
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss

    private var suggestions: [String] {
        topic?.suggestions ?? [
            "Quelle est la vitesse maximale en agglomération ?",
            "Qui doit céder le passage à une intersection sans panneau ?",
            "Quel est le taux d’alcool autorisé ?",
        ]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    EngineCard()
                    if let topic {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Question n° \(topic.question.id)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text(topic.question.q).font(.subheadline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
                    }
                    ForEach(conversation.messages) { message in
                        MessageView(message: message).id(message.id)
                    }
                    if conversation.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions, id: \.self) { s in
                                Button { send(s) } label: {
                                    Text(s).font(.subheadline).multilineTextAlignment(.leading)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation.messages.last?.text) {
                if let id = conversation.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
            }
        }
        .background(Color.groupedBackground)
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle("Assistant")
        #if os(macOS)
        .toolbarBackground(Color.groupedBackground, for: .windowToolbar)
        #endif
        .inlineTitle()
        .toolbar {
            if topic != nil {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            if !conversation.messages.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Effacer", systemImage: "trash") { conversation.clear() }
                }
            }
        }
        .onChange(of: phase) { if phase == .active { engines.refresh() } }
    }

    #if os(macOS)
    private static let sendIconSize: CGFloat = 28
    #else
    private static let sendIconSize: CGFloat = 34
    #endif

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Posez votre question sur le code de la route", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { send(input) }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.cardBackground))
            if conversation.isAnswering {
                Button { conversation.stop() } label: { Image(systemName: "stop.circle.fill").font(.system(size: Self.sendIconSize)) }
                    // Plain: on the Mac a button otherwise gets a large bordered frame around its icon.
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Arrêter")
            } else {
                let canSend = !input.trimmingCharacters(in: .whitespaces).isEmpty
                Button { send(input) } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: Self.sendIconSize)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(canSend ? Color.accentColor : Color.secondary.opacity(0.5))
                    .disabled(!canSend)
                    .accessibilityLabel("Envoyer")
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.bar)
    }

    private func send(_ text: String) {
        conversation.send(text, brain: app.brain, topic: topic, engines: engines, learner: LearnerContext(stats: app.progress.stats, pool: app.pool))
        input = ""
    }
}

private struct MessageView: View {
    let message: ChatMessage
    @State private var showSources = false

    var body: some View {
        if message.role == .user {
            Text(message.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.accentColor))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let note = message.note {
                    Label(note, systemImage: "person.crop.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.subtleFill))
                }
                if message.text.isEmpty && message.streaming {
                    HStack(spacing: 8) { ProgressView(); Text("Réflexion…").foregroundStyle(.secondary) }
                } else if message.text.isEmpty {
                    Text("Je n’ai rien trouvé à ce sujet dans la banque officielle. Essayez d’autres mots.").foregroundStyle(.secondary)
                } else {
                    Text(message.text).textSelection(.enabled)
                }
                if !message.streaming && !message.sources.isEmpty {
                    DisclosureGroup(isExpanded: $showSources) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(message.sources) { SourceRow(question: $0) }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("Voir les \(message.sources.count) questions officielles utilisées").font(.footnote)
                    }
                }
                if message.byModel && !message.streaming {
                    Label("Rédigé par l’IA à partir des textes officiels", systemImage: "sparkles").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.cardBackground))
            .padding(.trailing, 24)
        }
    }
}

private struct SourceRow: View {
    let question: Question
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("n° \(question.id)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text(question.q).font(.subheadline.weight(.semibold))
            Text(question.correct).font(.subheadline).foregroundStyle(Color.ringGreen)
            if let e = question.e { Text(e).font(.footnote) }
            if let refs = question.r, !refs.isEmpty {
                Text(refs.map { app.law[$0]?.l ?? $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// What powers the assistant on this iPhone, and the offer to download Qwen when needed.
private struct EngineCard: View {
    @Environment(AIEngines.self) private var engines

    var body: some View {
        if engines.current == .apple {
            note("IA Apple Intelligence active sur cet appareil : gratuite, hors ligne, rien n’est envoyé sur internet.", icon: "apple.intelligence")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                switch engines.appleStatus {
                case .disabled:
                    Text("Activez Apple Intelligence dans Réglages pour une IA intégrée, sans téléchargement.").font(.subheadline)
                case .preparing:
                    Text("Apple Intelligence se prépare sur cet appareil : l’IA sera disponible dans quelques minutes.").font(.subheadline)
                default:
                    Text("Cet appareil n’a pas Apple Intelligence. L’assistant fonctionne en mode recherche : il retrouve les questions officielles, les explications et les articles de loi.")
                        .font(.subheadline)
                }
                Text("Sans IA, l’assistant répond déjà à partir des textes officiels.").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground))
        }
    }

    private func note(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.footnote).foregroundStyle(.secondary)
    }
}
