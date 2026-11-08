// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Ce qui est PROPRE à l'app dans la vitrine : la devise et les boutons (absents du
/// site), les symboles et l'ordre de ce qu'elle montre, et les `id` du site auxquels
/// elle les accroche. Les textes viennent de coprofirst.fr (`contenu.json`, #51) :
/// `Vitrine` les lit, `PagesVitrine` les met en pages.
enum ContenuVitrine {
    static let nom = "CoproFirst"

    // MARK: Accueil « le sceau » (maquette validée)

    static let devise = "La copropriété, enfin partagée."
    static let entrer = "Entrer dans ma résidence"
    static let decouvrirDemo = "Découvrir la démo"
    static let enSavoirPlus = "En savoir plus sur CoproFirst"
    static let essayerDemo = "Essayer la démo"

    // MARK: Démo

    /// L'installation de démonstration, à laquelle l'app se connecte : elle reste ici,
    /// jamais lue du réseau — l'app ne contacte que des adresses qu'elle porte.
    static let adresseDemo = "demo.coprofirst.fr"
    /// La page publique où le site publie les identifiants de la démo.
    static let pageIdentifiantsDemo = "https://coprofirst.fr/demo.html"

    // MARK: Le contrat avec coprofirst-site (#51)

    /// Un `id` de `contenu.json` et le symbole que l'app y accroche.
    struct Accroche: Sendable {
        let id: String
        let symbole: String
    }

    /// Un rôle de la démo : son `id` sur le site, et la partie locale de son
    /// identifiant public (`app/demo/personnages.py` de coprofirst).
    struct RoleDemo: Sendable {
        let id: String
        let code: String
        let symbole: String
    }

    static let heros = "heros"
    static let fonctions = "fonctions"
    static let demo = "demo"

    /// Les fonctions montrées par « En savoir plus », dans l'ordre de l'app — le site en
    /// présente davantage ; l'app garde les six de la maquette validée.
    static let rangees = [
        Accroche(id: "demande", symbole: "exclamationmark.bubble.fill"),
        Accroche(id: "documents", symbole: "doc.text.fill"),
        Accroche(id: "point-syndic", symbole: "person.2.fill"),
        Accroche(id: "badges", symbole: "key.fill"),
        Accroche(id: "carnet", symbole: "book.closed.fill"),
        Accroche(id: "communaute", symbole: "person.3.fill"),
    ]

    /// ⚠️ Les codes sont recopiés faute de route : aucun point de l'API ne sert les
    /// personnages de la démo (`app/demo/personnages.py`). Besoin noté pour
    /// coprofirst#2460. Les mots de passe, publics mais sensibles par nature, ne sont
    /// PAS dans ce dépôt.
    static let roles = [
        RoleDemo(id: "conseil-syndical", code: "user-cs", symbole: "person.badge.shield.checkmark.fill"),
        RoleDemo(id: "coproprietaire", code: "user-copro", symbole: "house.fill"),
        RoleDemo(id: "locataire", code: "user-loc", symbole: "key.fill"),
    ]

    /// FIGÉE avant la première version publiée : chaque `id` dont l'app dépend
    /// (`section` ou `section/élément`). Le site les protège par un contrôle
    /// (coprofirst-site#66) : en retirer un, c'est laisser les apps installées sur leur
    /// dernière lecture. Ce que l'app lit de chacun : `PagesVitrine.lire`.
    static let idsRequis: [String] =
        [heros, fonctions] + rangees.map { "\(fonctions)/\($0.id)" }
        + [demo] + roles.map { "\(demo)/\($0.id)" }
}
