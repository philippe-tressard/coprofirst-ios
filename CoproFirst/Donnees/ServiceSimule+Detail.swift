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

    /// Le devis joint à l'affaire 41, sous le nom que le serveur donne à un téléversement
    /// (préfixe de 32 chiffres hexadécimaux) : l'écran doit montrer « Devis plombier ».
    static let devisSimule = "/uploads/tickets/0123456789abcdef0123456789abcdef_Devis%20plombier.pdf"

    /// Un fichier de `/uploads/` inventé selon son extension : une « photo » dessinée (un
    /// aplat de la charte et un pictogramme), un PDF d'une page, ou du texte.
    func fichierProtege(_ chemin: String, dans installation: Installation) async throws -> Data {
        try await Task.sleep(for: .milliseconds(250))
        let nom = Fichiers.nomAffiche(chemin)
        if Fichiers.estImage(chemin) { return Self.photoDessinee(chemin) }
        if nom.lowercased().hasSuffix(".pdf") {
            return UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { contexte in
                contexte.beginPage()
                ("\(Fichiers.nomSansExtension(chemin))\n\nDocument fictif de l'API simulée." as NSString).draw(
                    in: CGRect(x: 56, y: 72, width: 483, height: 700),
                    withAttributes: [.font: UIFont.preferredFont(forTextStyle: .title2)])
            }
        }
        return Data("\(Fichiers.nomSansExtension(chemin)) — texte fictif de l'API simulée.\n".utf8)
    }

    private static func photoDessinee(_ chemin: String) -> Data {
        let teintes = [Palette.seine.filIndigoFond, Palette.seine.filCyanFond, Palette.seine.infoFond]
        let teinte = UIColor(teintes[chemin.unicodeScalars.reduce(0) { $0 + Int($1.value) } % teintes.count])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { contexte in
            teinte.setFill()
            contexte.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            let symbole = UIImage(systemName: "drop.fill")?.withTintColor(UIColor(Palette.seine.primary))
            symbole?.draw(in: CGRect(x: 260, y: 180, width: 120, height: 120))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    /// Les droits sont ceux qu'un serveur servirait au compte simulé : tout au conseil
    /// syndical ; « Répondre » seul à un résident, sur les affaires qui le concernent.
    /// Le fil des messages vient des fixtures, notes internes au conseil seulement.
    static func affaires(_ id: Int, conseil: Bool) throws -> DetailAffaire? {
        guard var detail = [44, 45].contains(id) ? affaireDatee(id) : affaires(id) else { return nil }
        if !detail.estActualite { detail.messages = try FixturesMessagesAffaire.lus(pour: id, conseil: conseil) }
        let repondre = detail.droits.repondre
        detail.droits =
            conseil
            ? DroitsServisAffaire(repondre: !detail.estActualite, changerEtat: true, modifier: true, archiver: true)
            : DroitsServisAffaire(repondre: repondre)
        return detail
    }

    /// L'affaire 41 : urgente, quatre photos, un devis et un texte joints ; une suite joint
    /// à son tour une photo et le devis.
    private static func affaire41(_ ilYA: (Double) -> Date) -> DetailAffaire {
        DetailAffaire(
            id: 41, numero: "A-0041", titre: "Fuite d'eau au plafond du parking",
            description: "<p>Une infiltration goutte au niveau -1, place 12. Le sol est <strong>glissant</strong>"
                + "&nbsp;: un seau a été posé en attendant le plombier.</p><ol><li><p>Merci de contourner la "
                + "zone, et de ne pas déplacer le seau posé sous la fuite ;</p></li><li><p>photos jointes "
                + "ci-dessous.</p></li></ol><p>Le contrat d'entretien : "
                + "<a href=\"https://www.example.org/contrat\">consulter</a>.</p>",
            categorie: "sinistre", statut: "en_cours", urgente: true, creeLe: ilYA(5),
            auteur: "Un résident du bâtiment A", lieu: "Parking",
            pieces: PiecesJointes(urls: [
                "/uploads/tickets/41-1.jpg", "/uploads/tickets/41-2.jpg", "/uploads/tickets/41-3.jpg",
                "/uploads/tickets/41-4.jpg", Self.devisSimule, "/uploads/tickets/41-consignes.txt",
            ]),
            suites: [
                SuiteAffaire(
                    id: 1, type: "etat", date: ilYA(4), auteur: "Le conseil syndical", contenu: nil,
                    ancienStatut: "ouvert", nouveauStatut: "en_cours"),
                SuiteAffaire(
                    id: 2, type: "commentaire", date: ilYA(3), auteur: "Le conseil syndical",
                    contenu: "<p>Le syndic est prévenu ; le plombier passe <strong>demain matin</strong>.</p>",
                    ancienStatut: nil,
                    nouveauStatut: nil),
                SuiteAffaire(
                    id: 3, type: "reponse", date: ilYA(1), auteur: "Le syndic",
                    contenu: "Intervention confirmée à 9 h. La vanne d'arrêt sera fermée une heure.",
                    ancienStatut: nil, nouveauStatut: nil,
                    pieces: PiecesJointes(urls: ["/uploads/tickets/41-vanne.jpg", Self.devisSimule])),
            ],
            droits: DroitsServisAffaire(repondre: true), perimetres: ["parking"])
    }

    private static func affaires(_ id: Int) -> DetailAffaire? {
        let maintenant = Date.now
        func ilYA(_ heures: Double) -> Date { maintenant.addingTimeInterval(-heures * 3600) }
        switch id {
        case 41:
            return affaire41(ilYA)
        case 12:
            return DetailAffaire(
                id: 12, numero: "A-0012", titre: "Coupure d'eau jeudi de 9 h à 12 h",
                description: "Le remplacement d'une vanne dans la cave du bâtiment A impose de couper l'eau froide "
                    + "et l'eau chaude jeudi matin, de 9 h à 12 h. Pensez à faire une réserve.",
                categorie: "actualite", statut: "publie", urgente: false, creeLe: ilYA(6),
                auteur: "Le conseil syndical", lieu: "Bâtiment A", suites: [], perimetres: ["bat_a"])
        case 38, 31:
            return DetailAffaire(
                id: id, numero: "A-00\(id)",
                titre: id == 38 ? "Ravalement de la façade côté rue" : "Portail du garage remis en service",
                description: id == 38
                    ? "Le devis retenu en assemblée générale sera présenté au conseil syndical."
                    : "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                categorie: id == 38 ? "etude_travaux" : "panne", statut: id == 38 ? "en_ag" : "résolu",
                urgente: false, creeLe: ilYA(id == 38 ? 52 : 100), auteur: "Le conseil syndical",
                lieu: id == 38 ? "Bâtiment A" : "Parking", suites: [],
                droits: DroitsServisAffaire(repondre: id == 38), perimetres: [id == 38 ? "bat_a" : "parking"])
        default:
            return nil
        }
    }

    /// Deux affaires datées du fil (#75) : un ramonage le jour même, un contrôle passé.
    private static func affaireDatee(_ id: Int) -> DetailAffaire {
        let creeLe = Date.now.addingTimeInterval(-(id == 44 ? 9 : 20) * 3600)
        return DetailAffaire(
            id: id, numero: "A-00\(id)",
            titre: id == 44 ? "Ramonage des conduits de cheminée" : "Contrôle annuel de l'ascenseur",
            description: id == 44
                ? "Le ramoneur passe dans les caves du bâtiment B ; laissez l'accès aux conduits."
                : "Le contrôleur est passé ; son rapport sera transmis au conseil syndical.",
            categorie: "entretien", statut: "en_cours", urgente: false, creeLe: creeLe,
            auteur: "Le conseil syndical", lieu: "Bâtiment B", suites: [], perimetres: ["bat_b"])
    }
}
#endif
