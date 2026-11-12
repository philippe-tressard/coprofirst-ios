// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// La file de travail que l'API simulée sert à « Comptes & accès » — en JSON, à la forme
/// de ses routes, lue par les types GÉNÉRÉS puis par le MÊME branchement que le service
/// réel, et jugée contre le contrat par `scripts/verifier-fixtures.py`. La validation du
/// compte 502 rend l'avertissement du serveur : l'app doit le montrer tel quel (#55).
///
/// Tout est inventé : aucun nom de personne réelle.
enum FixturesComptesCS {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /admin/comptes-en-attente → `[UserRead]`.
    static let comptes = #"""
        [
          {"id": 501, "prenom": "Camille", "nom": "Exemple", "email": "camille.exemple@exemple.fr", "actif": false,
           "nom_affiche": "Camille EXEMPLE", "nom_aide_affiche": "", "est_moderateur": false,
           "role": "propriétaire", "statut": "copropriétaire_résident", "batiment_nom": "Bâtiment A",
           "cree_le": "2026-11-06T08:00:00", "onboarding_complete": false, "onboarding_etape": 1,
           "preferences_notifications": "{}"},
          {"id": 502, "prenom": "Dominique", "nom": "Fictif", "email": "dominique@exemple.fr", "actif": false,
           "nom_affiche": "Dominique FICTIF", "nom_aide_affiche": "", "est_moderateur": false,
           "role": "résident", "statut": "locataire", "batiment_nom": "Bâtiment B",
           "cree_le": "2026-11-07T08:00:00", "onboarding_complete": false, "onboarding_etape": 1,
           "preferences_notifications": "{}"},
          {"id": 503, "prenom": "Alix", "nom": "Modèle", "email": "alix@exemple.fr", "actif": false,
           "nom_affiche": "Alix MODÈLE", "nom_aide_affiche": "Claude FICTIF", "est_moderateur": false,
           "role": "externe", "statut": "aidant", "prenom_aide": "Claude", "nom_aide": "Fictif",
           "cree_le": "2026-11-08T07:00:00", "onboarding_complete": false, "onboarding_etape": 1,
           "preferences_notifications": "{}"}
        ]
        """#

    /// GET /admin/commandes-acces → `[CommandeAccesEnAttente]`.
    static let commandes = #"""
        [
          {"id": 71, "user_id": 31, "lot_id": 12, "type": "vigik", "quantite": 2, "statut": "en_attente",
           "demandeur_nom": "Sacha Exemple", "lot": "Lot 12 — appartement", "batiment": "Bâtiment A",
           "cree_le": "2026-11-03T10:00:00"},
          {"id": 72, "user_id": 32, "lot_id": 104, "type": "telecommande", "quantite": 1, "statut": "en_attente",
           "demandeur_nom": "Morgan Fictif", "lot": "Lot 104 — parking", "batiment": null,
           "cree_le": "2026-11-07T15:00:00"}
        ]
        """#

    /// POST /admin/comptes/{id}/traiter → `CompteTraiteResult` : un compte apparié.
    static let validation = #"""
        {"user": {"id": 501, "prenom": "Camille", "nom": "Exemple", "email": "camille.exemple@exemple.fr",
                  "nom_affiche": "Camille EXEMPLE", "nom_aide_affiche": "", "est_moderateur": false,
                  "actif": true, "role": "propriétaire", "statut": "copropriétaire_résident",
                  "cree_le": "2026-11-06T08:00:00", "onboarding_complete": false, "onboarding_etape": 1,
                  "preferences_notifications": "{}"},
         "annonce": {"ton": "success", "texte": "Compte activé — 1 lot rattaché."}}
        """#

    /// …et un compte que l'import ne connaît pas : l'avertissement du serveur.
    static let validationSansLot = #"""
        {"user": {"id": 502, "prenom": "Dominique", "nom": "Fictif", "email": "dominique@exemple.fr",
                  "nom_affiche": "Dominique FICTIF", "nom_aide_affiche": "", "est_moderateur": false,
                  "actif": true, "role": "résident", "statut": "locataire", "cree_le": "2026-11-07T08:00:00",
                  "onboarding_complete": false, "onboarding_etape": 1, "preferences_notifications": "{}"},
         "annonce": {"ton": "warning", "texte": "Compte activé. ⚠️ Aucun lot trouvé dans l'import."}}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "comptes", schema: "UserRead", json: comptes),
        Reponse(nom: "commandes", schema: "CommandeAccesEnAttente", json: commandes),
        Reponse(nom: "validation", schema: "CompteTraiteResult", json: validation),
        Reponse(nom: "validationSansLot", schema: "CompteTraiteResult", json: validationSansLot),
    ]

    // MARK: - Lues comme le client généré les lit, branchées comme le service réel

    static func comptesLus() throws -> [CompteEnAttente] {
        try Relecture.generee([Components.Schemas.UserRead].self, json: comptes).map(CompteEnAttente.init)
    }

    static func commandesLues() throws -> [CommandeEnAttente] {
        try Relecture.generee([Components.Schemas.CommandeAccesEnAttente].self, json: commandes)
            .map(CommandeEnAttente.init)
    }

    /// L'annonce que rend la validation du compte `id`.
    static func annonceDeValidation(_ id: Int) throws -> PhraseAvis? {
        let json = id == 502 ? validationSansLot : validation
        return try Relecture.generee(Components.Schemas.CompteTraiteResult.self, json: json).annonce
            .map(PhraseAvis.init)
    }
}
#endif
