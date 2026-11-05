// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Un onglet d'une page du site (`OngletDef` de `pages.ts`) — la table est GÉNÉRÉE :
/// `OngletsDuSite.parPage` (Charte/OngletsDuSite.swift, scripts/generateurs/onglets.py).
struct OngletDuSite: Hashable, Sendable, Identifiable {
    let id: String
    /// Le libellé du site, pictogramme retiré ; l'administration peut le renommer
    /// (`page_config_<id>`), comme les pages.
    let libelle: String
    /// À qui l'onglet est réservé, quand sa route d'API refuse les autres.
    let reserve: ReserveOnglet?
    /// Sur une page réservée à l'administration, l'onglet que l'opérateur ouvre aussi.
    let ouvertOperateur: Bool
}

/// Les réserves du site (`OngletDef.reserve`). Une valeur neuve côté site fait échouer
/// la génération : l'app l'apprend ici, elle ne l'ouvre jamais par défaut.
enum ReserveOnglet: String, Sendable {
    case proprioOuCS, nonLocataire, operateur, nonGestionnaire
}

/// Ce que l'utilisateur est, pour juger d'un onglet (`DroitsOnglet` du site).
///
/// Les populations sont GÉNÉRÉES (`OngletsDuSite.roles…`, `statuts…`) ; seule la façon
/// de les lire est écrite ici, comme `aRole` et `statutDe` le font sur le site.
struct DroitsOnglet: Hashable, Sendable {
    var administrateur = false
    var operateur = false
    var proprioOuCS = false
    var locataire = false
    var gestionnaire = false
    /// Conseil syndical ou administration — `$isCS` du site, qui inclut l'administrateur.
    /// Aucune réserve d'onglet ne l'emploie ; un écran le lit (le Règlement, #12).
    var cs = false
    /// Le compte technique de l'installation : administrateur, sans lot ni conseil
    /// (`$isAdminOnly` du site). Il n'a pas les outils du conseil (`PagesOuvertes`).
    var adminSeul = false

    init(
        administrateur: Bool = false, operateur: Bool = false, proprioOuCS: Bool = false,
        locataire: Bool = false, gestionnaire: Bool = false, cs: Bool = false, adminSeul: Bool = false
    ) {
        self.administrateur = administrateur
        self.operateur = operateur
        self.proprioOuCS = proprioOuCS
        self.locataire = locataire
        self.gestionnaire = gestionnaire
        self.cs = cs
        self.adminSeul = adminSeul
    }

    /// Depuis le compte servi par `GET /auth/me` : `roles` (ou, à défaut, `role` seul —
    /// `aRole` du site) et `statut`.
    init(roles: [String], role: String?, statut: String?) {
        let portes = Set(roles.isEmpty ? [role].compactMap { $0 } : roles)
        let statut = statut ?? ""
        self.init(
            administrateur: !portes.isDisjoint(with: OngletsDuSite.rolesAdministrateur),
            operateur: !portes.isDisjoint(with: OngletsDuSite.rolesOperateur),
            proprioOuCS: !portes.isDisjoint(with: OngletsDuSite.rolesProprioOuCS),
            locataire: OngletsDuSite.statutsLocataire.contains(statut),
            gestionnaire: OngletsDuSite.statutsGestionnaire.contains(statut),
            cs: !portes.isDisjoint(with: OngletsDuSite.rolesCS),
            adminSeul: !portes.isDisjoint(with: OngletsDuSite.rolesAdminSeul)
                && portes.isDisjoint(with: OngletsDuSite.rolesSansAdminSeul))
    }
}

extension OngletsDuSite {
    /// Les onglets qu'un compte ouvre sur une page, dans l'ordre du site —
    /// `ongletsOuverts` de `#lib/onglets-ouverts.ts`, et nulle part ailleurs dans l'app.
    ///
    /// ⚠️ Masquer ne protège rien : le serveur tranche. Cela évite de tendre une entrée
    /// qui mène à un refus. Un masquage qui dépend des DONNÉES (« Gestion locative »
    /// sans bail) reste à l'écran, seul à le savoir.
    static func ouverts(page: String, droits: DroitsOnglet) -> [OngletDuSite] {
        let reserveeAdmin = pagesReserveesAdmin.contains(page)
        return (parPage[page] ?? []).filter { onglet in
            admise(onglet.reserve, droits)
                && (!reserveeAdmin || droits.administrateur || (droits.operateur && onglet.ouvertOperateur))
        }
    }

    /// `reserveAdmise` du site.
    private static func admise(_ reserve: ReserveOnglet?, _ droits: DroitsOnglet) -> Bool {
        switch reserve {
        case nil: true
        case .proprioOuCS: droits.proprioOuCS
        case .nonLocataire: !droits.locataire
        case .operateur: droits.operateur
        case .nonGestionnaire: !droits.gestionnaire
        }
    }
}

extension DroitsOnglet {
    /// Depuis le profil gardé de la résidence ouverte. `ProfilResidence.roles` porte déjà
    /// `role` à la suite de `roles` (ServiceAPI+Compte) : un rôle principal absent de
    /// `roles` y compte, là où `aRole` l'ignorerait — sans effet tant que le serveur
    /// range le rôle principal dans `roles`, ce qu'il fait.
    init(profil: ProfilResidence?) {
        self.init(roles: profil?.roles ?? [], role: nil, statut: profil?.statut)
    }
}
