// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce qu'une saisie dit de ses lecteurs (`ApercuLectureEntree`, `POST /lectures/apercu`).
/// Les codes se rangent triés : deux ordres de choix sont la même saisie, et ne se
/// redemandent pas (la `cle` de `#lib/apercu-lecture` du site).
struct SaisieLecture: Hashable, Sendable {
    let categorie: String?
    let statut: String?
    let confidentiel: Bool
    let publicCible: [String]
    let perimetreCible: [String]
    let reservePerimetre: Bool

    /// Une saisie sans Destinataires choisis (`public_cible` vide) : la règle de sa nature.
    init(
        categorie: String?, statut: String? = nil, confidentiel: Bool = false, publicCible: [String] = [],
        perimetreCible: [String] = [], reservePerimetre: Bool = false
    ) {
        self.categorie = categorie
        self.statut = statut
        self.confidentiel = confidentiel
        self.publicCible = publicCible.sorted()
        self.perimetreCible = perimetreCible.sorted()
        self.reservePerimetre = reservePerimetre
    }
}

/// Ce qu'une saisie dit d'une personne (`NomSaisi`, `POST /noms/affiche`) — tel que tapé :
/// le serveur seul en fait « Prénom NOM ».
struct NomSaisi: Hashable, Sendable {
    let prenom: String
    let nom: String
}

/// L'aperçu SERVI d'une saisie non enregistrée (#129, #130, #135) : trois routes, une
/// porte. Un écran ne les appelle pas : il pose `ApercuServi`, qui porte le délai et
/// ignore les réponses périmées (`scripts/verifier-depot.sh` refuse un autre appel).
protocol ServiceApercus: Sendable {
    /// « Qui la lira » (`lecture` d'`ApercuLecture`, #129).
    func lecture(de saisie: SaisieLecture, dans installation: Installation) async throws -> Lecture
    /// Le lieu d'une sélection, en clair — même pour le périmètre par défaut (`libelle`, #130).
    func lieu(de codes: [String], dans installation: Installation) async throws -> String
    /// « Prénom NOM » (`nom_affiche`, #135) ; `""` sans prénom ni nom.
    func nomAffiche(_ saisie: NomSaisi, dans installation: Installation) async throws -> String
}

extension ServiceCoproFirst {
    /// `nil` pour un service qui ne les réalise pas : l'aperçu se tait, la saisie continue.
    var apercus: (any ServiceApercus)? { self as? any ServiceApercus }
}

extension ServiceAPI: ServiceApercus {
    func lecture(de saisie: SaisieLecture, dans installation: Installation) async throws -> Lecture {
        let corps = Components.Schemas.ApercuLectureEntree(
            categorie: saisie.categorie, confidentiel: saisie.confidentiel, perimetreCible: saisie.perimetreCible,
            publicCible: saisie.publicCible, reservePerimetre: saisie.reservePerimetre, statut: saisie.statut)
        switch try await appeler({ try await client(installation.adresse).postLecturesApercu(body: .json(corps)) }) {
        case .ok(let ok): return Lecture(try ok.body.json.lecture)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func lieu(de codes: [String], dans installation: Installation) async throws -> String {
        let corps = Components.Schemas.LibellePerimetreEntree(codes: codes)
        let sortie = try await appeler {
            try await client(installation.adresse).postPerimetresLibelle(body: .json(corps))
        }
        switch sortie {
        case .ok(let ok): return try ok.body.json.libelle
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func nomAffiche(_ saisie: NomSaisi, dans installation: Installation) async throws -> String {
        let corps = Components.Schemas.NomSaisi(nom: saisie.nom, prenom: saisie.prenom)
        switch try await appeler({ try await client(installation.adresse).postNomsAffiche(body: .json(corps)) }) {
        case .ok(let ok): return try ok.body.json.nomAffiche
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
