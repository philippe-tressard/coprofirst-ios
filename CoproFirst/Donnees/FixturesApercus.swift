// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

#if DEBUG
/// Les aperçus que l'API simulée sert (#129, #130, #135) — en JSON, à la forme de leur
/// route, lus par le type GÉNÉRÉ comme le service réel. Des réponses FIXES et plausibles :
/// le faux serveur ne recalcule pas la règle du vrai (qui lit, comment se nomme un lieu,
/// la casse d'un nom) — quelle que soit la saisie, il rend celles-ci.
enum FixturesApercus {
    typealias Reponse = FixturesAcces.Reponse

    /// POST /lectures/apercu → `ApercuLecture` : la réponse du serveur à une panne
    /// (`front/e2e/apercus-lecture.json` de coprofirst v3.88.1).
    static let apercuLecture = #"""
        {"lecture": {"cle": "copro_locataires", "icones": ["key-round", "user"],
          "court": "Copropriétaires + locataires", "long": "Copropriétaires et locataires",
          "titre": "Copropriétaires et locataires", "profils": ["occupants", "copro_bailleurs", "locataires"],
          "perimetre_reserve": false, "hors_perimetre": ["occupants", "copro_bailleurs", "locataires"],
          "du_perimetre": "", "phrase": "Lue par les copropriétaires et locataires, dans toute la copropriété.",
          "exclus": "Pas les bailleurs (mandataires).", "par_defaut": false, "avertissement": ""},
         "destinataires_par_defaut": ["copropriétaires_occupants", "bailleurs", "locataires"],
         "lue_du_seul_conseil": false}
        """#
    static let cleLecture = "copro_locataires"

    /// POST /perimetres/libelle → `LibellePerimetre` : « le toit du bâtiment A », tel que le
    /// parcours des tests le choisit…
    static let libellePerimetre = #"""
        {"libelle": "Bâtiment A › Toit", "badge": "Bâtiment A › Toit"}
        """#
    /// … et le périmètre par défaut (`copropriete` de `FixturesPerimetres`) : le libellé est
    /// en clair, le badge vide (rien sur une carte).
    static let libelleParDefaut = #"""
        {"libelle": "Toute la copropriété", "badge": ""}
        """#
    static let codeParDefaut = "copropriete"

    /// POST /noms/affiche → `NomRendu` : une personne fictive.
    static let nomRendu = #"""
        {"nom_affiche": "Camille EXEMPLE"}
        """#

    /// Chaque réponse et le schéma de sa route, pour le juge (`scripts/verifier-fixtures.py`).
    static let parSchema: [Reponse] = [
        Reponse(nom: "apercuLecture", schema: "ApercuLecture", json: apercuLecture),
        Reponse(nom: "libellePerimetre", schema: "LibellePerimetre", json: libellePerimetre),
        Reponse(nom: "libelleParDefaut", schema: "LibellePerimetre", json: libelleParDefaut),
        Reponse(nom: "nomRendu", schema: "NomRendu", json: nomRendu),
    ]

    static func lecture() throws -> Lecture {
        Lecture(try Relecture.generee(Components.Schemas.ApercuLecture.self, json: apercuLecture).lecture)
    }

    /// Le défaut seul a sa réponse ; toute autre sélection reçoit celle du toit.
    static func lieu(_ codes: [String] = []) throws -> String {
        let json = codes == [codeParDefaut] ? libelleParDefaut : libellePerimetre
        return try Relecture.generee(Components.Schemas.LibellePerimetre.self, json: json).libelle
    }

    static func nom() throws -> String {
        try Relecture.generee(Components.Schemas.NomRendu.self, json: nomRendu).nomAffiche
    }
}

extension ServiceSimule: ServiceApercus {
    func lecture(de saisie: SaisieLecture, dans installation: Installation) async throws -> Lecture {
        try FixturesApercus.lecture()
    }

    func lieu(de codes: [String], dans installation: Installation) async throws -> String {
        try FixturesApercus.lieu(codes)
    }

    func nomAffiche(_ saisie: NomSaisi, dans installation: Installation) async throws -> String {
        try FixturesApercus.nom()
    }
}
#endif
