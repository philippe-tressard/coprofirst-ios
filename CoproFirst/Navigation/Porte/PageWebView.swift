// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SafariServices
import SwiftUI

/// Une page du site que l'app ne porte pas, dans Safari au-dessus de l'app (#18).
///
/// Safari intégré, et non `openURL` : ouvrir dans Safari une adresse que l'app déclare
/// (lien universel) la renverrait à l'app — une boucle. Le contrôleur de Safari ne suit
/// pas les liens universels ; il garde ses cookies à part de ceux de l'app.
struct PageWebView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.palette) private var palette

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controleur = SFSafariViewController(url: url)
        controleur.preferredControlTintColor = UIColor(palette.primary)
        controleur.dismissButtonStyle = .close
        return controleur
    }

    func updateUIViewController(_ controleur: SFSafariViewController, context: Context) {}
}
