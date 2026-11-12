// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les formats du site, à la MÊME règle que lui (#37) — fr-FR, fuseau de Paris :
///
/// | App | Site (coprofirst v3.61.0) | Rendu |
/// |---|---|---|
/// | `date(_:)` | `fmtDate`, `front/src/lib/date.ts` | « 2 avr. 2026 » |
/// | `dateCourte(_:)` | `fmtDateShort`, idem | « 02/04/2026 » |
/// | `dateLongue(_:)` | `fmtDateLong`, idem | « 2 avril 2026 » |
/// | `dateHeure(_:)` | `fmtDatetime`, idem | « 2 avr. 2026, 16:30 » |
/// | `dateHeureCourte(_:)` | `fmtDatetimeShort`, idem | « 02/04/2026 16:30 » |
/// | `heure(_:)` | `fmtTime`, idem | « 16:30 » |
/// | `jourCourt(_:semaine:)` | `fmtJourCourt`, idem (v3.79.0) | « mar. 17 nov. », « 19 nov. » |
/// | `jourISO(_:)` | `jourIso`, idem | « 2026-04-02 » (envoyé) |
/// | `moisAnnee(_:)` | `fmtMonthYear`, idem | « novembre 2026 » |
/// | `moisCourt(_:)` | `fmtMoisCourt`, idem | « nov. » |
/// | `nombre(_:)` | `fmtNombre`, `front/src/lib/utils.ts` | « 47 047 », « 64,5 » |
/// | `montant(_:devise:decimales:)` | `fmtMontant`, idem | « 1 234,5 € » |
/// | `octets(_:)` | `fmtOctets`, idem | « 512 Ko », « 3,4 Mo », « 1,25 Go » |
///
/// Une valeur absente s'écrit « — », comme sur le site. Aucun écran n'écrit son
/// propre format de date ou de nombre : il passe par ici.
enum FormatsDuSite {
    static let tiret = "—"
    private static let locale = Locale(identifier: "fr_FR")
    private static let posix = Locale(identifier: "en_US_POSIX")
    static let paris = TimeZone(identifier: "Europe/Paris") ?? .gmt

    // MARK: Dates

    /// `fmtDate` : « 2 avr. 2026 ».
    static func date(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(style.day().month(.abbreviated).year())
    }

    /// `fmtDateShort` : « 10/04/2026 ».
    static func dateCourte(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(style.day(.twoDigits).month(.twoDigits).year())
    }

    /// `fmtDateLong` : « 2 avril 2026 » (#12).
    static func dateLongue(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(style.day().month(.wide).year())
    }

    /// `fmtDatetime` : « 2 avr. 2026, 16:30 » — la date de `fmtDate`, une virgule,
    /// l'heure sur 24 h à Paris (#12).
    static func dateHeure(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return "\(date(valeur)), \(heure(valeur))"
    }

    /// `fmtDatetimeShort` : « 10/04/2026 14:30 » — la date courte, une espace, l'heure
    /// (#15, le journal des courriels).
    static func dateHeureCourte(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return "\(dateCourte(valeur)) \(heure(valeur))"
    }

    /// `fmtTime` : « 16:30 » — l'heure seule, sur 24 h à Paris (#41) : une
    /// notification du jour, une carte du fil.
    static func heure(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(style.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// Une date telle que l'API la sert (chaîne ISO), lue comme `new Date()` la lit.
    static func date(_ iso: String?) -> String { date(lire(iso)) }
    static func dateCourte(_ iso: String?) -> String { dateCourte(lire(iso)) }
    static func dateLongue(_ iso: String?) -> String { dateLongue(lire(iso)) }
    static func dateHeure(_ iso: String?) -> String { dateHeure(lire(iso)) }
    static func dateHeureCourte(_ iso: String?) -> String { dateHeureCourte(lire(iso)) }
    static func heure(_ iso: String?) -> String { heure(lire(iso)) }

    /// `fmtJourCourt` (coprofirst v3.79.0) : « mar. 17 nov. » — le jour d'un rendez-vous
    /// en peu de place, la vignette d'échéance du fil (#75). L'année ne s'ajoute que si
    /// elle n'est pas celle de `maintenant`, à Paris : « ven. 15 janv. 2027 ».
    /// `semaine: false` retire le jour de la semaine (« 19 nov. ») : la fin d'une plage.
    static func jourCourt(_ valeur: Date?, semaine: Bool = true, maintenant: Date = .now) -> String {
        guard let valeur else { return tiret }
        var format = style.day().month(.abbreviated)
        if semaine { format = format.weekday(.abbreviated) }
        if annee(valeur) != annee(maintenant) { format = format.year() }
        return valeur.formatted(format)
    }

    static func jourCourt(_ iso: String?, semaine: Bool = true, maintenant: Date = .now) -> String {
        jourCourt(lire(iso), semaine: semaine, maintenant: maintenant)
    }

    /// L'année d'un instant à Paris (le 31 décembre à 23 h 30 UTC est déjà l'an suivant).
    private static func annee(_ valeur: Date) -> Int {
        Calendar(identifier: .gregorian).dateComponents(in: paris, from: valeur).year ?? 0
    }

    /// `jourIso` : le JOUR de Paris d'un instant, « 2026-04-10 » — la valeur qu'un
    /// formulaire envoie pour une date (#15, la fin d'une délégation). Jamais le jour
    /// UTC : il est faux d'un jour entre minuit et deux heures.
    static func jourISO(_ valeur: Date) -> String {
        let jour = Calendar(identifier: .gregorian).dateComponents(in: paris, from: valeur)
        return String(format: "%04d-%02d-%02d", jour.year ?? 0, jour.month ?? 0, jour.day ?? 0)
    }

    /// `fmtMonthYear` : « novembre 2026 » — un mois servi « 2026-11 » (#16, la
    /// télémétrie sur douze mois), ou un instant.
    static func moisAnnee(_ valeur: Date?) -> String {
        guard let valeur else { return tiret }
        return valeur.formatted(style.month(.wide).year())
    }

    static func moisAnnee(_ mois: String?) -> String { moisAnnee(lire(mois.map { "\($0)-15" })) }

    /// `fmtMoisCourt` : « nov. » — le nom court d'un mois, de 1 à 12.
    static func moisCourt(_ mois: Int) -> String {
        lire(String(format: "2000-%02d-15", mois))?.formatted(style.month(.abbreviated)) ?? tiret
    }

    private static var style: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, timeZone: paris)
    }

    /// Une chaîne ISO lue comme le navigateur la lit (`new Date(d)`) :
    /// - un JOUR seul (« 2026-04-10 ») est minuit UTC ;
    /// - un horodatage avec `Z` ou un décalage est absolu ;
    /// - un horodatage SANS fuseau est l'heure locale du navigateur — celle de Paris
    ///   pour le site : c'est elle qui est retenue ici.
    static func lire(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        if iso.count == 10 { return analyser(iso, motif: "yyyy-MM-dd", fuseau: .gmt) }
        if let absolu = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(iso) { return absolu }
        if let absolu = try? Date.ISO8601FormatStyle().parse(iso) { return absolu }
        for motif in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            if let local = analyser(iso, motif: motif, fuseau: paris) { return local }
        }
        return nil
    }

    private static func analyser(_ texte: String, motif: String, fuseau: TimeZone) -> Date? {
        let formateur = DateFormatter()
        formateur.locale = posix
        formateur.timeZone = fuseau
        formateur.dateFormat = motif
        return formateur.date(from: texte)
    }

    // MARK: Personnes

    /// Le nom d'une personne : « Prénom NOM » tel que le SERVEUR l'affiche (`nom_affiche`,
    /// `locataire_nom_affiche`, `bailleur_nom_affiche`, `nom_aide_affiche` — contrat 1.25.0,
    /// coprofirst#2633 lot 4, #135), jamais composé dans un écran.
    ///
    /// Non servi ou vide — une installation antérieure, une saisie pas encore enregistrée
    /// (`POST /noms/affiche` n'est pas au client généré du plancher) — : le repli d'avant,
    /// prénom puis nom tels que servis, « — » sans l'un ni l'autre. Ce repli vit ICI
    /// seulement : `scripts/verifier-regles-servies.py` refuse toute autre composition.
    static func nom(affiche: String?, prenom: String?, nom: String?) -> String {
        if let servi = affiche?.trimmingCharacters(in: .whitespaces), !servi.isEmpty { return servi }
        let morceaux = [prenom, nom].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return morceaux.isEmpty ? tiret : morceaux.joined(separator: " ")
    }

    // MARK: Nombres

    /// `fmtNombre` : `Intl.NumberFormat('fr-FR')` — espace fine insécable entre les
    /// milliers, virgule décimale, trois décimales au plus, arrondi « au plus proche ».
    static func nombre(_ valeur: Double?) -> String {
        guard let valeur else { return tiret }
        return decimal(valeur).formatted(
            .number.locale(locale).precision(.fractionLength(0...3)).rounded(rule: .toNearestOrAwayFromZero))
    }

    static func nombre(_ valeur: Int?) -> String { nombre(valeur.map(Double.init)) }

    /// `fmtMontant` : une devise, de zéro à `decimales` décimales (2, ou 4 pour le coût
    /// d'un appel d'IA).
    static func montant(_ valeur: Double?, devise: String = "EUR", decimales: Int = 2) -> String {
        guard let valeur else { return tiret }
        return decimal(valeur).formatted(
            .currency(code: devise).locale(locale).precision(.fractionLength(0...decimales))
                .rounded(rule: .toNearestOrAwayFromZero))
    }

    /// `fmtOctets` : une taille de fichier — octets, Ko arrondis, Mo à une décimale, Go à
    /// deux ; les seuils sont ceux de l'arrondi (jamais « 1 024 Ko ») (#16).
    static func octets(_ valeur: Int?) -> String {
        guard let valeur else { return tiret }
        let octets = Double(valeur)
        if octets < 1024 { return "\(nombre(octets.rounded())) o" }
        let ko = octets / 1024
        if ko < 1023.5 { return "\(nombre(ko.rounded())) Ko" }
        let mo = ko / 1024
        if mo < 1023.95 { return "\(fixe(mo, decimales: 1)) Mo" }
        return "\(fixe(mo / 1024, decimales: 2)) Go"
    }

    /// Un nombre à décimales FIXES (`minimumFractionDigits` = `maximumFractionDigits`).
    private static func fixe(_ valeur: Double, decimales: Int) -> String {
        decimal(valeur).formatted(
            .number.locale(locale).precision(.fractionLength(decimales)).rounded(rule: .toNearestOrAwayFromZero))
    }

    /// Le nombre tel que JavaScript l'écrit (la plus courte écriture décimale) :
    /// arrondir `12.345` donne alors « 12,35 », comme `Intl`, et non « 12,34 ».
    private static func decimal(_ valeur: Double) -> Decimal {
        Decimal(string: String(valeur), locale: posix) ?? Decimal(valeur)
    }
}
