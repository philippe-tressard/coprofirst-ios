// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Une question de la FAQ, telle que GET /faq la sert (`FaqItemRead`).
struct QuestionFAQ: Hashable, Sendable, Identifiable {
    let id: Int
    let categorie: String
    let question: String
    /// Du HTML de l'éditeur : il passe par `TexteDuSite`.
    let reponse: String
}

/// Une catégorie et ses questions, dans l'ordre du serveur (catégorie, ordre, id).
struct CategorieFAQ: Hashable, Sendable, Identifiable {
    let nom: String
    let questions: [QuestionFAQ]
    var id: String { nom }

    /// Regroupe sans retrier : le serveur a déjà rangé. Une catégorie vide se lit
    /// « Général », comme sur le site.
    static func regrouper(_ questions: [QuestionFAQ]) -> [CategorieFAQ] {
        var ordre: [String] = []
        var parNom: [String: [QuestionFAQ]] = [:]
        for question in questions {
            let nom = question.categorie.trimmingCharacters(in: .whitespaces).isEmpty ? "Général" : question.categorie
            if parNom[nom] == nil { ordre.append(nom) }
            parNom[nom, default: []].append(question)
        }
        return ordre.map { CategorieFAQ(nom: $0, questions: parNom[$0] ?? []) }
    }
}

/// Ce que l'écran de la FAQ demande à une installation (#14) : la lecture seule.
/// La rédaction (conseil syndical) reste au site.
protocol ServiceFAQ: Sendable {
    /// GET /faq : les questions actives.
    func questionsFAQ(_ installation: Installation) async throws -> [QuestionFAQ]
}

extension Parcours {
    /// Les deux réalisations s'y conforment (`FAQTests` le vérifie à la compilation).
    var serviceFAQ: any ServiceFAQ {
        // swiftlint:disable:next force_cast
        service as! any ServiceFAQ
    }
}

extension ServiceAPI: ServiceFAQ {
    func questionsFAQ(_ installation: Installation) async throws -> [QuestionFAQ] {
        let sortie = try await appeler { try await client(installation.adresse).listFaqFaqGet() }
        switch sortie {
        case .ok(let ok):
            return try ok.body.json.map {
                QuestionFAQ(id: $0.id, categorie: $0.categorie, question: $0.question, reponse: $0.reponse)
            }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

/// Des questions inventées, pour les aperçus, les tests et les captures.
extension ServiceSimule: ServiceFAQ {
    func questionsFAQ(_ installation: Installation) async throws -> [QuestionFAQ] {
        try await Task.sleep(for: .milliseconds(400))
        return [
            QuestionFAQ(
                id: 1, categorie: "🏠 Vie en résidence", question: """
                    Comment signaler une panne dans les parties communes ?
                    """,
                reponse: """
                    <p>Créez une <strong>affaire</strong> depuis la rubrique Affaires : le conseil \
                    syndical la suit jusqu'à sa résolution.</p>
                    """),
            QuestionFAQ(
                id: 2, categorie: "🏠 Vie en résidence", question: "Où déposer les encombrants ?",
                reponse: """
                    <p>Un local est réservé au rez-de-chaussée du bâtiment B. La collecte passe le \
                    premier mardi du mois.</p><ul><li>Pas de gravats</li><li>Pas de produits \
                    toxiques</li></ul>
                    """),
            QuestionFAQ(
                id: 3, categorie: "🔑 Accès", question: "Quel prix pour un badge ou une télécommande ?",
                reponse: "<p>Le prix est fixé par le conseil syndical ; il figure sur la demande d'accès.</p>"),
            QuestionFAQ(
                id: 4, categorie: "", question: "Qui contacter en cas d'urgence la nuit ?",
                reponse: "<p>Le numéro d'astreinte du syndic est affiché dans chaque hall.</p>"),
        ]
    }
}
