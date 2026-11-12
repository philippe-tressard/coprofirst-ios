// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

extension DetailAffaire {
    /// L'affaire servie, par ses types GÉNÉRÉS (`TicketRead`, `TicketEvolutionRead`) — le
    /// même branchement pour le service réel et l'API simulée.
    static func lue(
        _ ticket: Components.Schemas.TicketRead, evolutions: [Components.Schemas.TicketEvolutionRead]
    ) -> DetailAffaire {
        DetailAffaire(ticket: ticket, suites: evolutions.map(SuiteAffaire.init).sorted { $0.date < $1.date })
    }

    /// « Ascenseurs du Parc · ↺ Mensuel » : rien sans prestataire. Le cadre « sous
    /// contrat n° … » du site n'est pas servi : l'app ne le compose pas.
    static func intervenant(_ prestataire: String?, rythme: String?) -> String? {
        guard let prestataire = prestataire?.nulSiVide else { return nil }
        return [prestataire, rythme?.nulSiVide].compactMap(\.self).joined(separator: " · ")
    }

    /// Le rythme qui fait foi : celui du contrat sous contrat, celui de l'affaire sinon
    /// (`intervenantAffiche` du site) — `frequence_libelle`, servi (#125).
    static func rythme(_ ticket: Components.Schemas.TicketRead) -> String? {
        ticket.contrat?.frequenceLibelle ?? ticket.frequenceLibelle
    }

    init(ticket: Components.Schemas.TicketRead, suites: [SuiteAffaire]) {
        self.init(
            id: ticket.id, numero: ticket.numero, titre: ticket.titre, description: ticket.description,
            categorie: ticket.categorie, statut: ticket.statut,
            // Urgente au sens du SERVEUR (`TicketRead.urgente`, contrat 1.8.0) : l'app ne la
            // déduit pas de la priorité.
            urgente: ticket.urgente, creeLe: ticket.creeLe,
            auteur: ticket.saisiPourAffichage ?? ticket.auteurNom, lieu: ticket.lieuServi,
            pieces: PiecesJointes(urls: (ticket.photosUrls ?? []) + (ticket.fichiersUrls ?? [])),
            suites: suites,
            droits: DroitsServisAffaire(
                repondre: ticket.peutRepondre ?? false, changerEtat: ticket.peutChangerEtat ?? false,
                modifier: ticket.peutModifier ?? false, archiver: ticket.peutArchiver ?? false,
                // Le crayon SERVI (`peut_corriger`, #127) : jamais déduit du droit sur le contenu.
                corriger: ticket.peutCorriger ?? false),
            epingle: ticket.epingle ?? false, archivee: ticket.archivee ?? false,
            fusionnee: ticket.fusionnee ?? false, perimetres: ticket.perimetreCible ?? [],
            statutLibelle: ticket.statutLibelle, suiviActualite: ticket.suiviActualite,
            suiviActualiteLibelle: ticket.suiviActualiteLibelle,
            intervenant: Self.intervenant(ticket.prestataireNom, rythme: Self.rythme(ticket)),
            // « Qui la lit », servie (`lecture`, #129).
            lecture: ticket.lecture.map(Lecture.init))
        close = ticket.close ?? false
    }
}

extension SuiteAffaire {
    init(evolution: Components.Schemas.TicketEvolutionRead) {
        self.init(
            id: evolution.id, type: evolution._type, date: evolution.creeLe, auteur: evolution.auteurNom,
            // Ce que CE lecteur peut faire de l'entrée, servi avec elle (#93) ; absent, « non ».
            droits: DroitsServisSuite(
                modifier: evolution.peutModifier ?? false, supprimer: evolution.peutSupprimer ?? false),
            contenu: evolution.contenu, ancienStatut: evolution.ancienStatut ?? evolution.statutAvant,
            nouveauStatut: evolution.nouveauStatut,
            pieces: PiecesJointes(urls: evolution.fichiersUrls ?? []),
            nouveauStatutLibelle: evolution.nouveauStatutLibelle,
            // Le lieu qu'une Suite précise, tel que servi (`perimetre_precise_libelle`, #130).
            perimetrePrecise: LieuServi.lieu(evolution.perimetrePreciseLibelle))
    }
}
