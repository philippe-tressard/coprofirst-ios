// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// rendre-symbole-hors-ligne.swift <sortie.svg> — dessine le pictogramme « hors
// ligne » de l'app (le toit sans onde : un toit, deux ondes et leur point, barrés)
// et l'écrit en modèle de symbole personnalisé (SF Symbols, Regular-M), que le
// catalogue d'images compile en symbole : il suit la taille du texte qui l'entoure.
//
// Le dessin est la SOURCE : des traits sur une grille de 24, épaissis puis réunis
// par les opérations booléennes de Core Graphics — un modèle de symbole n'admet
// que des formes pleines. La barre, arrêtée sous le toit, est détourée (un jour de
// part et d'autre), pour rester lisible à 17 points. Dessin original, sans emprunt
// à un symbole d'Apple.
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage : rendre-symbole-hors-ligne.swift <sortie.svg>\n".data(using: .utf8)!)
    exit(1)
}

// ── Le dessin, sur la grille de 24 (y vers le bas, comme le SVG) ─────────────
let trait: CGFloat = 2.0  // l'épaisseur du trait (graisse Regular)
let jour: CGFloat = 0.9  // le blanc de chaque côté de la barre
let centreOndes = CGPoint(x: 12, y: 20.3)

/// Un arc des ondes, centré sur le point, de -135° à -45° (vers le haut, y vers le bas).
func onde(rayon: CGFloat) -> CGPath {
    let chemin = CGMutablePath()
    chemin.addArc(center: centreOndes, radius: rayon, startAngle: -.pi * 3 / 4, endAngle: -.pi / 4, clockwise: false)
    return chemin
}

func epaissi(_ chemin: CGPath, largeur: CGFloat = trait) -> CGPath {
    chemin.copy(strokingWithWidth: largeur, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

let toit = CGMutablePath()
toit.move(to: CGPoint(x: 3, y: 11.5))
toit.addLine(to: CGPoint(x: 12, y: 4))
toit.addLine(to: CGPoint(x: 21, y: 11.5))

let barre = CGMutablePath()
barre.move(to: CGPoint(x: 6.5, y: 21.5))
barre.addLine(to: CGPoint(x: 16, y: 12))

let point = CGPath(
    ellipseIn: CGRect(x: centreOndes.x - 1.25, y: centreOndes.y - 1.25, width: 2.5, height: 2.5), transform: nil)

let dessous = [epaissi(onde(rayon: 3.5)), epaissi(onde(rayon: 6.9)), point]
    .reduce(epaissi(toit)) { $0.union($1) }
let glyphe = dessous.subtracting(epaissi(barre, largeur: trait + 2 * jour)).union(epaissi(barre))

// ── Le modèle de symbole (gabarit v3, colonne Regular-M) ─────────────────────
// Lignes du gabarit : base 1126, capitale 1055.54 (taille 100). Le glyphe se centre
// sur la hauteur des capitales, à 86 unités de haut, comme les pictogrammes du système.
let boite = glyphe.boundingBoxOfPath
let echelle = 86 / boite.height
let milieuCapitales: CGFloat = 1126 - 70.459 / 2
let gauche: CGFloat = 1400
var placement = CGAffineTransform(translationX: gauche, y: milieuCapitales - boite.height * echelle / 2)
    .scaledBy(x: echelle, y: echelle)
    .translatedBy(x: -boite.minX, y: -boite.minY)
guard let place = glyphe.copy(using: &placement) else { exit(1) }
let cadre = place.boundingBoxOfPath

func nombre(_ valeur: CGFloat) -> String { String(format: "%.2f", Double(valeur)) }
func xy(_ point: CGPoint) -> String { "\(nombre(point.x)) \(nombre(point.y))" }
var d = ""
place.applyWithBlock { element in
    let p = element.pointee.points
    switch element.pointee.type {
    case .moveToPoint: d += "M\(xy(p[0]))"
    case .addLineToPoint: d += "L\(xy(p[0]))"
    case .addQuadCurveToPoint: d += "Q\(xy(p[0])) \(xy(p[1]))"
    case .addCurveToPoint: d += "C\(xy(p[0])) \(xy(p[1])) \(xy(p[2]))"
    case .closeSubpath: d += "Z"
    @unknown default: break
    }
}

let marge: CGFloat = 6
let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    <!-- GÉNÉRÉ par scripts/rendre-symbole-hors-ligne.swift — NE PAS MODIFIER -->
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">
     <g id="Notes">
      <text style="font-family:'LucidaGrande';font-size:13" x="18" y="40">hors-ligne — le toit sans onde (CoproFirst-iOS)</text>
      <text id="template-version" style="font-family:'LucidaGrande';font-size:13" x="3036" y="1933">Template v.3.0</text>
     </g>
     <g id="Guides">
      <line id="Baseline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
      <line id="Capline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="625.541" y2="625.541"/>
      <line id="Baseline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1126" y2="1126"/>
      <line id="Capline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
      <line id="Baseline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1556" y2="1556"/>
      <line id="Capline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
      <line id="left-margin-Regular-M" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(nombre(cadre.minX - marge))" x2="\(nombre(cadre.minX - marge))" y1="1030.79" y2="1150.12"/>
      <line id="right-margin-Regular-M" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(nombre(cadre.maxX + marge))" x2="\(nombre(cadre.maxX + marge))" y1="1030.79" y2="1150.12"/>
     </g>
     <g id="Symbols">
      <g id="Regular-M">
       <path d="\(d)"/>
      </g>
     </g>
    </svg>

    """
do {
    try svg.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
} catch {
    FileHandle.standardError.write("écriture impossible : \(error)\n".data(using: .utf8)!)
    exit(1)
}
print("✅ \(CommandLine.arguments[1]) : \(nombre(cadre.width)) × \(nombre(cadre.height)) unités")
