// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le marque-page du carnet (#119) : la page ouverte d'une résidence, gardée sur l'appareil
/// seulement, pour rouvrir au même endroit quand iOS a arrêté l'app pliée.
///
/// Décision du 17/11/2026 : il ne s'écrit que si une CHARNIÈRE est présente
/// (`Posture` ≠ `.sansPli`) — un iPhone ordinaire continue de s'ouvrir sur le Fil. Il
/// s'efface à la déconnexion, à la porte de tout ce qu'une session laisse
/// (`oublierCeQuiEstGarde`). L'élément ouvert d'une liste nommée s'y garde aussi
/// (`MemoireDesSelections.Disque`), par son identifiant seul (`SelectionGardable`).
///
/// Les clés séparent l'hôte par `/`, qu'un nom d'hôte ne contient jamais : effacer
/// `a.com` n'efface pas `a.com.exemple`.
///
/// `@unchecked` : `UserDefaults` est sûr d'un fil à l'autre (documentation d'Apple), sans
/// que le SDK le déclare `Sendable`.
struct MarquesPages: @unchecked Sendable {
    /// Ceux de l'app ; l'API simulée a les siens, effacés à chaque lancement.
    static let standard = MarquesPages(reglages: .standard)

    let reglages: UserDefaults

    func lire(_ hote: String) -> String? { reglages.string(forKey: cle(hote)) }

    func garder(_ page: String, pour hote: String) { reglages.set(page, forKey: cle(hote)) }

    func lire(_ cle: MemoireDesSelections.Cle, pour hote: String) -> String? {
        reglages.string(forKey: self.cle(hote, cle))
    }

    /// `nil` efface la case : une liste vidée ne rouvre pas l'ancienne fiche.
    func garder(_ element: String?, _ cle: MemoireDesSelections.Cle, pour hote: String) {
        if let element {
            reglages.set(element, forKey: self.cle(hote, cle))
        } else {
            reglages.removeObject(forKey: self.cle(hote, cle))
        }
    }

    /// La page ET les éléments de toutes les listes de cette résidence.
    func effacer(_ hote: String) {
        reglages.removeObject(forKey: cle(hote))
        let prefixe = cle(hote) + "/"
        for cle in reglages.dictionaryRepresentation().keys where cle.hasPrefix(prefixe) {
            reglages.removeObject(forKey: cle)
        }
    }

    private func cle(_ hote: String) -> String { "marque-page/\(hote)" }

    private func cle(_ hote: String, _ cle: MemoireDesSelections.Cle) -> String {
        "marque-page/\(hote)/\(cle.page)/\(cle.liste)"
    }
}

extension Parcours {
    /// La page où rouvrir une résidence : son marque-page sur un pliable, traduit vers la
    /// présentation en vigueur (`PresentationNavigation.traduire`) ; le Fil sinon.
    func pageARouvrir(_ installation: Installation) -> PresentationNavigation.Place {
        guard posture != .sansPli, let page = marques.lire(installation.hote) else {
            return .init(onglet: OrdrePages.idFil)
        }
        let pages = pagesDeLaBarre(installation).map(\.id)
        guard pages.contains(page) || EntreeFixe(rawValue: page) != nil else {
            return .init(onglet: OrdrePages.idFil)
        }
        return PresentationNavigation.traduire(.init(onglet: page), vers: presentation, pages: pages)
    }

    /// Le disque des sélections : le marque-page de la résidence ouverte, sur un pliable
    /// seulement — ailleurs, rien ne s'y lit ni ne s'y écrit.
    var disqueDesSelections: MemoireDesSelections.Disque {
        .init(
            lire: { [weak self] cle in
                guard let self, posture != .sansPli, let ouverte else { return nil }
                return marques.lire(cle, pour: ouverte.hote)
            },
            garder: { [weak self] element, cle in
                guard let self, posture != .sansPli, let ouverte else { return }
                marques.garder(element, cle, pour: ouverte.hote)
            })
    }

    /// Note la page ouverte — sur un pliable seulement. Dans « Plus », c'est la page qui y est
    /// ouverte ; « Plus » seul n'est pas une page, et ne se note pas.
    func noterLeMarquePage() {
        guard posture != .sansPli, let ouverte else { return }
        let page = onglet == Aiguillage.idPlus ? ouverteDansPlus : onglet
        if let page { marques.garder(page, pour: ouverte.hote) }
    }
}
