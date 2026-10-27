import Foundation

/// One official exam question (French text revised from the authoritative Hebrew).
public struct Question: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let q: String
    public let a: [String]
    /// Index of the correct answer in `a`.
    public let c: Int
    /// Official picture id, bundled as `Images/<id>.jpg`.
    public let img: String?
    public let lic: [String]
    public let cat: Category
    /// True when the French text was revised against the Hebrew original.
    public let rev: Bool?
    /// Explanation of the rule, in French.
    public let e: String?
    /// Legal references (keys of the law excerpts).
    public let r: [String]?

    public var correct: String { a[c] }

    public init(id: String, q: String, a: [String], c: Int, img: String? = nil, lic: [String], cat: Category, rev: Bool? = nil, e: String? = nil, r: [String]? = nil) {
        self.id = id
        self.q = q
        self.a = a
        self.c = c
        self.img = img
        self.lic = lic
        self.cat = cat
        self.rev = rev
        self.e = e
        self.r = r
    }
}

public enum Category: String, Codable, CaseIterable, Sendable {
    case rules, safety, signs, vehicle

    public var label: String {
        switch self {
        case .rules: "Code de la route"
        case .safety: "Sécurité"
        case .signs: "Panneaux"
        case .vehicle: "Connaissance du véhicule"
        }
    }

    public var hint: String {
        switch self {
        case .rules: "Priorités, vitesses, stationnement, documents"
        case .safety: "Comportement, distances, conditions difficiles"
        case .signs: "Signalisation et marquages au sol"
        case .vehicle: "Mécanique, entretien, équipements"
        }
    }
}

public enum License: String, Codable, CaseIterable, Sendable {
    case B, A
    case tractor = "1"
    case C1, C, D

    public var label: String {
        switch self {
        case .B: "Voiture (B)"
        case .A: "Moto (A)"
        case .tractor: "Tracteur (1)"
        case .C1: "Poids lourd léger (C1)"
        case .C: "Poids lourd (C)"
        case .D: "Autobus (D)"
        }
    }

    /// Licenses currently offered. The others are on hold: their questions stay in the data, but
    /// nothing in the interface exposes them. Add a case here to bring one back.
    public static let active: [License] = [.B, .A]
}

/// An excerpt of the Traffic Regulations (T) or Ordinance (P).
public struct LawExcerpt: Codable, Hashable, Sendable {
    public let ref: String
    /// French label, e.g. "Règlement de la circulation, art. 47(d)".
    public let l: String
    /// Hebrew section title.
    public let t: String
    /// Official Hebrew text.
    public let x: String
    /// French rendering, when available.
    public let f: String?
    public let src: String
    public let u: String

    public init(ref: String, l: String, t: String, x: String, f: String?, src: String, u: String) {
        self.ref = ref
        self.l = l
        self.t = t
        self.x = x
        self.f = f
        self.src = src
        self.u = u
    }
}

/// A road sign of the official chart.
public struct Sign: Codable, Hashable, Identifiable, Sendable {
    /// Number as printed in the questions, e.g. "432" or "426פ".
    public let n: String
    public let cat: String
    public let fr: String
    public let he: String?
    public let credit: String?
    public let src: String?
    /// Asset catalog image name, when a picture exists.
    public let asset: String?

    public var id: String { n }

    public init(n: String, cat: String, fr: String, he: String? = nil, credit: String? = nil, src: String? = nil, asset: String? = nil) {
        self.n = n
        self.cat = cat
        self.fr = fr
        self.he = he
        self.credit = credit
        self.src = src
        self.asset = asset
    }

    public static let categories = ["Danger", "Obligation", "Priorité", "Interdiction", "Transports en commun", "Information", "Feux", "Marquage", "Chantier"]
}
