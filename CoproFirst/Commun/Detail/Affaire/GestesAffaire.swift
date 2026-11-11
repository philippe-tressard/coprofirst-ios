// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une icône du bandeau d'une affaire. L'ORDRE est celui de la rangée du site
/// (`ActionsTicket.svelte`, arbitré le 18/08/2026) : 🔗 · 💬 · 🔄 · ✏️ · options · 📦.
///
/// ✏️ modifie l'AFFAIRE (décision du 10/11/2026, #91) ; corriger une suite de son
/// Historique attend que le serveur en serve le droit (coprofirst#2646).
enum GesteAffaire: String, CaseIterable, Identifiable, Sendable {
    case lien, repondre, suite, modifier, options, archiver

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .lien: "Copier le lien"
        case .repondre: "Répondre"
        case .suite: "Ajouter une suite"
        // « Modifier » tout court, comme le site : on est sur l'affaire.
        case .modifier: "Modifier"
        case .options: "Options"
        case .archiver: "Archiver"
        }
    }

    /// Le symbole SF le plus proche de l'icône du site (`IconeAction`, Lucide).
    var symbole: String {
        switch self {
        case .lien: "link"
        case .repondre: "text.bubble"
        case .suite: "arrow.triangle.2.circlepath"
        case .modifier: "pencil"
        case .options: "ellipsis.circle"
        case .archiver: "archivebox"
        }
    }

    /// Les icônes offertes à CE lecteur, dans l'ordre du site. Chaque droit est celui
    /// que le serveur sert avec l'affaire ; l'app n'en ajoute aucun, elle en retire :
    /// - 🔗 à tous : l'adresse ne donne pas plus d'accès que l'écran (`BoutonLien`) ;
    /// - 💬 au lecteur que la route accepte, sauf au conseil syndical et à
    ///   l'administration — eux suivent l'affaire par 🔄 (décision du 10/11/2026,
    ///   divergence iOS déclarée) ; jamais sur une actualité ni une affaire fusionnée
    ///   (`gesteReponse` du site) ;
    /// - ✏️ et les options au lecteur qui peut CORRIGER l'affaire (`peut_corriger`, comme
    ///   le site, #127) — l'auteur d'une affaire engagée le garde ; à défaut,
    ///   `peut_modifier` (installation antérieure au contrat 1.21.0) ;
    /// - 📦 tant que l'affaire n'est pas aux Archives.
    static func offerts(pour affaire: DetailAffaire, conseil: Bool) -> [GesteAffaire] {
        allCases.filter { geste in
            switch geste {
            case .lien: true
            case .repondre: affaire.droits.repondre && !conseil && !affaire.estActualite && !affaire.fusionnee
            case .suite: affaire.droits.changerEtat
            case .modifier, .options: affaire.droits.corriger
            case .archiver: affaire.droits.archiver && !affaire.archivee
            }
        }
    }
}

/// Une option de mise en avant (`OPTIONS_TICKET` du site) : générée avec ses mots
/// (`OptionsDuSite`) ; l'app n'y ajoute que son symbole, celui de l'icône du site.
typealias OptionAffaire = OptionsDuSite.Option

extension OptionsDuSite.Option: Identifiable {
    var id: String { cle }

    var symbole: String { cle == "epingle" ? "pin" : "bolt" }

    func active(dans affaire: DetailAffaire) -> Bool {
        cle == "epingle" ? affaire.epingle : affaire.urgente
    }

    static var toutes: [Self] { OptionsDuSite.affaire }
}

/// Ce que « Ajouter une suite » envoie : un commentaire, ou un nouvel état — garder
/// l'état courant fait de l'entrée un simple commentaire (`EvolForm` du site, R3).
struct SaisieSuite: Hashable, Sendable {
    let statutActuel: String
    var statut: String
    var contenu = ""

    init(affaire: DetailAffaire) {
        statutActuel = affaire.statut
        statut = affaire.statut
    }

    /// Les états proposés : le cycle d'une affaire (`etatsDeLaSuite` du site). Une
    /// actualité n'en a pas ici — son suivi (`SUIVI_ACTUALITE_OPTIONS`) reste au site.
    static func etats(pour affaire: DetailAffaire) -> [String] {
        affaire.estActualite ? [] : TablesAffaires.ordreDesStatuts
    }

    var changeEtat: Bool { statut != statutActuel }
    var texte: String { contenu.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Le texte est requis quand l'entrée n'apporte que lui.
    var prete: Bool { changeEtat || !texte.isEmpty }
    var type: String { changeEtat ? "etat" : "commentaire" }
}
