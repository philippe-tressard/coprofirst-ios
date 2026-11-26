// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// `PagesOuvertes` est une copie PARTIELLE du menu du site (#355) : depuis le contrat 2.11.0,
/// le serveur sert la règle (`acces_menu` de GET /auth/me, `pages[].acces`, coprofirst#3003).
/// Elle est au-dessus du plancher tant que la démo sert 2.10.0. Le jour où le plancher
/// l'atteint, ce test rougit : lire la règle servie, retirer la copie, puis retirer ce test.
@Test func laCopieDuMenuSeRetireQuandLePlancherSertLaRegle() {
    #expect(
        VersionContrat.plancher < VersionContrat(2, 11, 0),
        "le plancher \(VersionContrat.plancher) sert acces_menu : lire la règle servie, retirer PagesOuvertes (#355)")
}
