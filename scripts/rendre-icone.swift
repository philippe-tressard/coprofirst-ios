// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// rendre-icone.swift <logo.svg> <sortie.png> <côté> — rend le logo de CoproFirst
// en PNG carré, OPAQUE, sur fond blanc (le fond de sa propre tuile) : l'icône d'une
// app iOS n'admet pas de transparence, et iOS arrondit lui-même les coins.
// Redimensionner et poser sur un fond n'est pas une modification du dessin
// (licence LicenseRef-CoproFirst-Logo) ; rien d'autre n'est touché.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4, let cote = Int(arguments[3]),
    let logo = NSImage(contentsOf: URL(fileURLWithPath: arguments[1]))
else {
    FileHandle.standardError.write("usage : rendre-icone.swift <logo.svg> <sortie.png> <côté>\n".data(using: .utf8)!)
    exit(1)
}
// Un contexte RGB SANS canal alpha (noneSkipLast) : le PNG écrit est opaque.
guard
    let contexte = CGContext(
        data: nil, width: cote, height: cote, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { exit(1) }
contexte.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
contexte.fill(CGRect(x: 0, y: 0, width: cote, height: cote))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: contexte, flipped: false)
logo.draw(in: NSRect(x: 0, y: 0, width: cote, height: cote))
NSGraphicsContext.restoreGraphicsState()
guard let image = contexte.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: arguments[2]) as CFURL, "public.png" as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("✅ \(arguments[2]) : \(cote)×\(cote), opaque")
