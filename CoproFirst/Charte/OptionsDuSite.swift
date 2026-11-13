// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/tickets.ts (OPTIONS_TICKET), options-publication.ts (OPTIONS_PUBLICATION).

/// Les options de mise en avant d'une affaire, comme le site les nomme.
enum OptionsDuSite {
    /// Une option : la clé (le champ de `TicketUpdate`), le verbe, l'état actif, et ce
    /// qu'elle fait.
    struct Option: Hashable, Sendable {
        let cle: String
        let action: String
        let etat: String
        let aide: String
    }

    /// Dans l'ordre du site.
    static let affaire: [Option] = [
        Option(
            cle: "epingle", action: "Épingler", etat: "Épinglée",
            aide: "Maintenue en tête du fil d’activité."),
        Option(
            cle: "urgente", action: "Marquer urgente", etat: "Urgente",
            aide: "Signalée par un bord rouge sur la carte."),
    ]
}
