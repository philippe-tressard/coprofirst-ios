// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

extension Apercu {
    /// Des pastilles de lecture (`lecture`, #129) telles que coprofirst v3.88.1 (contrat
    /// 1.26.0) les sert — reprises des réponses que la règle du serveur produit
    /// (`front/e2e/apercus-lecture.json`), jamais composées ici. En JSON, lues par le
    /// MÊME décodeur que le service réel (`Relecture`) ; `meta` du fil les cite telles
    /// quelles. Rien d'une personne.
    static let lecturesServies: [String: String] = [
        "cs": #"""
            {"cle": "cs", "icones": ["shield-check"], "court": "CS", "long": "Conseil syndical seul",
             "titre": "Conseil syndical seul", "profils": [], "perimetre_reserve": false, "hors_perimetre": [],
             "du_perimetre": "", "phrase": "Personne d’autre que le conseil syndical ne la lit, à part son auteur.",
             "exclus": "", "par_defaut": false, "avertissement": ""}
            """#,
        "copros": #"""
            {"cle": "coproprietaires", "icones": ["key-round"], "court": "Copropriétaires",
             "long": "Copropriétaires (occupants et bailleurs)", "titre": "Copropriétaires (occupants et bailleurs)",
             "profils": ["occupants", "copro_bailleurs"], "perimetre_reserve": false,
             "hors_perimetre": ["occupants", "copro_bailleurs"], "du_perimetre": "",
             "phrase": "Lue par les copropriétaires (occupants et bailleurs), dans toute la copropriété.",
             "exclus": "Pas les bailleurs (mandataires), ni les locataires.", "par_defaut": false, "avertissement": ""}
            """#,
        "concerne": #"""
            {"cle": "concerne", "icones": ["lock"], "court": "Concerné", "long": "Résident concerné",
             "titre": "Résident concerné", "profils": [], "perimetre_reserve": false, "hors_perimetre": [],
             "du_perimetre": "",
             "phrase": "Lue par la personne concernée et par le conseil syndical, personne d’autre.",
             "exclus": "", "par_defaut": false, "avertissement": ""}
            """#,
        "reserve": #"""
            {"cle": "copro_locataires", "icones": ["key-round", "user"], "court": "Copropriétaires + locataires",
             "long": "Copropriétaires et locataires", "titre": "Copropriétaires et locataires · du périmètre seulement",
             "profils": ["occupants", "copro_bailleurs", "locataires"], "perimetre_reserve": true,
             "hors_perimetre": [], "du_perimetre": "",
             "phrase": "Lue par les copropriétaires et locataires, dans le périmètre seulement.",
             "exclus": "Pas les bailleurs (mandataires), ni les personnes hors du périmètre.", "par_defaut": false,
             "avertissement": ""}
            """#,
        "tous": #"""
            {"cle": "tous", "icones": ["users-round"], "court": "Tous", "long": "Tous", "titre": "Tous",
             "profils": ["occupants", "copro_bailleurs", "bailleurs", "locataires"], "perimetre_reserve": false,
             "hors_perimetre": ["occupants", "copro_bailleurs", "bailleurs", "locataires"], "du_perimetre": "",
             "phrase": "Lue par tous.", "exclus": "", "par_defaut": true, "avertissement": ""}
            """#,
    ]

    /// Une pastille servie, par son nom ci-dessus — `nil` pour un nom inconnu.
    static func lecture(_ nom: String) -> Lecture? {
        lecturesServies[nom].flatMap { try? Relecture.lire(Lecture.self, json: Data($0.utf8)) }
    }
}
