// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que « Modifier l'affaire » envoie (PATCH /tickets/{id}) : les SEULS champs que la
/// saisie a changés. Un champ resté `nil` n'est pas envoyé, donc pas réécrit — un PATCH
/// plein écraserait ce que la feuille ne montre pas, ou ce qu'un autre a changé entre-temps.
struct EditionAffaire: Hashable, Sendable {
    var titre: String?
    var descriptionHTML: String?
    var categorie: String?
    var urgente: Bool?
    /// `[]` : plus aucun lieu désigné — le serveur pose alors son défaut.
    var perimetres: [String]?

    /// Rien n'a changé : « Enregistrer » reste éteint.
    var vide: Bool { self == EditionAffaire() }
}

extension DetailAffaire {
    /// La description en texte simple, si la réenregistrer ne perd rien
    /// (`TexteDuSite.saisi(html:)`) — sinon `nil`, et elle se modifie depuis le site.
    var descriptionSaisie: String? { TexteDuSite.saisi(html: description) }

    /// Un lieu au plus : le choix de la feuille le porte. Plusieurs se corrigent depuis
    /// le site — les ramener à un seul en effacerait sans qu'on l'ait demandé.
    var lieuModifiable: Bool { perimetres.count <= 1 }
}

extension SaisieAffaire {
    /// La catégorie d'un bogue : son lieu est le site, et il ne s'épingle ni ne s'urge.
    static let bogue = "bug"

    var estBogue: Bool { categorie == Self.bogue }

    /// La saisie de « Modifier l'affaire » : l'affaire telle que le serveur la sert.
    init(modifiant affaire: DetailAffaire) {
        self.init(
            categorie: affaire.categorie, titre: affaire.titre, description: affaire.descriptionSaisie ?? "",
            urgente: affaire.urgente, perimetre: affaire.perimetres.first)
    }

    /// Ce qui a changé depuis `affaire` — et rien d'autre.
    func edition(depuis affaire: DetailAffaire) -> EditionAffaire {
        let origine = SaisieAffaire(modifiant: affaire)
        var edition = EditionAffaire()
        let titre = titre.trimmingCharacters(in: .whitespacesAndNewlines)
        if titre != origine.titre.trimmingCharacters(in: .whitespacesAndNewlines) { edition.titre = titre }
        if affaire.descriptionSaisie != nil, descriptionHTML != origine.descriptionHTML {
            edition.descriptionHTML = descriptionHTML
        }
        if categorie != origine.categorie { edition.categorie = categorie }
        if urgente != origine.urgente { edition.urgente = urgente }
        let perimetre = estBogue ? nil : perimetre
        if affaire.lieuModifiable, perimetre != origine.perimetre { edition.perimetres = perimetre.map { [$0] } ?? [] }
        return edition
    }

    /// Prête à partir : un titre, une description si la feuille la porte, et un changement.
    func prete(depuis affaire: DetailAffaire) -> Bool {
        let rempli = { (texte: String) in !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return rempli(titre) && (affaire.descriptionSaisie == nil || rempli(description))
            && !edition(depuis: affaire).vide
    }
}
