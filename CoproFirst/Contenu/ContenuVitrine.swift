// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// ⚠️ PROVISOIRE — les textes de la vitrine viendront de coprofirst-site#42
/// (`contenu.json`, une seule source pour le site et l'app). D'ici là, cette copie
/// ne dit rien que le README de CoproFirst n'affirme : chaque phrase en reprend une.
enum ContenuVitrine {
    static let nom = "CoproFirst"
    /// README de CoproFirst, accroche.
    static let accroche = "Signalez un problème, suivez les travaux, consultez vos documents."

    struct Atout: Identifiable {
        let symbole: String
        let titre: String
        let ligne: String
        var id: String { titre }
    }

    static let atouts = [
        // README, « Affaires / Demandes ».
        Atout(
            symbole: "exclamationmark.bubble.fill", titre: "Les affaires",
            ligne: "Signalements et travaux, suivis par le conseil syndical."),
        // README, « Documents ».
        Atout(
            symbole: "doc.text.fill", titre: "Les documents",
            ligne: "Classés par catégorie, ouverts selon votre profil."),
    ]

    static let entrer = "Entrer dans ma résidence"
    static let demo = "Essayer la démo"
    /// L'installation de démonstration publique.
    static let adresseDemo = "demo.coprofirst.fr"
}
