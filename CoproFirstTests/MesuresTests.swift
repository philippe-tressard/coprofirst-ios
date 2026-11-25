// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import CoreGraphics
import Foundation
import Testing

@testable import CoproFirst

/// Les mesures de l'app (`Mise`, Charte.swift) face à celles du site (#85).
///
/// Une mesure dont le site a le jeton se GÉNÈRE (`MesuresDuSite`, scripts/generateurs/charte.py) ;
/// les autres sont PROPRES À iOS et se déclarent ici, avec leur raison et leur date. Refusé :
/// une mesure de `Mise` non déclarée, un écart que le site a rendu caduc (même valeur : il
/// faut prendre la sienne), un jeton du site qui a bougé depuis la décision (à redécider).

/// Une mesure propre à iOS. `ecart` : le jeton du site qu'elle écarte et la valeur qu'il
/// avait quand l'écart a été décidé — `nil` quand le site n'a pas de jeton pour elle.
private struct MesurePropre {
    struct Ecart {
        let jeton: String
        let auSite: CGFloat
        let aLaDecision: CGFloat
    }

    let valeur: CGFloat
    let ecart: Ecart?
    let raison: String
    let depuis: String
}

/// La liste des mesures PROPRES À iOS — une entrée par mesure de `Mise`.
private let propresAIOS: [String: MesurePropre] = [
    "rayon": MesurePropre(
        valeur: Mise.rayon, ecart: .init(jeton: "--radius", auSite: MesuresDuSite.rayon, aLaDecision: 8),
        raison: "coins continus de 14 pt, à l'échelle des cartes du système — le site arrondit à 0,5 rem ; "
            + "rendu validé au simulateur avec le parcours v2 (#4)",
        depuis: "02/11/2026"),
    "rayonTuile": MesurePropre(
        valeur: Mise.rayonTuile, ecart: nil,
        raison: "une tuile DANS une carte (vignette de nature, choix d'un état d'avis, encadré) : un cran sous "
            + "`rayon`, que huit vues écrivaient en dur (#347) ; le site n'a qu'un jeton de rayon",
        depuis: "24/11/2026"),
    "medaillon": MesurePropre(
        valeur: Mise.medaillon, ecart: nil,
        raison: "le logo d'une résidence ou le symbole d'un personnage en tête d'une ligne : trois vues "
            + "l'écrivaient en dur (#347) ; il n'est pas une cible tactile, il en a la taille",
        depuis: "24/11/2026"),
    "marge": MesurePropre(
        valeur: Mise.marge, ecart: nil,
        raison: "la marge latérale des écrans iOS ; le site n'a pas de jeton (1,25 rem écrit dans `.card`)",
        depuis: "02/11/2026"),
    "cible": MesurePropre(
        valeur: Mise.cible, ecart: nil,
        raison: "44 pt, Human Interface Guidelines ; le site écrit 44 px en dur sous `(pointer: coarse)`, sans jeton",
        depuis: "02/11/2026"),
    "approcheLibelle": MesurePropre(
        valeur: Mise.approcheLibelle, ecart: nil,
        raison: "l'approche des capitales sur le style `caption` ; le site écrit 0,06 em en dur (`.section-title`)",
        depuis: "02/11/2026"),
    "mosaique": MesurePropre(
        valeur: Mise.mosaique, ecart: nil,
        raison: "la mosaïque des photos (à la Messages) n'existe pas au site, qui fait défiler une galerie "
            + "de photos entières (`PiecesJointes.svelte`, format grand) ; retenue par l'utilisateur",
        depuis: "11/11/2026"),
    "mosaiqueCompacte": MesurePropre(
        valeur: Mise.mosaiqueCompacte, ecart: nil,
        raison: "la mosaïque sous une suite ou dans un message ; le site y met des vignettes de 72 px "
            + "écrites en dur (`size`), sans jeton",
        depuis: "11/11/2026"),
    "vignette": MesurePropre(
        valeur: Mise.vignette, ecart: nil,
        raison: "la vignette d'une carte du fil : 56 px au site (`FluxVignette.svelte`, `size`), écrit en dur, "
            + "sans jeton",
        depuis: "11/11/2026"),
    "jalon": MesurePropre(
        valeur: Mise.jalon, ecart: nil,
        raison: "la pastille d'une section du fil d'une affaire, pleine pour le réalisé (maquette A, #178) ; "
            + "le site y met un jalon à pictogramme de 2 rem écrit en dur (`RubriqueEtape.svelte`), sans jeton",
        depuis: "12/11/2026"),
    "jalonSecondaire": MesurePropre(
        valeur: Mise.jalonSecondaire, ecart: nil,
        raison: "la pastille d'un élément sous une section (arborescence de la maquette A, #178) : "
            + "le site n'a pas de sous-jalon",
        depuis: "12/11/2026"),
    "filetRail": MesurePropre(
        valeur: Mise.filetRail, ecart: nil,
        raison: "le trait du rail : 2 px au site, écrit en dur (`RubriqueEtape.svelte`, `.etape::before`), sans jeton",
        depuis: "12/11/2026"),
    "listeIdeale": MesurePropre(
        valeur: Mise.listeIdeale, ecart: nil,
        raison: "la colonne de liste à côté d'une fiche sur iPad (`ListeEtFiche`, #222), à l'échelle de "
            + "celle des apps du système ; le site n'a pas de liste et fiche côte à côte",
        depuis: "16/11/2026"),
    "listeMin": MesurePropre(
        valeur: Mise.listeMin, ecart: nil,
        raison: "la colonne de liste à côté d'une fiche sur iPad (`ListeEtFiche`, #222), à l'échelle de "
            + "celle des apps du système ; le site n'a pas de liste et fiche côte à côte",
        depuis: "16/11/2026"),
    "listeMax": MesurePropre(
        valeur: Mise.listeMax, ecart: nil,
        raison: "la colonne de liste à côté d'une fiche sur iPad (`ListeEtFiche`, #222), à l'échelle de "
            + "celle des apps du système ; le site n'a pas de liste et fiche côte à côte",
        depuis: "16/11/2026"),
    "filetChoisi": MesurePropre(
        valeur: Mise.filetChoisi, ecart: nil,
        raison: "le trait qui souligne la carte dont la fiche est ouverte à côté (iPad, #222) ; "
            + "le site n'a pas de liste et fiche côte à côte",
        depuis: "16/11/2026"),
    "tranche": MesurePropre(
        valeur: Mise.tranche, ecart: nil,
        raison: "la tranche des intercalaires du carnet de l'iPhone pliable (#119) : le site n'a pas de "
            + "carnet ; le plus long mot des libellés par défaut (« Prestataires », « Communauté ») en "
            + "`caption2` y tient entier à la taille par défaut (CarnetTests)",
        depuis: "17/11/2026"),
    "debordChoisi": MesurePropre(
        valeur: Mise.debordChoisi, ecart: nil,
        raison: "l'écart de ce trait autour d'un lien dans le texte (le syndic, une annexe), pour qu'il "
            + "ne touche pas ses lettres ; le site n'a pas de liste et fiche côte à côte",
        depuis: "17/11/2026"),
    "lecture": MesurePropre(
        valeur: Mise.lecture, ecart: nil,
        raison: "la colonne de lecture d'un écran sur iPad (#223), la largeur que prenaient déjà les "
            + "onglets, les accès, les délégations et les prestataires ; le site n'a pas de jeton de "
            + "largeur de contenu",
        depuis: "17/11/2026"),
]

/// Les mesures que `Mise` déclare, lues dans sa source : `static let <nom>: CGFloat`.
private func mesuresDeMise() throws -> Set<String> {
    let charte = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("CoproFirst/Charte/Charte.swift")
    let source = try String(contentsOf: charte, encoding: .utf8)
    let debut = try #require(source.range(of: "enum Mise {"), "enum Mise introuvable dans Charte.swift")
    let fin = try #require(source.range(of: "\n}", range: debut.upperBound..<source.endIndex))
    let corps = source[debut.upperBound..<fin.lowerBound]
    return Set(corps.matches(of: /static let (\w+): CGFloat/).map { String($0.output.1) })
}

@Test func chaqueMesureDeMiseEstDeclareeProprePourIOS() throws {
    let lues = try mesuresDeMise()
    // Une lecture vide rendrait le test vert sans rien vérifier (standards/04).
    #expect(lues.count >= 3, "Charte.swift : mesures de Mise illisibles (\(lues))")
    let nonDeclarees = lues.subtracting(propresAIOS.keys).sorted()
    let sansMesure = Set(propresAIOS.keys).subtracting(lues).sorted()
    #expect(lues == Set(propresAIOS.keys), "non déclarées : \(nonDeclarees) ; déclarées sans mesure : \(sansMesure)")
    for (nom, mesure) in propresAIOS {
        #expect(!mesure.raison.isEmpty && mesure.depuis.wholeMatch(of: /\d\d\/\d\d\/\d{4}/) != nil, "\(nom)")
    }
}

@Test func chaqueEcartAuSiteSertEncore() {
    for (nom, mesure) in propresAIOS {
        guard let ecart = mesure.ecart else { continue }
        #expect(
            ecart.auSite == ecart.aLaDecision,
            "\(nom) : \(ecart.jeton) vaut \(ecart.auSite) pt, \(ecart.aLaDecision) à la décision — à redécider")
        #expect(
            mesure.valeur != ecart.auSite,
            "\(nom) : égale au site (\(ecart.jeton)) — l'écart ne sert plus, prendre MesuresDuSite.\(nom)")
    }
}
