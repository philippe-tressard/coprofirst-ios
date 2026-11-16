// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Un avis du conseil syndical sur un prestataire (`NotationRead`, coprofirst#2728 à #2745,
/// #207) : un ÉTAT (mauvais, neutre, excellent), son auteur, son commentaire, et le droit
/// SERVI de le corriger (`peut_modifier`).
struct AvisPrestataire: Hashable, Sendable, Identifiable {
    let id: Int
    var etat: String
    var commentaire: String?
    var auteurNom: String?
    var creeLe: Date
    var peutModifier = false
    /// L'affaire jugée et le contrat de rattachement — `nil` hors affaire, hors contrat.
    var ticketId: Int?
    var contratId: Int?
}

extension AvisPrestataire {
    init(_ lu: Components.Schemas.NotationRead) {
        self.init(
            id: lu.id, etat: lu.etat ?? "", commentaire: lu.commentaire?.nulSiVide, auteurNom: lu.auteurNom,
            creeLe: lu.creeLe, peutModifier: lu.peutModifier ?? false, ticketId: lu.ticketId, contratId: lu.contratId)
    }
}

/// L'état d'un avis ou d'une moyenne, en clair — la table GÉNÉRÉE du site
/// (`TablesNotations`, `notations.ts`) : l'app ne recopie ni libellé, ni teinte, ni seuil.
enum EtatAvis {
    /// Un état inconnu se montre brut, en gris (`LibelleTeinte.brut`).
    static func libelle(_ etat: String) -> String { TablesNotations.libelles[etat] ?? etat }
    static func teinte(_ etat: String) -> String { TablesNotations.teintes[etat] ?? "badge-gray" }

    /// `etatDeMoyenne` du site : sous la première borne franchie, son état ; au-delà, le dernier.
    static func deMoyenne(_ moyenne: Double) -> String {
        TablesNotations.seuilsDeMoyenne.first { moyenne < $0.borne }?.etat ?? TablesNotations.etatAuDela
    }
}

/// Un exercice du récapitulatif d'un prestataire (`ExerciceInterventions`, R3d) : ses
/// interventions, ses avis sans affaire, le compte des états — tout est SERVI par
/// `GET /prestataires/{id}/interventions`, l'app ne regroupe ni ne compte rien.
struct ExerciceAvis: Hashable, Sendable, Identifiable {
    let annee: Int
    var libelle: String
    var nbInterventions: Int
    var nbNotees: Int
    var compte: [String: Int]
    var lignes: [LigneIntervention]
    var id: Int { annee }
}

/// Une ligne d'un exercice : une affaire du prestataire et les avis portés sur ce couple
/// (aucun : « non notée »), ou la ligne des avis sans affaire.
struct LigneIntervention: Hashable, Sendable, Identifiable {
    let id: String
    var date: Date?
    var numero: String?
    var titre: String
    var avis: [AvisPrestataire]
}

extension ExerciceAvis {
    init(_ lu: Components.Schemas.ExerciceInterventions) {
        var lignes = (lu.interventions ?? []).map {
            LigneIntervention(
                id: "t\($0.ticketId)", date: $0.date, numero: $0.numero, titre: $0.titre,
                avis: ($0.avis ?? []).map(AvisPrestataire.init))
        }
        let generaux = (lu.avisGeneraux ?? []).map(AvisPrestataire.init)
        if !generaux.isEmpty {
            lignes.append(LigneIntervention(id: "generaux", titre: TextesAvisPrestataire.sansAffaire, avis: generaux))
        }
        self.init(
            annee: lu.annee, libelle: lu.libelle, nbInterventions: lu.nbInterventions ?? 0,
            nbNotees: lu.nbNotees ?? 0, compte: lu.compte?.additionalProperties ?? [:], lignes: lignes)
    }

    /// Le compte des états, dans l'ordre du site — seuls ceux qui en ont.
    var comptes: [(etat: String, nombre: Int)] {
        TablesNotations.etats.compactMap { etat in compte[etat].flatMap { $0 > 0 ? (etat, $0) : nil } }
    }
}

extension LigneIntervention {
    init(id: String, titre: String, avis: [AvisPrestataire]) {
        self.init(id: id, date: nil, numero: nil, titre: titre, avis: avis)
    }
}

/// Les textes des avis — ceux de `NotationsPrestataire.svelte`.
enum TextesAvisPrestataire {
    static let sansAffaire = "Avis sans affaire"
    static let nonNotee = "non notée"
    static func exercice(_ libelle: String) -> String { "Exercice \(libelle)" }
    /// « 5 interventions · 4 notées ».
    static func nombres(_ exercice: ExerciceAvis) -> String {
        let interventions = exercice.nbInterventions > 1 ? "interventions" : "intervention"
        let notees = exercice.nbNotees > 1 ? "notées" : "notée"
        return "\(FormatsDuSite.nombre(exercice.nbInterventions)) \(interventions)\(Separateur.point)"
            + "\(FormatsDuSite.nombre(exercice.nbNotees)) \(notees)"
    }
    /// « 3 Excellent ».
    static func compte(_ nombre: Int, _ etat: String) -> String {
        "\(FormatsDuSite.nombre(nombre)) \(EtatAvis.libelle(etat))"
    }
    /// Le badge de moyenne de la carte : « Excellent · 4,5/5 ».
    static func moyenne(_ moyenne: Double) -> String {
        "\(EtatAvis.libelle(EtatAvis.deMoyenne(moyenne)))\(Separateur.point)\(FormatsDuSite.nombre(moyenne))/5"
    }
    /// Ce que VoiceOver lit du badge de moyenne : « Excellent, 4,33 sur 5, 3 avis ».
    static func moyenneEnClair(_ moyenne: Double, nombre: Int) -> String {
        "\(EtatAvis.libelle(EtatAvis.deMoyenne(moyenne))), \(FormatsDuSite.nombre(moyenne)) sur 5, "
            + "\(FormatsDuSite.nombre(nombre)) avis"
    }
    /// Ce que VoiceOver lit d'un badge d'avis.
    static func badge(_ avis: AvisPrestataire) -> String {
        "Avis \(EtatAvis.libelle(avis.etat))"
    }
    static func indice(ouvert: Bool) -> String { ouvert ? "Replie l'avis" : "Déplie l'avis" }
}
