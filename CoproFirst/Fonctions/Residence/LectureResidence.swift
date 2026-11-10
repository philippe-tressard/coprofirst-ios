// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

// Les réponses du client généré → les modèles de « Ma résidence ». Aucune règle
// n'y est ajoutée : chaque champ est celui que le serveur sert.

extension FicheResidence {
    init(lue c: Components.Schemas.CoproprieteRead) {
        self.init(
            nom: c.nom, adresse: c.adresse, photo: c.photoUrl, immatriculation: c.numeroImmatriculation,
            lotsPrincipaux: c.nbLotsPrincipaux, lotsTotal: c.nbLotsTotal, parkingsCommuns: c.nbParkingsCommuns ?? 0,
            assurance: c.assuranceCompagnie, assuranceEcheance: FormatsDuSite.lire(c.assuranceEcheance),
            assuranceReconduit: c.assuranceReconduit ?? false, syndic: c.syndicCabinet,
            syndicEcheance: FormatsDuSite.lire(c.syndicEcheance), syndicEchu: c.syndicEchu ?? false)
    }
}

extension Batiment {
    init(lu b: Components.Schemas.BatimentRead) {
        self.init(
            id: b.id, numero: b.numero, parkings: b.nbParkings ?? 0, caves: b.nbCaves ?? 0,
            appartements: b.nbAppartements ?? 0, locauxCommerciaux: b.nbLocauxCommerciaux ?? 0)
    }
}

extension DocumentResidence {
    init(lu d: Components.Schemas.DocumentRead) {
        self.init(
            id: d.id, titre: d.titre, description: d.description.flatMap { $0.isEmpty ? nil : $0 },
            fichier: d.fichierNom, batimentId: d.batimentId, annee: d.annee,
            date: FormatsDuSite.lire(d.dateAg ?? d.dateDocument), parent: d.documentParentId, regle: d.regleResidenceId,
            rapport: d.diagnosticRapportId)
    }
}

extension TypeDiagnostic {
    init(lu t: Components.Schemas.DiagnosticTypeRead) {
        self.init(
            id: t.id, nom: t.nom, texteLegislatif: t.texteLegislatif, frequence: t.frequence,
            nonApplicable: t.nonApplicable ?? false,
            rapports: (t.rapports ?? []).map {
                RapportDiagnostic(
                    id: $0.id, titre: $0.titre, fichier: $0.fichierNom, date: FormatsDuSite.lire($0.dateRapport),
                    synthese: $0.synthese.flatMap { $0.isEmpty ? nil : $0 })
            })
    }
}

extension QuestionReglement {
    init(lue q: Components.Schemas.QuestionReglementRead) {
        self.init(
            id: q.id, question: q.question, reponse: q.reponse, reponseSansRenvois: q.reponseSansRenvois,
            verdictLibelle: q.verdictLibelle, poseeLe: q.creeLe,
            texteEnVigueur: q.texteEnVigueur, selonReglement: q.selonReglement, selonAG: q.selonAg,
            synthese: q.synthese, reserves: q.reserves, provenance: q.provenance, modele: q.modele,
            auteur: q.auteurNom, dansLaFAQ: q.faqItemId != nil,
            extraits: q.extraits.map {
                ExtraitReglement(
                    citation: $0.citation, verifie: $0.verifie, reference: $0.reference, apport: $0.apport,
                    acte: $0.acte, page: $0.page, source: $0.source)
            }, renvoisSansExtrait: q.renvoisSansExtrait)
    }
}
