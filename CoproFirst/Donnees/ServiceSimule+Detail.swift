// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

#if DEBUG
/// Les détails inventés : affaires, actualité, document (le sondage : `Commun/Detail/Sondage/`). Aucun nom de
/// personne, aucune requête.
extension ServiceSimule {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        try await Task.sleep(for: delaiDetail)
        return try detailSimule(id)
    }

    func document(_ id: Int, nom: String?, dans installation: Installation) async throws -> URL {
        try await Task.sleep(for: .milliseconds(450))
        let fichier = FileManager.default.temporaryDirectory.appending(
            path: Fichiers.nomSur(nom, defaut: "document.pdf"))
        let renduPDF = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try renduPDF.writePDF(to: fichier) { contexte in
            contexte.beginPage()
            let titre = "Procès-verbal de l'assemblée générale\n\nDocument fictif de l'API simulée."
            (titre as NSString).draw(
                in: CGRect(x: 56, y: 72, width: 483, height: 700),
                withAttributes: [.font: UIFont.preferredFont(forTextStyle: .title2)])
        }
        return fichier
    }

    func photo(_ chemin: String, dans installation: Installation) async throws -> Data {
        try await Task.sleep(for: .milliseconds(250))
        // Une « photo » dessinée : un aplat de la charte et un pictogramme.
        let teinte = UIColor(chemin.hasSuffix("2.jpg") ? Palette.seine.filCyanFond : Palette.seine.filIndigoFond)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { contexte in
            teinte.setFill()
            contexte.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            let symbole = UIImage(systemName: "drop.fill")?.withTintColor(UIColor(Palette.seine.primary))
            symbole?.draw(in: CGRect(x: 260, y: 180, width: 120, height: 120))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    /// Les affaires de `FixturesDetailAffaire`, lues comme le service réel les lit ; les
    /// droits servis y sont ceux d'un résident. Le conseil syndical reçoit les siens ici,
    /// comme un serveur les lui servirait : tout, sauf « Répondre » sur une actualité. Le
    /// fil des messages vient des fixtures, notes internes au conseil seulement.
    static func affaires(_ id: Int, conseil: Bool) throws -> DetailAffaire? {
        guard var detail = try FixturesDetailAffaire.lue(id) else { return nil }
        if !detail.estActualite { detail.messages = try FixturesMessagesAffaire.lus(pour: id, conseil: conseil) }
        if conseil {
            detail.droits = DroitsServisAffaire(
                repondre: !detail.estActualite, changerEtat: true, modifier: true, archiver: true, corriger: true)
        }
        return detail
    }
}
#endif
