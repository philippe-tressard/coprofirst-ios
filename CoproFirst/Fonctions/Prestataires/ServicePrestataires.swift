// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que « Prestataires » demande à une installation (#13). Réalisé par `ServiceAPI`
/// (client généré) et `ServiceSimule`, dans ce dossier.
///
/// Des gestes du conseil syndical, l'app porte les AVIS (#207) : noter, corriger son avis,
/// le retirer. Créer, corriger, archiver une fiche ou un contrat, relever un compteur
/// restent sur le site pour l'instant : l'écran le dit.
protocol ServicePrestataires: Sendable {
    /// GET /prestataires, ou /prestataires/archives.
    func prestataires(_ installation: Installation, archives: Bool) async throws -> [Prestataire]
    /// GET /prestataires/contrats, ou /prestataires/contrats/archives.
    func contrats(_ installation: Installation, archives: Bool) async throws -> [Contrat]
    /// GET /prestataires/{id}/interventions : le récapitulatif de ses avis, par exercice et
    /// par intervention (#207) — regroupé et compté par l'API.
    func interventions(de prestataire: Int, dans installation: Installation) async throws -> [ExerciceAvis]
    /// GET /prestataires/affaires-a-noter : les affaires qu'un avis peut juger, servies
    /// triées — celles où le prestataire intervient, puis les autres.
    func affairesANoter(de prestataire: Int, dans installation: Installation) async throws -> [AffaireANoter]
    /// POST /prestataires/notations : noter (le conseil syndical, `est_moderateur`).
    func noter(_ envoi: EnvoiAvis, dans installation: Installation) async throws
    /// PATCH /prestataires/notations/{id} : l'auteur corrige son avis (`peut_modifier`).
    /// L'état, le commentaire et l'affaire partent toujours, `null` compris : un avis
    /// ramené « sans affaire » le dit au serveur (il ne lit que les champs envoyés).
    func corriger(_ avis: Int, _ envoi: EnvoiAvis, dans installation: Installation) async throws
    /// DELETE /prestataires/notations/{id} : retirer un avis (le conseil syndical).
    func retirer(_ avis: Int, dans installation: Installation) async throws
    /// GET /equipements : les équipements (libellés et ordre) — des données, pas une table.
    func equipements(_ installation: Installation) async throws -> [Equipement]
    /// GET /documents?contrat_id= : les documents d'un contrat.
    func documents(contrat: Int, dans installation: Installation) async throws -> [DocumentContrat]
    /// GET /prestataires/compteurs-config : les catégories de compteurs.
    func compteurs(_ installation: Installation) async throws -> [Compteur]
    /// GET /prestataires/releves?type_compteur= : les relevés d'un compteur.
    func releves(_ typeCompteur: String, dans installation: Installation) async throws -> [Releve]
}

extension Parcours {
    /// Le service de « Prestataires » (réalisé par les deux services de l'app :
    /// `ServicesDesMenusTests` le vérifie).
    var servicePrestataires: (any ServicePrestataires)? { service as? any ServicePrestataires }
}

struct ContactPrestataire: Hashable, Sendable {
    var prenom: String?
    var nom: String?
    var fonction: String?
    var telephone: String?
    var email: String?
    /// `nom_affiche` servi (`PrestataireContactLu`, contrat 1.25.0, #135).
    var nomServi: String?

    /// « Prénom NOM » servi. `nil` pour un contact sans nom.
    var nomAffiche: String? { nomServi?.trimmingCharacters(in: .whitespaces).nulSiVide }
}

struct Prestataire: Hashable, Sendable, Identifiable {
    let id: Int
    var nom: String
    var specialite: String
    var type: String?
    var telephone: String?
    var email: String?
    var adresse: String?
    var description: String?
    var contacts: [ContactPrestataire] = []
    /// La moyenne de ses avis et leur nombre, SERVIS (`note_moyenne`, `nb_notations`) —
    /// `nil` sans avis, jamais 0.
    var noteMoyenne: Double?
    var nbNotations = 0
    /// Les numéros, un lien d'appel chacun : ceux que le serveur SERT, découpés et
    /// dédoublonnés (`telephones`, contrat 1.20.0, #125).
    var telephones: [String] = []
}

struct Contrat: Hashable, Sendable, Identifiable {
    let id: Int
    var prestataireId: Int
    var libelle: String
    var typeEquipement: String
    var numeroContrat: String?
    var dateDebut: String
    var dureeValeur: Int?
    var dureeUnite: String?
    var frequenceType: String?
    var frequenceValeur: Int?
    /// « ↺ Mensuel » : la fréquence en clair, SERVIE (`frequence_libelle`, contrat ≤ 1.14.0,
    /// coprofirst#2507) — vide sans fréquence.
    var frequenceLibelle: String?
    var prochaineVisite: String?
    var notes: String?
    /// La résiliation et le remplacement servis (contrat 1.29.0, #185).
    var remplacement = RemplacementContrat()
}

struct Equipement: Hashable, Sendable {
    let code: String
    var libelle: String
    var ordre: Int
}

struct DocumentContrat: Hashable, Sendable, Identifiable {
    let id: Int
    var titre: String
    var fichierNom: String
}

struct Compteur: Hashable, Sendable, Identifiable {
    let id: Int
    var typeCompteur: String
    var libelle: String
    var ordre: Int
    var prestataireId: Int?
}

struct Releve: Hashable, Sendable, Identifiable {
    let id: Int
    var dateReleve: String
    var index: Int?
    var note: String?
    var photoUrl: String?
}
