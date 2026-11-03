// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Les détails inventés : affaires, actualité, sondage, document. Aucun nom de
/// personne, aucune requête.
extension ServiceSimule {
    func affaire(_ id: Int, dans installation: Installation) async throws -> DetailAffaire {
        try await Task.sleep(for: .milliseconds(500))
        guard let detail = Self.affaires(id) else { throw ErreurService.introuvable }
        return detail
    }

    func repondre(_ texte: String, a affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func sondage(_ id: Int, dans installation: Installation) async throws -> DetailSondage {
        try await Task.sleep(for: .milliseconds(450))
        return DetailSondage(
            id: id, question: "Quel jour pour la fête des voisins ?",
            description: "Trois dates sont proposées. Les réponses sont ouvertes jusqu'à vendredi.",
            options: [
                OptionSondage(id: 1, libelle: "Samedi 6 juin", nbVotes: 14),
                OptionSondage(id: 2, libelle: "Samedi 13 juin", nbVotes: 9),
                OptionSondage(id: 3, libelle: "Dimanche 14 juin", nbVotes: 4),
            ],
            monVote: nil, cloture: false, resultatsVisibles: true)
    }

    func voter(_ option: Int, au sondage: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
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

    static func affaires(_ id: Int) -> DetailAffaire? {
        let maintenant = Date.now
        func ilYA(_ heures: Double) -> Date { maintenant.addingTimeInterval(-heures * 3600) }
        switch id {
        case 41:
            return DetailAffaire(
                id: 41, numero: "A-0041", titre: "Fuite d'eau au plafond du parking",
                description: "Une infiltration goutte au niveau -1, place 12. Le sol est glissant : un seau a été "
                    + "posé en attendant le plombier. Merci de contourner la zone.",
                categorie: "plomberie", statut: "en_cours", urgente: true, creeLe: ilYA(5),
                auteur: "Un résident du bâtiment A", lieu: "Parking, niveau -1",
                photos: ["/uploads/tickets/41-1.jpg", "/uploads/tickets/41-2.jpg"],
                suites: [
                    SuiteAffaire(
                        id: 1, type: "etat", date: ilYA(4), auteur: "Le conseil syndical", contenu: nil,
                        ancienStatut: "ouvert", nouveauStatut: "en_cours", photos: []),
                    SuiteAffaire(
                        id: 2, type: "commentaire", date: ilYA(3), auteur: "Le conseil syndical",
                        contenu: "Le syndic est prévenu ; le plombier passe demain matin.", ancienStatut: nil,
                        nouveauStatut: nil, photos: []),
                    SuiteAffaire(
                        id: 3, type: "reponse", date: ilYA(1), auteur: "Le syndic",
                        contenu: "Intervention confirmée à 9 h. La vanne d'arrêt sera fermée une heure.",
                        ancienStatut: nil, nouveauStatut: nil, photos: []),
                ],
                peutRepondre: true)
        case 12:
            return DetailAffaire(
                id: 12, numero: "A-0012", titre: "Coupure d'eau jeudi de 9 h à 12 h",
                description: "Le remplacement d'une vanne dans la cave du bâtiment A impose de couper l'eau froide "
                    + "et l'eau chaude jeudi matin, de 9 h à 12 h. Pensez à faire une réserve.",
                categorie: "actualite", statut: "publie", urgente: false, creeLe: ilYA(6),
                auteur: "Le conseil syndical", lieu: "Bâtiment A", photos: [], suites: [], peutRepondre: false)
        case 38, 31:
            return DetailAffaire(
                id: id, numero: "A-00\(id)",
                titre: id == 38 ? "Ravalement de la façade côté rue" : "Portail du garage remis en service",
                description: id == 38
                    ? "Le devis retenu en assemblée générale sera présenté au conseil syndical."
                    : "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                categorie: id == 38 ? "batiment" : "equipement", statut: id == 38 ? "en_ag" : "résolu",
                urgente: false, creeLe: ilYA(id == 38 ? 52 : 100), auteur: "Le conseil syndical",
                lieu: id == 38 ? "Façade nord" : "Garage", photos: [], suites: [], peutRepondre: id == 38)
        default:
            return nil
        }
    }
}
