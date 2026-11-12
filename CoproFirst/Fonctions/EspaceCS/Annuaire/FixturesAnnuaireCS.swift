// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// L'annuaire que l'API simulée sert à « Annuaire CS & Syndic » — le JSON de
/// `/admin/annuaire/cs` et `/admin/annuaire/syndic`, lu par les types GÉNÉRÉS puis par le
/// MÊME branchement que le service réel, et jugé contre le contrat par
/// `scripts/verifier-fixtures.py`.
///
/// Tout est inventé : des noms qui n'appartiennent à personne, des numéros de la plage
/// réservée à la fiction (01 99 00 …), des adresses `exemple.fr`.
enum FixturesAnnuaireCS {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /admin/annuaire/cs → `CompositionConseil`.
    static let conseil = #"""
        {"ag_annee": 2026, "ag_date": "2026-06-12", "whatsapp_url": "https://chat.whatsapp.com/exemple",
         "membres": [
           {"id": 31, "ordre": 0, "genre": "Mme", "prenom": "Alix", "nom": "Exemple", "nom_affiche": "Alix Exemple",
            "batiment_id": 1, "batiment_nom": "A", "etage": 2, "etage_libelle": "2ᵉ étage",
            "est_gestionnaire_site": true, "est_president": true, "photo_url": null, "user_id": 7},
           {"id": 32, "ordre": 1, "genre": "Mr", "prenom": "Basile", "nom": "Fictif", "nom_affiche": "Basile Fictif",
            "batiment_id": 1, "batiment_nom": "A", "etage": null, "etage_libelle": "",
            "est_gestionnaire_site": false, "est_president": false, "photo_url": null, "user_id": null},
           {"id": 33, "ordre": 2, "genre": "Mme", "prenom": "Céleste", "nom": "Inventé",
            "nom_affiche": "Céleste Inventé",
            "batiment_id": 2, "batiment_nom": "B", "etage": 0, "etage_libelle": "Rez-de-chaussée",
            "est_gestionnaire_site": false, "est_president": false, "photo_url": null, "user_id": 9}
         ]}
        """#

    /// GET /admin/annuaire/syndic → `InfoSyndicAdmin`.
    static let syndic = #"""
        {"nom_syndic": "Cabinet Exemple Gestion", "nom_syndic_source": "contrat",
         "adresse": "1 rue de l'Exemple, 75000 Paris", "site_web": "https://syndic.exemple.fr",
         "membres": [
           {"id": 35, "ordre": 0, "genre": "Mme", "prenom": "Désirée", "nom": "Modèle", "nom_affiche": "Désirée Modèle",
            "fonction": "Gestionnaire de copropriété", "email": "gestion@exemple.fr",
            "telephone": "01 99 00 12 34,06 99 00 12 34", "telephones": ["01 99 00 12 34", "06 99 00 12 34"],
            "est_principal": true, "photo_url": null, "user_id": null},
           {"id": 36, "ordre": 1, "genre": "Mr", "prenom": "Eudes", "nom": "Fictif", "nom_affiche": "Eudes Fictif",
            "fonction": "Comptable", "email": "compta@exemple.fr", "telephone": "01 99 00 56 78",
            "telephones": ["01 99 00 56 78"], "est_principal": false, "photo_url": null, "user_id": null}
         ]}
        """#

    /// GET /admin/annuaire/rapprochement?nom=Exemple → `Rapprochement` : l'inscrit n° 7 et
    /// son logement, l'étage en clair à la forme du serveur v3.88.1 (`etage_libelle`,
    /// contrat 1.21.0, #127). Tout autre nom ne désigne personne.
    static let rapprochementExemple = #"""
        {"user_id": 7, "batiment_id": 1, "batiment_nom": "A", "etage": 2, "etage_libelle": "2ème étage"}
        """#

    static let auDessus = AuDessusDuPlancher(schema: "Rapprochement", champs: ["etage_libelle"], contrat: "1.21.0")

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "conseil", schema: "CompositionConseil", json: conseil),
        Reponse(nom: "syndic", schema: "InfoSyndicAdmin", json: syndic),
        Reponse(nom: "rapprochementExemple", schema: "Rapprochement", json: rapprochementExemple),
    ]

    // MARK: - Lus comme le client généré les lit, branchés comme le service réel

    static func conseilLu() throws -> ConseilCS {
        ConseilCS(try Relecture.generee(Components.Schemas.CompositionConseil.self, json: conseil))
    }

    static func syndicLu() throws -> SyndicCS {
        SyndicCS(try Relecture.generee(Components.Schemas.InfoSyndicAdmin.self, json: syndic))
    }

    static func rapprochementLu(_ nom: String) throws -> Rapprochement {
        guard nom.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare("Exemple") == .orderedSame
        else { return Rapprochement() }
        return Rapprochement.lu(
            try Relecture.generee(Components.Schemas.Rapprochement.self, json: rapprochementExemple),
            corps: Data(rapprochementExemple.utf8))
    }
}
#endif
