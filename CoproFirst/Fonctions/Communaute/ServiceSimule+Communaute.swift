// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une Communauté inventée, pour les aperçus, les tests et les captures : aucune
/// personne réelle (des prénoms d'exemple), aucune requête. Les écritures réussissent
/// sans rien garder : l'écran relit la liste, comme après un vrai envoi.
extension ServiceSimule: ServiceCommunaute {
    func moiCommunaute(_ installation: Installation) async throws -> MoiCommunaute {
        try await Task.sleep(for: .milliseconds(150))
        return MoiCommunaute(id: 7, statut: profilSimule.statut ?? "", roles: profilSimule.roles, motifRefus: nil)
    }

    func sondagesCommunaute(_ installation: Installation) async throws -> [SondageResume] {
        try await Task.sleep(for: .milliseconds(400))
        return [
            SondageResume(
                id: 12, question: "Quel jour pour la fête des voisins ?",
                description: "<p>Trois dates sont proposées.</p>", clotureLe: Self.dans(jours: 5), cloture: false,
                nbVotants: 27, archivee: false, creeLe: Self.dans(jours: -1)),
            SondageResume(
                id: 11, question: "Faut-il installer des arceaux à vélos devant le bâtiment B ?",
                description: "<p>Le devis est joint à l'affaire correspondante.</p>", clotureLe: nil, cloture: false,
                nbVotants: 1, archivee: false, creeLe: Self.dans(jours: -9)),
            SondageResume(
                id: 9, question: "Horaires d'ouverture du local à vélos", description: nil,
                clotureLe: Self.dans(jours: -20), cloture: true, nbVotants: 41, archivee: true,
                creeLe: Self.dans(jours: -40)),
        ]
    }

    func idees(_ installation: Installation) async throws -> [Idee] {
        try await Task.sleep(for: .milliseconds(400))
        return [
            Idee(
                id: 3, titre: "Un composteur partagé dans le jardin",
                description: "<p>Pour réduire nos déchets et nourrir les massifs.</p>", auteurId: 7,
                statut: "retenue", creeLe: Self.dans(jours: -12), nbVotes: 18, monVote: true, archivee: false,
                reponses: [Self.reponse(1, "Excellente idée, je veux bien m'en occuper.", estCs: false)]),
            Idee(
                id: 5, titre: "Une boîte à livres dans le hall A",
                description: "<p>Une étagère où chacun dépose et emprunte.</p>", auteurId: 4, statut: "ouverte",
                creeLe: Self.dans(jours: -1), nbVotes: 9, monVote: false, archivee: false,
                reponses: [Self.reponse(2, "Le conseil syndical en parlera jeudi.", estCs: true)]),
            Idee(
                id: 1, titre: "Repeindre la cage d'escalier", description: "<p>Elle en a bien besoin.</p>",
                auteurId: 2, statut: "realisee", creeLe: Self.dans(jours: -200), nbVotes: 31, monVote: false,
                archivee: true, reponses: []),
        ]
    }

    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String? {
        try await Task.sleep(for: .milliseconds(200))
        return "Vote enregistré"
    }

    func annonces(_ installation: Installation) async throws -> [Annonce] {
        try await Task.sleep(for: .milliseconds(400))
        return [
            Annonce(
                id: 21, titre: "Lave-linge presque neuf", description: """
                    <p>Huit kilos, deux ans, factures à l'appui.</p>
                    """,
                typeAnnonce: "vente", categorie: "electromenager", prix: 180, negotiable: true, photos: [],
                statut: "en_cours", auteurPrenom: "Voisine du 2ᵉ", auteurNom: nil, auteurEmail: "voisine@exemple.fr",
                estAuteur: false, archivee: false, creeLe: Self.dans(jours: -2),
                reponses: [Self.reponse(3, "Est-il encore disponible samedi ?", estCs: false)]),
            Annonce(
                id: 22, titre: "Plantes vertes à donner", description: "<p>Un ficus et deux monsteras.</p>",
                typeAnnonce: "don", categorie: "divers", prix: nil, negotiable: false, photos: [], statut: "reserve",
                auteurPrenom: "Moi", auteurNom: nil, auteurEmail: nil, estAuteur: true, archivee: false,
                creeLe: Self.dans(jours: -6), reponses: []),
            Annonce(
                id: 23, titre: "Cherche place de parking", description: "<p>Au sous-sol, pour une citadine.</p>",
                typeAnnonce: "recherche", categorie: "parking_cave", prix: nil, negotiable: false, photos: [],
                statut: "en_cours", auteurPrenom: "Voisin du 5ᵉ", auteurNom: nil, auteurEmail: nil, estAuteur: false,
                archivee: false, creeLe: Self.dans(jours: -15), reponses: []),
        ]
    }

    func deposerAnnonce(_ saisie: SaisieAnnonce, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func changerStatutAnnonce(_ id: Int, statut: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func supprimerAnnonce(_ id: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func repondreCommunaute(_ texte: String, a cible: CibleCommunaute, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func supprimerReponseCommunaute(_ id: Int, de cible: CibleCommunaute, dans installation: Installation)
        async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    func signalerAuConseil(_ cible: CibleCommunaute, motif: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func avisCommunaute(_ installation: Installation) async throws -> ListeAvis {
        try await Task.sleep(for: .milliseconds(400))
        return ListeAvis(
            avis: [
                AvisResident(
                    id: 4, note: 5, titre: "Enfin une résidence où l'on sait ce qui se passe",
                    description: "<p>Les affaires sont suivies, et on voit où elles en sont.</p>",
                    auteurNom: "Résidente du bât. A", auteurRole: "Copropriétaire résident", estAuteur: false,
                    reponse: "Merci pour ce retour !", reponseLe: Self.dans(jours: -3), remarque: nil,
                    consentement: true, archivee: false, restaurable: false, luDeTous: true, retenu: true,
                    creeLe: Self.dans(jours: -8)),
                AvisResident(
                    id: 6, note: 2, titre: "Il manque les comptes de la copropriété",
                    description: "<p>J'aimerais suivre les dépenses.</p>", auteurNom: "Résident du bât. B",
                    auteurRole: "Locataire", estAuteur: false, reponse: nil, reponseLe: nil,
                    remarque: "Un tableau des charges par année.", consentement: nil, archivee: false,
                    restaurable: false, luDeTous: false, retenu: false, creeLe: Self.dans(jours: -4)),
            ], gestionnaire: false, monAvisId: nil)
    }

    func deposerAvis(_ saisie: SaisieAvis, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func corrigerAvis(_ id: Int, _ saisie: SaisieAvis, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func archiverAvis(_ id: Int, archive: Bool, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    private static func dans(jours: Double) -> Date { Date.now.addingTimeInterval(jours * 86_400) }

    private static func reponse(_ id: Int, _ contenu: String, estCs: Bool) -> ReponseCommunaute {
        ReponseCommunaute(
            id: id, auteurId: estCs ? 1 : 5, contenu: contenu, creeLe: dans(jours: -0.5),
            auteurNom: estCs ? "Conseil syndical" : "Voisin du bât. A", auteurBatiment: "Bât. A",
            auteurRole: estCs ? "Conseil syndical" : "Résident", estCs: estCs)
    }
}
