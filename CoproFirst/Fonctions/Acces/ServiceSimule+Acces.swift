// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// « Mes lots & accès » simulé : tout est inventé — aucun nom de personne, des
/// numéros de la plage réservée à la fiction (01 99 00 …), des adresses `exemple.fr`.
extension ServiceSimule: ServiceAcces {
    func mesLots(_ installation: Installation) async throws -> [LotDuCompte] {
        try await Task.sleep(for: .milliseconds(300))
        return LotsSimules.lots
    }

    func monBail(_ installation: Installation) async throws -> BailDuLocataire? {
        try await Task.sleep(for: .milliseconds(200))
        return nil  // le compte simulé n'est pas locataire
    }

    func baux(_ installation: Installation, tous: Bool) async throws -> [Bail] {
        try await Task.sleep(for: .milliseconds(300))
        return LotsSimules.baux
    }

    func mesAcces(_ type: TypeAcces, dans installation: Installation) async throws -> [AccesDetenu] {
        try await Task.sleep(for: .milliseconds(300))
        return AccesSimules.partage.detenus(type)
    }

    func accesRecus(_ installation: Installation) async throws -> [AccesDetenu] {
        try await Task.sleep(for: .milliseconds(200))
        return []
    }

    func demander(_ demande: DemandeAcces, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(450))
        guard let lot = demande.lotId, LotsSimules.lots.contains(where: { $0.id == lot }) else {
            // La règle du serveur : un lot qui n'est pas le sien est refusé.
            throw RefusDuServeur(phrase: "Vous n'êtes pas associé à ce lot")
        }
    }

    func declarer(_ type: TypeAcces, code: String, dans installation: Installation) async throws -> Bool {
        try await Task.sleep(for: .milliseconds(450))
        return try AccesSimules.partage.declarer(type, code: code)
    }

    func signalerPerdu(_ acces: AccesDetenu, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
        AccesSimules.partage.signalerPerdu(acces)
    }

    func recupererAcces(bail: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

/// Les accès simulés, qui changent avec les gestes (déclarer, signaler perdu).
final class AccesSimules: @unchecked Sendable {
    static let partage = AccesSimules()
    private let verrou = NSLock()
    private var parType: [TypeAcces: [AccesDetenu]] = [
        .vigik: [
            AccesDetenu(id: 11, code: "A4F21C07", statut: "actif", type: "vigik"),
            AccesDetenu(id: 12, code: "A4F21C08", statut: "actif", type: "vigik"),
            AccesDetenu(id: 13, code: "9B0E33D1", statut: "perdu", type: "vigik"),
        ],
        .telecommande: [
            AccesDetenu(id: 21, code: "TC-2048", statut: "actif", type: "telecommande")
        ],
    ]

    func detenus(_ type: TypeAcces) -> [AccesDetenu] { verrou.withLock { parType[type] ?? [] } }

    func declarer(_ type: TypeAcces, code: String) throws -> Bool {
        try verrou.withLock {
            let tous = parType.values.flatMap { $0 }
            if tous.contains(where: { $0.code == code }) {
                let nom = type == .vigik ? "Vigik" : "Télécommande"
                throw RefusDuServeur(phrase: "\(nom) déjà enregistré sur votre compte")
            }
            let id = (tous.map(\.id).max() ?? 0) + 1
            parType[type, default: []].append(AccesDetenu(id: id, code: code, statut: "actif", type: type.rawValue))
            return code.hasPrefix("IMPORT")
        }
    }

    func signalerPerdu(_ acces: AccesDetenu) {
        verrou.withLock {
            for (type, liste) in parType {
                parType[type] = liste.map { lu in
                    var marque = lu
                    if lu.id == acces.id { marque.statut = "perdu" }
                    return marque
                }
            }
        }
    }
}

/// Les lots et les baux simulés : un appartement, une cave, une place de parking.
enum LotsSimules {
    static let lots: [LotDuCompte] = [
        LotDuCompte(
            id: 15, numero: "15", type: "appartement", typeAppartement: "T3", etage: 2, superficie: 64.5,
            batimentNom: "Bât. A", typeLien: "propriétaire", numeroUsage: "21",
            perimetres: [
                .init(libelle: "Bâtiment A", relation: "situe_dans"),
                .init(libelle: "Escalier A", relation: "desservi_par"),
            ],
            alertes: [
                .init(
                    code: "etage_inconnu", gravite: "information",
                    message: "L'étage de ce lot vient de votre déclaration ; le fichier du syndic ne le précise pas."),
            ]),
        LotDuCompte(
            id: 417, numero: "417", type: "cave", etage: -1, superficie: 4, batimentNom: "Bât. A",
            typeLien: "propriétaire",
            perimetres: [.init(libelle: "Sous-sol A", relation: "situe_dans")], alertes: []),
        LotDuCompte(
            id: 450, numero: "450", type: "parking", etage: -2, batimentNom: "Bât. B", typeLien: "propriétaire",
            numeroUsage: "5 & 6", perimetres: [.init(libelle: "Parking niveau -2", relation: "situe_dans")],
            alertes: []),
    ]

    static let baux: [Bail] = [
        Bail(
            id: 3, lotId: 31, statut: "actif", locataireId: 81, locatairePrenom: "Locataire",
            locataireNom: "du lot 31", locataireEmail: "locataire.31@exemple.fr", locataireTelephone: "01 99 00 00 31",
            dateEntree: "2025-09-01", dateSortiePrevue: nil, dateSortieReelle: nil,
            notes: "<p>Préavis d'<strong>un mois</strong> (zone tendue).</p>",
            objets: [
                ObjetRemis(
                    id: 1, type: "cle", libelle: "Clé de la porte palière", quantite: 2, statut: "en_possession",
                    remisLe: "2025-09-01"),
                ObjetRemis(
                    id: 2, type: "vigik", libelle: "Badge du hall", quantite: 1, reference: "A4F21C09",
                    statut: "en_possession", remisLe: "2025-09-01"),
            ]),
        Bail(
            id: 4, lotId: 32, statut: "en_cours_sortie", locataireId: nil, locatairePrenom: "Locataire",
            locataireNom: "du lot 32", locataireEmail: nil, locataireTelephone: nil,
            dateEntree: "2023-02-15", dateSortiePrevue: "2026-11-30", dateSortieReelle: nil, notes: nil, objets: []),
        Bail(
            id: 2, lotId: 31, statut: "termine", locataireId: 80, locatairePrenom: "Ancien locataire",
            locataireNom: "du lot 31", locataireEmail: nil, locataireTelephone: nil,
            dateEntree: "2021-03-01", dateSortiePrevue: "2025-06-30", dateSortieReelle: "2025-07-02", notes: nil,
            objets: [
                ObjetRemis(
                    id: 3, type: "telecommande", libelle: "Télécommande du parking", quantite: 1, statut: "rendu",
                    remisLe: "2021-03-01", renduLe: "2025-07-02"),
            ]),
    ]

    /// Le compte simulé n'est pas locataire : ce bail ne sert qu'aux aperçus et aux tests.
    static let bailDExemple = BailDuLocataire(
        id: 9, statut: "actif", lotBatimentNom: "Bât. B", lotNumero: "22", lotType: "appartement",
        lotTypeAppartement: "T2", lotEtage: 0, lotSuperficie: 41, dateEntree: "2024-10-01", dateSortiePrevue: nil,
        bailleurPrenom: "", bailleurNom: "Propriétaire du lot 22", bailleurEmail: "proprietaire.22@exemple.fr",
        bailleurTelephone: "01 99 00 00 22")
}
