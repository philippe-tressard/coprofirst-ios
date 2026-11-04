// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Ma résidence » dans l'API simulée : tout est inventé — aucune personne, aucune
/// adresse réelle. Le HTML est celui de l'éditeur du site, pour que la porte
/// `TexteDuSite` ait à travailler (#22).
extension ServiceSimule: ServiceResidence {
    func fiche(_ installation: Installation) async throws -> ContenuFiche {
        try await Task.sleep(for: .milliseconds(450))
        return Self.contenuFiche
    }

    func rapport(_ id: Int, nom: String, dans installation: Installation) async throws -> URL {
        try await document(id, nom: nom, dans: installation)
    }

    func carnet(perimetre: String?, dans installation: Installation) async throws -> ContenuCarnet {
        try await Task.sleep(for: .milliseconds(450))
        let entrees = Self.carnet.filter { perimetre == nil || perimetre == "bat_a" || $0.equipement != "ascenseur" }
        return ContenuCarnet(
            entrees: entrees,
            libellesEquipements: ["ascenseur": "Ascenseur", "chaufferie": "Chaufferie", "toiture": "Toiture"])
    }

    func perimetres(_ installation: Installation) async throws -> [Perimetre] {
        [
            Perimetre(code: "bat_a", libelle: "Bâtiment A"), Perimetre(code: "bat_b", libelle: "Bâtiment B"),
            Perimetre(code: "parking", libelle: "Parking"),
        ]
    }

    func accesReglement(_ installation: Installation) async throws -> Bool { true }

    func reglement(_ installation: Installation) async throws -> (EtatReglement, [QuestionReglement]) {
        try await Task.sleep(for: .milliseconds(450))
        let etat = EtatReglement(disponible: true, texteDisponible: true, lienReglement: nil)
        return (etat, verrouQuestions.withLock { questionsPosees } + [Self.question])
    }

    func poser(_ question: String, dans installation: Installation) async throws -> QuestionReglement {
        try await Task.sleep(for: .seconds(2))
        let modele = Self.question
        var reponse = QuestionReglement(
            id: Int.random(in: 1_000...9_999), question: question, reponse: modele.reponse,
            verdictLibelle: modele.verdictLibelle, poseeLe: .now, texteEnVigueur: true, dansLaFAQ: false,
            extraits: modele.extraits)
        reponse.selonReglement = modele.selonReglement
        reponse.reserves = modele.reserves
        reponse.provenance = modele.provenance
        reponse.modele = modele.modele
        verrouQuestions.withLock { questionsPosees.insert(reponse, at: 0) }
        return reponse
    }
}

/// Les questions posées pendant la séance simulée (un toucher les ajoute en tête).
nonisolated(unsafe) private var questionsPosees: [QuestionReglement] = []
private let verrouQuestions = NSLock()

extension ServiceSimule {
    static let contenuFiche: ContenuFiche = {
        func jour(_ texte: String) -> Date? { FormatsDuSite.lire(texte) }
        func document(
            _ id: Int, _ titre: String, _ fichier: String, description: String? = nil, batiment: Int? = nil,
            annee: Int? = nil, date: String? = nil, parent: Int? = nil, regle: Int? = nil, rapport: Int? = nil
        ) -> DocumentResidence {
            DocumentResidence(
                id: id, titre: titre, description: description, fichier: fichier, batimentId: batiment, annee: annee,
                date: date.flatMap(jour), parent: parent, regle: regle, rapport: rapport)
        }
        return ContenuFiche(
            fiche: FicheResidence(
                nom: "Résidence Les Tilleuls", adresse: "12 allée des Tilleuls, 00000 Ville-Exemple", photo: nil,
                immatriculation: "AA0-000-000", lotsPrincipaux: 48, lotsTotal: 112, parkingsCommuns: 4,
                assurance: "Mutuelle Exemple", assuranceEcheance: jour("2027-03-31"), assuranceReconduit: true,
                syndic: "Cabinet Exemple Gestion", syndicEcheance: jour("2026-06-30"), syndicEchu: true),
            batiments: [
                Batiment(id: 1, numero: "A", parkings: 18, caves: 24, appartements: 24, locauxCommerciaux: 1),
                Batiment(id: 2, numero: "B", parkings: 14, caves: 22, appartements: 23, locauxCommerciaux: 0),
            ],
            regles: [
                RegleResidence(
                    id: 1, titre: "Tri des déchets",
                    contenu: "<p>Les bacs <strong>jaunes</strong> reçoivent les emballages ; le verre va au "
                        + "conteneur de la rue.</p><ul><li>Sortie des bacs le mardi soir</li>"
                        + "<li>Encombrants : sur rendez-vous</li></ul>"),
                RegleResidence(
                    id: 2, titre: "Travaux bruyants",
                    contenu: "<p>En semaine de 8 h à 19 h, le samedi de 9 h à 12 h. Jamais le dimanche.</p>"),
            ],
            plans: [
                document(10, "Plan de masse de la résidence", "plan-masse.pdf"),
                document(11, "Plan du sous-sol", "sous-sol.pdf", description: "Caves et locaux techniques.",
                         batiment: 1),
            ],
            reglements: [
                document(20, "Règlement de copropriété", "reglement.pdf",
                         description: "Version consolidée, avec le modificatif de 2019.", date: "2019-05-14"),
            ],
            comptesRendus: [
                document(30, "PV de l'assemblée générale ordinaire", "pv-ag-2026.pdf", annee: 2026, date: "2026-06-12"),
                document(31, "PV de l'assemblée générale ordinaire", "pv-ag-2025.pdf", annee: 2025, date: "2025-06-20"),
            ],
            diagnostics: [
                TypeDiagnostic(
                    id: 1, nom: "Diagnostic technique global",
                    texteLegislatif: "Article L.731-1 du Code de la construction et de l'habitation.",
                    frequence: "Tous les 10 ans", nonApplicable: false,
                    rapports: [
                        RapportDiagnostic(
                            id: 5, titre: "DTG — rapport final", fichier: "dtg.pdf", date: jour("2024-11-04"),
                            synthese: "<p>Bon état général. <strong>Toiture</strong> à reprendre d'ici cinq ans.</p>"),
                    ]),
                TypeDiagnostic(
                    id: 2, nom: "Repérage amiante",
                    texteLegislatif: "Article R.1334-29-5 du Code de la santé publique.",
                    frequence: nil, nonApplicable: false, rapports: []),
                TypeDiagnostic(
                    id: 3, nom: "Termites", texteLegislatif: "Hors zone délimitée.", frequence: nil,
                    nonApplicable: true, rapports: []),
            ],
            annexes: [
                document(40, "Calendrier de collecte", "collecte.pdf", regle: 1),
                document(41, "Annexe : plan des réseaux", "reseaux.pdf", parent: 11),
            ])
    }()

    static let carnet: [EntreeCarnet] = [
        EntreeCarnet(
            date: "2026-10-28", libelle: "Révision annuelle de la chaudière", origine: "intervention",
            detail: "Remplacement du brûleur.", numero: nil, equipement: "chaufferie", lien: nil, alerte: nil,
            extrait: nil),
        EntreeCarnet(
            date: "2026-09-15", libelle: "Contrat d'entretien de l'ascenseur", origine: "contrat",
            detail: "Visite mensuelle.", numero: nil, equipement: "ascenseur", lien: nil,
            alerte: "visite attendue le 01/10/2026", extrait: nil),
        EntreeCarnet(
            date: "2026-08-02", libelle: "Fuite sur la colonne d'eau froide", origine: "affaire",
            detail: nil, numero: "A-0029", equipement: "chaufferie", lien: "/tickets/29", alerte: nil,
            extrait: "<p>La colonne a été <em>remplacée</em> sur deux étages.</p>"),
        EntreeCarnet(
            date: "2026-04-11", libelle: "Démoussage de la toiture", origine: "intervention",
            detail: nil, numero: nil, equipement: "toiture", lien: nil, alerte: nil, extrait: nil),
        EntreeCarnet(
            date: "2025-12-03", libelle: "Remplacement d'un luminaire du hall", origine: "affaire",
            detail: nil, numero: "A-0012", equipement: nil, lien: "/tickets/12", alerte: nil, extrait: nil),
    ]

    static let question = QuestionReglement(
        id: 1, question: "Puis-je installer une climatisation sur mon balcon ?",
        reponse: "<p>Oui, <strong>sous conditions</strong> : l'unité extérieure modifie l'aspect de la façade, "
            + "ce qui demande une autorisation de l'assemblée générale.</p>",
        verdictLibelle: "Sous conditions", poseeLe: FormatsDuSite.lire("2026-10-20T08:05:00") ?? .now,
        texteEnVigueur: true,
        selonReglement: "<p>L'article 9 interdit de modifier l'aspect extérieur sans accord de l'AG.</p>",
        selonAG: nil, synthese: nil, reserves: "<p>Le bruit de l'unité reste soumis aux règles de voisinage.</p>",
        provenance: "le règlement de copropriété de 2019", modele: "l'assistant", auteur: nil, dansLaFAQ: false,
        extraits: [
            ExtraitReglement(
                citation: "Aucune modification de l'aspect extérieur ne pourra être faite sans l'autorisation "
                    + "de l'assemblée générale.",
                verifie: true, reference: "Art. 9", apport: "Fonde l'autorisation préalable.",
                acte: "Règlement de copropriété", page: "14", source: "reglement"),
            ExtraitReglement(
                citation: "Les balcons restent à l'usage exclusif du lot.", verifie: false, reference: "Art. 4",
                apport: nil, acte: nil, page: nil, source: "reglement"),
        ])
}
