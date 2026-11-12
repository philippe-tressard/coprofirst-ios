// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que la consultation hors ligne demande à un service (#101). Les lectures
/// elles-mêmes ne changent pas de chemin : `fil`, `affaire`, `profil`… rendent la
/// lecture gardée quand la résidence est ouverte sans réseau, par la porte du client
/// (`GarderLesLectures`) — aucun écran ne lit le disque.
protocol ServiceHorsLigne: Sendable {
    /// La reprise a échoué faute de réseau, Face ID passé : y a-t-il une lecture à
    /// ouvrir ? `.gardee` ouvre la consultation de cette résidence — plus rien ne part
    /// vers elle, hors la reprise de sa session.
    func consulterHorsLigne(_ installation: Installation) -> LectureDisponible
    /// Le réseau est revenu : rouvrir la session, sans redemander Face ID (le jeton lu
    /// à l'entrée attend dans la session HTTP). Un refus du serveur efface le jeton et
    /// la lecture gardée, et lève `ErreurService.sessionExpiree`.
    func reprendreEnLigne(_ installation: Installation) async throws
    /// Au lancement : rien ne reste d'une lecture périmée, ni d'une résidence dont la
    /// session n'est plus gardée.
    func purgerLesLectures(sauf gardees: [Installation])
    /// Un fichier protégé (photo, pièce jointe), gardé une fois ouvert — il ne passe pas
    /// par le client généré, donc pas par sa porte.
    func fichierGarde(_ chemin: String, dans installation: Installation) async throws -> Data
}

extension ServiceCoproFirst {
    /// La consultation hors ligne de ce service — `nil` pour un service qui ne la porte pas.
    var horsLigne: (any ServiceHorsLigne)? { self as? any ServiceHorsLigne }

    /// LA lecture d'un fichier protégé pour un écran : gardée pour la consultation hors
    /// ligne quand le service le sait. `scripts/verifier-depot.sh` refuse tout autre
    /// appel à `fichierProtege(` hors de `Session/`.
    func fichierConsultable(_ chemin: String, dans installation: Installation) async throws -> Data {
        guard let horsLigne else { return try await fichierProtege(chemin, dans: installation) }
        return try await horsLigne.fichierGarde(chemin, dans: installation)
    }
}

extension ServiceAPI: ServiceHorsLigne {
    /// LA porte de l'effacement de ce qu'une session laisse sur l'appareil : le jeton du
    /// Trousseau, la lecture gardée et les copies des fichiers ouverts, jamais l'un sans
    /// l'autre — la déconnexion, une session que le serveur refuse. `scripts/verifier-depot.sh`
    /// refuse tout autre appel à `Trousseau.supprimer(pour:)` hors du Trousseau.
    func oublierCeQuiEstGarde(_ installation: Installation) {
        Trousseau.supprimer(pour: installation.hote)
        lectures.effacer(installation.hote)
        Fichiers.effacerLesCopies()
    }

    /// La porte des lectures gardées de l'installation à cette adresse, pour son client.
    func garderLesLectures(_ adresse: URL) -> GarderLesLectures {
        GarderLesLectures(hote: SessionsParHote.cle(adresse), lectures: lectures)
    }

    func consulterHorsLigne(_ installation: Installation) -> LectureDisponible {
        lectures.consulter(installation.hote)
    }

    func reprendreEnLigne(_ installation: Installation) async throws {
        // La porte du renouvellement (#81) ; accepté, `GarderLesLectures` referme la consultation.
        guard try await appeler({ try await renouveler(installation.adresse) }) else {
            oublierCeQuiEstGarde(installation)
            throw ErreurService.sessionExpiree
        }
    }

    func purgerLesLectures(sauf gardees: [Installation]) {
        lectures.purger(sauf: Set(gardees.map(\.hote)))
    }

    func fichierGarde(_ chemin: String, dans installation: Installation) async throws -> Data {
        let (cle, hote) = (LectureGardee.cleFichier(chemin), installation.hote)
        if lectures.enConsultation(hote) {
            guard let lue = lectures.lire(cle, de: hote) else { throw ErreurService.horsLigne }
            return lue.corps
        }
        do {
            let donnees = try await fichierProtege(chemin, dans: installation)
            if donnees.count <= LectureGardee.plafond { lectures.garder(donnees, type: nil, cle: cle, de: hote) }
            return donnees
        } catch ErreurService.sessionExpiree {
            lectures.effacer(hote)
            throw ErreurService.sessionExpiree
        } catch ErreurService.introuvable {
            lectures.retirer(cle, de: hote)
            throw ErreurService.introuvable
        }
    }
}
