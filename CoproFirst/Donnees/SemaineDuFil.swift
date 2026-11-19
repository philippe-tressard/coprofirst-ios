// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une semaine du carnet de l'iPhone pliable (#277) : du lundi au dimanche, lue par
/// `GET /flux?du=&au=` (coprofirst#2834, servi depuis coprofirst v3.116.0, sous le plancher).
///
/// Le SERVEUR range chaque carte à son jour (`FluxItem.jour`) : son échéance quand elle en
/// porte une, sa publication sinon. L'app ne recompose jamais ce rangement — une semaine
/// recalculée ici ne montrerait que les affaires datées (décision du 17/11/2026,
/// coprofirst#2834). Les jours s'y comparent par leur écriture ISO à Paris (`jourISO`), celle
/// que le serveur sert et reçoit : aucun fuseau ne s'y glisse.
struct SemaineDuFil: Hashable, Sendable {
    /// Minuit du lundi, au calendrier du fil (`Chronologie.calendrier`).
    let lundi: Date

    /// La semaine qui contient `jour`.
    init(contenant jour: Date) {
        let calendrier = Chronologie.calendrier
        let debut = calendrier.startOfDay(for: jour)
        // `weekday` : 1 pour dimanche, 2 pour lundi… — le lundi est 0, le dimanche 6.
        let rang = (calendrier.component(.weekday, from: debut) + 5) % 7
        lundi = calendrier.date(byAdding: .day, value: -rang, to: debut) ?? debut
    }

    /// Les sept jours, du lundi au dimanche.
    var jours: [Date] {
        (0..<7).map { Chronologie.calendrier.date(byAdding: .day, value: $0, to: lundi) ?? lundi }
    }

    var dimanche: Date { jours[6] }

    /// La période demandée au serveur : du lundi au dimanche, bornes incluses.
    var periode: ClosedRange<Date> { lundi...dimanche }

    /// La semaine d'avant (`-1`) ou d'après (`1`).
    func decalee(de semaines: Int) -> SemaineDuFil {
        SemaineDuFil(
            contenant: Chronologie.calendrier.date(byAdding: .day, value: 7 * semaines, to: lundi) ?? lundi)
    }

    func contient(_ jour: Date) -> Bool { SemaineDuFil(contenant: jour) == self }

    /// Les cartes de chaque jour, du lundi au dimanche, dans l'ordre servi (`jour`, puis
    /// l'heure). Une carte sans `jour` (une réponse sans période) n'a pas de place ici.
    func ranger(_ elements: [ElementDuFil]) -> [[ElementDuFil]] {
        jours.map { jour in
            let iso = FormatsDuSite.jourISO(jour)
            return elements.filter { $0.jourServi == iso }
        }
    }

    /// « Semaine du 16 novembre 2026 » : la date longue du site (`fmtDateLong`), jamais un
    /// format écrit ici.
    var titre: String { "\(TextesSemaine.semaine) du \(FormatsDuSite.dateLongue(lundi))" }
}

/// Les textes de la semaine du carnet — écrits une fois.
enum TextesSemaine {
    static let semaine = "Semaine"
    static let precedente = "Semaine précédente"
    static let suivante = "Semaine suivante"
    static let rien = "Rien ce jour"
    /// Les actions de VoiceOver : le même passage que le pincement et l'écartement.
    static let voirLaSemaine = "Voir la semaine"
    static let ouvrirCeJour = "Ouvrir ce jour"
}
