import Foundation

// Text normalisation shared by every search: same rules as the web app (src/assistant/search.ts), so
// both give the same results for the same question.

private let stopWords: Set<String> = Set("""
le la les un une des de du d l au aux et ou en a à est sont il elle on je tu vous nous ce cet cette ces que qui quoi
quel quelle quels quelles dans sur sous pour par avec sans ne pas plus moins se sa son ses leur leurs y si mais
comme quand comment pourquoi peux veux puis qu elles ils ont mon ma mes ton ta tes notre votre entre vers chez lors dont ainsi afin est-ce faut peut doit dois puis-je ai as avez être avoir fait faire très tout tous
""".split(whereSeparator: \.isWhitespace).map(String.init))

/// Lower-case, accent-free search words, without stop words, with plurals and "-ement" nouns folded.
public func tokens(_ text: String) -> [String] {
    let folded = text.folding(options: .diacriticInsensitive, locale: nil).lowercased()
    var words: [String] = []
    var current = String.UnicodeScalarView()
    for scalar in folded.unicodeScalars {
        if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
            current.append(scalar)
        } else if !current.isEmpty {
            words.append(String(current))
            current = String.UnicodeScalarView()
        }
    }
    if !current.isEmpty { words.append(String(current)) }
    return words
        .filter { $0.count > 1 && !stopWords.contains($0) }
        .map { $0.count > 4 && ($0.hasSuffix("s") || $0.hasSuffix("x")) ? String($0.dropLast()) : $0 }
        // "dépassement" and "dépasser" (or "stationnement" / "stationner") are the same idea.
        .map { $0.count > 8 && $0.hasSuffix("ement") ? String($0.dropLast(5)) + "er" : $0 }
}

/// Words a learner may use for the same idea; a query word also looks for the others in its group.
private let synonyms = [
    "vitesse limitation limite maximale km/h",
    "ville agglomération urbain urbaine localité village",
    "alcool alcoolémie alcoolisé boisson ivresse ivre",
    "priorité céder cédez passage",
    "stop arrêt arrêter immobilisation",
    "stationnement stationner garer garé parking",
    "feu feux sémaphore rouge vert orange clignotant",
    "piéton trottoir",
    "ceinture attaché bouclé",
    "téléphone portable mobile smartphone",
    "permis licence conducteur novice jeune nouveau",
    "accident collision blessé",
    "dépasser dépassement doubler",
    "carrefour intersection croisement rond-point giratoire",
    "panneau signal signalisation",
    "moto motocycle scooter motard casque",
    "vélo bicyclette cycliste",
    "camion poids lourd",
    "amende sanction contravention points pénalité infraction",
    "distance sécurité espacement écart intervalle suivre derrière",
    "voiture véhicule automobile auto",
    "nuit éclairage phare croisement lumière",
    "frein freinage",
    "autoroute voie rapide",
    "enfant mineur siège gosse gosses gamin môme mioche bébé petit",
    "conduire conduit conduis conduisez conduira conduisant conduite rouler roule roules roulez roulant circuler circule piloter",
    "conducteur chauffeur automobiliste",
    "bus autobus car",
    "mettre poser placer installer disposer",
    "triangle signalisation",
    "phare feux route croisement éblouir éblouissement code",
    "griller brûler franchir ignorer passer feu",
    "ambulance pompier pompiers police policier gyrophare sirène urgence prioritaire secours",
    "papiers documents identité attestation passeport",
    "prêter prête prêtes prêtent prêté laisser laisse autoriser autorise autorisé permettre permet confier emprunter",
    "âge ans année",
    "taux concentration seuil limite maximum niveau mesure",
    "verre bière vin whisky alcool boire boit bois bu boisson ivresse ivre alcoolémie souffler éthylotest",
    "tel téléphoner téléphone portable mobile appel appeler sms message répondre",
    "pote potes copain copains ami amis passager passagers",
    "perdre perd perte retirer retire retrait retiré déchéance déchu suspendre suspendu suspension annuler",
    "coller colle collé talonner serrer proche distance",
    "accotement bas-côté bande urgence",
    "devant avant",
    "pneu pneus lisse lisses usé usure profondeur rainure sculpture",
    "côte pente montée descente colline",
    "risque risquer passe sanction peine puni punit punir prison amende encourt grave",
]

/// For each search word, every word of the groups it belongs to (in first-seen order).
let groups: [String: [String]] = {
    var map: [String: [String]] = [:]
    for line in synonyms {
        let group = tokens(line).uniqued()
        // A word in several groups gets all of them ("feux" is both a traffic light and a headlight).
        for t in group { map[t] = ((map[t] ?? []) + group).uniqued() }
    }
    return map
}()

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array {
    /// Sorted by descending key; ties keep their original order (like JavaScript's stable sort).
    func stableSorted(byDescending key: (Element) -> Double) -> [Element] {
        enumerated()
            .map { (offset: $0.offset, element: $0.element, key: key($0.element)) }
            .sorted { $0.key != $1.key ? $0.key > $1.key : $0.offset < $1.offset }
            .map(\.element)
    }
}

/// A compiled regular expression (ICU syntax), usable from any thread.
struct Pattern: @unchecked Sendable {
    let regex: NSRegularExpression

    init(_ pattern: String, caseInsensitive: Bool = true) {
        regex = try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
    }

    func test(_ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Text of capture group `group` (0 = whole match) for every match.
    func matches(in text: String, group: Int = 0) -> [String] {
        regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: group), in: text).map { String(text[$0]) }
        }
    }

    func firstMatchRange(in text: String) -> Range<String.Index>? {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)).flatMap { Range($0.range, in: text) }
    }

    func replacing(in text: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }
}

/// A number with its unit (240 microgrammes, 50 km/h, 3 ans…), unlike list numbers such as "(3a)".
let hasFigure = Pattern(#"\d+(?:[.,]\d+)?\s*(?:km|kg|m\b|mètres?|heures?|minutes?|secondes?|ans?\b|jours?|mois|%|cm|mm|microgrammes?|milligrammes?|livres|passagers|points)"#)

/// Words of a question whose answer is a figure (a rate, a limit, an age, a duration…).
let asksFigure = Pattern(#"combien|taux|seuil|limite|maxim|minim|(?<!\p{L})âge(?!\p{L})|dur[ée]e|distance|vitesse|poids"#)

let otherVehicles = Pattern(#"commercial|autobus|tracteur|\blent|travail|excursion|machine mobile|quad|camion|\bmoto|taxi"#)

let vehicleKinds = [
    #"\bmoto|scooter|motocycl"#, #"\bquad|tout-terrain"#, "tracteur", "camion|poids lourd",
    #"\bbus\b|autobus|\bcar\b"#, "v[ée]lo|bicyclette|cycliste", "taxi", "ambulance|pompier",
].map { Pattern($0) }

/// Removes trailing dots and spaces.
func trimEnd(_ text: String) -> String {
    var t = Substring(text)
    while let last = t.last, last == "." || last.isWhitespace { t = t.dropLast() }
    return String(t)
}

/// Ends a sentence with a dot unless it already ends with punctuation.
func sentence(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return [".", "!", "?", "…"].contains(where: t.hasSuffix) ? t : t + "."
}

/// What the learner is asking for, which decides how an answer opens.
public enum QuestionKind: String, Sendable {
    case why, remember, figure, definition, permission, who, when, how, other
}

private let kindPatterns: [(QuestionKind, Pattern)] = [
    (.why, Pattern(#"(?<!\p{L})pourquoi(?!\p{L})|pour quelle raison"#)),
    (.remember, Pattern(#"retenir|mémoriser|astuce|moyen (?:simple )?de"#)),
    // Before "definition": "c'est quoi la vitesse max" asks for a figure.
    (.figure, asksFigure),
    (.definition, Pattern(#"c['’]est quoi|qu['’]est[- ]ce (?:que|qu['’])|que (?:signifie|veut dire)|définition"#)),
    (.permission, Pattern(#"(?<!\p{L})(?:peut[- ]on|peut[- ]il|puis[- ]je|ai[- ]je le droit|a[- ]t[- ]on le droit|faut[- ]il|dois[- ]je|doit[- ]on|est[- ]il (?:permis|autorisé|interdit)|est[- ]ce (?:que|permis|autorisé|interdit)|je peux|on peut|j['’]ai le droit|c['’]est (?:permis|autorisé|interdit|légal))(?!\p{L})"#)),
    (.who, Pattern(#"^\s*(?:et )?qui(?!\p{L})"#)),
    (.when, Pattern(#"(?<!\p{L})quand(?!\p{L})|à partir de quand|dans quel cas"#)),
    (.how, Pattern(#"^\s*comment(?!\p{L})"#)),
]

public func questionKind(_ text: String) -> QuestionKind {
    kindPatterns.first { $0.1.test(text) }?.0 ?? .other
}

/// What a model is told about the kind of answer expected, so it answers the question as it was asked.
public func kindHint(_ kind: QuestionKind) -> String {
    switch kind {
    case .why: "l'élève demande la raison : commence par la raison, avec les mots des sources."
    case .remember: "l'élève veut retenir la règle : résume-la en une seule phrase courte et facile à mémoriser, commençant par « À retenir : », sans rien ajouter aux sources."
    case .figure: "l'élève veut une valeur : commence par ce chiffre, tel qu'il est dans les sources."
    case .definition: "l'élève veut une définition : donne-la en une phrase, avec les mots des sources."
    case .permission: "l'élève demande si c'est permis : énonce la règle des sources qui répond, sans conclure au-delà de ce qu'elles disent."
    case .who: "l'élève demande « qui » : commence par la personne ou l'autorité désignée dans les sources."
    case .when: "l'élève demande « quand » : commence par la condition ou le moment indiqué dans les sources."
    case .how: "l'élève demande « comment » : commence par la manière indiquée dans les sources."
    case .other: ""
    }
}

private let illustrationRequest = Pattern(#"(?<!\p{L})(?:exemples?|concret|imaginons|imagine|analogie|métaphore|scénario|mise en situation|vulgaris\p{L}*|explication imagée|eli5|comme (?:un|une|à un|à une) (?:enfant|gamin|bébé|débutant|petit)|(?:pour|à) un enfant|comme si j['’]avais \d+ ans)(?!\p{L})"#)

/// The learner wants an example or an image ("donne-moi un exemple", "explique-moi comme à un enfant"):
/// the answer may then contain a clearly labelled invented example.
public func asksForIllustration(_ text: String) -> Bool { illustrationRequest.test(text) }

/// The message without the words that only ask for an example or an image, so that "comme si j'avais 5 ans"
/// is not searched for as if it were a subject.
public func withoutIllustrationWords(_ text: String) -> String {
    illustrationRequest.replacing(in: text, with: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
}
