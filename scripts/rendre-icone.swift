// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// rendre-icone.swift <logo.svg> <sortie.png> <côté>
// rendre-icone.swift <logo.svg> <sortie.png> <largeur> <hauteur> <part> fond|transparent
//
// Rend le logo de CoproFirst en PNG. La première forme : l'icône de l'iPhone, carrée,
// OPAQUE, sur fond blanc (le fond de sa propre tuile) — l'icône d'une app iOS n'admet pas
// de transparence, et iOS arrondit lui-même les coins. La seconde : les images de l'Apple TV
// (#320) — le logo carré, haut de `part` × la hauteur (0 : aucun logo), centré, sur le fond
// blanc (`fond`, opaque : la couche arrière de l'icône, l'étagère) ou sans fond
// (`transparent` : la couche avant, qui bouge au-dessus de l'arrière).
// Redimensionner et poser sur un fond n'est pas une modification du dessin
// (licence LicenseRef-CoproFirst-Logo) ; rien d'autre n'est touché.
import AppKit

let arguments = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write(
        "usage : rendre-icone.swift <logo.svg> <sortie.png> <côté> | <largeur> <hauteur> <part> fond|transparent\n"
            .data(using: .utf8)!)
    exit(1)
}
guard arguments.count == 4 || arguments.count == 7, let largeur = Int(arguments[3]),
    let logo = NSImage(contentsOf: URL(fileURLWithPath: arguments[1]))
else { usage() }
let carre = arguments.count == 4
guard let hauteur = carre ? largeur : Int(arguments[4]), let part = carre ? 1 : Double(arguments[5]),
    (0...1).contains(part), carre || ["fond", "transparent"].contains(arguments[6])
else { usage() }
let opaque = carre || arguments[6] == "fond"
// Opaque : un contexte RGB SANS canal alpha (noneSkipLast), le PNG écrit l'est aussi.
guard
    let contexte = CGContext(
        data: nil, width: largeur, height: hauteur, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)
else { exit(1) }
if opaque {
    contexte.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    contexte.fill(CGRect(x: 0, y: 0, width: largeur, height: hauteur))
}
let cote = Double(hauteur) * part
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: contexte, flipped: false)
logo.draw(in: NSRect(x: (Double(largeur) - cote) / 2, y: (Double(hauteur) - cote) / 2, width: cote, height: cote))
NSGraphicsContext.restoreGraphicsState()
guard let image = contexte.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: arguments[2]) as CFURL, "public.png" as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("✅ \(arguments[2]) : \(largeur)×\(hauteur), \(opaque ? "opaque" : "transparente")")
