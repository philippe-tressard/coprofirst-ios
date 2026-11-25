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
    /// « hasKeyboardFocus == true » — au plus tard au plafond commun (ou après `duree`, l'un des
    /// délais d'`Attente`). La seule attente par prédicat des tests : `scripts/verifier-depot.sh`
    /// refuse les autres, dont chacune portait son propre délai.
    @MainActor
    func attendre(_ condition: String, pendant duree: TimeInterval = Attente.plafond) -> Bool {
        let etat = XCTNSPredicateExpectation(predicate: NSPredicate(format: condition), object: self)
        return XCTWaiter().wait(for: [etat], timeout: duree) == .completed
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
    ///
    /// `rangee` : une ligne qui ne se CRÉE qu'en approchant (une carte d'une colonne de kanban,
    /// à droite) n'existe pas encore — on glisse alors vers la droite du contenu, à la hauteur
    /// de `rangee`, jusqu'à ce qu'elle existe dans la fenêtre.
    @discardableResult
    func amenerDansSaRangee(_ element: XCUIElement, par rangee: XCUIElement? = nil, essais: Int = 6) -> Bool {
        guard (rangee ?? element).apparait() else { return false }
        let fenetre = windows.firstMatch
        let origine = fenetre.coordinate(withNormalizedOffset: .zero)
        let arrive = { element.exists && fenetre.frame.contains(element.frame) }
        for _ in 0..<essais where !arrive() {
            let repere = element.exists ? element : (rangee ?? element)
            let hauteur = repere.frame.midY - fenetre.frame.minY
            let sens: CGFloat = !element.exists || element.frame.minX > fenetre.frame.midX ? 1 : -1
            let largeur = fenetre.frame.width
            origine.withOffset(CGVector(dx: largeur * (0.5 + 0.25 * sens), dy: hauteur))
                .press(forDuration: 0.05, thenDragTo: origine.withOffset(
                    CGVector(dx: largeur * (0.5 - 0.25 * sens), dy: hauteur)))
        }
        return arrive()
    }

    /// L'élément est-il hors de la fenêtre DE CÔTÉ seulement (à sa hauteur, mais à gauche ou à
    /// droite) ? Un onglet d'une rangée qui défile de côté : seul un glissé horizontal l'amène.
    fileprivate func deCote(_ element: XCUIElement) -> Bool {
        let fenetre = windows.firstMatch.frame, cadre = element.frame
        return cadre.minY >= fenetre.minY && cadre.maxY <= fenetre.maxY
            && (cadre.maxX > fenetre.maxX || cadre.minX < fenetre.minX)
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
    ///
    /// Un CHAMP de saisie touché doit prendre le focus du clavier : sinon le toucher s'est perdu
    /// (main ab11792, ConnexionUITests : l'app occupée 7 s après le toucher du mot de passe, puis
    /// « Neither element nor any descendant has keyboard focus » à la saisie). Il est rejoué, au
    /// plus `Attente.reprises` fois, et chaque reprise s'écrit au journal — toucher un champ qui
    /// a déjà le focus n'y change rien.
    @MainActor
    func toucher(_ element: XCUIElement, essais: Int = 10, file: StaticString = #filePath, line: UInt = #line) {
        // Le type se lit AVANT le toucher : un bouton qui ferme sa feuille n'existe plus après.
        let saisie = element.apparait() && Self.saisies.contains(element.elementType)
        toucherUneFois(element, essais: essais, file: file, line: line)
        guard saisie else { return }
        let focus = "hasKeyboardFocus == true"
        for reprise in 1...Attente.reprises {
            if element.attendre(focus, pendant: Attente.effet) { return }
            tracerReprise("toucher", reprise, element, "le focus du clavier")
            toucherUneFois(element, essais: essais, file: file, line: line)
        }
        XCTAssertTrue(
            element.attendre(focus), "toucher de \(element) \(Attente.reprises + 1) fois, sans le focus du clavier",
            file: file, line: line)
    }

    /// Les champs de saisie : un toucher leur donne le focus du clavier.
    private static let saisies: Set<XCUIElement.ElementType> = [.textField, .secureTextField, .searchField, .textView]

    /// Le toucher lui-même, sans la vérification du focus (`toucher`).
    @MainActor
    private func toucherUneFois(_ element: XCUIElement, essais: Int, file: StaticString, line: UInt) {
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
            // Hors de l'écran sur le côté (un onglet d'une rangée, #183 : main 4d9c5ac, un
            // `swipeLeft()` perdu et 90 s de glissés verticaux sans effet) : glissés horizontaux.
            if deCote(element) {
                amenerDansSaRangee(element, essais: essais)
            } else {
                amener(element, essais: essais) { visible(element) != nil }
            }
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
        jusqua(effet, ("toucher", element), file: file, line: line) {
            toucher(element, essais: essais, file: file, line: line)
        }
    }

    /// Un INTERRUPTEUR d'une ligne de formulaire (#340) : toucher son libellé ne le bascule pas,
    /// il se touche à droite de la ligne, une fois celle-ci à l'écran et immobile. Pas de
    /// reprise : basculer deux fois défait le geste.
    @MainActor
    func basculer(_ ligne: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(ligne.apparait(), "à basculer : \(ligne) absent", file: file, line: line)
        immobile(ligne)
        ligne.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// Le toucher d'un ONGLET (#340) : la barre, remontée jusqu'à lui s'il est caché au-dessus
    /// (une page défilée), puis `toucher(_:jusqua:)` — par défaut jusqu'à l'onglet RETENU (le
    /// trait `isSelected` que posent les rangées d'onglets de l'app : `RangeeChoisie`, la
    /// Communauté), sinon jusqu'à ce que l'onglet montre d'abord. Un onglet ne se touche que par
    /// ici ou par `toucher(_:jusqua:)` : `scripts/touchers_onglets.py` refuse un `tap()`, un
    /// `toucher` sans effet et un `toucherAuDessin` sur un onglet.
    @MainActor
    func toucherLOnglet(
        _ onglet: XCUIElement, jusqua effet: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(onglet.apparait(), "à toucher : l'onglet \(onglet) absent", file: file, line: line)
        // De côté, `toucher` fait glisser la rangée ; au-dessus (la page a défilé), on la remonte.
        for _ in 0..<6 where !onglet.isHittable && !deCote(onglet) { swipeDown() }
        let retenu = descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND isSelected == true", onglet.identifier)).firstMatch
        toucher(onglet, jusqua: effet ?? retenu, file: file, line: line)
    }

    /// Le balayage vers la gauche d'une ligne JUSQU'À L'EFFET : ses actions révélées (supprimer,
    /// signaler). Un `swipeLeft()` se perd sous charge comme un toucher (#183) : il est rejoué
    /// et chaque reprise s'écrit au journal, comme celles de `toucher(_:jusqua:)`. Idempotent :
    /// balayer une ligne déjà ouverte la laisse ouverte.
    @MainActor
    func balayer(
        _ element: XCUIElement, jusqua effet: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(element.apparait(), "à balayer : \(element) absent", file: file, line: line)
        jusqua(effet, ("balayage", element), file: file, line: line) { element.swipeLeft() }
    }

    /// `geste`, puis l'attente de `effet`, rejoué au plus `Attente.reprises` fois — chaque reprise
    /// au journal (« ↻ reprise du toucher n/N : … », ou du balayage), lue par `scripts/bilan_tests_ui.py`.
    ///
    /// Rejoué TANT QUE l'élément touché existe : disparu, le geste a porté (la page a changé) et
    /// l'effet tarde seulement — le rejouer finirait sur « absent » et ferait d'une page lente un
    /// rouge. L'échec écrit l'arbre : il dit lequel des deux, geste perdu ou page jamais parue
    /// (main 413580b, deux gestes de navigation sans effet et sans trace, #183).
    @MainActor
    private func jusqua(
        _ effet: XCUIElement, _ quoi: (nom: String, element: XCUIElement), file: StaticString, line: UInt,
        geste: () -> Void
    ) {
        let (nom, element) = quoi
        geste()
        for reprise in 1...Attente.reprises {
            if effet.waitForExistence(timeout: Attente.effet) { return }
            guard element.exists else { break }
            tracerReprise(nom, reprise, element, "\(effet)")
            geste()
        }
        XCTAssertTrue(
            effet.apparait(),
            "\(nom) de \(element) sans effet (\(effet)) — arbre à l'échec :\n\(debugDescription)",
            file: file, line: line)
    }

    /// La trace d'une reprise, au journal et dans le rapport (« ↻ reprise du toucher n/N : … »),
    /// que `scripts/bilan_tests_ui.py` déclare au résumé : une reprise muette masquerait un défaut.
    @MainActor
    private func tracerReprise(_ nom: String, _ reprise: Int, _ element: XCUIElement, _ effet: String) {
        let trace = "↻ reprise du \(nom) \(reprise)/\(Attente.reprises) : \(element) sans effet "
            + "(\(effet)) en \(Int(Attente.effet)) s (#282)"
        print(trace)
        XCTContext.runActivity(named: trace) { _ in }
    }

    /// DÉPLIER un en-tête posé par `.depliage(…)` (#384) : le toucher, puis attendre son ÉTAT —
    /// sa valeur d'accessibilité, « déplié » (ou « dépliée »). Un toucher perdu sous charge ne
    /// change pas l'état (PrestatairesUITests sur #383 : l'exercice touché, jamais ouvert) : il
    /// est rejoué au plus `Attente.reprises` fois, chaque reprise au journal, et seulement à état
    /// inchangé — un dépliage touché deux fois se refermerait. Déjà déplié : rien n'est touché.
    @MainActor
    func deplier(_ entete: XCUIElement, essais: Int = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(entete.apparait(), "à déplier : \(entete) absent", file: file, line: line)
        let deplie = "value BEGINSWITH 'dépli'"
        if (entete.value as? String)?.hasPrefix("dépli") == true { return }
        toucher(entete, essais: essais, file: file, line: line)
        for reprise in 1...Attente.reprises {
            if entete.attendre(deplie, pendant: Attente.effet) { return }
            tracerReprise("toucher", reprise, entete, "la valeur « déplié »")
            toucher(entete, essais: essais, file: file, line: line)
        }
        XCTAssertTrue(
            entete.attendre(deplie), "dépliage de \(entete) sans effet (valeur « \(entete.value ?? "?") »)",
            file: file, line: line)
    }

    /// Un toucher LÀ OÙ l'élément est dessiné, comme un doigt — sans le défilement
    /// qu'XCUITest ajoute avant `tap()` sur un élément caché (#47) : une fois son cadre
    /// immobile (le clavier et la mise en page bougeaient encore, #183, ex-#270) et son centre
    /// hors du cadre du clavier ; un bouton qui y RESTE est un défaut de l'app (#47), dit ici.
    /// Le 19/11/2026 (#299, #315, iOS 26.5), « Se connecter » était touché à y = 540 au lieu de
    /// 513 — pas défilé — et rien ne partait. Au poste (iOS 26.5), le défilement le pose 44 pt
    /// AU-DESSUS du cadre du clavier : ce cadre ne dit pas tout ce qui le couvre. Les cadres
    /// s'impriment donc à chaque toucher : le prochain rouge se lit au journal, sans le rejouer.
    @MainActor
    func toucherAuDessin(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.apparait(), "à toucher : \(element) absent", file: file, line: line)
        let clavier = keyboards.firstMatch
        let sousLeClavier = {
            clavier.exists && clavier.frame.contains(CGPoint(x: element.frame.midX, y: element.frame.midY))
        }
        let limite = Date().addingTimeInterval(Attente.plafond)
        repeat { immobile(element) } while sousLeClavier() && Date() < limite
        let cadre = element.frame
        let leClavier = clavier.exists ? "\(clavier.frame)" : "absent"
        print("toucher au dessin : \(element.identifier) \(cadre), clavier \(leClavier)")
        guard !sousLeClavier() else {
            XCTFail("\(element) reste sous le clavier (#47) : \(cadre), clavier \(leClavier)", file: file, line: line)
            return
        }
        coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: cadre.midX, dy: cadre.midY)).tap()
    }

    /// Le point à toucher, en coordonnées relatives à son cadre : le centre de sa PARTIE VISIBLE
    /// dans la zone utile (`zoneUtile`) — son centre (0,5 ; 0,5) s'il y est entier. Pas son propre
    /// centre dès qu'il y entre : un onglet qui déborde à droite (x 339 à 457 sur 402) était
    /// touché à 4 pt du bord, sans effet (AdminUITests, #183). `nil` s'il n'en montre pas assez
    /// (22 pt de côté, ou tout l'élément s'il est plus petit), au plus tard après `duree`
    /// secondes ; rien sous le clavier. Lu sur les cadres seuls (voir `toucher`).
    private func visible(_ element: XCUIElement, pendant duree: TimeInterval = 0) -> CGVector? {
        let limite = Date().addingTimeInterval(duree)
        let zone = zoneUtile(pour: element)
        while true {
            if element.exists {
                let cadre = element.frame
                let vu = cadre.intersection(zone)
                let centre = CGPoint(x: vu.midX, y: vu.midY)
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

    /// La zone utile : l'écran de l'app (son cadre : `windows.firstMatch` peut être une autre
    /// fenêtre), moins les barres du BAS, sauf pour leurs propres boutons. Une ligne passée
    /// DERRIÈRE l'une d'elles n'est pas à l'écran : le toucher partait sur la barre.
    /// - la barre d'onglets (DelegationsCSUITests, très grand texte) ;
    /// - la barre de gestes d'un écran (`.bottomBar`, le bandeau d'une affaire) : le « ⋯ » d'un
    ///   message passait sous elle, et le toucher archivait l'affaire (#211). XCUITest lui donne
    ///   TOUT l'écran pour cadre (iOS 26 et 27) : son bord se lit sur ses boutons du bas.
    private func zoneUtile(pour element: XCUIElement) -> CGRect {
        var zone = frame
        let onglets = tabBars.firstMatch
        if onglets.exists, !onglets.frame.contains(element.frame) {
            zone.size.height = max(0, min(zone.maxY, onglets.frame.minY) - zone.minY)
        }
        let gestes = toolbars.firstMatch
        if gestes.exists, !gestes.buttons.matching(identifier: element.identifier).firstMatch.exists {
            let hauts = gestes.buttons.allElementsBoundByIndex.map(\.frame.minY).filter { $0 > zone.midY }
            if let haut = hauts.min() { zone.size.height = max(0, min(zone.maxY, haut) - zone.minY) }
        }
        return zone
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
