// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le principal du paquet de tests (`NSPrincipalClass`, project.yml) : créé au chargement,
/// avant tout test, il imprime l'empreinte des sources COMPILÉE dans ce binaire
/// (`EmpreinteSources`, écrite par `scripts/empreinte_tests.py`). `scripts/tests-simulateur.sh`
/// la compare à celle du source : un binaire périmé — le passage précédent, resté installé
/// sur le simulateur (#328) — ou muet rend le passage INCONNU, jamais vert.
@objc(EmpreinteDesTests)
final class EmpreinteDesTests: NSObject {
    override init() {
        super.init()
        print("Empreinte des tests jouée : \(EmpreinteSources.valeur)")
    }
}
