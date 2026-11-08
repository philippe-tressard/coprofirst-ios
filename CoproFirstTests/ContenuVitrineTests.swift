// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// La vitrine lit `contenu.json` de coprofirst.fr (#51) : copie embarquée, cache, réseau.

/// Un `contenu.json` complet pour l'app, au format 1, avec ce que `modifier` y change.
private func contenu(_ modifier: (inout [String: Any]) -> Void = { _ in }) -> Data {
    let fonctions = ContenuVitrine.rangees.map { ["id": $0.id, "titre": "T-\($0.id)", "textes": ["L-\($0.id)"]] }
    let roles = ContenuVitrine.roles.map { ["id": $0.id, "titre": "R-\($0.id)", "textes": ["P-\($0.id)"]] }
    var json: [String: Any] = [
        "format": 1,
        "sections": [
            ["id": "heros", "titre": "Titre.", "textes": ["Première phrase. Deuxième phrase."]],
            ["id": "fonctions", "titre": "Section", "textes": ["Sous-titre"], "elements": fonctions],
            ["id": "demo", "titre": "Démo", "textes": ["Chapeau", "Avertissement", "Adresse"], "elements": roles],
        ],
    ]
    modifier(&json)
    return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
}

private func sansElement(_ id: String, dans section: String) -> (inout [String: Any]) -> Void {
    { json in
        let sections = (json["sections"] as? [[String: Any]]) ?? []
        json["sections"] = sections.map { bloc in
            guard bloc["id"] as? String == section else { return bloc }
            var copie = bloc
            copie["elements"] = ((bloc["elements"] as? [[String: Any]]) ?? []).filter { $0["id"] as? String != id }
            return copie
        }
    }
}

@Test func laCopieEmbarqueePorteChaqueIdDontLAppDepend() throws {
    let contenu = try ContenuDuSite.lire(Data(ContenuEmbarque.json.utf8))
    for chemin in ContenuVitrine.idsRequis {
        let parties = chemin.split(separator: "/").map(String.init)
        let section = try #require(contenu.section(parties[0]), "section \(parties[0])")
        if parties.count == 2 { #expect(section.element(parties[1]) != nil, "élément \(chemin)") }
    }
    let pages = try #require(PagesVitrine(contenu))
    #expect(pages.enSavoirPlus.rangees.map(\.id) == ContenuVitrine.rangees.map(\.id))
    #expect(pages.demo.personnages.map(\.code) == ["user-cs", "user-copro", "user-loc"])
}

@Test func lesPagesSuiventLesIdsJamaisLesTitres() throws {
    let pages = try #require(PagesVitrine.lire(contenu()))
    #expect(pages.enSavoirPlus.titre == "Titre.")
    #expect(pages.enSavoirPlus.chapeau == "Première phrase.")
    #expect(pages.enSavoirPlus.section == "Section")
    #expect(pages.enSavoirPlus.sousTitre == "Sous-titre")
    let badges = try #require(pages.enSavoirPlus.rangees.first { $0.id == "badges" })
    #expect(badges.titre == "T-badges" && badges.ligne == "L-badges" && badges.symbole == "key.fill")
    #expect(pages.demo.chapeau == "Chapeau" && pages.demo.avertissement == "Avertissement")
    #expect(pages.demo.personnages.first?.role == "R-conseil-syndical")
}

@Test func unChampInconnuSIgnoreUnFormatPlusRecentSeRefuse() throws {
    let enPlus = contenu { $0["nouveau"] = ["x": 1] }
    #expect(PagesVitrine.lire(enPlus) != nil)
    #expect(throws: ContenuDuSite.Refus.formatInconnu(2)) {
        try ContenuDuSite.lire(contenu { $0["format"] = 2 })
    }
    #expect(PagesVitrine.lire(contenu { $0["format"] = 2 }) == nil)
}

@Test func unIdRetireNeDonnePasDePagesAMoitieVides() {
    #expect(PagesVitrine.lire(contenu(sansElement("carnet", dans: "fonctions"))) == nil)
    #expect(PagesVitrine.lire(contenu(sansElement("locataire", dans: "demo"))) == nil)
    #expect(PagesVitrine.lire(Data("pas du JSON".utf8)) == nil)
}

@Test func laPremierePhraseNeCoupePasUneQuestionCitee() {
    #expect(premierePhrase("Un. Deux.") == "Un.")
    let citee = "« Où en est ma demande\u{00A0}? » Suite."
    #expect(premierePhrase(citee) == citee)
    #expect(premierePhrase("Sans point final") == "Sans point final")
    let chapeau = "Signalements suivis, voisins informés. Une application libre."
    #expect(premierePhrase(chapeau) == "Signalements suivis, voisins informés.")
}

/// Un lecteur qui rend toujours la même réponse, et compte ses appels.
private final class LecteurFactice: @unchecked Sendable {
    private let verrou = NSLock()
    private var nombre = 0
    let donnees: Data
    let statut: Int

    init(_ donnees: Data, statut: Int = 200) {
        self.donnees = donnees
        self.statut = statut
    }

    var appels: Int { verrou.withLock { nombre } }

    func lire(_ requete: URLRequest) throws -> (Data, URLResponse) {
        verrou.withLock { nombre += 1 }
        let url = try #require(requete.url)
        let reponse = try #require(HTTPURLResponse(url: url, statusCode: statut, httpVersion: nil, headerFields: nil))
        return (donnees, reponse)
    }
}

private func fichierCache() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("vitrine-\(UUID().uuidString).json")
}

@MainActor
@Test func sansCacheLaCopieEmbarqueeSertPuisLeSiteLaRemplaceEtSeGarde() async throws {
    let cache = fichierCache()
    defer { try? FileManager.default.removeItem(at: cache) }
    let lecteur = LecteurFactice(contenu())
    let vitrine = Vitrine(lecteur: { try lecteur.lire($0) }, cache: cache)
    #expect(vitrine.pages == Vitrine.embarquee)
    await vitrine.actualiser()
    #expect(vitrine.pages.enSavoirPlus.titre == "Titre.")
    await vitrine.actualiser()
    #expect(lecteur.appels == 1, "une lecture réussie par lancement")
    // Lancement suivant, hors ligne : la dernière lecture, gardée.
    let horsLigne = Vitrine(lecteur: nil, cache: cache)
    #expect(horsLigne.pages.enSavoirPlus.titre == "Titre.")
}

@MainActor
@Test func uneReponseRefuseeOuIncompleteNeChangeRien() async {
    let cache = fichierCache()
    defer { try? FileManager.default.removeItem(at: cache) }
    let incomplet = contenu(sansElement("demande", dans: "fonctions"))
    for lecteur in [LecteurFactice(contenu(), statut: 404), LecteurFactice(incomplet)] {
        let vitrine = Vitrine(lecteur: { try lecteur.lire($0) }, cache: cache)
        await vitrine.actualiser()
        #expect(vitrine.pages == Vitrine.embarquee)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
    }
}

@MainActor
@Test func unCacheIllisibleLaisseLaCopieEmbarquee() throws {
    let cache = fichierCache()
    defer { try? FileManager.default.removeItem(at: cache) }
    try Data(#"{"format":1,"sections":[]}"#.utf8).write(to: cache)
    #expect(Vitrine(lecteur: nil, cache: cache).pages == Vitrine.embarquee)
}
