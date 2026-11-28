// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le rendez-vous d'une affaire datée, tel que le SERVEUR le compose (`GET /tickets/{id}/agenda`,
/// contrat 2.15.0, coprofirst#3164, #435) : titre, dates en UTC, lieu, description — vide pour
/// une affaire réservée au conseil —, lien absolu de l'affaire, et les pages de saisie des
/// agendas en ligne. L'app n'y ajoute rien et n'y retranche rien : jamais la description de
/// l'affaire lue à l'écran, que le serveur peut taire ici.
struct RendezVousAffaire: Identifiable, Hashable, Sendable {
    let id: String
    let titre: String
    let debut: Date
    let fin: Date
    let lieu: String
    let description: String
    let lien: URL?
    /// Les agendas en ligne servis, dans l'ordre de « Autre agenda… » du site.
    let enLigne: [AgendaEnLigne: URL]

    init(_ servi: Components.Schemas.AgendaServi) {
        id = servi.uid
        titre = servi.titre
        debut = servi.debut
        fin = servi.fin
        lieu = servi.lieu
        description = servi.description
        lien = URL(string: servi.lien)
        enLigne = AgendaEnLigne.allCases.reduce(into: [:]) { liens, agenda in
            liens[agenda] = URL(string: agenda.adresse(dans: servi.liens))
        }
    }
}

/// Un agenda en ligne de « Autre agenda… », avec le libellé du site (`AGENDAS` de
/// `agendas.ts`). Le « Fichier .ics » n'y est pas : sur un appareil Apple, le site le retire
/// des autres agendas, puisque c'est lui qui ouvre Calendrier (`autresAgendas`).
enum AgendaEnLigne: String, CaseIterable, Identifiable, Sendable {
    case google, outlook, microsoft365, yahoo

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .google: "Google Agenda"
        case .outlook: "Outlook.com"
        case .microsoft365: "Outlook — Microsoft 365"
        case .yahoo: "Yahoo Agenda"
        }
    }

    func adresse(dans liens: Components.Schemas.LiensAgenda) -> String {
        switch self {
        case .google: liens.google
        case .outlook: liens.outlook
        case .microsoft365: liens.microsoft365
        case .yahoo: liens.yahoo
        }
    }
}

/// `agenda_propose` (contrat 2.15.0), servi avec l'affaire au-dessus du plancher (#89) et
/// relu dans le corps de GET /tickets/{id} — le type généré du plancher le jette. Le jour où
/// le plancher sert 2.15.0, il se lit par `TicketRead.agendaPropose` et ce type se retire.
struct ChampsAgenda: Decodable, Identifiable, Sendable {
    let id: Int
    let agendaPropose: Bool?

    /// Absent (installation antérieure), illisible ou faux : « Ajouter à mon agenda » ne
    /// s'offre pas — défaut fermé.
    static func propose(_ lu: ChampsAgenda?, pour affaire: Int) -> Bool {
        lu?.id == affaire && lu?.agendaPropose == true
    }
}
