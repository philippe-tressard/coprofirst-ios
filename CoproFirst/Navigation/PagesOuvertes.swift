// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les pages qu'un compte voit dans la barre — le filtre du menu du site (`allNav` de
/// `Nav.svelte`), écrit ICI et nulle part ailleurs dans l'app (#15).
///
/// Les populations (qui est conseil, administrateur, opérateur, « admin seul ») sont
/// GÉNÉRÉES (`OngletsDuSite.roles…`) et lues par `DroitsOnglet` ; seule la règle qui
/// les combine est écrite ici, comme `OngletsDuSite.ouverts` pour les onglets.
///
/// ⚠️ Masquer ne protège rien : chaque route de ces pages est refusée par le serveur
/// à qui n'a pas le rôle. Cela évite de tendre une entrée qui mène à un refus.
enum PagesOuvertes {
    static func filtrer(_ pages: [PageDeNavigation], droits: DroitsOnglet) -> [PageDeNavigation] {
        pages.filter { ouverte($0.id, droits: droits) }
    }

    /// Une page réservée à un rôle ; toute autre page reste ouverte, comme aujourd'hui.
    static func ouverte(_ page: String, droits: DroitsOnglet) -> Bool {
        switch page {
        // « Les outils du conseil » : `$isCS` inclut l'administrateur, pas le compte
        // technique de l'installation (admin seul, sans lot ni conseil).
        case "prestataires", "espace-cs": droits.outilDuConseil
        // À compléter par le lot Délégations (#15) : le site l'ouvre aussi à l'aidant
        // (statut, ou `delegations_aidant` non vide de GET /auth/me).
        case "delegations": droits.outilDuConseil
        // `$isAdminOuOperateur` : l'opérateur n'y ouvre que sa supervision (`ouverts`).
        case "admin": droits.administrateur || droits.operateur
        default: true
        }
    }
}

extension DroitsOnglet {
    /// `outilDuConseil` du menu du site : conseil syndical ou administration, hors
    /// compte technique.
    var outilDuConseil: Bool { cs && !adminSeul }
}
