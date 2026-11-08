// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes du Reporting, écrits une fois : ceux de `VueSuiviAffaires.svelte` et
/// `BarresCroisees` (coprofirst v3.61.0) ; la vue et les tests les lisent ici.
enum TextesReporting {
    static let parCategorie = "Par catégorie"
    static let parBatiment = "Par bâtiment"
    static let resumeAssistant = "Résumé de l’assistant"
    static let aucuneAffaire = "Aucune affaire ouverte."
    static let aucunEntretien = "Aucun entretien périodique ouvert."
    /// Ce que l'app laisse au site, dit une fois sous le suivi.
    static let surLeSite =
        "La relance du syndic, les points CS / Syndic et leurs comptes rendus, les résumés de l’assistant, "
        + "la fusion des affaires liées, l’export PDF et la synthèse des prestataires se font sur le site."

    /// « 5 affaires non fermées », « 1 entretien non clos ».
    static func nonFermees(_ nombre: Int, entretien: Bool) -> String {
        let pluriel = nombre > 1 ? "s" : ""
        return entretien ? "entretien\(pluriel) non clos" : "affaire\(pluriel) non fermée\(pluriel)"
    }

    /// « de plus de 90 jours » — le délai que le serveur sert.
    static func anciennes(_ delai: Int) -> String { "de plus de \(FormatsDuSite.nombre(delai)) jours" }

    static func fusionnees(_ nombre: Int) -> String {
        let pluriel = nombre > 1 ? "s" : ""
        return "affaire\(pluriel) fusionnée\(pluriel)"
    }

    /// « 143 j », et « 143 jours » à VoiceOver.
    static func age(_ jours: Int) -> String { "\(FormatsDuSite.nombre(jours)) j" }
    static func ageLu(_ jours: Int) -> String { "\(FormatsDuSite.nombre(jours)) jours" }
}
