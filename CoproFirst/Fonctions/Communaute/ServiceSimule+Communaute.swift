// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une Communauté inventée, pour les aperçus, les tests et les captures : aucune
/// personne réelle (des prénoms d'exemple), aucune requête. Les écritures réussissent
/// sans rien garder : l'écran relit la liste, comme après un vrai envoi.
extension ServiceSimule: ServiceCommunaute {
    /// Les idées dont le vote a basculé pendant la session — un jeu par service simulé
    /// (`MagasinSimuleCS`, qui retient le service : une adresse réemployée ne rend pas
    /// les votes d'un autre).
    private var votesBascules: MagasinSimuleCS<Set<Int>> { MagasinSimuleCS.de(self) { [] } }

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
        // Les votes donnés pendant la session : la liste relue les montre, comme le serveur.
        let basculees = votesBascules.valeur
        // Le JSON de la route, lu comme le service réel le lit (`FixturesCommunaute`).
        return try FixturesCommunaute.ideesLues().map { idee in
            guard basculees.contains(idee.id) else { return idee }
            var votee = idee
            votee.monVote.toggle()
            votee.nbVotes += votee.monVote ? 1 : -1
            return votee
        }
    }

    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String? {
        try await Task.sleep(for: .milliseconds(200))
        let basculee = votesBascules.modifier { $0.remove(id) == nil ? $0.insert(id).inserted : false }
        return basculee ? "Vote enregistré" : "Vote retiré"
    }

    func annonces(_ installation: Installation) async throws -> [Annonce] {
        try await Task.sleep(for: .milliseconds(400))
        return try FixturesCommunaute.annoncesLues()
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
}
