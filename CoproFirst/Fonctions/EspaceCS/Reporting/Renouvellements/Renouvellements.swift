// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Reporting › Renouvellements (#56) : le relevé SERVI par `GET /reporting/renouvellements`
/// (`ReleveRenouvellements`, coprofirst#2525) — l'année de référence (le jour de Paris),
/// le préavis, les compteurs, l'ordre des contrats (la pire note d'abord) et celui des
/// diagnostics (l'échéance la plus proche d'abord), et ce qui tombe dans l'année. L'app
/// n'en recalcule rien.
struct Renouvellements: Hashable, Sendable {
    var annee: Int
    var preavisMois: Int
    var contratsEnPreavis: Int
    var echeancesContratsAnnee: Int
    var auditsAPlanifier: Int
    var contrats: [ContratARenouveler]
    var diagnostics: [DiagnosticAEcheance]
}

/// Un contrat de prestataire et son échéance.
struct ContratARenouveler: Hashable, Sendable, Identifiable {
    let id: Int
    var libelle: String
    var prestataireNom: String
    var numeroContrat: String?
    var noteMoyenne: Double?
    var nbNotations: Int
    /// Jours ISO (`AAAA-MM-JJ`), tels que servis.
    var dateDebut: String
    var dateFin: String?
    var datePreavis: String?
    var echeanceDansLAnnee: Bool
    /// `preavis`, `annee`, `futur`… tel que le serveur la classe ; `nil` : dates manquantes.
    var urgence: String?
    var reconduit: Bool
}

/// Un diagnostic réglementaire applicable et sa prochaine échéance.
struct DiagnosticAEcheance: Hashable, Sendable, Identifiable {
    let id: Int
    var nom: String
    var code: String
    var frequence: String?
    var dernierRapportLe: String?
    var prochaineEcheance: String?
    var permanent: Bool
    /// `depasse`, `annee` ou `futur`, tel que servi ; `nil` sans échéance connue.
    var urgence: String?
}

extension Renouvellements {
    init(_ lu: Components.Schemas.ReleveRenouvellements) {
        self.init(
            annee: lu.annee, preavisMois: lu.preavisMois, contratsEnPreavis: lu.compteurs.contratsEnPreavis,
            echeancesContratsAnnee: lu.compteurs.echeancesContratsAnnee,
            auditsAPlanifier: lu.compteurs.auditsAPlanifier, contrats: lu.contrats.map(ContratARenouveler.init),
            diagnostics: lu.diagnostics.map(DiagnosticAEcheance.init))
    }
}

extension ContratARenouveler {
    init(_ lu: Components.Schemas.ContratARenouveler) {
        self.init(
            id: lu.id, libelle: lu.libelle, prestataireNom: lu.prestataireNom, numeroContrat: lu.numeroContrat,
            noteMoyenne: lu.noteMoyenne, nbNotations: lu.nbNotations ?? 0, dateDebut: lu.dateDebut,
            dateFin: lu.dateFin, datePreavis: lu.datePreavis, echeanceDansLAnnee: lu.echeanceDansLAnnee,
            urgence: lu.urgenceEcheance, reconduit: lu.reconduit ?? false)
    }
}

extension DiagnosticAEcheance {
    init(_ lu: Components.Schemas.DiagnosticAEcheance) {
        self.init(
            id: lu.id, nom: lu.nom, code: lu.code, frequence: lu.frequence, dernierRapportLe: lu.dernierRapportLe,
            prochaineEcheance: lu.prochaineEcheance, permanent: lu.permanent, urgence: lu.urgenceEcheance?.rawValue)
    }
}

extension Renouvellements {
    /// Les contrats dont l'échéance tombe dans l'année servie.
    var contratsDeLAnnee: [ContratARenouveler] { contrats.filter(\.echeanceDansLAnnee) }
    /// Les échéances des années suivantes (`futur`, hors de l'année).
    var contratsFuturs: [ContratARenouveler] {
        contrats.filter { !$0.echeanceDansLAnnee && $0.dateFin != nil && $0.urgence == "futur" }
    }
    /// Les contrats sans échéance connue.
    var contratsSansDate: [ContratARenouveler] { contrats.filter { $0.urgence == nil } }

    /// Les diagnostics à échéance, rangés par l'année de leur échéance servie, dans l'ordre
    /// servi ; les permanents à part.
    var diagnosticsParAnnee: [(annee: String, diagnostics: [DiagnosticAEcheance])] {
        var groupes: [(annee: String, diagnostics: [DiagnosticAEcheance])] = []
        for diagnostic in diagnostics where !diagnostic.permanent {
            let annee = String((diagnostic.prochaineEcheance ?? "").prefix(4))
            if let rang = groupes.firstIndex(where: { $0.annee == annee }) {
                groupes[rang].diagnostics.append(diagnostic)
            } else {
                groupes.append((annee, [diagnostic]))
            }
        }
        return groupes
    }

    var diagnosticsPermanents: [DiagnosticAEcheance] { diagnostics.filter(\.permanent) }
}

extension ServiceAPI {
    func renouvellements(_ installation: Installation) async throws -> Renouvellements {
        let sortie = try await appeler { try await client(installation.adresse).getReportingRenouvellements() }
        switch sortie {
        case .ok(let ok): return Renouvellements(try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}

extension ServiceSimule {
    func renouvellements(_ installation: Installation) async throws -> Renouvellements {
        try await Task.sleep(for: .milliseconds(350))
        return try FixturesRenouvellements.releveLu()
    }
}
