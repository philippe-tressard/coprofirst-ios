// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

// La saisie d'une affaire, Essentielle ou Complète (#69, coprofirst#2595) : le même
// formulaire, montré de deux façons. En Essentielle, les sections qui ne sont pas
// essentielles pour la catégorie se rangent, à leur rang, dans « Plus de détails », et
// partent à leur valeur par défaut ; ce qui part au serveur ne change pas.
//
// Rien ne se décide ici (`standards/09` §8) : le MODE est celui que le serveur calcule
// pour le compte (`UserRead.saisie_affaire_effective`), les SECTIONS celles qu'il sert
// pour chaque catégorie (`CategorieServie.sections_essentielles`).

/// Une entrée du choix du Profil (`TablesSaisie.options`, généré).
struct OptionSaisie: Hashable, Sendable {
    let code: String
    let libelle: String
    let detail: String
}

/// Le mode d'un compte, tel que le serveur le sert.
enum ModeSaisie: String, Sendable {
    case essentielle
    case complete

    /// Un mot inconnu ne range rien : la saisie reste complète, sans phrase qui mentirait.
    init?(servi: String?) {
        guard let servi else { return nil }
        self.init(rawValue: servi)
    }

    /// « Saisie essentielle » (`LIBELLE_MODE` du site).
    var libelle: String { TablesSaisie.libellesMode[rawValue] ?? rawValue }
}

/// Une section que la feuille de l'app pose, par son identifiant dans le cadre du site
/// (`TablesSaisie.sectionsAffaire`, que `SaisieAffaireTests` confronte).
enum SectionAffaire: String, CaseIterable, Sendable {
    case titre
    case nature
    case perimetre
    case description
    case miseEnAvant = "mise_en_avant"

    /// Ce que la feuille peut ranger : catégorie, titre et description sont requis pour
    /// envoyer, ils restent toujours sous les yeux. Dans l'ordre du cadre.
    static let repliables: [SectionAffaire] = [.perimetre, .miseEnAvant].sorted {
        (TablesSaisie.sectionsAffaire.firstIndex(of: $0.rawValue) ?? .max)
            < (TablesSaisie.sectionsAffaire.firstIndex(of: $1.rawValue) ?? .max)
    }
}

/// Les sections que la saisie Essentielle montre, catégorie par catégorie — servies par
/// `GET /tickets/referentiels`.
struct SectionsEssentielles: Equatable, Sendable {
    let parCategorie: [String: Set<String>]

    init(_ parCategorie: [String: [String]]) {
        self.parCategorie = parCategorie.mapValues(Set.init)
    }

    /// Les catégories servies, lues par leur type GÉNÉRÉ.
    init(servies: [Components.Schemas.CategorieServie]) {
        self.init(
            Dictionary(servies.map { ($0.code, $0.sectionsEssentielles) }, uniquingKeysWith: { premier, _ in premier }))
    }

    /// Celles d'une catégorie. Sans catégorie choisie : ce que TOUTES partagent — la base
    /// du serveur, déduite de ce qu'il sert, jamais écrite ici.
    func pour(_ categorie: String) -> Set<String> {
        if let servies = parCategorie[categorie] { return servies }
        return parCategorie.values.dropFirst().reduce(parCategorie.values.first ?? []) { $0.intersection($1) }
    }
}

/// Comment « Nouvelle affaire » se compose pour ce compte.
struct FormeDeSaisie: Equatable, Sendable {
    let mode: ModeSaisie
    /// `nil` : pas encore lues, ou illisibles — rien ne se range, puisque rien ne le justifie.
    let essentielles: SectionsEssentielles?

    /// Le groupe « Plus de détails » existe-t-il pour ce compte ?
    var range: Bool { mode == .essentielle && essentielles != nil }

    /// Les sections rangées dans « Plus de détails », dans l'ordre du cadre. Une section
    /// ÉTEINTE (`eteintes` : un bogue n'a ni lieu ni urgence) n'a pas d'objet : elle n'y
    /// entre pas, au lieu d'y paraître vide.
    func rangees(categorie: String, eteintes: Set<SectionAffaire> = []) -> [SectionAffaire] {
        guard range, let essentielles else { return [] }
        let montrees = essentielles.pour(categorie)
        return SectionAffaire.repliables.filter { !montrees.contains($0.rawValue) && !eteintes.contains($0) }
    }

    /// La phrase discrète en tête du formulaire : la saisie en cours, et où la changer.
    func phrase(rangees: Int) -> String {
        let renvoi = rangees > 0 ? " — les autres sections sont dans « Plus de détails »" : ""
        return "\(mode.libelle)\(renvoi). À changer dans votre profil."
    }

    /// « Plus de détails (1 section) ».
    static func intitule(_ nombre: Int) -> String {
        "Plus de détails (\(nombre) \(nombre > 1 ? "sections" : "section"))"
    }
}
