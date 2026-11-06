// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes des « Délégations aidant », écrits une fois : ceux de la page du site
/// (`routes/(app)/delegations/+page.svelte`, v3.61.0) ; la vue et les tests les lisent ici.
enum TextesDelegations {
    static let personneAidee = "Personne aidée"
    static let aidant = "Aidant"
    static let aucune = "Aucune délégation."
    static let nouvelle = "Nouvelle délégation"
    static let titreFormulaire = "Nouvelle délégation aidant"
    static let accepter = "Accepter"
    static let revoquer = "Révoquer"
    static let revoquerQuestion = "Révoquer cette délégation ?"
    static let annuler = "Annuler"
    static let enregistrer = "Enregistrer"
    static let mandant = "Personne aidée (mandant)"
    static let procheAidant = "Proche aidant"
    static let choisir = "Choisir…"
    static let motif = "Motif"
    static let motifExemple = "Ex : Assistance personne âgée"
    static let dateFin = "Date de fin"
    static let avecDateFin = "Fixer une date de fin"
    static let sansDate = "Sans date, la délégation reste valable sans limite."
    static let avertissement =
        "L'aidant devra accepter la délégation. Il pourra consulter à la place de la personne aidée ce qui lui est "
        + "adressé, sans agir en son nom. L'accès aidant ne constitue pas une procuration d'AG."
    static let residentsIndisponibles =
        "Les menus « mandant » et « aidant » sont vides : la liste des résidents n'a pas pu être chargée — ce "
        + "n'est pas qu'aucun résident n'est éligible."
    static let acceptee = "Délégation acceptée"
    static let revoquee = "Délégation révoquée"
    static let creee = "Délégation créée"

    /// « Du 02/04/2026 au 30/06/2026 », ou « Du 02/04/2026 — illimité ».
    static func periode(_ delegation: Delegation) -> String {
        let debut = "Du \(FormatsDuSite.dateCourte(delegation.dateDebut))"
        guard let fin = delegation.dateFin else { return debut + " — illimité" }
        return debut + " au \(FormatsDuSite.dateCourte(fin))"
    }
}
