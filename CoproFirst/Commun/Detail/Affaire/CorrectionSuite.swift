// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un geste sur UNE entrée de l'Historique (#91, #93). L'ORDRE est celui du site
/// (`RubriqueHistorique.svelte`) : ✏️ puis 🗑️, l'irréversible en dernier.
enum GesteSuite: String, CaseIterable, Identifiable, Sendable {
    case modifier, supprimer

    var id: String { rawValue }

    var libelle: String {
        switch self {
        // Le titre de la boîte qui corrige une Suite (`SUITE.libelleModifier` du site).
        case .modifier: "Modifier la suite"
        case .supprimer: TextesSuite.supprimer
        }
    }

    var symbole: String {
        switch self {
        case .modifier: "pencil"
        case .supprimer: "trash"
        }
    }

    /// Les gestes offerts sur cette entrée : ceux que le serveur a servis AVEC elle
    /// (`DroitsServisSuite`), et aucun autre — sans droit servi, l'Historique se lit sans
    /// geste, comme avant.
    static func offerts(pour suite: SuiteAffaire) -> [GesteSuite] {
        allCases.filter { geste in
            switch geste {
            case .modifier: suite.droits.modifier
            case .supprimer: suite.droits.supprimer
            }
        }
    }
}

/// Les mots des gestes d'une entrée, ceux du site (`RubriqueHistorique.svelte`,
/// `affaires-en-liste.ts`), écrits une fois.
enum TextesSuite {
    /// Le bouton « ⋯ » d'une entrée, pour VoiceOver.
    static let gestes = "Actions sur cette entrée"
    static let supprimer = "Supprimer cette entrée"
    static let confirmer = "Supprimer"
    static let corrigee = "Entrée corrigée"
    static let supprimee = "Entrée supprimée"
    static let indisponible = "Ce geste n'est pas disponible ici."
    /// Le titre de la feuille : le mot du geste — « Modifier la suite » se tronquait
    /// entre « Annuler » et « Enregistrer », comme « Ajouter une suite » (`SUITE.court`).
    static let titreCorrection = "Modifier"
    static let etatDonne = "L'entrée porte ce changement d'état, à sa date."
    static let etatDAvant = "L'état d'avant l'entrée : elle reste un commentaire."

    /// La question posée avant d'effacer : ce qui disparaît, et ce qui ne change pas.
    static func question(_ suite: SuiteAffaire) -> String {
        "L’entrée du \(FormatsDuSite.date(suite.date)) disparaît du fil. L’état de l’affaire ne change pas."
    }
}

/// Ce que « Modifier la suite » envoie (PATCH /tickets/{id}/evolutions/{evol_id}) : les
/// SEULS champs que la saisie a changés. Un champ resté `nil` n'est pas envoyé, donc pas
/// réécrit — ni les pièces jointes ni le lieu de l'entrée, que la feuille ne montre pas.
struct CorrectionSuite: Hashable, Sendable {
    /// Le texte corrigé, écrit comme l'éditeur du site ; vide : l'entrée n'en a plus.
    var contenuHTML: String?
    /// Le Suivi corrigé ; `nil` : l'entrée garde le sien.
    var suivi: Suivi?

    /// Ce que l'entrée devient : un changement d'état (`etat`, et l'état qu'elle donne),
    /// ou un commentaire — revenir à l'état d'avant l'entrée la ramène à un commentaire
    /// (`typeDeLEntree` du site, arbitré le 01/10/2026).
    struct Suivi: Hashable, Sendable {
        let type: String
        let statut: String?
    }

    /// Rien n'a changé : « Enregistrer » reste éteint.
    var vide: Bool { self == CorrectionSuite() }
}

extension SuiteAffaire {
    /// Le texte de l'entrée en texte simple, si le réenregistrer ne perd rien
    /// (`TexteDuSite.saisi(html:)`) — sinon `nil` : il se montre sans se modifier.
    var contenuSaisi: String? { TexteDuSite.saisi(html: contenu ?? "") }
}

extension SaisieSuite {
    /// La saisie de « Modifier la suite » : l'entrée telle que le serveur la sert. Le
    /// Suivi part de l'état qu'elle a donné ; l'état « courant » est celui d'AVANT elle,
    /// que le serveur calcule (`ancien_statut` d'une transition, sinon `statut_avant` :
    /// `SuiteAffaire.ancienStatut`) — à défaut, celui de l'affaire.
    init(corrigeant suite: SuiteAffaire, de affaire: DetailAffaire) {
        let avant = suite.ancienStatut ?? affaire.statut
        statutActuel = avant
        statut = suite.nouveauStatut ?? avant
        contenu = suite.contenuSaisi ?? ""
    }

    /// Le Suivi d'une entrée se corrige quand la liste des états sait le montrer : celui
    /// d'avant et celui qu'elle donne y sont. Sinon l'entrée garde le sien, et son texte
    /// seul se corrige — rien ne se réenregistre que la feuille n'a pas montré.
    func suiviCorrigeable(parmi etats: [String]) -> Bool {
        etats.contains(statutActuel) && etats.contains(statut)
    }

    /// Ce qui a changé depuis `suite` — et rien d'autre. Le texte ne part que si la feuille
    /// le montrait à modifier ; le Suivi, que si l'entrée n'en dit plus la même chose.
    func correction(depuis suite: SuiteAffaire, de affaire: DetailAffaire) -> CorrectionSuite {
        let origine = SaisieSuite(corrigeant: suite, de: affaire)
        var correction = CorrectionSuite()
        if suite.contenuSaisi != nil, texte != origine.texte {
            correction.contenuHTML = texte.isEmpty ? "" : TexteDuSite.html(saisi: texte)
        }
        let suivi = suiviDeLEntree
        if suivi != origine.suiviDeLEntree { correction.suivi = suivi }
        return correction
    }

    /// Ce que l'entrée dit de l'état : une transition vers l'état choisi, ou rien.
    private var suiviDeLEntree: CorrectionSuite.Suivi {
        changeEtat ? .init(type: "etat", statut: statut) : .init(type: "commentaire", statut: nil)
    }

    /// Prête à partir : ce qu'une Suite exige (un état donné, ou un texte — celui que la
    /// feuille montre sans le modifier compte), et un changement.
    func prete(depuis suite: SuiteAffaire, de affaire: DetailAffaire) -> Bool {
        (changeEtat || !texte.isEmpty || suite.contenuSaisi == nil) && !correction(depuis: suite, de: affaire).vide
    }
}
