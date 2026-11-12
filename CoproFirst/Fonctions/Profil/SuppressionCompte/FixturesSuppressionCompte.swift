// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
// Les conséquences sont des phrases entières du serveur : une chaîne JSON ne se coupe pas, et
// le juge des données simulées (`verifier-fixtures.py`) lit le JSON tel qu'écrit, sans
// continuation de ligne Swift.
// swiftlint:disable line_length
/// Ce que l'API simulée sert pour la demande de suppression (#166) — en JSON, à la forme
/// de la route, lu par le type GÉNÉRÉ puis par le même branchement que le service réel.
/// Les conséquences sont celles du serveur (`CONSEQUENCES` de `utils/demande_suppression`,
/// coprofirst v3.89.0) : l'app ne les écrit nulle part ailleurs.
enum FixturesSuppressionCompte {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /auth/demande-suppression → `EtatDemandeSuppression`, sans demande en cours (la clé est absente : le
    /// contrat ne déclare pas `demande` nullable).
    static let etat = #"""
        {
          "delai_annonce_jours": 30,
          "consequences": [
            "Votre compte et vos données personnelles sont effacés : profil, liens à vos lots, badges et demandes, notifications, sessions, petites annonces, avis, délégations et mandats.",
            "Ce que vous avez écrit dans la vie collective de la résidence — affaires et leurs messages, votes, soutiens, réponses dans les échanges, documents publiés — reste, sans votre nom : il est attribué à « Ancien résident ».",
            "L'effacement est définitif. Vous pouvez retirer votre demande tant que l'administration ne l'a pas traitée.",
            "L'administration de la résidence la traite sous 30 jours au plus."
          ]
        }
        """#
    // swiftlint:enable line_length

    /// POST /auth/demande-suppression → `DemandeSuppressionRead`.
    static let demande = #"""
        {"id": 1, "statut": "ouverte", "cree_le": "2026-11-12T09:00:00", "traitee_le": null, "delai_annonce_jours": 30}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "etat", schema: "EtatDemandeSuppression", json: etat),
        Reponse(nom: "demande", schema: "DemandeSuppressionRead", json: demande),
    ]

    static func etatLu() throws -> EtatSuppressionCompte {
        EtatSuppressionCompte(try Relecture.generee(Components.Schemas.EtatDemandeSuppression.self, json: etat))
    }

    static func demandeLue() throws -> DemandeSuppressionCompte {
        DemandeSuppressionCompte(try Relecture.generee(Components.Schemas.DemandeSuppressionRead.self, json: demande))
    }
}
#endif
