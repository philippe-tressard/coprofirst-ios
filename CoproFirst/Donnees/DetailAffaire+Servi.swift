// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

extension DetailAffaire {
    /// L'affaire servie et ses suites, par les types générés — le MÊME branchement pour le
    /// service réel et l'API simulée.
    static func lue(
        _ ticket: Components.Schemas.TicketRead, evolutions: [Components.Schemas.TicketEvolutionRead]
    ) -> DetailAffaire {
        let suites = evolutions.map { evolution in
            var suite = SuiteAffaire(evolution: evolution)
            // L'état qu'une Suite donne, en clair (`nouveau_statut_libelle`, contrat 1.21.0, #127).
            suite.nouveauStatutLibelle = evolution.nouveauStatutLibelle
            // Le lieu qu'une Suite précise, tel que servi (`perimetre_precise_libelle`, #130).
            suite.perimetrePrecise = LieuServi.lieu(evolution.perimetrePreciseLibelle)
            return suite
        }
        var detail = DetailAffaire(ticket: ticket, suites: suites.sorted { $0.date < $1.date })
        // Le crayon SERVI (`peut_corriger`, contrat 1.21.0, #127) ; non servi, le droit sur le contenu.
        detail.droits.corriger = ticket.peutCorriger ?? detail.droits.modifier
        // Le suivi d'une actualité en clair (1.21.0) ; le rythme qui fait foi : celui du contrat
        // sous contrat, celui de l'affaire sinon (`intervenantAffiche` du site, 1.20.0, #125).
        detail.suiviActualiteLibelle = ticket.suiviActualiteLibelle
        detail.intervenant = intervenant(
            ticket.prestataireNom, rythme: ticket.contrat?.frequenceLibelle ?? ticket.frequenceLibelle)
        // « Qui la lit », servie (`lecture`, contrat 1.22.0, #129).
        detail.lecture = ticket.lecture.map(Lecture.init)
        return detail
    }

    /// « Ascenseurs du Parc · ↺ Mensuel » : rien sans prestataire. Le cadre « sous
    /// contrat n° … » du site n'est pas servi : l'app ne le compose pas.
    static func intervenant(_ prestataire: String?, rythme: String?) -> String? {
        guard let prestataire = prestataire?.nulSiVide else { return nil }
        return [prestataire, rythme?.nulSiVide].compactMap(\.self).joined(separator: " · ")
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
                modifier: ticket.peutModifier ?? false, archiver: ticket.peutArchiver ?? false),
            epingle: ticket.epingle ?? false, archivee: ticket.archivee ?? false,
            fusionnee: ticket.fusionnee ?? false, perimetres: ticket.perimetreCible ?? [],
            statutLibelle: ticket.statutLibelle, suiviActualite: ticket.suiviActualite)
        close = ticket.close ?? false
    }
}

extension SuiteAffaire {
    init(evolution: Components.Schemas.TicketEvolutionRead) {
        self.init(
            id: evolution.id, type: evolution._type, date: evolution.creeLe, auteur: evolution.auteurNom,
            contenu: evolution.contenu, ancienStatut: evolution.ancienStatut ?? evolution.statutAvant,
            nouveauStatut: evolution.nouveauStatut,
            pieces: PiecesJointes(urls: evolution.fichiersUrls ?? []))
    }
}
