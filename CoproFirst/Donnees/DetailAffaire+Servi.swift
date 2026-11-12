// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que GET /tickets/{id} sert au-dessus du plancher, relu par
/// `Relecture.auDessusDuPlancher` : tout est facultatif — absent d'une installation
/// antérieure, la fiche garde son rendu d'avant.
/// - `peut_corriger` (contrat 1.21.0, #127) : le crayon ;
/// - `suivi_actualite_libelle` (1.21.0) : le suivi d'une actualité, en clair ;
/// - `frequence_libelle`, et celui de son contrat (1.20.0, #125) : le rythme.
struct AffaireAuDessusDuPlancher: Decodable {
    var peutCorriger: Bool?
    var suiviActualiteLibelle: String?
    var frequenceLibelle: String?
    var contrat: ContratLu?

    struct ContratLu: Decodable {
        var frequenceLibelle: String?
    }

    /// Le rythme qui fait foi : celui du contrat sous contrat, celui de l'affaire sinon
    /// (`intervenantAffiche` du site).
    var rythme: String? { contrat?.frequenceLibelle ?? frequenceLibelle }
}

/// Ce que GET /tickets/{id}/evolutions sert au-dessus du plancher, par entrée :
/// l'état qu'une Suite donne, en clair (`nouveau_statut_libelle`, contrat 1.21.0, #127).
struct SuiteAuDessusDuPlancher: Decodable, Identifiable {
    let id: Int
    var nouveauStatutLibelle: String?
}

extension DetailAffaire {
    /// L'affaire servie : les types générés, puis ce que les corps servent au-dessus du
    /// plancher — le MÊME branchement pour le service réel et l'API simulée.
    static func lue(
        _ ticket: Components.Schemas.TicketRead, corps: Data?,
        evolutions: [Components.Schemas.TicketEvolutionRead], corpsEvolutions: Data?
    ) -> DetailAffaire {
        let entrees = Relecture.auDessusDuPlancher(parLigne: SuiteAuDessusDuPlancher.self, corps: corpsEvolutions)
        // Le lieu qu'une Suite précise, tel que servi (`perimetre_precise_libelle`, #130).
        let lieux = ServiAuDessusDuPlancher.parLigne(corpsEvolutions)
        let suites = evolutions.map { evolution in
            var suite = SuiteAffaire(evolution: evolution)
            suite.nouveauStatutLibelle = entrees[evolution.id]?.nouveauStatutLibelle
            suite.perimetrePrecise = LieuServi.lieu(lieux[evolution.id]?.perimetrePreciseLibelle?.valeur)
            return suite
        }
        var detail = DetailAffaire(ticket: ticket, suites: suites.sorted { $0.date < $1.date })
        let servi = Relecture.auDessusDuPlancher(AffaireAuDessusDuPlancher.self, corps: corps)
        // Le crayon SERVI ; à défaut (installation antérieure), le droit sur le contenu.
        detail.droits.corriger = servi?.peutCorriger ?? detail.droits.modifier
        detail.suiviActualiteLibelle = servi?.suiviActualiteLibelle
        detail.intervenant = intervenant(ticket.prestataireNom, rythme: servi?.rythme)
        // « Qui la lit », servie (`lecture`, contrat 1.22.0, #129).
        detail.lecture = ServiAuDessusDuPlancher.un(corps)?.lecture?.valeur
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
            photos: (ticket.photosUrls ?? []) + (ticket.fichiersUrls ?? []).filter(Fichiers.estImage),
            suites: suites,
            droits: DroitsServisAffaire(
                repondre: ticket.peutRepondre ?? false, changerEtat: ticket.peutChangerEtat ?? false,
                modifier: ticket.peutModifier ?? false, archiver: ticket.peutArchiver ?? false),
            epingle: ticket.epingle ?? false, archivee: ticket.archivee ?? false,
            fusionnee: ticket.fusionnee ?? false, perimetres: ticket.perimetreCible ?? [],
            statutLibelle: ticket.statutLibelle, suiviActualite: ticket.suiviActualite)
    }
}

extension SuiteAffaire {
    init(evolution: Components.Schemas.TicketEvolutionRead) {
        self.init(
            id: evolution.id, type: evolution._type, date: evolution.creeLe, auteur: evolution.auteurNom,
            contenu: evolution.contenu, ancienStatut: evolution.ancienStatut ?? evolution.statutAvant,
            nouveauStatut: evolution.nouveauStatut,
            photos: (evolution.fichiersUrls ?? []).filter(Fichiers.estImage))
    }
}
