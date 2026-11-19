// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les écrans que l'API simulée sert — le JSON de `GET /ecrans` et de `POST /ecrans`, lu par
/// le type GÉNÉRÉ puis par le MÊME branchement que le service réel, et jugé contre le contrat
/// par `scripts/verifier-fixtures.py`. Le deuxième est échu ; le troisième n'a rien lu.
enum FixturesEcransCS {
    typealias Reponse = FixturesAcces.Reponse

    /// GET /ecrans → `[EcranLu]`, rangés par nom comme le serveur les sert.
    static let ecrans = #"""
        [
          {"id": 3, "nom": "Hall du bâtiment A", "perimetre": "bat_a/hall", "perimetre_libelle": "Bât. A › Hall",
           "cree_le": "2026-11-02T10:15:00", "vu_le": "2026-11-18T08:42:00", "expire_le": "2026-12-18T08:42:00",
           "echu": false},
          {"id": 1, "nom": "Hall du bâtiment B", "perimetre": "bat_b", "perimetre_libelle": "Bât. B",
           "cree_le": "2026-09-14T09:00:00", "vu_le": "2026-09-30T18:05:00", "expire_le": "2026-10-30T18:05:00",
           "echu": true},
          {"id": 4, "nom": "Loge du gardien", "perimetre": "copropriete", "perimetre_libelle": "",
           "cree_le": "2026-11-18T07:30:00", "vu_le": null, "expire_le": "2026-12-18T07:30:00", "echu": false}
        ]
        """#

    /// POST /ecrans → `AppairageConfirme` : la forme de la réponse, pour le juge.
    static let appairage = #"""
        {"nom": "Hall du bâtiment A", "perimetre": "bat_a/hall", "perimetre_libelle": "Bât. A › Hall"}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "ecrans", schema: "EcranLu", json: ecrans),
        Reponse(nom: "appairage", schema: "AppairageConfirme", json: appairage),
    ]

    /// Lus comme le client généré les lit, branchés comme le service réel.
    static func ecransLus() throws -> [EcranDuHall] {
        try Relecture.generee([Components.Schemas.EcranLu].self, json: ecrans).map(EcranDuHall.init)
    }

    /// Le seul code que l'API simulée reconnaît : tout autre rend la phrase du serveur.
    static let codeAffiche = "BCDF-GHJK"
    static let codeInconnu = "Code inconnu ou expiré — affichez un nouveau code sur l'écran."
}
#endif
