import SwiftUI

struct SourcesView: View {
    @State private var confirmReset = false
    @Environment(AppModel.self) private var app

    private let datasets = [
        ("Hébreu (texte officiel de référence)", "https://data.gov.il/dataset/tqhe"),
        ("Français", "https://data.gov.il/dataset/tqfr"),
        ("Anglais", "https://data.gov.il/dataset/tqen"),
    ]

    var body: some View {
        List {
            Section("D’où viennent les questions") {
                Text("Toutes les questions, réponses et illustrations proviennent de la banque officielle de l’examen théorique informatisé, publiée par le ministère des Transports et de la Sécurité routière de l’État d’Israël (משרד התחבורה והבטיחות בדרכים) sur le portail de données ouvertes data.gov.il.")
                ForEach(datasets, id: \.1) { name, url in
                    Link(destination: URL(string: url)!) {
                        LabeledContent(name, value: url.replacingOccurrences(of: "https://", with: ""))
                    }
                }
            }
            Section("Licence") {
                Text("Ces jeux de données sont publiés sous licence Creative Commons Attribution. Réutilisation autorisée avec mention de la source : « Ministère des Transports d’Israël — data.gov.il ».")
            }
            Section("Texte de loi") {
                Text("Les extraits du Règlement de la circulation (תקנות התעבורה) et de l’Ordonnance de la circulation (פקודת התעבורה) viennent de Wikisource en hébreu. Leur traduction française est non officielle : le texte hébreu, affiché sous chaque extrait, fait foi.")
            }
            Section("Traduction française") {
                Text("La version hébraïque fait foi : c’est celle de l’examen et la plus à jour. Les textes français de l’application ont été révisés à partir de l’original hébreu, que chaque question permet d’afficher.")
            }
            Section("Assistant") {
                Text("L’assistant fonctionne entièrement sur l’iPhone : Apple Intelligence quand l’iPhone l’a, sinon le modèle Qwen téléchargé une fois. Rien n’est envoyé sur internet. Ses réponses sont vérifiées contre les textes officiels ; en cas de doute, c’est le texte officiel qui s’affiche.")
            }
            Section("Avertissement") {
                Text("Cette application n’est ni éditée ni approuvée par le ministère des Transports. Le format d’examen simulé (30 questions, 40 minutes, 4 erreurs maximum) reprend celui de l’examen informatisé ; la répartition des thèmes est proportionnelle à la banque et peut différer du tirage réel.")
            }
            Section {
                Button("Réinitialiser ma progression", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Sources et licence")
        .confirmationDialog("Effacer toutes les réponses et examens enregistrés ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Réinitialiser", role: .destructive) { app.resetProgress() }
        }
    }
}
