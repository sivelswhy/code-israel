import CodeIsraelKit
import SwiftUI

/// The official Israeli sign chart, with the numbers used in the exam questions.
struct SignsView: View {
    @State private var query = ""
    @State private var quiz = false
    @Environment(AppModel.self) private var app

    var body: some View {
        list
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { quiz = true } label: { Label("Quiz", systemImage: "questionmark.square.dashed") }
                }
            }
            .sheet(isPresented: $quiz) { SignQuizView { quiz = false }.environment(app) }
    }

    @ViewBuilder private var list: some View {
        let n = query.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let signs = app.library.signs.filter {
            n.isEmpty || $0.n.contains(n) || $0.fr.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(n)
        }
        #if os(macOS)
        macGrid(signs)
        #else
        List {
            ForEach(Sign.categories, id: \.self) { cat in
                let inCat = signs.filter { $0.cat == cat }
                if !inCat.isEmpty {
                    Section(cat) {
                        ForEach(inCat) { sign in
                            NavigationLink(value: sign) { SignRow(number: sign.n, sign: sign) }
                        }
                    }
                }
            }
            Section {
            } footer: {
                Text("Significations : tableau officiel des panneaux (ministère des Transports), via Wikipédia en hébreu. Images : Wikimedia Commons.")
            }
        }
        .navigationTitle("Panneaux")
        .searchable(text: $query, prompt: "Numéro ou mot-clé (ex. 433, stationnement)")
        .navigationDestination(for: Sign.self) { SignDetail(sign: $0) }
        #endif
    }

    #if os(macOS)
    /// On the Mac the signs are cards on a grid, as many columns as the window allows.
    private func macGrid(_ signs: [Sign]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Sign.categories, id: \.self) { cat in
                    let inCat = signs.filter { $0.cat == cat }
                    if !inCat.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cat).font(.title3.weight(.semibold))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12, alignment: .top)], spacing: 12) {
                                ForEach(inCat) { sign in
                                    NavigationLink(value: sign) { SignRow(number: sign.n, sign: sign).card() }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                Text("Significations : tableau officiel des panneaux (ministère des Transports), via Wikipédia en hébreu. Images : Wikimedia Commons.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(Color.groupedBackground)
        .navigationTitle("Panneaux")
        .searchable(text: $query, prompt: "Numéro ou mot-clé (ex. 433, stationnement)")
        .navigationDestination(for: Sign.self) { SignDetail(sign: $0) }
    }
    #endif
}

struct SignDetail: View {
    let sign: Sign

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SignImage(sign: sign, number: sign.n, size: 180).padding(.top, 20)
                Text("Panneau \(sign.n)").font(.title2.weight(.bold))
                Text(sign.cat).font(.subheadline).foregroundStyle(.secondary)
                Text(sign.fr).font(.title3).multilineTextAlignment(.center)
                if let he = sign.he {
                    Text(he).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if let credit = sign.credit {
                    Text("Image : \(credit)").font(.footnote).foregroundStyle(.secondary)
                }
                if let src = sign.src, let url = URL(string: src) {
                    Link("Source de l’image", destination: url).font(.footnote)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .inlineTitle()
    }
}
