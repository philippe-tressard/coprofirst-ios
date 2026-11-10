// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// LA porte de navigation : un lien (#18) ou une notification (#17) devient une
/// `Destination`, et seul `suivre(_:)` l'ouvre.
///
/// | La résidence du lien | Ce qui se passe |
/// |---|---|
/// | celle qui est ouverte | l'écran, tout de suite |
/// | une résidence connue | sa connexion (Face ID si la session est gardée), puis l'écran |
/// | un hôte jamais vu | la connexion, adresse pré-remplie : découverte, puis confirmation de l'hôte avant tout mot de passe (#82) |
///
/// Une page que l'app ne porte pas s'ouvre dans Safari, au-dessus de l'app, quelle que
/// soit la résidence : un lien à jeton ne demande pas d'être connecté.
extension Parcours {
    func suivre(_ destination: Destination) {
        if case .navigateur(let url) = destination.ecran {
            porte.pageWeb = PageWeb(url: url)
            return
        }
        if let ouverte, ouverte.adresse == destination.adresse {
            montrer(destination.ecran, dans: ouverte)
            return
        }
        let connue = connues.liste.first { $0.adresse == destination.adresse }
        changer(pour: connue)
        if connue == nil {
            chemin = [.connexion(Preremplissage(adresse: destination.adresse, depuisUnLien: true))]
        }
        porte.enAttente = destination.ecran == .connexion ? nil : destination
    }

    /// Appelé à chaque ouverture d'une résidence : l'écran d'un lien qui l'attendait.
    func suivreLeLienEnAttente(_ installation: Installation) {
        guard let attente = porte.enAttente else { return }
        porte.enAttente = nil
        if attente.adresse == installation.adresse { montrer(attente.ecran, dans: installation) }
    }

    /// Une résidence peut-elle s'ouvrir d'elle-même (le retour par Face ID, au lancement) ?
    /// Pas sous un lien qui en vise une autre : la connexion du lien est par-dessus, et
    /// c'est elle que l'utilisateur regarde.
    func ouvertureLibre(_ installation: Installation) -> Bool {
        porte.enAttente.map { $0.adresse == installation.adresse } ?? true
    }

    /// Les pages de la barre de cette résidence, pour ce compte, dans leur ordre —
    /// celles qu'affiche `OngletsView`, et celles où la porte peut se poser.
    func pagesDeLaBarre(_ installation: Installation) -> [PageDeNavigation] {
        let profil = ouverteAJour?.profil ?? installation.profil
        return PagesOuvertes.filtrer(installation.pages, droits: DroitsOnglet(profil: profil))
    }

    private func montrer(_ ecran: Destination.Ecran, dans installation: Installation) {
        let pages = pagesDeLaBarre(installation).map(\.id)
        switch Aiguillage.aiguiller(ecran, pages: pages, visibles: OngletsView.visibles) {
        case .onglet(let id):
            onglet = id
        case .affaireDansLOnglet(let id, let affaire):
            porte.affaireDansLOnglet = affaire
            onglet = id
        case .affaireEnFeuille(let affaire):
            porte.affaireEnFeuille = AffaireEnFeuille(id: affaire)
        case .elementDuFil(let cle):
            aOuvrir = cle
            onglet = OrdrePages.idFil
        }
    }
}
