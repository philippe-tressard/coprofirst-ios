// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Un suivi inventé, pour les aperçus, les tests et les captures : des affaires
/// d'exemple, aucune requête. Les teintes sont celles que le serveur choisirait : les
/// séries pour les catégories (`s1`…), les paliers pour les bâtiments (`p1`…).
extension ServiceSimule: ServiceReporting {
    func suiviAffaires(_ releve: ReleveSuivi, dans installation: Installation) async throws -> SuiviAffaires {
        try await Task.sleep(for: .milliseconds(400))
        return releve == .entretien ? Self.suiviEntretien : Self.suiviAffaires
    }
}

private typealias Tranche = Repartition.Tranche

private let ascenseur = Tranche(cle: "ascenseur", libelle: "Ascenseur", nombre: 1, teinte: "s1")
private let communes = Tranche(cle: "parties_communes", libelle: "Parties communes", nombre: 1, teinte: "s2")
private let verts = Tranche(cle: "espaces_verts", libelle: "Espaces verts", nombre: 1, teinte: "s3")
private let batA = Tranche(cle: "bat_a", libelle: "Bât. A", nombre: 1, teinte: "p1")
private let batB = Tranche(cle: "bat_b", libelle: "Bât. B", nombre: 1, teinte: "p2")
private let copro = Tranche(cle: "copro", libelle: "Copropriété", nombre: 1, teinte: "p3")
private let plusieurs = Tranche(cle: "plusieurs", libelle: "Plusieurs bâtiments", nombre: 1, teinte: "plusieurs")

/// Une barre, dont le nombre est la somme de ses tranches.
private func barre(_ cle: String, _ libelle: String, _ tranches: [Tranche]) -> Repartition {
    Repartition(cle: cle, libelle: libelle, nombre: tranches.map(\.nombre).reduce(0, +), tranches: tranches)
}

/// Une affaire ouverte il y a `age` jours ; l'ancienneté suit les seuils du serveur (30, 90).
private func affaire(
    _ id: Int, _ titre: String, _ age: Int, _ details: (inout AffaireSuivie) -> Void
) -> AffaireSuivie {
    var lue = AffaireSuivie(
        id: id, numero: String(format: "TK-A%05d", id), titre: titre, statut: "ouvert",
        libelleCategorie: "Parties communes",
        ouverteLe: FormatsDuSite.jourISO(Date.now.addingTimeInterval(-Double(age) * 86_400)), ageJours: age,
        anciennete: age > 90 ? "ancienne" : age > 30 ? "moyenne" : "recente", apercu: "", apercuIA: false,
        aEvolue: false, motifEvolution: nil, etatVisite: nil)
    details(&lue)
    return lue
}

extension ServiceSimule {
    fileprivate static let suiviAffaires = SuiviAffaires(
        total: 5, anciennes: 2, delaiJours: 90, fusionnees: 1,
        parCategorie: [
            barre("ascenseur", "Ascenseur", [batA, batB]),
            barre("parties_communes", "Parties communes", [batA, plusieurs]),
            barre("espaces_verts", "Espaces verts", [copro]),
        ],
        parBatiment: [
            barre("bat_a", "Bât. A", [ascenseur, communes]),
            barre("bat_b", "Bât. B", [ascenseur]),
            barre("copro", "Copropriété", [communes, verts]),
        ],
        affaires: [
            affaire(12, "Fuite au plafond du parking", 143) {
                $0.statut = "en_cours"
                $0.apercu = "Le syndic a mandaté un étancheur ; l'intervention attend l'accord du conseil sur le devis."
                $0.apercuIA = true
                $0.aEvolue = true
                $0.motifEvolution = "reponse"
            },
            affaire(18, "Ascenseur du bâtiment B souvent à l'arrêt", 97) {
                $0.statut = "chez_prestataire"
                $0.libelleCategorie = "Ascenseur"
                $0.apercu = "Trois pannes en un mois ; le prestataire doit remplacer la carte de commande."
            },
            affaire(27, "Porte du hall A qui ne se referme pas", 41) {
                $0.apercu = "Le groom est à régler ; un devis est demandé."
                $0.aEvolue = true
                $0.motifEvolution = "nouvelle"
            },
            affaire(31, "Taille des haies côté rue", 12) {
                $0.libelleCategorie = "Espaces verts"
                $0.apercu = "À prévoir avant la fin du mois, avec le passage du jardinier."
            },
            affaire(33, "Voyant d'alarme de l'ascenseur A", 4) {
                $0.statut = "en_cours"
                $0.libelleCategorie = "Ascenseur"
                $0.apercu = "Signalé par plusieurs résidents ; le syndic a prévenu l'ascensoriste."
            },
        ])

    fileprivate static let suiviEntretien = SuiviAffaires(
        total: 2, anciennes: 0, delaiJours: 90, fusionnees: 0,
        parCategorie: [barre("ascenseur", "Ascenseur", [batA, batB])],
        parBatiment: [barre("bat_a", "Bât. A", [ascenseur]), barre("bat_b", "Bât. B", [ascenseur])],
        affaires: [
            affaire(40, "Visite semestrielle de l'ascenseur A", 20) {
                $0.libelleCategorie = "Ascenseur"
                $0.apercu = "Visite prévue avec l'ascensoriste."
                $0.etatVisite = "a_venir"
            },
            affaire(41, "Visite semestrielle de l'ascenseur B", 60) {
                $0.libelleCategorie = "Ascenseur"
                $0.apercu = "Aucune date proposée par le prestataire."
                $0.etatVisite = "a_planifier"
            },
        ])
}
