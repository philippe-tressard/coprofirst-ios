// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'utilisateur EST dans la résidence, pour choisir ce que l'écran affiche
/// et ce qu'il offre — les questions de `front/src/lib/roles.ts` (`estLocataire`…)
/// et de `stores/auth.ts` (`isCS`), appliquées au profil servi par GET /auth/me.
///
/// ⚠️ Elles disent ce qu'on AFFICHE, jamais ce qu'on autorise : le serveur tranche
/// (`auth/deps.py`), et un refus s'affiche avec sa phrase.
struct DroitsAcces: Hashable, Sendable {
    let statut: String?
    /// Ce que l'app sait déjà juger pour toutes les pages (`DroitsOnglet`, populations
    /// GÉNÉRÉES depuis le site) : locataire, conseil syndical.
    let onglet: DroitsOnglet

    init(_ profil: ProfilResidence?) {
        statut = profil?.statut
        onglet = DroitsOnglet(profil: profil)
    }

    var locataire: Bool { onglet.locataire }
    /// Copropriétaire qui LOUE son lot.
    var bailleur: Bool { statut == "copropriétaire_bailleur" }
    /// Copropriétaire qui HABITE son lot.
    var resident: Bool { statut == "copropriétaire_résident" }
    var coproprietaire: Bool { bailleur || resident }
    /// `isCS` : conseil syndical ou administration.
    var conseil: Bool { onglet.cs }

    /// Quels baux CE compte gère (`lireBaux` de `mon-lot`) : les siens
    /// (copropriétaire), tous (conseil), aucun sinon (`nil`).
    var baux: LectureBaux? {
        if coproprietaire { return .siens }
        if conseil { return .tous }
        return nil
    }

    enum LectureBaux: Sendable { case siens, tous }

    /// L'onglet « Gestion locative » (`peutGererLocation`) : bailleur, conseil, ou
    /// copropriétaire résident qui a des baux terminés.
    func voitLocation(bauxTermines: Int) -> Bool {
        bailleur || conseil || (resident && bauxTermines > 0)
    }

    /// « + Nouvel accès » : POST /acces/commandes exige un lot rattaché au compte —
    /// le geste n'est offert qu'à qui en a un, et seuls SES lots sont proposés.
    func peutDemander(lots: [LotDuCompte]) -> Bool { !lots.isEmpty }
}
