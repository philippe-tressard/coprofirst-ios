// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

@Test func lAccueilPorteLeNomDuProduit() {
    #expect(Accueil.titre == "CoproFirst")
}
