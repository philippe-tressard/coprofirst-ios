// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les pages qu'un compte voit dans la barre — LUES, jamais recomposées (#355).
///
/// Le serveur dit à quels publics le compte appartient (`acces_menu` de GET /auth/me,
/// calculé par `api/app/utils/acces_menu.py` de coprofirst, #3003) ; chaque page déclare
/// le sien (`acces`, table `pages` de tables-clients.json, GÉNÉRÉ dans `PagesParDefaut`).
/// Une page s'affiche si son public est servi — `pageAuMenu` de `front/src/lib/acces-menu.ts`,
/// et rien d'autre : aucun rôle ni statut n'est lu ici.
///
/// ⚠️ Masquer ne protège rien : chaque route de ces pages est refusée par le serveur
/// à qui n'a pas le droit. Cela évite de tendre une entrée qui mène à un refus.
enum PagesOuvertes {
    /// Un profil gardé avant #355 n'a pas `acces_menu` : jusqu'à sa relecture à
    /// l'ouverture (GET /auth/me), la barre ne montre que les pages de tous. Divergence
    /// déclarée au défaut fermé du site, qui n'a pas de profil gardé : une barre vide
    /// laisserait l'app sans écran le temps d'une requête.
    static let avantRelecture = ["tous"]

    static func filtrer(_ pages: [PageDeNavigation], droits: DroitsOnglet) -> [PageDeNavigation] {
        pages.filter { droits.accesMenu.contains($0.acces) }
    }

    /// Une page nommée par son identifiant (`CadreAOnglets`) ; inconnue : fermée.
    static func ouverte(_ page: String, droits: DroitsOnglet) -> Bool {
        PagesParDefaut.toutes.first { $0.id == page }.map { droits.accesMenu.contains($0.acces) } ?? false
    }
}
