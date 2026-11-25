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
///
/// ⚠️ Copie PARTIELLE, et datée (#355). Le site a eu cinq branches, celle-ci en a trois ;
/// depuis le contrat 2.11.0 (v3.124.0), le serveur SERT la règle : `acces_menu` de
/// GET /auth/me, croisé avec le public de chaque page (`pages[].acces`, tables 1.7.0,
/// coprofirst#3003). Écarts connus avec elle : l'aidant voit ici la Communauté, le compte
/// technique (administrateur ou opérateur seul) les pages générales ; le syndic et le
/// mandataire y voient ce que le serveur leur ouvre. La règle servie est au-dessus du
/// plancher (2.10.0, la démo) : elle remplace cette copie quand il l'atteint —
/// `PagesOuvertesTests` rougit ce jour-là. Les versions publiées (1.0, 1.1) gardent la copie.
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
        // Le site l'ouvre aussi à l'aidant : statut, ou `delegations_aidant` non vide de
        // GET /auth/me (`DroitsOnglet.aidant`).
        case "delegations": droits.outilDuConseil || droits.aidant
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
