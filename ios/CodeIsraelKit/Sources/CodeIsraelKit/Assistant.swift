import Foundation

/// The rules every model follows, whichever runs it (Apple Intelligence or Qwen).
public enum AssistantPrompt {
    public static let system = """
    Tu es un moniteur d'auto-école qui prépare des francophones à l'examen théorique du code de la route en Israël.
    Règles absolues :
    - Réponds uniquement à partir des SOURCES fournies (questions officielles, explications, références légales). N'invente jamais un article, un chiffre ou une règle.
    - Utilise uniquement la source qui répond directement à la question posée et ignore les autres, même si elles parlent d'un sujet voisin. Ne mélange jamais des règles de sources différentes.
    - Si aucune source ne répond précisément à la question, réponds seulement « Je n'ai pas trouvé cette information dans les sources » et propose de reformuler (ne devine pas). Le silence des sources ne prouve jamais qu'une chose est permise, interdite ou sans conséquence : ne conclus jamais « non » ou « ce n'est pas grave » faute de source.
    - Reprends les mots des sources sans rien interpréter. Ne commence jamais par « oui » ou « non » : énonce d'abord la règle des sources, puis seulement ensuite la conclusion si elle en découle directement.
    - Quand tu t'appuies sur une règle, cite la référence telle qu'elle apparaît dans les sources (par exemple « Règlement de la circulation, art. 47(d) »).
    - Chaque chiffre, unité ou numéro de panneau que tu écris doit apparaître tel quel dans les SOURCES. N'ajoute aucune condition, exception ou catégorie de véhicule qui n'y figure pas.
    - Réponds directement à ce que l'élève demande : ne répète jamais sa question, commence par la réponse en une phrase (la raison, le chiffre, la personne, le moment ou la manière demandés), puis cite seulement la référence de l'article, sans recopier son texte.
    - Réponds en français clair, en 80 mots maximum, avec des phrases courtes.
    """

    public static func user(question: String, sources: String) -> String {
        "SOURCES :\n\(sources)\n\nQUESTION DE L'ÉLÈVE :\n\(question)"
    }
}

/// A question the learner is asking about (from a quiz or a correction).
public struct AssistantTopic: Hashable, Sendable {
    public let question: Question
    /// Answer the learner picked, if any.
    public let chosen: Int?

    public init(question: Question, chosen: Int? = nil) {
        self.question = question
        self.chosen = chosen
    }

    public var wasWrong: Bool { chosen.map { $0 != question.c } ?? false }

    public var suggestions: [String] {
        [
            wasWrong
                ? "Pourquoi ma réponse « \(question.a[chosen!]) » est-elle fausse ?"
                : "Pourquoi la bonne réponse est-elle « \(question.correct) » ?",
            "Donne-moi un moyen simple de retenir cette règle.",
        ]
    }
}

/// Everything prepared for one learner message: sources, the answer composed without a model, and
/// what to send to a model if one is available.
public struct AssistantTurn: Sendable {
    /// Official questions shown as sources.
    public let hits: [Question]
    public let lawHits: [LawHit]
    /// Answer composed from the official texts only (also the fallback when a model answer is rejected).
    public let direct: String
    /// Grounding block given to the model.
    public let sourceText: String
    /// Question text given to the model.
    public let prompt: String
    /// Search query (the message, completed with the previous one for a short follow-up).
    public let query: String
    /// A remark about the learner's own results (repeated mistake, weak theme), when there is one.
    public let note: String?

    /// With no matching official source a model would improvise, so it is not asked.
    public var canUseModel: Bool { !hits.isEmpty }

    /// Whether a model answer may be shown, or must be replaced by `direct`.
    public func accepts(_ answer: String) -> Bool {
        !unsupported(answer: answer, sourceText: sourceText, query: query)
    }
}

private let followUp = Pattern(#"^\s*(et|mais|alors|donc|aussi|pareil|même|pour|avec|sans|si)(?!\p{L})"#)

/// The whole knowledge base the assistant searches, built once.
public struct AssistantBrain: Sendable {
    public let questions: QuestionIndex
    public let lawIndex: LawIndex
    public let law: [String: LawExcerpt]
    public let signs: [String: Sign]

    public init(pool: [Question], law: [LawExcerpt], signs: [Sign]) {
        questions = QuestionIndex(pool)
        lawIndex = LawIndex(law)
        self.law = Dictionary(law.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        self.signs = Dictionary(signs.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Prepares the answer to `message`. `previous` is the learner's previous message, if any.
    public func turn(for message: String, previous: String?, topic: AssistantTopic?, learner: LearnerContext? = nil) -> AssistantTurn {
        let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let focus = topic?.question
        // A follow-up ("et pour plus de 125 ?", "c'est quoi le seuil") only makes sense with the previous question.
        let continues = previous != nil && (followUp.test(clean) || tokens(clean).count <= 1)
        let query = focus.map { "\(clean) \($0.q)" } ?? (continues ? "\(previous!) \(clean)" : clean)
        let found = retrieve(questions, lawIndex, query: query)
        // Sources about another kind of vehicle than the one asked about are not an answer.
        let off = focus == nil && vehicleMismatch(query: query, best: found.hits.first, bestLaw: found.lawHits.first)
        let hits = off ? [] : found.hits
        let lawHits = off ? [] : found.lawHits
        let shown = focus.map { f in Array(([f] + hits.filter { $0.id != f.id }).prefix(4)) } ?? hits
        let direct = reply(hits: shown, law: law, signs: signs, focus: focus, chosen: topic?.chosen, lawHits: lawHits, query: query, message: clean)
        let context = topic?.wasWrong == true ? "\n(L'élève avait répondu « \(focus!.a[topic!.chosen!]) », ce qui est faux : explique d'abord en une phrase pourquoi cette réponse est fausse, puis donne la bonne règle.)" : ""
        // Only a follow-up carries the previous question; with a question in focus the focus is the context.
        let asked: String
        if focus == nil, continues, let previous {
            asked = "\(previous) (suite) \(clean)"
        } else {
            asked = clean
        }
        return AssistantTurn(
            hits: shown,
            lawHits: lawHits,
            direct: direct,
            sourceText: sources(hits: shown, law: law, focus: focus, signs: signs, lawHits: lawHits, query: query),
            prompt: asked + context + (kindHint(questionKind(clean)).isEmpty ? "" : "\nTYPE DE DEMANDE : \(kindHint(questionKind(clean)))"),
            query: query,
            note: learner.flatMap { personalNote(topic: topic, hits: shown, learner: $0) }
        )
    }
}

/// Removes reasoning blocks some models emit (`<think>…</think>`), even while still streaming.
public func visibleAnswer(_ raw: String) -> String {
    var t = raw
    while let open = t.range(of: "<think>") {
        if let close = t.range(of: "</think>", range: open.upperBound..<t.endIndex) {
            var end = close.upperBound
            while end < t.endIndex, t[end].isWhitespace { end = t.index(after: end) }
            t.removeSubrange(open.lowerBound..<end)
        } else {
            t.removeSubrange(open.lowerBound..<t.endIndex)
        }
    }
    // A tag being streamed ("<thi") is hidden until it is complete.
    if let lt = t.lastIndex(of: "<"), "</think>".hasPrefix(String(t[lt...])) || "<think>".hasPrefix(String(t[lt...])) {
        t.removeSubrange(lt..<t.endIndex)
    }
    return String(t.drop { $0.isWhitespace })
}

private let lawQuote = Pattern(#"^\s*\[?((?:Règlement|Ordonnance) de la circulation, art\. [^:\]\n]+?)\]?\s*:\s*.{120,}$"#)

/// A model sometimes pastes a whole article after its answer. A long quotation is replaced by the
/// reference alone: the text of the law stays available through the sources.
public func tidyAnswer(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
        let line = String(line)
        guard let ref = lawQuote.matches(in: line, group: 1).first else { return line }
        return "Référence : \(ref.trimmingCharacters(in: .whitespaces))."
    }.joined(separator: "\n")
}
