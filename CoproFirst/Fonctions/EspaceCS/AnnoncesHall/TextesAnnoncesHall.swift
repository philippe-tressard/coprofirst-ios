// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

/// Les textes des Annonces Hall, écrits une fois : ceux de `OngletAnnoncesHall`,
/// `HistoriqueAnnoncesHall` et `FormulaireAnnonceHall` (coprofirst v3.61.0).
enum TextesAnnoncesHall {
    static let nouvelle = "Nouvelle annonce"
    static let archives = "Archives"
    static let aucune = "Aucune annonce"
    static let aucuneDetail = "Créez la première annonce depuis l'onglet « Nouvelle annonce »."
    static let archivee = "Archivée"
    static let actualite = "Actualité"
    static let nonEnvoyee = "Non envoyée"
    static let renvoyer = "Renvoyer au CS du périmètre"
    static let archiver = "Archiver"
    static let restaurer = "Restaurer"
    static let supprimer = "Supprimer définitivement"
    static let gestes = "Gestes sur l'annonce"
    static let titre = "Titre"
    static let titreExemple = "Ex : Coupure d'eau jeudi matin"
    static let message = "Message"
    static let messageExemple = "Le texte de l'affiche…"
    static let perimetre = "Périmètre"
    static let perimetreAide = "Sans choix, l'affiche vaut pour le périmètre par défaut de la résidence."
    static let format = "Format"
    static let formatAide = "Auto : le serveur choisit le plus grand format où le texte tient."
    static let diffusion = "Diffusion"
    static let envoyerCS = "Envoyer aux membres du CS du périmètre"
    static let envoyerSyndic = "Envoyer au syndic"
    static let envoyerAuteur = "M'envoyer une copie"
    static let creer = "Créer l'annonce"
    static let surLeSite =
        "Les photos, l’assistant de rédaction, l’aperçu avant envoi, la reprise d’un élément du fil, le partage "
        + "WhatsApp et le PDF de l’affiche se trouvent sur le site."

    static func destinataires(_ nombre: Int) -> String { "\(nombre) destinataire\(nombre > 1 ? "s" : "")" }

    /// « Envoyée le 02/04/2026 14:30 à Lucie Exemple, Marc Démo ».
    static func envoi(_ annonce: AnnonceHall) -> String {
        "Envoyée le \(FormatsDuSite.dateHeureCourte(annonce.envoyeLe ?? annonce.creeLe)) à "
            + annonce.destinataires.joined(separator: ", ")
    }

    /// Le compte rendu d'une création, comme le site le dit.
    static func creee(_ annonce: AnnonceHall) -> String {
        let nombre = annonce.destinataires.count
        return nombre > 0
            ? "Annonce \(annonce.formatLabel) créée et envoyée à \(nombre) membre\(nombre > 1 ? "s" : "") du CS"
            : "Annonce \(annonce.formatLabel) créée — aucun membre du CS à notifier sur ce périmètre"
    }

    /// La phrase brève qui suit un geste réussi — celle du site.
    static func fait(_ geste: GesteAnnonceHall, _ annonce: AnnonceHall) -> String {
        switch geste {
        case .renvoyer: "Annonce renvoyée au CS du périmètre"
        case .archiver: annonce.archivee ? "Annonce restaurée" : "Annonce archivée"
        case .supprimer: "Annonce supprimée"
        }
    }

    static func supprimerQuestion(_ annonce: AnnonceHall) -> String { "Supprimer « \(annonce.titre) » ?" }

    static func supprimerMessage(_ annonce: AnnonceHall) -> String {
        "Son PDF sera effacé ; les photos qu'elle reprend restent."
            + (annonce.destinataires.isEmpty
                ? "" : " Elle a déjà été envoyée par courriel : les destinataires la gardent.")
    }
}
