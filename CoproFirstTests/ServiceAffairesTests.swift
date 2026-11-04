// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Testing

@testable import CoproFirst

/// Un service par menu, réalisé par extension (#11) : l'écran le tire de la session
/// par `menuAffaires`. Ces affectations ne COMPILENT que si les deux services s'y
/// conforment — un oubli casse le build, au lieu d'un `nil` découvert à l'écran.
@Test func lesDeuxServicesRealisentLeMenuAffaires() {
    let reel: any ServiceAffaires = ServiceAPI()
    let simule: any ServiceAffaires = ServiceSimule(delai: .zero)
    #expect(ServiceAPI().menuAffaires != nil && ServiceSimule().menuAffaires != nil)
    _ = (reel, simule)
}
