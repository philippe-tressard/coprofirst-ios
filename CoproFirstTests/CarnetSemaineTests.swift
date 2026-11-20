// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import CoproFirst

// Les deux suites du carnet de l'iPhone pliable : la semaine du Fil (#277), lue par
// `GET /flux?du=&au=` (coprofirst#2834), et le sommaire de « Ma résidence » (#278).

private let calendrier = Chronologie.calendrier

private func jour(_ iso: String) -> Date {
    // Midi : aucun passage d'heure ne change le jour.
    let minuit = calendrier.startOfDay(for: FormatsDuSite.lire(iso) ?? .distantPast)
    return calendrier.date(byAdding: .hour, value: 12, to: minuit) ?? minuit
}

private func iso(_ date: Date) -> String { FormatsDuSite.jourISO(date) }

struct SemaineDuFilTests {
    @Test func laSemaineVaDuLundiAuDimanche() {
        // Le mercredi 18 novembre 2026 et le dimanche 22 : la même semaine.
        let mercredi = SemaineDuFil(contenant: jour("2026-11-18"))
        #expect(iso(mercredi.lundi) == "2026-11-16")
        #expect(mercredi.jours.map(iso) == (16...22).map { "2026-11-\($0)" })
        #expect(SemaineDuFil(contenant: jour("2026-11-22")) == mercredi, "le dimanche ferme la semaine")
        #expect(SemaineDuFil(contenant: jour("2026-11-16")) == mercredi, "le lundi l'ouvre")
        #expect(iso(SemaineDuFil(contenant: jour("2026-11-23")).lundi) == "2026-11-23")
    }

    @Test func lesSemainesSeTournentEtFranchissentLesMoisEtLesAnnees() {
        let semaine = SemaineDuFil(contenant: jour("2026-12-30"))
        #expect(iso(semaine.lundi) == "2026-12-28")
        #expect(iso(semaine.dimanche) == "2027-01-03", "à cheval sur deux années")
        #expect(iso(semaine.decalee(de: -1).lundi) == "2026-12-21")
        #expect(iso(semaine.decalee(de: 1).lundi) == "2027-01-04")
        #expect(semaine.contient(jour("2027-01-03")))
        #expect(!semaine.contient(jour("2027-01-04")))
    }

    @Test func laPeriodeDemandeeEstLaSemaineEntiere() {
        let semaine = SemaineDuFil(contenant: jour("2026-11-18"))
        #expect(iso(semaine.periode.lowerBound) == "2026-11-16")
        #expect(iso(semaine.periode.upperBound) == "2026-11-22", "au : le dimanche, inclus")
    }

    @Test func chaqueCarteVaAuJourQueLeServeurSert() {
        let semaine = SemaineDuFil(contenant: jour("2026-11-18"))
        func carte(_ id: String, _ jourServi: String?) -> ElementDuFil {
            var element = ElementDuFil(
                id: "publication:\(id)", type: "publication", date: jour("2026-11-16"), titre: id, detail: nil,
                badges: [], publicationUrgente: false, statut: nil, meConcerne: false, cible: .affaire(id: 1))
            element.jourServi = jourServi
            return element
        }
        let rangees = semaine.ranger([carte("coupure", "2026-11-19"), carte("ag", "2026-11-16"), carte("hors", nil)])
        #expect(rangees.count == 7)
        #expect(rangees[3].map(\.titre) == ["coupure"], "au jeudi de son échéance, pas au lundi de sa publication")
        #expect(rangees[0].map(\.titre) == ["ag"])
        #expect(rangees.joined().count == 2, "une carte sans jour servi n'a pas de place")
    }

    @Test func leTitreDitLaSemaineAuFormatDuSite() {
        let semaine = SemaineDuFil(contenant: jour("2026-11-18"))
        #expect(semaine.titre == "Semaine du \(FormatsDuSite.dateLongue(semaine.lundi))")
        #expect(semaine.titre.hasSuffix("16 novembre 2026"))
    }

    /// Les cartes que l'API simulée sert sur deux mois autour d'aujourd'hui, datées par
    /// cette horloge.
    private func periode(_ horloge: Apercu.Horloge) -> [ElementDuFil] {
        Apercu.filDeLaPeriode(horloge.le(-30, a: 0)...horloge.le(30, a: 0), dans: Apercu.filInvente(horloge))
    }

    /// Le jour où l'API simulée range la coupure d'eau, face à l'attendu : deux jours après
    /// aujourd'hui, compté avec LA MÊME horloge qu'elle — même « maintenant », même
    /// calendrier, même fuseau (#316).
    private func coupure(_ horloge: Apercu.Horloge) -> (servi: String?, attendu: String) {
        (periode(horloge).first { $0.id == "publication:12" }?.jourServi, iso(horloge.le(2, a: 12)))
    }

    /// L'API simulée range une affaire datée à son échéance, comme le serveur.
    @Test func lApiSimuleeRangeUneEcheanceASonJour() {
        let jour = coupure(.appareil)
        #expect(jour.servi == jour.attendu, "« Coupure d'eau jeudi » : au jour de la coupure")
        #expect(periode(.appareil).allSatisfy { $0.jourServi != nil })
        let semaine = SemaineDuFil(contenant: .now)
        #expect(Apercu.filDeLaPeriode(semaine.periode).allSatisfy { semaine.ranger([$0]).joined().count == 1 })
    }

    /// Garde-fou de #316 : à 23:30 UTC un jour d'hiver, il est déjà demain à Paris. L'attendu
    /// d'avant (maintenant + 48 h, lu à Paris) donnait le 22 sur un appareil en UTC — le runner
    /// de la CI —, qui range la coupure au 21 : le test rougissait chaque nuit, main comprise.
    @Test(arguments: ["UTC", "Europe/Paris"])
    func lEcheanceSimuleeTientQuandIlEstDejaDemainAParis(_ fuseau: String) throws {
        var calendrier = Chronologie.calendrier
        calendrier.timeZone = try #require(TimeZone(identifier: fuseau))
        let maintenant = try #require(FormatsDuSite.lire("2026-11-19T23:30:00Z"))
        let jour = coupure(Apercu.Horloge(maintenant: maintenant, calendrier: calendrier))
        #expect(jour.servi == jour.attendu)
        #expect(jour.attendu == (fuseau == "UTC" ? "2026-11-21" : "2026-11-22"), "le jeudi de chaque appareil")
    }
}

struct ZoomDuCarnetTests {
    @Test func pincerResserreEtEcarterOuvre() {
        #expect(ZoomDuCarnet.franchi(0.8, vitesse: 0, sens: .resserrer))
        #expect(!ZoomDuCarnet.franchi(0.9, vitesse: 0, sens: .resserrer), "sous le seuil, la page revient")
        #expect(ZoomDuCarnet.franchi(0.94, vitesse: -2, sens: .resserrer), "un pincement vif suffit")
        #expect(!ZoomDuCarnet.franchi(0.94, vitesse: 2, sens: .resserrer), "décidé sur le SENS de la vitesse")
        #expect(!ZoomDuCarnet.franchi(1.5, vitesse: 3, sens: .resserrer), "écarter ne pince pas")
        #expect(ZoomDuCarnet.franchi(1.2, vitesse: 0, sens: .ecarter))
        #expect(!ZoomDuCarnet.franchi(0.5, vitesse: -3, sens: .ecarter))
    }

    @Test func laPageSuitLesDoigtsPuisResiste() {
        #expect(ZoomDuCarnet.suivie(1, sens: .resserrer) == 1)
        let debut = ZoomDuCarnet.suivie(0.99, sens: .resserrer)
        #expect(abs(debut - 0.99) < 0.001, "1:1 au départ")
        #expect(ZoomDuCarnet.suivie(0.1, sens: .resserrer) > 1 - ZoomDuCarnet.course, "elle ne disparaît jamais")
        #expect(ZoomDuCarnet.suivie(3, sens: .resserrer) < 1 + ZoomDuCarnet.resistance, "à rebours, à peine")
        #expect(ZoomDuCarnet.suivie(1.5, sens: .ecarter) > 1)
    }
}

private let coproprietaire = DroitsOnglet(
    roles: ["propriétaire"], role: "propriétaire", statut: "copropriétaire_bailleur")
private let locataire = DroitsOnglet(roles: ["résident"], role: "résident", statut: "locataire")

struct SommaireResidenceTests {
    @Test func leSommaireSuitLesRubriquesPuisLesOngletsDuSite() {
        #expect(
            PageDeResidence.sommaire(coproprietaire, accesReglement: true) == [
                .rubrique(.identite), .rubrique(.regles), .rubrique(.plans), .rubrique(.reglement),
                .rubrique(.comptesRendus), .rubrique(.diagnostics), .onglet(.carnet), .onglet(.reglement),
            ])
        #expect(
            !PageDeResidence.sommaire(coproprietaire, accesReglement: false).contains(.onglet(.reglement)),
            "l'assistant fermé aux copropriétaires : pas de page")
    }

    @Test func leLocataireNeLitNiPVNiDiagnosticsNiCarnet() {
        #expect(
            PageDeResidence.sommaire(locataire, accesReglement: nil) == [
                .rubrique(.identite), .rubrique(.regles), .rubrique(.plans), .rubrique(.reglement),
            ])
    }

    @Test func laPageOuverteSeGardeParSonNomSeul() {
        for page in PageDeResidence.sommaire(coproprietaire, accesReglement: true) {
            #expect(PageDeResidence(cleGardee: page.cleGardee) == page)
        }
        #expect(PageDeResidence(cleGardee: "rubrique.inconnue") == nil)
        #expect(PageDeResidence(cleGardee: "onglet") == nil)
    }

    @Test func lesTitresSontCeuxDuSite() {
        #expect(PageDeResidence.rubrique(.comptesRendus).titre == TextesResidence.comptesRendus)
        #expect(PageDeResidence.onglet(.carnet).titre == "Carnet d’entretien", "le libellé généré de l'onglet")
    }
}

/// Le serveur d'une période : il note la requête de `GET /flux` et range une carte au jeudi.
private actor ServeurDePeriode {
    private(set) var requete: String?

    func repondre(_ chemin: String?) -> String {
        requete = chemin
        return #"""
            {"delai_recent_jours": 7, "items": [{"type": "publication", "id": "12", "date": "2026-11-16T08:00:00",
             "titre": "Coupure d'eau jeudi", "jour": "2026-11-19", "rattachement": "echeance"}]}
            """#
    }
}

private struct TransportDePeriode: ClientTransport {
    let serveur: ServeurDePeriode

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        let corps = await serveur.repondre(request.path)
        var reponse = HTTPResponse(status: .ok)
        reponse.headerFields[.contentType] = "application/json"
        return (reponse, HTTPBody(corps))
    }
}

struct FilDeLaPeriodeTests {
    @Test func laSemaineSeDemandeEnJoursDeParisEtSeLitAuJourServi() async throws {
        let serveur = ServeurDePeriode()
        let api = ServiceAPI(transport: { _ in TransportDePeriode(serveur: serveur) })
        let adresse = try #require(URL(string: "https://periode.exemple"))
        let residence = Installation(adresse: adresse, nom: "Résidence", aUnLogo: false)
        let semaine = SemaineDuFil(contenant: jour("2026-11-18"))

        let cartes = try await api.fil(residence, periode: semaine.periode)
        let requete = try #require(await serveur.requete)
        #expect(requete.contains("du=2026-11-16"))
        #expect(requete.contains("au=2026-11-22"))
        #expect(cartes.map(\.jourServi) == ["2026-11-19"])
        #expect(semaine.ranger(cartes)[3].count == 1, "au jeudi")

        _ = try await api.fil(residence, periode: nil)
        let sansPeriode = try #require(await serveur.requete)
        #expect(!sansPeriode.contains("du="), "sans période, la requête d'avant : rien ne change")
    }
}
