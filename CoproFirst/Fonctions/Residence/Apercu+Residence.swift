// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Ma résidence » inventée : la forme des squelettes de la fiche, du carnet et du
/// règlement, et ce que sert le service simulé. Le HTML est celui de l'éditeur du site,
/// pour que la porte `TexteDuSite` ait à travailler (#22).
extension Apercu {
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

    /// Un avis à renvois (contrat 1.14.0) : chaque affirmation porte son renvoi, R3 n'a
    /// pas d'extrait derrière, R2 n'a pas été retrouvé mot pour mot.
    static let question = QuestionReglement(
        id: 1, question: "Puis-je installer une climatisation sur mon balcon ?",
        reponse: "<p>Oui, <strong>sous conditions</strong> : l'unité extérieure modifie l'aspect de la façade, "
            + "ce qui demande une autorisation de l'assemblée générale [R1]. L'assemblée de 2024 l'a accordée "
            + "pour les balcons sur cour [AG1]. Le bruit reste encadré [R3].</p>",
        reponseSansRenvois: "<p>Oui, <strong>sous conditions</strong> : l'unité extérieure modifie l'aspect "
            + "de la façade, ce qui demande une autorisation de l'assemblée générale. L'assemblée de 2024 l'a "
            + "accordée pour les balcons sur cour. Le bruit reste encadré.</p>",
        verdictLibelle: "Sous conditions", verdictTon: "alerte",
        poseeLe: FormatsDuSite.lire("2026-10-20T08:05:00") ?? .now, texteEnVigueur: true,
        selonReglement: "<ul><li>L'aspect extérieur ne se modifie pas sans l'accord de l'assemblée [R1].</li>"
            + "<li>Le balcon reste à l'usage exclusif du lot [R2].</li></ul>",
        selonAG: "<ul><li>La résolution 12 autorise les unités extérieures sur les balcons sur cour [AG1].</li></ul>",
        synthese: nil, reserves: "<p>Le bruit de l'unité reste soumis aux règles de voisinage.</p>",
        provenance: "le règlement de copropriété de 2019", modele: "l'assistant", auteur: nil, dansLaFAQ: false,
        extraits: [
            ExtraitReglement(
                citation: "Aucune modification de l'aspect extérieur ne pourra être faite sans l'autorisation "
                    + "de l'assemblée générale.",
                verifie: true, reference: "Art. 9", apport: "Fonde l'autorisation préalable.",
                acte: "Règlement de copropriété", rubrique: "Chapitre II", page: "p. 14", source: "reglement",
                renvoi: "R1"),
            ExtraitReglement(
                citation: "Les balcons restent à l'usage exclusif du lot.", verifie: false, reference: "Art. 4",
                apport: nil, acte: nil, page: nil, source: "reglement", renvoi: "R2"),
            ExtraitReglement(
                citation: "L'assemblée autorise l'installation d'unités extérieures sur les balcons donnant sur cour.",
                verifie: true, reference: "Résolution 12", apport: "Une autorisation déjà donnée.",
                acte: "AG du 12 juin 2024", rubrique: "Résolution 12", page: "p. 3", source: "ag", renvoi: "AG1"),
        ], renvoisSansExtrait: ["R3"])

    /// Un avis d'avant les renvois : il se lit section après section, comme avant.
    static let questionAvant = QuestionReglement(
        id: 2, question: "Puis-je poser une jardinière sur le garde-corps ?",
        reponse: "<p><strong>Non</strong> : le règlement interdit tout objet en surplomb de la façade.</p>",
        reponseSansRenvois: "<p><strong>Non</strong> : le règlement interdit tout objet en surplomb de la "
            + "façade.</p>",
        verdictLibelle: "Non", verdictTon: "danger",
        poseeLe: FormatsDuSite.lire("2026-06-02T18:40:00") ?? .now, texteEnVigueur: true,
        selonReglement: "<p>L'article 11 interdit les objets suspendus aux garde-corps.</p>",
        selonAG: nil, synthese: nil, reserves: nil, provenance: "le règlement de copropriété de 2019",
        modele: "l'assistant", auteur: nil, dansLaFAQ: true,
        extraits: [
            ExtraitReglement(
                citation: "Il ne pourra être suspendu aucun objet aux garde-corps des balcons.", verifie: true,
                reference: "Art. 11", apport: nil, acte: "Règlement de copropriété", page: "p. 16",
                source: "reglement"),
        ])
}
