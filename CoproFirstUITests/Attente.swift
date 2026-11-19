// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import XCTest

/// Le point d'attente commun des tests d'interface (#98, #123) : on attend un ÉTAT,
/// jamais une durée.
enum Attente {
    /// Le plafond, large exprès. Sur un runner chargé, une requête d'accessibilité met
    /// 1 à 2 s et une seule évaluation peut manger un délai de 3 s (#123) ; le détail
    /// d'une affaire y est arrivé jusqu'à 12 s après le toucher (#98). L'attente rend
    /// la main dès que l'état est là : un plafond large ne ralentit pas un test vert,
    /// il ne coûte qu'à un test rouge.
    static let plafond: TimeInterval = 30

    /// Le délai d'une SONDE : l'élément est-il déjà là ? Pour ce qui peut légitimement
    /// manquer — une boucle qui fait défiler jusqu'à lui, un chemin facultatif, une
    /// absence à prouver une fois l'écran posé. Jamais pour affirmer une présence :
    /// une sonde qui échoue n'est pas un défaut de l'app (#147).
    static let sonde: TimeInterval = 2

    /// Le délai d'un EFFET, avant de reprendre un toucher qui n'a rien fait (`toucher(_:jusqua:)`,
    /// #282) : un écran poussé arrive en 1 à 3 s au poste, jusqu'à 12 s sur un runner chargé
    /// (#98) — une reprise sur un effet seulement lent est sans dommage pour un toucher qui
    /// ouvre une page (le second ne change rien), et la dernière attente est le plafond.
    static let effet: TimeInterval = 10
    /// Au plus deux reprises : au-delà, ce n'est plus un toucher perdu, c'est un défaut.
    static let reprises = 2
}

extension XCUIElement {
    /// L'élément existe, au plus tard au plafond commun. Les seules attentes d'existence
    /// des tests sont ces trois-là : `scripts/verifier-depot.sh` refuse tout délai écrit
    /// sur place — 8 s n'ont pas suffi à la feuille des notifications sur un runner
    /// chargé, et `main` en est sorti rouge sans que l'app ait tort (#147).
    func apparait() -> Bool { waitForExistence(timeout: Attente.plafond) }

    /// L'élément n'existe plus, au plus tard au plafond commun.
    func disparait() -> Bool { waitForNonExistence(timeout: Attente.plafond) }

    /// L'élément est-il là dans le délai d'une sonde (`Attente.sonde`) ? Le résultat se
    /// LIT (boucle, chemin facultatif, absence) ; il ne s'affirme pas par `XCTAssertTrue`.
    func sonde() -> Bool { waitForExistence(timeout: Attente.sonde) }

    /// L'élément est-il ENCORE là après `duree` secondes ? La seule attente qui dure exprès :
    /// elle prouve qu'un état passager est tenu (l'avis sous `-avis-durable`, #123).
    func demeure(_ duree: TimeInterval) -> Bool { !waitForNonExistence(timeout: duree) }

    /// L'élément est dans l'état `condition` — un format de `NSPredicate`, par exemple
    /// « hasKeyboardFocus == true » — au plus tard au plafond commun. La seule attente
    /// par prédicat des tests : `scripts/verifier-depot.sh` refuse les autres, dont
    /// chacune portait son propre délai.
    @MainActor
    func attendre(_ condition: String) -> Bool {
        let etat = XCTNSPredicateExpectation(predicate: NSPredicate(format: condition), object: self)
        return XCTWaiter().wait(for: [etat], timeout: Attente.plafond) == .completed
    }
}

extension XCUIApplication {
    /// L'élément amené à l'écran, touchable : par PETITS défilements (un quart d'écran), vers
    /// le bas du contenu d'abord, puis vers le haut s'il a été dépassé. Un balayage plein
    /// sautait une ligne d'un `Form`, qui ne crée pas ses lignes hors de l'écran — surtout
    /// clavier ouvert (AffairesUITests rouge en CI le 12/11/2026). Les gestes se font dans
    /// le haut de l'écran, au-dessus d'un clavier. `false` s'il n'existe pas à l'issue.
    ///
    /// `pourLire` : un élément qu'on LIT (un texte) s'arrête dès qu'il existe à l'écran. Sous
    /// iOS 26.5, un texte statique d'une feuille n'est jamais `isHittable` : exiger qu'il le
    /// soit faisait faire à la boucle ses 2 × `essais` défilements avant de rendre `true` —
    /// 750 s au lieu de 78 pour `SuppressionCompteUITests`, et le lot 2 de la CI au-delà de
    /// son plafond de 70 min (15/11/2026).
    @discardableResult
    func amener(_ element: XCUIElement, essais: Int = 10, pourLire: Bool = false) -> Bool {
        let fenetre = windows.firstMatch
        return amener(element, essais: essais) {
            pourLire ? element.frame.intersects(fenetre.frame) : element.isHittable
        }
    }

    /// `amener`, jusqu'à ce que l'élément soit tout entier AU-DESSUS de `borne` (le haut d'une
    /// barre du bas). Sous iOS 26.5, la barre `.bottomBar` d'un écran n'est pas exposée comme
    /// `Toolbar` (des `Other` seuls) : `zoneUtile` ne la voit pas, `isHittable` la traverse, et
    /// le toucher d'un « ⋯ » passé sous son verre ne l'ouvrait pas (#211). La borne se nomme
    /// donc par un bouton de la barre, que le test connaît. Le défilement est un BALAYAGE lent,
    /// pas l'appui-glisser d'`amener` : sous iOS 26.5, celui-ci partait sur un texte sélectionnable
    /// de la fiche (`textSelection`) et la page ne bougeait pas (vidéo du xcresult, #211) — le
    /// geste de `HistoriqueUITests` sur le même écran.
    @discardableResult
    func amener(_ element: XCUIElement, auDessusDe borne: XCUIElement, essais: Int = 8) -> Bool {
        let arrive = { !borne.exists || element.frame.maxY + 8 <= borne.frame.minY }
        _ = element.sonde()
        for _ in 0..<essais where !(element.exists && arrive()) {
            swipeUp(velocity: .slow)
        }
        return element.exists && arrive()
    }

    /// `amener`, arrivé quand `arrive` le dit (l'élément existe en plus).
    @discardableResult
    fileprivate func amener(_ element: XCUIElement, essais: Int, jusqua arrive: () -> Bool) -> Bool {
        _ = element.sonde()
        let fenetre = windows.firstMatch
        for (depart, arrivee) in [(0.5, 0.25), (0.25, 0.5)] {
            for _ in 0..<essais where !(element.exists && arrive()) {
                let vers = fenetre.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: arrivee))
                fenetre.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: depart))
                    .press(forDuration: 0.05, thenDragTo: vers)
            }
        }
        return element.exists
    }

    /// L'élément d'une rangée qui défile de côté (la barre d'onglets d'une page, #295), amené
    /// dans la fenêtre par de petits glissés horizontaux SUR SA RANGÉE, à sa hauteur : `amener`
    /// fait défiler la page de haut en bas et n'y arrive jamais. « Dans la fenêtre » se lit sur
    /// le cadre, jamais par `isHittable` (refusé sous iOS 26.5, #242). `false` sinon.
    @discardableResult
    func amenerDansSaRangee(_ element: XCUIElement, essais: Int = 6) -> Bool {
        guard element.apparait() else { return false }
        let fenetre = windows.firstMatch
        let origine = fenetre.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<essais where !fenetre.frame.contains(element.frame) {
            let hauteur = element.frame.midY - fenetre.frame.minY
            let sens: CGFloat = element.frame.minX > fenetre.frame.midX ? 1 : -1
            let largeur = fenetre.frame.width
            origine.withOffset(CGVector(dx: largeur * (0.5 + 0.25 * sens), dy: hauteur))
                .press(forDuration: 0.05, thenDragTo: origine.withOffset(
                    CGVector(dx: largeur * (0.5 - 0.25 * sens), dy: hauteur)))
        }
        return fenetre.frame.contains(element.frame)
    }
}

extension XCUIApplication {
    /// Le SEUL toucher des tests (#217, comme `toucher()` de coprofirst-android#126) : un
    /// `tap()` envoyé trop tôt part sur un élément pas encore touchable — une feuille qui
    /// monte encore, un bouton sous le clavier, un onglet hors du cadre — et ne fait rien,
    /// sans erreur : le test échouait plus loin, sur l'effet absent (4 occurrences en CI sous
    /// iOS 26.5). Ici, dans l'ordre : l'élément existe ; s'il est sous le clavier, le clavier
    /// se ferme ; il ne bouge plus ; il est À L'ÉCRAN de lui-même (`visible`, le temps d'une
    /// sonde : une feuille qui finit de monter) ; sinon seulement, il y est amené par
    /// défilement (borné en `essais`). Faire défiler d'emblée un bouton de barre de feuille
    /// pas encore posé tirait la feuille vers le bas et la FERMAIT : le bouton disparaissait
    /// (SuppressionCompteUITests, 350 s). Il ne bouge plus ; il est touché au centre de sa
    /// partie visible. L'EFFET se vérifie ensuite par le test.
    ///
    /// Jamais `isHittable` ici : sous iOS 26.5, un bouton de la barre d'onglets ou d'un menu
    /// n'a pas de point d'activation, et DEMANDER s'il est touchable fait échouer le test
    /// (« Failed to determine hittability », #242 en CI). « À l'écran » se lit sur son cadre,
    /// et le toucher part d'une coordonnée : rien ne demande le point d'activation.
    ///
    /// Une ligne qu'une liste ne CRÉE qu'au défilement (sous le pli, au très grand texte)
    /// n'existe pas encore : l'appelant l'amène d'abord (`amener`), puis la touche. `toucher`
    /// ne fait pas défiler pour attendre un élément qui tarde — ce défilement fermait les
    /// feuilles. `scripts/verifier-touchers.sh` tient le plafond des `tap()` directs, qui ne
    /// fait que baisser.
    @MainActor
    func toucher(_ element: XCUIElement, essais: Int = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.apparait(), "à toucher : \(element) absent", file: file, line: line)
        let clavier = keyboards.firstMatch
        if element.elementType != .key, clavier.exists, element.frame.intersects(clavier.frame),
           navigationBars.firstMatch.exists {
            // Le titre de la barre de navigation : une zone neutre, hors du clavier, qui ne valide rien.
            navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = clavier.disparait()
        }
        immobile(element)
        if visible(element, pendant: Attente.sonde) == nil {
            amener(element, essais: essais) { visible(element) != nil }
            immobile(element)
        }
        guard let point = visible(element) else {
            XCTFail("à toucher : \(element) hors de l'écran (\(element.frame) dans \(frame))", file: file, line: line)
            return
        }
        if point == CGVector(dx: 0.5, dy: 0.5) {
            element.tap()
        } else {
            // Il dépasse de l'écran (un onglet d'une rangée qui défile) : sa partie visible.
            element.coordinate(withNormalizedOffset: point).tap()
        }
    }

    /// Le toucher JUSQU'À L'EFFET (#282, #183) : `toucher`, puis l'attente de `effet` (un
    /// élément qui doit apparaître). Sous charge, un toucher synthétisé peut se perdre : il
    /// est rejoué, au plus `Attente.reprises` fois, et CHAQUE reprise s'écrit au journal
    /// (« ↻ reprise du toucher n/N : … »), que `scripts/bilan_tests_ui.py` déclare au résumé
    /// et en annotation — une reprise muette masquerait un vrai toucher sans réponse.
    ///
    /// Pour un toucher IDEMPOTENT seulement (ouvrir une page, un onglet, une feuille) : le
    /// rejouer sur un effet simplement lent ne change rien. Jamais pour un interrupteur, un
    /// dépliage ni un envoi.
    @MainActor
    func toucher(
        _ element: XCUIElement, jusqua effet: XCUIElement, essais: Int = 10, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        toucher(element, essais: essais, file: file, line: line)
        for reprise in 1...Attente.reprises {
            if effet.waitForExistence(timeout: Attente.effet) { return }
            let trace = "↻ reprise du toucher \(reprise)/\(Attente.reprises) : \(element) sans effet "
                + "(\(effet)) en \(Int(Attente.effet)) s (#282)"
            print(trace)
            XCTContext.runActivity(named: trace) { _ in }
            toucher(element, essais: essais, file: file, line: line)
        }
        XCTAssertTrue(
            effet.apparait(), "\(element) touché \(Attente.reprises + 1) fois, sans effet", file: file, line: line)
    }

    /// Un toucher LÀ OÙ l'élément est dessiné, comme un doigt — sans le défilement
    /// qu'XCUITest ajoute avant `tap()` sur un élément caché (#47) : une fois son cadre
    /// immobile (le clavier et la mise en page bougeaient encore, #183, ex-#270).
    @MainActor
    func toucherAuDessin(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.apparait(), "à toucher : \(element) absent", file: file, line: line)
        immobile(element)
        let cadre = element.frame
        coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: cadre.midX, dy: cadre.midY)).tap()
    }

    /// Le point à toucher, en coordonnées relatives à son cadre : son centre (0,5 ; 0,5) s'il
    /// est dans la zone utile, sinon le centre de sa PARTIE VISIBLE ; `nil` s'il n'en montre
    /// pas assez (22 pt de côté, ou tout l'élément s'il est plus petit), au plus tard après
    /// `duree` secondes. La zone utile : l'écran de l'app, moins la barre d'onglets (sauf
    /// pour ses propres boutons) — une ligne passée DERRIÈRE elle n'est pas à l'écran, le
    /// toucher partait sur la barre (DelegationsCSUITests, très grand texte) —, et rien sous
    /// le clavier. Lu sur les cadres seuls (voir `toucher`).
    private func visible(_ element: XCUIElement, pendant duree: TimeInterval = 0) -> CGVector? {
        let limite = Date().addingTimeInterval(duree)
        while true {
            if element.exists {
                let cadre = element.frame
                // Le cadre de l'APP, l'écran : `windows.firstMatch` peut être une autre fenêtre.
                var zone = frame
                let barre = tabBars.firstMatch
                if barre.exists, !barre.frame.contains(cadre) {
                    zone.size.height = max(0, min(zone.maxY, barre.frame.minY) - zone.minY)
                }
                let vu = cadre.intersection(zone)
                let centre = zone.contains(CGPoint(x: cadre.midX, y: cadre.midY))
                    ? CGPoint(x: cadre.midX, y: cadre.midY) : CGPoint(x: vu.midX, y: vu.midY)
                let clavier = keyboards.firstMatch
                if !cadre.isEmpty, !vu.isNull, vu.width >= min(22, cadre.width), vu.height >= min(22, cadre.height),
                   !(clavier.exists && clavier.frame.contains(centre)) {
                    return CGVector(
                        dx: (centre.x - cadre.minX) / cadre.width, dy: (centre.y - cadre.minY) / cadre.height)
                }
            }
            if Date() >= limite { return nil }
            _ = XCTWaiter().wait(for: [XCTestExpectation(description: "visible")], timeout: 0.25)
        }
    }

    /// Attend que l'élément ne bouge plus : deux cadres égaux à un quart de seconde d'écart
    /// (la fin d'une animation de feuille ou d'un défilement), au plus `essais` fois.
    private func immobile(_ element: XCUIElement, essais: Int = 8) {
        var avant = element.frame
        for _ in 0..<essais {
            _ = XCTWaiter().wait(for: [XCTestExpectation(description: "immobile")], timeout: 0.25)
            let apres = element.frame
            if apres == avant { return }
            avant = apres
        }
    }
}
