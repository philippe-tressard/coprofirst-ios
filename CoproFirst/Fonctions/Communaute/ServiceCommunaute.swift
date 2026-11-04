// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'écran Communauté demande à une installation (#14). Ce que le site
/// réserve au conseil syndical ou à l'administration (créer un sondage, changer le
/// statut d'une idée, modérer, répondre aux avis) reste au site, et l'écran le dit.
protocol ServiceCommunaute: Sendable {
    /// GET /auth/me : statut, rôles, suspension.
    func moiCommunaute(_ installation: Installation) async throws -> MoiCommunaute
    /// GET /sondages.
    func sondagesCommunaute(_ installation: Installation) async throws -> [SondageResume]
    /// GET /idees ; POST /idees ; POST /idees/{id}/voter (une bascule : le serveur rend sa phrase).
    func idees(_ installation: Installation) async throws -> [Idee]
    func proposerIdee(titre: String, description: String, dans installation: Installation) async throws
    func voterIdee(_ id: Int, dans installation: Installation) async throws -> String?
    /// GET /annonces ; POST /annonces ; PATCH /annonces/{id}/statut ; DELETE /annonces/{id}.
    func annonces(_ installation: Installation) async throws -> [Annonce]
    func deposerAnnonce(_ saisie: SaisieAnnonce, dans installation: Installation) async throws
    func changerStatutAnnonce(_ id: Int, statut: String, dans installation: Installation) async throws
    func supprimerAnnonce(_ id: Int, dans installation: Installation) async throws
    /// POST /{idees|annonces}/{id}/reponses ; DELETE …/reponses/{rep}.
    func repondreCommunaute(_ texte: String, a cible: CibleCommunaute, dans installation: Installation) async throws
    func supprimerReponseCommunaute(_ id: Int, de cible: CibleCommunaute, dans installation: Installation)
        async throws
    /// POST /signalements : au conseil syndical, avec un motif.
    func signalerAuConseil(_ cible: CibleCommunaute, motif: String, dans installation: Installation) async throws
    /// GET /avis ; POST /avis ; PATCH /avis/{id} ; PATCH /avis/{id}/archivage.
    func avisCommunaute(_ installation: Installation) async throws -> ListeAvis
    func deposerAvis(_ saisie: SaisieAvis, dans installation: Installation) async throws
    func corrigerAvis(_ id: Int, _ saisie: SaisieAvis, dans installation: Installation) async throws
    func archiverAvis(_ id: Int, archive: Bool, dans installation: Installation) async throws
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`CommunauteTests` le vérifie à la compilation).
    var serviceCommunaute: any ServiceCommunaute {
        // swiftlint:disable:next force_cast
        service as! any ServiceCommunaute
    }
}

extension SaisieAvis {
    /// Ce que le serveur attend selon la note : la remarque sous le seuil, l'accord
    /// de diffusion à partir de l'autre (`exiger_saisie_valide`) ; hors seuil, rien.
    var remarqueEnvoyee: String? {
        RegleCommunaute.demandeRemarque(note) ? remarque.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    var consentementEnvoye: Bool? { RegleCommunaute.demandeConsentement(note) ? consentement : nil }

    /// Le bouton s'ouvre quand le serveur n'a plus de raison de refuser.
    var complete: Bool {
        let pleins = [titre, description].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard pleins, RegleCommunaute.noteValable(note) else { return false }
        if RegleCommunaute.demandeRemarque(note), (remarqueEnvoyee ?? "").isEmpty { return false }
        if RegleCommunaute.demandeConsentement(note), consentement == nil { return false }
        return true
    }
}
