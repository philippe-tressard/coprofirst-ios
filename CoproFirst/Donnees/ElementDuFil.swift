// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI

/// Un élément du fil de la résidence — lu dans `FluxItem` de GET /flux, le flux que
/// lit le tableau de bord du site.
struct ElementDuFil: Identifiable, Hashable, Sendable {
    /// \`type:id\`, JAMAIS l'id seul (\`cleFluxItem\` du site) : le fil agrège plusieurs
    /// tables, et deux éléments de types différents peuvent porter le même id — un
    /// sondage ouvert puis clos en est un cas garanti.
    let id: String
    let type: String
    let date: Date
    let titre: String
    let detail: String?
    let badges: [String]
    /// `meta.urgente` d'une publication, et son `meta.statut`.
    let publicationUrgente: Bool
    let statut: String?
    let meConcerne: Bool
    /// Ce qu'ouvre un toucher sur la carte.
    let cible: CibleDuFil
    /// Le délai et les dates d'une affaire datée (`meta.affaire`, coprofirst v3.79.0) ;
    /// `nil` sans date, ou servi par une installation plus ancienne (#75).
    var echeance: EcheanceDuFil?
    /// Les natures de l'affaire que porte la carte (`meta.affaire.natures`, dérivées par
    /// le serveur) ; vide pour une rubrique qui n'en a pas — `NatureDeLaCarte` (#78).
    var natures: [String] = []
    /// « Qui la lit » (`meta.affaire.lecture`, #129) ; `nil` hors affaire, ou d'une
    /// installation antérieure.
    var lecture: Lecture?
    /// Le lieu de l'affaire (`meta.affaire.perimetre_libelle`, #130) ; `nil` pour le défaut.
    var lieu: String?
    /// Ses photos et documents (`meta.photos_urls`, `meta.fichiers_urls`), comme le site les lit.
    var pieces: PiecesJointes = .aucune

    var nature: NatureDuFil { NaturesDuFil.parType[type] ?? .inconnue }

    /// La règle du site (`estUrgent`, #lib/flux.ts) : une affaire ouverte de priorité
    /// haute, ou une actualité urgente non résolue.
    var urgent: Bool {
        (type == "ticket_ouvert" && badges.contains("urgent"))
            || (type == "publication" && publicationUrgente && statut != "resolu")
    }
}

extension ElementDuFil {
    /// Ce que la carte relit de `meta.affaire` — le MÊME branchement pour le service réel
    /// (`init(item:)`) et l'API simulée (`Apercu.fil`).
    mutating func poser(_ meta: MetaDuFil?) {
        natures = meta?.affaire?.natures ?? []
        lecture = meta?.affaire?.lecture?.valeur
        lieu = LieuServi.lieu(meta?.affaire?.perimetreLibelle)
        pieces = meta?.pieces ?? .aucune
    }
}

/// Une journée du fil : son en-tête, ses éléments du plus récent au plus ancien.
struct JourDuFil: Identifiable, Hashable, Sendable {
    let jour: Date
    let elements: [ElementDuFil]
    var id: Date { jour }
}

enum Chronologie {
    static let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.locale = Locale(identifier: "fr_FR")
        calendrier.timeZone = .current
        return calendrier
    }()

    /// Les éléments rangés jour par jour, le plus récent en tête.
    static func parJour(_ elements: [ElementDuFil]) -> [JourDuFil] {
        Dictionary(grouping: elements) { calendrier.startOfDay(for: $0.date) }
            .map { JourDuFil(jour: $0.key, elements: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.jour > $1.jour }
    }

    /// « AUJOURD'HUI · LUNDI 2 », « HIER · DIMANCHE 1ᵉʳ », puis « SAMEDI 31 OCTOBRE ».
    static func entete(_ jour: Date, maintenant: Date = .now) -> String {
        let quantieme = calendrier.component(.day, from: jour)
        let numero = quantieme == 1 ? "1ᵉʳ" : String(quantieme)
        let jourSemaine = jour.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR")))
        if calendrier.isDate(jour, inSameDayAs: maintenant) {
            return "Aujourd'hui · \(jourSemaine) \(numero)".uppercased()
        }
        if let hier = calendrier.date(byAdding: .day, value: -1, to: maintenant),
            calendrier.isDate(jour, inSameDayAs: hier)
        {
            return "Hier · \(jourSemaine) \(numero)".uppercased()
        }
        let memeAnnee = calendrier.isDate(jour, equalTo: maintenant, toGranularity: .year)
        let mois = jour.formatted(.dateTime.month(.wide).locale(Locale(identifier: "fr_FR")))
        let annee = memeAnnee ? "" : " \(calendrier.component(.year, from: jour))"
        return "\(jourSemaine) \(numero) \(mois)\(annee)".uppercased()
    }

    /// L'interlettrage des libellés en capitales (`styleLibelle`), en points.
    static let interlettrage: CGFloat = 0.6

    /// L'en-tête tel qu'il s'affiche : en capitales espacées, et « 1ᵉʳ » collé.
    ///
    /// Les lettres modificatives « ᵉʳ » (U+1D49, U+02B3) ont leur propre chasse dans
    /// la police système : elles s'écartaient du chiffre (« 1 e r », capture du
    /// 02/11/2026), interlettrage ou non. Le « er » devient un VRAI exposant — petit
    /// corps, surélevé, sans interlettrage.
    static func enteteAffiche(_ jour: Date, maintenant: Date = .now) -> AttributedString {
        espacer(entete(jour, maintenant: maintenant))
    }

    static func espacer(_ texte: String) -> AttributedString {
        var affiche = AttributedString(texte)
        affiche.tracking = interlettrage
        if let modificatives = affiche.range(of: "ᵉʳ") {
            // Le chiffre qui précède aussi : l'interlettrage s'ajoute APRÈS chaque glyphe.
            let chiffre = affiche.characters.index(before: modificatives.lowerBound)
            affiche[chiffre..<modificatives.lowerBound].tracking = 0
            var exposant = AttributedString("er")
            exposant.font = .caption2.weight(.semibold)
            exposant.baselineOffset = 3
            exposant.tracking = 0
            affiche.replaceSubrange(modificatives, with: exposant)
        }
        return affiche
    }
}
