// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// L'annuaire du conseil simulé : des prénoms et des noms qui n'appartiennent à
/// personne, des numéros de la plage réservée à la fiction (01 99 00 …), des adresses
/// `exemple.fr`. Un enregistrement numérote les fiches neuves, comme le serveur.
extension ServiceSimule: ServiceAnnuaireCS {
    private var annuaireCS: MagasinSimuleCS<AnnuaireCSSimule> {
        MagasinSimuleCS.de(self) { AnnuaireCSSimule() }
    }

    func conseil(_ installation: Installation) async throws -> ConseilCS {
        try await Task.sleep(for: .milliseconds(300))
        return annuaireCS.valeur.conseil
    }

    func enregistrer(_ conseil: ConseilCS, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(350))
        annuaireCS.modifier { annuaire in
            var conseil = conseil
            for i in conseil.membres.indices where conseil.membres[i].id == nil {
                conseil.membres[i].id = annuaire.prochainId()
            }
            annuaire.conseil = conseil
        }
    }

    func syndic(_ installation: Installation) async throws -> SyndicCS {
        try await Task.sleep(for: .milliseconds(300))
        return annuaireCS.valeur.syndic
    }

    func enregistrer(_ syndic: SyndicCS, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(350))
        annuaireCS.modifier { annuaire in
            var syndic = syndic
            for i in syndic.membres.indices where syndic.membres[i].id == nil {
                syndic.membres[i].id = annuaire.prochainId()
            }
            // Le contrat fait foi : un nom saisi ne remplace pas celui du contrat.
            if annuaire.syndic.nomDuContrat { syndic.nomSyndic = annuaire.syndic.nomSyndic }
            syndic.nomSyndicSource = annuaire.syndic.nomSyndicSource
            annuaire.syndic = syndic
        }
    }
}

/// L'annuaire inventé du conseil.
struct AnnuaireCSSimule: Sendable {
    private var dernierId = 40

    var conseil = ConseilCS(
        agAnnee: 2026, agDate: "2026-06-12", whatsappUrl: "https://chat.whatsapp.com/exemple",
        membres: [
            MembreConseil(
                id: 31, genre: "Mme", prenom: "Alix", nom: "Exemple", batimentId: 1, batimentNom: "A", etage: 2,
                estGestionnaireSite: true, estPresident: true, userId: 7),
            MembreConseil(id: 32, genre: "Mr", prenom: "Basile", nom: "Fictif", batimentId: 1, batimentNom: "A"),
            MembreConseil(
                id: 33, genre: "Mme", prenom: "Céleste", nom: "Inventé", batimentId: 2, batimentNom: "B", userId: 9),
        ])

    var syndic = SyndicCS(
        nomSyndic: "Cabinet Exemple Gestion", nomSyndicSource: "contrat", adresse: "1 rue de l'Exemple, 75000 Paris",
        siteWeb: "https://syndic.exemple.fr",
        membres: [
            MembreSyndic(
                id: 35, genre: "Mme", prenom: "Désirée", nom: "Modèle", fonction: "Gestionnaire de copropriété",
                email: "gestion@exemple.fr", telephone: "01 99 00 12 34,06 99 00 12 34", estPrincipal: true),
            MembreSyndic(
                id: 36, genre: "Mr", prenom: "Eudes", nom: "Fictif", fonction: "Comptable",
                email: "compta@exemple.fr", telephone: "01 99 00 56 78"),
        ])

    mutating func prochainId() -> Int {
        dernierId += 1
        return dernierId
    }
}
