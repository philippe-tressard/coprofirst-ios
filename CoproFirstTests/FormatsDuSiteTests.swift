// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import Testing

@testable import CoproFirst

/// Les formats du site (#37). Chaque attendu est la sortie de `front/src/lib/date.ts`
/// et `utils.ts` (coprofirst v3.61.0) sous Node — le même `Intl` que le navigateur.

@Test(arguments: [
    ("2026-04-02", "2 avr. 2026", "02/04/2026"),
    ("2026-08-01", "1 août 2026", "01/08/2026"),  // le 1er, sans zéro devant
    ("2026-05-01", "1 mai 2026", "01/05/2026"),
    ("2026-12-31", "31 déc. 2026", "31/12/2026"),
    // Minuit à 2 h à Paris : le jour de Paris n'est pas le jour UTC.
    ("2026-07-25T21:59:00Z", "25 juil. 2026", "25/07/2026"),
    ("2026-07-25T22:00:00Z", "26 juil. 2026", "26/07/2026"),
    ("2026-07-25T23:30:00Z", "26 juil. 2026", "26/07/2026"),
    // Fin de mois en hiver (UTC+1) : le 1er du mois suivant à Paris.
    ("2026-01-31T23:30:00Z", "1 févr. 2026", "01/02/2026"),
    ("2026-03-31T22:30:00+00:00", "1 avr. 2026", "01/04/2026"),
    // Sans fuseau : l'heure locale du navigateur, celle de Paris.
    ("2026-07-25T23:30:00.123456", "25 juil. 2026", "25/07/2026"),
])
func lesDatesSontCellesDuSite(iso: String, date: String, courte: String) {
    #expect(FormatsDuSite.date(iso) == date)
    #expect(FormatsDuSite.dateCourte(iso) == courte)
}

/// `fmtDateLong` et `fmtDatetime` (#12) : chaque attendu est leur sortie sous Node
/// (coprofirst v3.62.0, `front/src/lib/date.ts`, fuseau du poste : Paris) ; la
/// « Dernière connexion » du Profil s'écrit ainsi (#41).
@Test(arguments: [
    ("2026-06-12", "12 juin 2026", "12 juin 2026, 02:00"),  // un jour seul : minuit UTC
    ("2026-08-01", "1 août 2026", "1 août 2026, 02:00"),
    ("2026-04-02T14:30:00Z", "2 avril 2026", "2 avr. 2026, 16:30"),
    // Minuit à 2 h à Paris : le jour de Paris n'est pas le jour UTC.
    ("2026-07-25T21:59:00Z", "25 juillet 2026", "25 juil. 2026, 23:59"),
    ("2026-07-25T22:00:00Z", "26 juillet 2026", "26 juil. 2026, 00:00"),
    ("2026-07-25T23:30:00Z", "26 juillet 2026", "26 juil. 2026, 01:30"),
    ("2026-01-31T23:30:00Z", "1 février 2026", "1 févr. 2026, 00:30"),
    // Passage à l'heure d'hiver (25/10, 3 h → 2 h) : deux instants, la même heure affichée.
    ("2026-10-24T23:59:00Z", "25 octobre 2026", "25 oct. 2026, 01:59"),
    ("2026-10-25T00:30:00Z", "25 octobre 2026", "25 oct. 2026, 02:30"),
    ("2026-10-25T01:30:00Z", "25 octobre 2026", "25 oct. 2026, 02:30"),
    // Passage à l'heure d'été (29/03, 2 h → 3 h) : 2 h n'existe pas.
    ("2026-03-29T00:59:00Z", "29 mars 2026", "29 mars 2026, 01:59"),
    ("2026-03-29T01:00:00Z", "29 mars 2026", "29 mars 2026, 03:00"),
    // Sans fuseau : l'heure locale du navigateur, celle de Paris.
    ("2026-07-25T23:30:00.123456", "25 juillet 2026", "25 juil. 2026, 23:30"),
    ("2026-10-20T08:05:00", "20 octobre 2026", "20 oct. 2026, 08:05"),
])
func lesDatesLonguesEtLesHeuresSontCellesDuSite(iso: String, longue: String, heure: String) {
    #expect(FormatsDuSite.dateLongue(iso) == longue)
    #expect(FormatsDuSite.dateHeure(iso) == heure)
}

/// `fmtTime` (#41) : l'heure seule d'une notification du jour, d'une carte du fil —
/// sortie de Node (coprofirst v3.62.1, `TZ=Europe/Paris`), changements d'heure compris.
@Test(arguments: [
    ("2026-06-12", "02:00"),  // un jour seul : minuit UTC
    ("2026-04-02T14:30:00Z", "16:30"),
    ("2026-07-25T21:59:00Z", "23:59"),
    ("2026-07-25T22:00:00Z", "00:00"),
    ("2026-10-25T00:30:00Z", "02:30"),  // heure d'hiver : deux instants, la même heure
    ("2026-10-25T01:30:00Z", "02:30"),
    ("2026-03-29T01:00:00Z", "03:00"),  // heure d'été : 2 h n'existe pas
    ("2026-10-20T08:05:00", "08:05"),  // sans fuseau : l'heure de Paris
    ("2026-11-04T09:07:00Z", "10:07"),
])
func lHeureSeuleEstCelleDuSite(iso: String, heure: String) throws {
    #expect(FormatsDuSite.heure(iso) == heure)
    let instant = try #require(FormatsDuSite.lire(iso))
    #expect(FormatsDuSite.heure(instant) == heure, "une date déjà décodée s'écrit pareil")
}

@Test func uneDateAbsenteSEcritParUnTiret() {
    #expect(FormatsDuSite.date(nil as String?) == "—")
    #expect(FormatsDuSite.dateCourte("") == "—")
    #expect(FormatsDuSite.date(nil as Date?) == "—")
    #expect(FormatsDuSite.dateLongue(nil as String?) == "—")
    #expect(FormatsDuSite.dateHeure("") == "—")
    #expect(FormatsDuSite.heure(nil as Date?) == "—")
}

@Test func uneDateDejaDecodeeSeFormateAParis() throws {
    let instant = try #require(try? Date.ISO8601FormatStyle().parse("2026-07-25T23:30:00Z"))
    #expect(FormatsDuSite.date(instant) == "26 juil. 2026")
}

@Test(arguments: [
    (47_047.0, "47\u{202F}047"),
    (64.5, "64,5"),
    (3.14159, "3,142"),
    (-1_234.5, "-1\u{202F}234,5"),
    (0.0, "0"),
    (1_000_000.0, "1\u{202F}000\u{202F}000"),
    (12.345, "12,345"),
    (1.0005, "1,001"),  // arrondi au plus proche, comme `Intl`
])
func lesNombresSontCeuxDuSite(valeur: Double, attendu: String) {
    #expect(FormatsDuSite.nombre(valeur) == attendu)
}

@Test func unNombreAbsentSEcritParUnTiret() {
    #expect(FormatsDuSite.nombre(nil as Int?) == "—")
    #expect(FormatsDuSite.nombre(42) == "42")
}

@Test(arguments: [
    (1_234.5, "1\u{202F}234,5\u{00A0}€"),
    (1_234.0, "1\u{202F}234\u{00A0}€"),
    (12.345, "12,35\u{00A0}€"),  // JavaScript arrondit l'écriture décimale, pas le binaire
    (0.0041, "0\u{00A0}€"),
])
func lesMontantsSontCeuxDuSite(valeur: Double, attendu: String) {
    #expect(FormatsDuSite.montant(valeur) == attendu)
}

@Test func unMontantDIAGardeQuatreDecimales() {
    #expect(FormatsDuSite.montant(0.0041, devise: "USD", decimales: 4) == "0,0041\u{00A0}$US")
    #expect(FormatsDuSite.montant(nil) == "—")
}

/// `PastilleStatut` est devenue un cas de `PastilleTeinte` : les teintes des
/// statuts d'affaire n'ont pas bougé.
@MainActor
@Test func lesTeintesDesAffairesNOntPasChange() {
    let attendues: [String: (KeyPath<Palette, Color>, KeyPath<Palette, Color>)] = [
        "badge-blue": (\.info, \.infoFond), "badge-purple": (\.violet, \.violetFond),
        "badge-orange": (\.orangeTexte, \.orangeFond), "badge-yellow": (\.jauneTexte, \.jauneFond),
        "badge-green": (\.successTexte, \.successFond), "badge-gray": (\.textMuted, \.neutreFond),
    ]
    for pastille in StatutsAffaire.pastilles.values {
        let (texte, fond) = PastilleTeinte.teintes(pastille)
        #expect(attendues[pastille]?.0 == texte && attendues[pastille]?.1 == fond, "\(pastille)")
    }
    let (texteRouge, fondRouge) = PastilleTeinte.teintes("badge-red")
    #expect(texteRouge == \Palette.danger && fondRouge == \Palette.dangerFond)
    #expect(LibelleTeinte.brut("inconnu") == LibelleTeinte("inconnu", "badge-gray"))
}

/// `fmtOctets` (#16, le dernier export) — sortie de Node (coprofirst v3.73.0) : les
/// seuils sont ceux de l'arrondi.
@Test(arguments: [
    (0, "0 o"), (512, "512 o"), (1_023, "1\u{202F}023 o"), (1_024, "1 Ko"), (1_048_000, "1\u{202F}023 Ko"),
    (1_048_500, "1,0 Mo"), (48_234_496, "46,0 Mo"), (1_342_177_280, "1,25 Go"),
])
func lesTaillesSontCellesDuSite(octets: Int, attendu: String) {
    #expect(FormatsDuSite.octets(octets) == attendu)
}

/// `fmtMoisCourt` et `fmtMonthYear` (#16, la télémétrie) — sortie de Node.
@Test func lesMoisSontCeuxDuSite() {
    #expect([1, 6, 7, 11, 12].map(FormatsDuSite.moisCourt) == ["janv.", "juin", "juil.", "nov.", "déc."])
    #expect(FormatsDuSite.moisAnnee("2026-11") == "novembre 2026")
    #expect(FormatsDuSite.moisAnnee("2026-01") == "janvier 2026")
    #expect(FormatsDuSite.moisAnnee(nil as String?) == "—")
    #expect(FormatsDuSite.octets(nil) == "—")
}

/// `fmtJourCourt` (#75) : la vignette d'échéance du fil. Chaque attendu est sa sortie sous
/// Node (coprofirst v3.79.0, `front/src/lib/date.ts`, `TZ=Europe/Paris`), « maintenant »
/// posé au 10 novembre 2026 : l'année ne s'écrit que si elle n'est pas celle-là.
@Test(arguments: [
    ("2026-11-17T08:00:00", "mar. 17 nov.", "17 nov."),  // sans fuseau : l'heure de Paris
    ("2026-11-19T16:00:00", "jeu. 19 nov.", "19 nov."),
    ("2026-11-01T09:00:00Z", "dim. 1 nov.", "1 nov."),  // le 1er, sans « er » ni zéro
    ("2026-06-12", "ven. 12 juin", "12 juin"),  // un jour seul : minuit UTC
    ("2026-02-03T10:00:00Z", "mar. 3 févr.", "3 févr."),
    ("2026-09-06T10:00:00Z", "dim. 6 sept.", "6 sept."),
    // Minuit à Paris n'est pas minuit UTC.
    ("2026-07-25T21:59:00Z", "sam. 25 juil.", "25 juil."),
    ("2026-07-25T22:00:00Z", "dim. 26 juil.", "26 juil."),
    // Une autre année : écrite. Le 31 décembre à 23 h 30 UTC est déjà 2027 à Paris.
    ("2027-01-15T09:00:00", "ven. 15 janv. 2027", "15 janv. 2027"),
    ("2026-12-31T22:30:00Z", "jeu. 31 déc.", "31 déc."),
    ("2026-12-31T23:30:00Z", "ven. 1 janv. 2027", "1 janv. 2027"),
])
func leJourCourtEstCeluiDuSite(iso: String, avecSemaine: String, sansSemaine: String) throws {
    let maintenant = try #require(FormatsDuSite.lire("2026-11-10T12:00:00Z"))
    #expect(FormatsDuSite.jourCourt(iso, maintenant: maintenant) == avecSemaine)
    #expect(FormatsDuSite.jourCourt(iso, semaine: false, maintenant: maintenant) == sansSemaine)
    #expect(FormatsDuSite.jourCourt(nil as String?) == "—")
}
