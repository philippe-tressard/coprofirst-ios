// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Les gestes du bandeau sur l'API simulée : les affaires inventées
/// (`ServiceSimule.affaires(_:)`) changent comme le serveur les changerait, le temps
/// de la session — une réponse rejoint le fil des messages, une suite l'Historique,
/// l'archivage retire 📦.
extension ServiceSimule: ServiceGestesAffaire {
    /// « Répondre » (`ServiceCoproFirst`) : un message du compte simulé, que le serveur
    /// double d'une suite « reponse » portant son texte (`add_message`, `messages.py`).
    func repondre(_ texte: String, a affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        let contenu = TexteDuSite.html(saisi: texte)
        try changerAffaireSimulee(affaire) { detail in
            guard !detail.fusionnee else {
                throw ErreurService.refus(
                    .init(phrase: "Cette affaire a été fusionnée : son suivi se poursuit dans l'affaire principale"))
            }
            detail.messages.append(
                MessageAffaire(
                    id: (detail.messages.map(\.id).max() ?? 500) + 1, contenu: contenu, date: .now, deMoi: true,
                    qualite: nil, interne: false, photos: []))
            detail.suites.append(
                SuiteAffaire(
                    id: (detail.suites.map(\.id).max() ?? 0) + 1, type: "reponse", date: .now,
                    auteur: "Camille Essai", contenu: contenu, ancienStatut: nil, nouveauStatut: nil, photos: []))
        }
    }

    func ajouterSuite(_ suite: SaisieSuite, a affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        try changerAffaireSimulee(affaire) { detail in
            guard detail.droits.changerEtat else { throw ErreurService.refus(.init(phrase: "Action non autorisée")) }
            detail.suites.append(
                SuiteAffaire(
                    id: (detail.suites.map(\.id).max() ?? 0) + 1, type: suite.type, date: .now,
                    auteur: "Le conseil syndical",
                    contenu: suite.texte.isEmpty ? nil : TexteDuSite.html(saisi: suite.texte),
                    ancienStatut: suite.changeEtat ? detail.statut : nil,
                    nouveauStatut: suite.changeEtat ? suite.statut : nil, photos: []))
            detail.statut = suite.statut
        }
    }

    func enregistrer(_ edition: EditionAffaire, de affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        let lieux = try FixturesPerimetres.lus()
        try changerAffaireSimulee(affaire) { detail in
            guard detail.droits.modifier else { throw ErreurService.refus(.init(phrase: "Accès refusé")) }
            detail.titre = edition.titre ?? detail.titre
            detail.description = edition.descriptionHTML ?? detail.description
            detail.categorie = edition.categorie ?? detail.categorie
            detail.urgente = edition.urgente ?? detail.urgente
            if let codes = edition.perimetres {
                // Sans lieu, le serveur pose le défaut qu'il désigne.
                let code = codes.first ?? Perimetre.codeParDefaut(lieux)
                detail.perimetres = code.map { [$0] } ?? []
                detail.lieu = lieux.first { $0.code == code }?.libelle
            }
        }
    }

    func regler(
        _ option: OptionAffaire, active: Bool, de affaire: Int, dans installation: Installation
    ) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try changerAffaireSimulee(affaire) { detail in
            if option.cle == "epingle" { detail.epingle = active } else { detail.urgente = active }
        }
    }

    func archiverAffaire(_ affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try changerAffaireSimulee(affaire) { $0.archivee = true }
    }

    /// Au premier usage, aucune affaire n'a encore changé.
    private static func aucuneChangee() -> [Int: DetailAffaire] { [:] }

    /// L'affaire telle que la session l'a laissée — ou telle qu'inventée, au premier usage.
    func detailSimule(_ id: Int) throws -> DetailAffaire {
        try changerAffaireSimulee(id) { _ in }
    }

    @discardableResult
    private func changerAffaireSimulee(
        _ id: Int, _ geste: (inout DetailAffaire) throws -> Void
    ) throws -> DetailAffaire {
        let conseil = DroitsOnglet(profil: profilSimule).cs
        return try modifierSimule(depuis: Self.aucuneChangee) { affaires in
            guard var detail = try affaires[id] ?? Self.affaires(id, conseil: conseil) else {
                throw ErreurService.introuvable
            }
            try geste(&detail)
            // Servis à CE compte, comme le vrai serveur : une Suite qui change l'état relit son libellé.
            detail.referentiels = try FixturesReferentielsAffaires.lus(moderateur: conseil)
            detail.statutServi = nil
            affaires[id] = detail
            return detail
        }
    }
}
#endif
