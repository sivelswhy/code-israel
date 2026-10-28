import CodeIsraelKit
import SwiftUI

/// The official Israeli sign chart, with the numbers used in the exam questions.
struct SignsView: View {
    @State private var query = ""
    @Environment(AppModel.self) private var app

    var body: some View {
        let n = query.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let signs = app.library.signs.filter {
            n.isEmpty || $0.n.contains(n) || $0.fr.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(n)
        }
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
    }
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
