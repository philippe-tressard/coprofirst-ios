// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une installation simulée, pour les aperçus et les tests d'interface : aucune
/// requête ne part. Tout y est inventé — aucun nom de personne, aucune adresse réelle.
final class ServiceSimule: ServiceCoproFirst {
    /// Une résidence inventée, à sa palette (bouteille), avec la barre par défaut du site.
    static let residence = Installation(
        adresse: URL(string: "https://tilleuls.exemple.fr")!, nom: "Résidence Les Tilleuls", aUnLogo: false,
        codePalette: "bouteille")
    /// La démonstration, telle que la simule l'app (sans requête).
    static let demo = Installation(
        adresse: URL(string: "https://demo.coprofirst.fr")!, nom: "Résidence Les Glycines", aUnLogo: false)

    /// Le délai d'une réponse : assez pour voir le squelette, pas pour attendre.
    private let delai: Duration

    init(delai: Duration = .milliseconds(450)) {
        self.delai = delai
    }

    func decouvrir(_ adresse: URL) async throws -> Installation {
        try await Task.sleep(for: delai)
        switch adresse.host() {
        case "inconnue.exemple.fr": throw ErreurService.hoteInconnu
        case "injoignable.exemple.fr": throw ErreurService.injoignable
        case "demo.coprofirst.fr": return Self.demo
        default:
            var installation = Self.residence
            installation.adresse = adresse
            return installation
        }
    }

    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws {
        try await Task.sleep(for: delai)
        if motDePasse == "refuse" { throw ErreurService.identifiantsRefuses }
    }

    func aUneSessionGardee(_ installation: Installation) -> Bool { false }

    func reprendre(_ installation: Installation) async throws {
        throw ErreurService.sessionExpiree
    }

    func activerFaceID(_ installation: Installation) async -> Bool { true }

    func fil(_ installation: Installation) async throws -> [ElementDuFil] {
        try await Task.sleep(for: delai)
        return Self.fil
    }

    func entrerEnDemo(_ code: String) async throws -> Installation? {
        try await Task.sleep(for: delai)
        return Self.demo
    }

    func affaires(_ installation: Installation) async throws -> [Affaire] {
        try await Task.sleep(for: delai)
        return Self.affaires
    }

    func peutArchiver(_ installation: Installation) -> Bool { true }

    func archiver(_ affaire: Affaire, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    static let affaires: [Affaire] = {
        let maintenant = Date(timeIntervalSince1970: 1_793_610_000)  // 02/11/2026
        func jours(_ n: Double) -> Date { maintenant.addingTimeInterval(-n * 86_400) }
        return [
            Affaire(
                id: 41, numero: "A-0041", titre: "Fuite d'eau au plafond du parking",
                apercu: "Une infiltration goutte au niveau -1, place 12. Le sol est glissant : un seau a été posé "
                    + "en attendant le plombier. Merci de contourner la zone.",
                creeLe: jours(0.2), statut: "en_cours", urgente: true, meConcerne: true,
                lieu: "Parking, niveau -1", messages: 6),
            Affaire(
                id: 40, numero: "A-0040", titre: "Ascenseur du bâtiment B à l'arrêt",
                apercu: "L'ascenseur reste bloqué au troisième étage depuis ce matin. Le prestataire est prévenu "
                    + "et doit passer dans la journée.",
                creeLe: jours(1), statut: "chez_prestataire", urgente: true, meConcerne: false,
                lieu: "Bâtiment B", messages: 3),
            Affaire(
                id: 38, numero: "A-0038", titre: "Ravalement de la façade côté rue",
                apercu: "Le devis retenu en assemblée générale sera présenté au conseil syndical. Les échafaudages "
                    + "sont prévus au printemps, pour six semaines environ.",
                creeLe: jours(6), statut: "en_ag", urgente: false, meConcerne: true,
                lieu: "Façade nord", messages: 12),
            Affaire(
                id: 35, numero: "A-0035", titre: "Éclairage du hall en panne",
                apercu: "Deux plafonniers ne s'allument plus dans le hall d'entrée. Les ampoules ont été changées, "
                    + "le problème vient du minuteur.",
                creeLe: jours(9), statut: "ouvert", urgente: false, meConcerne: false,
                lieu: "Hall A", messages: 2),
            Affaire(
                id: 31, numero: "A-0031", titre: "Portail du garage remis en service",
                apercu: "La télécommande fonctionne de nouveau après le remplacement de la carte électronique.",
                creeLe: jours(21), statut: "résolu", urgente: false, meConcerne: true,
                lieu: "Garage", messages: 4),
        ]
    }()
}

extension ServiceSimule {
    /// Le fil inventé : trois jours, toutes les natures, une urgence.
    static let fil: [ElementDuFil] = {
        let calendrier = Chronologie.calendrier
        let aujourdhui = calendrier.startOfDay(for: .now)
        func le(_ jours: Int, _ heure: Int) -> Date {
            let jour = calendrier.date(byAdding: .day, value: -jours, to: aujourdhui) ?? aujourdhui
            return calendrier.date(byAdding: .hour, value: heure, to: jour) ?? jour
        }
        // Le constructeur des éléments inventés : un paramètre par champ du fil.
        // swiftlint:disable:next function_parameter_count
        func element(
            _ id: String, _ type: String, _ date: Date, _ titre: String, _ detail: String?,
            badges: [String] = [], meConcerne: Bool = false, cible: CibleDuFil
        ) -> ElementDuFil {
            ElementDuFil(
                id: "\(type):\(id)", type: type, date: date, titre: titre, detail: detail, badges: badges,
                publicationUrgente: false, statut: nil, meConcerne: meConcerne, cible: cible)
        }
        return [
            element(
                "41", "ticket_ouvert", le(0, 9), "Fuite d'eau au plafond du parking",
                "Niveau -1, place 12. Le plombier passe dans la matinée.", badges: ["urgent"], meConcerne: true,
                cible: .affaire(id: 41)),
            element(
                "12", "publication", le(0, 8), "Coupure d'eau jeudi de 9 h à 12 h",
                "Remplacement d'une vanne dans la cave du bâtiment A.", cible: .affaire(id: 12)),
            element(
                "3", "sondage_ouvert", le(1, 18), "Quel jour pour la fête des voisins ?",
                "Trois dates proposées, réponses jusqu'à vendredi.", cible: .sondage(id: 3)),
            element(
                "7", "document", le(1, 11), "Procès-verbal de l'assemblée générale",
                "Ajouté dans Documents › Assemblées.", cible: .document(id: 7, nom: "proces-verbal-ag.pdf")),
            element(
                "2", "point_conseil", le(2, 17), "Point avec le syndic",
                "Ordre du jour : ascenseur, ravalement, contrat d'entretien.", cible: .resume(lien: nil)),
            element(
                "38", "ticket_mis_a_jour", le(2, 10), "Ravalement de la façade côté rue",
                "Le devis retenu sera présenté au conseil syndical.", meConcerne: true, cible: .affaire(id: 38)),
            element(
                "31", "ticket_resolu", le(4, 15), "Portail du garage remis en service",
                "La carte électronique a été remplacée.", cible: .affaire(id: 31)),
        ]
    }()
}
