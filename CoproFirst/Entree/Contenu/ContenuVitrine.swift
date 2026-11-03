// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// ⚠️ PROVISOIRE — les textes de la vitrine viendront de coprofirst-site#42
/// (`contenu.json`, une seule source pour le site et l'app). D'ici là, cette copie
/// reprend la page de coprofirst.fr (`site/index.html`, commit 0849752) et la
/// maquette validée par Philippe ; elle n'affirme rien d'autre.
enum ContenuVitrine {
    static let nom = "CoproFirst"

    // MARK: Accueil « le sceau » (maquette validée)

    static let devise = "La copropriété, enfin partagée."
    static let entrer = "Entrer dans ma résidence"
    static let decouvrirDemo = "Découvrir la démo"
    static let enSavoirPlus = "En savoir plus sur CoproFirst"

    // MARK: En savoir plus (coprofirst.fr, raccourcie)

    static let titre = "La copropriété, enfin en ordre."
    static let chapeau = "Signalements suivis, documents rangés, carnet d'entretien tenu, voisins informés."
    static let sectionVraieVie = "Pensée pour la vraie vie d'un immeuble"
    static let sousTitreVraieVie = "Chaque écran répond à une question que les résidents se posent déjà."

    struct Rangee: Identifiable {
        let symbole: String
        let titre: String
        let ligne: String
        var id: String { titre }
    }

    static let rangees = [
        Rangee(
            symbole: "exclamationmark.bubble.fill", titre: "« Où en est ma demande ? »",
            ligne: "Chaque affaire se lit en trois temps, qui se déplient l'un après l'autre."),
        Rangee(
            symbole: "doc.text.fill", titre: "Documents",
            ligne: "Chacun lit ce qui le concerne, selon son profil."),
        Rangee(
            symbole: "person.2.fill", titre: "Le point avec le syndic",
            ligne: "Le conseil prend le compte rendu affaire par affaire ; les présents le valident."),
        Rangee(
            symbole: "key.fill", titre: "Badges et accès",
            ligne: "Demander, déclarer, confier à son locataire pour la durée du bail."),
        Rangee(
            symbole: "book.closed.fill", titre: "Carnet d'entretien",
            ligne: "Constitué à partir des contrats et des affaires closes, sans ressaisie."),
        Rangee(
            symbole: "person.3.fill", titre: "Communauté",
            ligne: "Idées, sondages, petites annonces — entre résidents."),
    ]

    static let essayerDemo = "Essayer la démo"

    // MARK: Démo (coprofirst.fr, section « Essayez-la sans rien installer »)

    static let titreDemo = "Essayez-la sans rien installer"
    static let chapeauDemo = "Une résidence fictive, ouverte à tous. Choisissez un rôle."
    static let avertissementDemo = "Données fictives, effacées chaque nuit. Rien n'y est réellement envoyé."
    static let adresseDemo = "demo.coprofirst.fr"
    /// La page publique où le site publie les identifiants de la démo.
    static let pageIdentifiantsDemo = "https://coprofirst.fr/demo.html"

    struct Personnage: Identifiable {
        /// La partie locale de l'identifiant public (`app/demo/personnages.py`).
        let code: String
        let role: String
        let ligne: String
        let symbole: String
        var id: String { code }
    }

    /// ⚠️ Recopié faute de route : aucun point de l'API ne sert les personnages de la
    /// démo (`app/demo/personnages.py`). Besoin noté pour coprofirst#2460. Les mots
    /// de passe, publics mais sensibles par nature, ne sont PAS dans ce dépôt.
    static let personnages = [
        Personnage(
            code: "user-cs", role: "Conseil syndical", ligne: "Le plus complet : suivi, relances, compte rendu.",
            symbole: "person.badge.shield.checkmark.fill"),
        Personnage(
            code: "user-copro", role: "Copropriétaire", ligne: "Son bien, ses documents, ses voisins.",
            symbole: "house.fill"),
        Personnage(
            code: "user-loc", role: "Locataire", ligne: "Informé comme un voisin.",
            symbole: "key.fill"),
    ]
}
