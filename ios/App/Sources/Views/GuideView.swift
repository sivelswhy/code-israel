import CodeIsraelKit
import SwiftUI

/// Practical help around the exam: the steps in Israel, and a French ↔ Hebrew glossary of the terms of the road code.
struct GuideView: View {
    @Environment(AppModel.self) private var app
    private let guide = GuideContent.load()

    var body: some View {
        List {
            Section {
                NavigationLink { GlossaryView() } label: { Label("Glossaire français ↔ hébreu", systemImage: "character.book.closed") }
                NavigationLink { SourcesView() } label: { Label("Sources officielles et licence", systemImage: "info.circle") }
            }
            if let guide {
                ForEach(guide.sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items, id: \.self) { Text($0).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    }
                }
                Section {
                    ForEach(guide.links, id: \.url) { link in
                        if let url = URL(string: link.url) { Link(link.label, destination: url) }
                    }
                } header: {
                    Text("Pour aller plus loin")
                } footer: {
                    Text(guide.note)
                }
            }
        }
        .navigationTitle("Guide")
    }
}

struct GuideContent: Decodable {
    struct Section: Decodable { let title: String; let items: [String] }
    struct Link: Decodable { let label: String; let url: String }
    let sections: [Section]
    let links: [Link]
    let note: String

    static func load() -> GuideContent? {
        Bundle.main.url(forResource: "guide", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(GuideContent.self, from: $0) }
    }
}

/// Everyday words of the road code, in French and in Hebrew, to read the official texts and the signs.
struct GlossaryView: View {
    struct TermGroup: Decodable { let title: String; let terms: [Term] }
    struct Term: Decodable, Hashable { let fr: String; let he: String }

    @State private var query = ""
    private let groups: [TermGroup] = {
        Bundle.main.url(forResource: "glossary", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([TermGroup].self, from: $0) } ?? []
    }()

    var body: some View {
        let n = query.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        List {
            ForEach(groups, id: \.title) { group in
                let terms = group.terms.filter { n.isEmpty || $0.fr.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(n) || $0.he.contains(n) }
                if !terms.isEmpty {
                    Section(group.title) {
                        ForEach(terms, id: \.self) { term in
                            HStack {
                                Text(term.fr)
                                Spacer(minLength: 12)
                                Text(term.he).font(.title3).environment(\.layoutDirection, .rightToLeft)
                                    .accessibilityLabel("En hébreu : \(term.he)")
                            }
                        }
                    }
                }
            }
            Section {} footer: {
                Text("Traductions indicatives. Le texte officiel de l’examen et de la loi est en hébreu : c’est lui qui fait foi.")
            }
        }
        .navigationTitle("Glossaire")
        .searchable(text: $query, prompt: "Un mot, en français ou en hébreu")
    }
}

/// The cloud button of the home screens: opens the sync code of the devices. Hidden when no sync server is set up.
struct SyncButton: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if app.sync.available {
            NavigationLink { SyncView() } label: {
                Image(systemName: app.sync.code == nil ? "icloud.and.arrow.down" : "checkmark.icloud")
            }
            .accessibilityLabel(app.sync.code == nil ? "Synchroniser mes appareils" : "Synchronisation active : mes appareils")
            .help("Synchroniser mes appareils")
        }
    }
}

/// Create a sync code, or enter the code of another device.
struct SyncView: View {
    @Environment(AppModel.self) private var app
    @State private var entering = false
    @State private var text = ""
    @State private var copied = false
    @State private var email = ""
    @State private var mailing = false
    @State private var mailMessage: String?
    @State private var mailSent = false

    var body: some View {
        let sync = app.sync
        List {
            if let code = sync.code {
                Section {
                    HStack {
                        Text(code).font(.title3.monospaced().weight(.bold)).textSelection(.enabled)
                        Spacer()
                        Button(copied ? "Copié" : "Copier") { copy(code) }.buttonStyle(.bordered)
                    }
                    if sync.mailEndpoint != nil {
                        TextField("Votre adresse e-mail", text: $email)
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            #endif
                            .autocorrectionDisabled()
                        Button {
                            mailing = true
                            Task {
                                mailMessage = await sync.mailCode(to: email.trimmingCharacters(in: .whitespaces))
                                mailSent = mailMessage == nil
                                if mailSent { mailMessage = "E-mail envoyé. Pensez à regarder vos courriers indésirables." }
                                mailing = false
                            }
                        } label: {
                            HStack { Label("M’envoyer le code par e-mail", systemImage: "envelope"); if mailing { Spacer(); ProgressView() } }
                        }
                        .disabled(mailing || !email.contains("@"))
                        if let mailMessage { Text(mailMessage).font(.footnote).foregroundStyle(mailSent ? Color.secondary : Color.signRed) }
                    } else if let mail = mailURL(code) {
                        Link(destination: mail) { Label("M’envoyer le code par e-mail", systemImage: "envelope") }
                    }
                    ShareLink(item: code) { Label("Envoyer le code autrement", systemImage: "square.and.arrow.up") }
                } header: {
                    Text("Votre code")
                } footer: {
                    Text("Saisissez ce code sur vos autres appareils (« J’ai déjà un code »). Gardez-le secret : celui qui le connaît peut lire et modifier votre progression.")
                }
                Section {
                    Button { Task { await sync.now(model: app) } } label: {
                        HStack { Text("Synchroniser maintenant"); if sync.busy { Spacer(); ProgressView() } }
                    }
                    .disabled(sync.busy)
                } footer: {
                    if let error = sync.error { Text(error).foregroundStyle(Color.signRed) }
                    else if let last = sync.lastSync { Text("Dernière synchronisation : \(last.formatted(date: .omitted, time: .shortened))") }
                }
                Section {
                    Button("Arrêter la synchronisation", role: .destructive) { sync.stop() }
                } footer: {
                    Text("Votre progression reste sur cet appareil. Notez votre code pour la retrouver ailleurs.")
                }
            } else {
                Section {
                    Text("Un code secret suffit : pas de compte, pas d’e-mail, gratuit. Le même code sur le site, sur l’iPhone et sur le Mac, et la progression est la même partout.")
                        .font(.subheadline)
                }
                if entering {
                    Section("Votre code") {
                        TextField("XXXX-XXXX-XXXX-XXXX", text: $text)
                            #if !os(macOS)
                            .textInputAutocapitalization(.characters)
                            #endif
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                        Button("Rejoindre") { if sync.enable(code: text, model: app) { entering = false } }
                        Button("Annuler", role: .cancel) { entering = false; text = "" }
                    }
                } else {
                    Section {
                        Button("Créer mon code") { sync.enable(model: app) }
                        Button("J’ai déjà un code") { entering = true }
                    }
                }
                if let error = sync.error { Section { Text(error).foregroundStyle(Color.signRed) } }
            }
        }
        .navigationTitle("Synchronisation")
    }

    /// A draft e-mail with the code, that opens in the mail app: the learner chooses the address, nothing goes through our servers.
    private func mailURL(_ code: String) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Mon code de synchronisation Code Israël"),
            URLQueryItem(name: "body", value: "Votre code de synchronisation Code Israël :\n\n\(code)\n\nPour retrouver votre progression sur un autre appareil : ouvrez l’app ou le site (https://sivelswhy.github.io/code-israel/), allez dans Guide, puis « Synchroniser mes appareils » ou « J’ai déjà un code », et saisissez ce code.\n\nGardez-le secret : celui qui le connaît peut lire et modifier votre progression."),
        ]
        return c.url
    }

    private func copy(_ code: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif
        copied = true
        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
    }
}
