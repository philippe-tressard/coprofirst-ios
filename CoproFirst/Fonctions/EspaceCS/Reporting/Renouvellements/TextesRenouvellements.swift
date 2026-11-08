// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes de Reporting › Renouvellements, écrits une fois : ceux de
/// `VueRenouvellements*.svelte` (coprofirst v3.73.0) ; la vue et les tests les lisent ici.
enum TextesRenouvellements {
    static let titre = "Renouvellements"
    static let contratsEnPreavis = "Contrats en préavis"
    static let auditsAPlanifier = "Audits à (re)planifier"
    static let preavisEnCours = "Préavis en cours"
    static let actif = "Actif"
    static let reconduit = "♻ Reconduit"
    static let datesManquantes = "Dates manquantes"
    static let echeancesFutures = "Échéances futures"
    static let diagnosticsIntro =
        "Échéances issues de Résidence / Diagnostics et Contrôles Réglementaires, calculées depuis le "
        + "dernier rapport + fréquence légale."
    static let aucunDiagnostic = "Aucun diagnostic applicable"
    static let aucunDiagnosticDetail = "Tous les diagnostics sont non applicables."
    static let depasse = "Dépassé"
    static let permanent = "Permanent"
    static let permanentIntro = "Diagnostics à validité permanente (sauf si révision nécessaire)."
    static let permanentBadge = "✓ Permanent"

    static func echeancesAnnee(_ annee: Int) -> String { "Échéances contrats en \(String(annee))" }
    static func contratsTitre(_ annee: Int) -> String { "Contrats prestataires — échéances \(String(annee))" }

    static func contratsIntro(_ annee: Int, preavis: Int) -> String {
        "Contrats dont la fin ou le préavis tombe en \(String(annee)). Préavis de \(preavis) mois."
    }

    static func aucuneEcheance(_ annee: Int) -> String { "Aucune échéance de contrat en \(String(annee))" }
    static func diagnosticsTitre(_ annee: Int) -> String {
        "Diagnostics et Contrôles Réglementaires — \(String(annee))–\(String(annee + 10))"
    }

    static func aFaireEn(_ annee: Int) -> String { "À faire en \(String(annee))" }
    static func audits(_ nombre: Int) -> String { "\(nombre) audit\(nombre > 1 ? "s" : "")" }
    static func groupe(_ titre: String, _ nombre: Int) -> String { "\(titre) (\(nombre))" }

    /// « 01/12/2023 → 30/11/2026 · préavis dès 31/08/2026 ».
    static func periode(_ contrat: ContratARenouveler) -> String {
        let dates = "\(FormatsDuSite.date(contrat.dateDebut)) → \(FormatsDuSite.date(contrat.dateFin))"
        guard contrat.datePreavis != nil else { return dates }
        return dates + " · préavis dès \(FormatsDuSite.date(contrat.datePreavis))"
    }

    /// « Ascenseurs Exemple · N° ASC-2023-07 · ★ 2,5 (4 avis) ».
    static func prestataire(_ contrat: ContratARenouveler) -> String {
        [contrat.prestataireNom, contrat.numeroContrat.map { "N° \($0)" }, note(contrat)]
            .compactMap(\.self).joined(separator: " · ")
    }

    /// « ★ 2,5 (4 avis) », ou rien sans note.
    static func note(_ contrat: ContratARenouveler) -> String? {
        guard let note = contrat.noteMoyenne else { return nil }
        return "★ \(FormatsDuSite.nombre(note)) (\(contrat.nbNotations) avis)"
    }

    static func dernierRapport(_ jour: String?) -> String { "Dernier rapport : \(FormatsDuSite.date(jour))" }
    static func prochaineEcheance(_ jour: String?) -> String { "Prochaine échéance : \(FormatsDuSite.date(jour))" }
}
