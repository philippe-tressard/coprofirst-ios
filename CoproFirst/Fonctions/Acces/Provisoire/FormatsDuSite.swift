// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// ⚠️ PROVISOIRE (#13) : les formats du site, à la même règle que lui.
///
/// - `date` : `fmtDate` de `front/src/lib/date.ts` — « 2 avr. 2026 », fuseau de Paris ;
/// - `dateCourte` : `fmtDateShort` — « 10/04/2026 » ;
/// - `nombre` : `fmtNombre` de `front/src/lib/utils.ts` — `Intl.NumberFormat('fr-FR')`.
///
/// Absent → « — », comme le site. Ces formats servent à deux menus (Accès,
/// Prestataires) et sans doute aux quatre : ils iront dans `Commun/Texte/` — demande
/// faite à la coordination le 04/11/2026.
enum FormatsDuSite {
    static let tiret = "—"
    private static let locale = Locale(identifier: "fr_FR")
    private static let paris = TimeZone(identifier: "Europe/Paris") ?? .current

    static func date(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(
            Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, timeZone: paris)
                .day().month(.abbreviated).year())
    }

    static func dateCourte(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(
            Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, timeZone: paris)
                .day(.twoDigits).month(.twoDigits).year())
    }

    static func date(_ iso: String?) -> String { date(lire(iso)) }
    static func dateCourte(_ iso: String?) -> String { dateCourte(lire(iso)) }

    static func nombre(_ valeur: Double?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(.number.locale(locale))
    }

    static func nombre(_ valeur: Int?) -> String { nombre(valeur.map(Double.init)) }

    /// Une date de l'API : « 2026-04-10 » (un jour : minuit UTC, comme `new Date()` le
    /// lit) ou un horodatage ISO, avec ou sans fuseau (sans fuseau : l'heure de Paris).
    static func lire(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        if iso.count == 10 {
            var jour = Date.ISO8601FormatStyle().year().month().day()
            jour.timeZone = TimeZone(identifier: "UTC") ?? .gmt
            return try? jour.parse(iso)
        }
        if let avecFuseau = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(iso) {
            return avecFuseau
        }
        if let avecFuseau = try? Date.ISO8601FormatStyle().parse(iso) { return avecFuseau }
        // Sans fuseau : UTC, comme le transcodeur du client généré (`TranscodeurDates`).
        let formateur = DateFormatter()
        formateur.locale = Locale(identifier: "en_US_POSIX")
        formateur.timeZone = TimeZone(identifier: "UTC")
        for motif in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            formateur.dateFormat = motif
            if let date = formateur.date(from: iso) { return date }
        }
        return nil
    }

    /// Un jour « 2026-04-10 » à minuit, heure de l'appareil — ce que `new Date()` du
    /// site compare à `minuitDuJour()` pour dire une visite en retard.
    static func jourLocal(_ iso: String?) -> Date? {
        guard let iso, iso.count >= 10 else { return nil }
        let parties = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parties.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parties[0], month: parties[1], day: parties[2]))
    }

    /// L'année d'une date de l'API, à l'heure de l'appareil (`getFullYear`).
    static func annee(_ iso: String?) -> Int? {
        lire(iso).map { Calendar.current.component(.year, from: $0) }
    }
}
