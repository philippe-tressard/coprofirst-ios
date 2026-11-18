// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'installation SUSPENDUE par la référence, en lecture seule (Registre R6,
/// coprofirst#1882, #262) — le `BandeauInstallation` du site. Le fait est calculé par le
/// serveur (`installation_suspendue` de GET /config, `Installation.suspendue`), le texte
/// est celui que la release publie (`TexteBandeauSuspendue`) : rien n'est saisi ni recopié.
///
/// Purement informatif, comme celui du site : rien à toucher, une seule annonce. Il décide
/// seul de paraître ; deux rendus, un texte :
/// - sous la barre de CHAQUE page de la résidence ouverte, pages de « Plus », Profil et
///   À propos compris (`.bandeauInstallation()`, posé une fois par `RegistreDesMenus` et
///   par les pages fixes) — au-dessus du bandeau du réseau qu'un écran pose lui-même ;
/// - dans la connexion et au retour (`encartPour:`), pour la résidence reconnue.
/// Le comportement est celui de l'Android (coprofirst-android#233), repère compris.
struct BandeauInstallation: View {
    /// L'encart du formulaire de connexion (`dansCarte` du site), pour la résidence qu'il
    /// nomme ; sinon le bandeau de page, pour la résidence ouverte.
    private let encart: Installation??
    static let identifiant = "bandeau.installation"
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours: Parcours?

    /// En tête d'une page : la résidence ouverte.
    init() { encart = nil }

    /// Dans le formulaire de connexion : la résidence reconnue — aucune, rien ne paraît.
    init(encartPour installation: Installation?) { encart = .some(installation) }

    private var enEncart: Bool { encart != nil }

    var body: some View {
        if (encart ?? parcours?.ouverteAJour)?.suspendue == true {
            if enEncart {
                texte.encartAvertissement().elementIdentifie(Self.identifiant, lu: Self.phrase)
            } else {
                texte
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, Mise.marge)
                    .background(palette.warningFond)
                    .overlay(alignment: .bottom) { palette.warningBordure.frame(height: 1) }
                    .elementIdentifie(Self.identifiant, lu: Self.phrase)
            }
        }
    }

    /// « **Installation suspendue — lecture seule.** Tout reste consultable… », composé
    /// comme le site : `titre` + tiret + `precision` + « . », en gras, puis le `texte`.
    private var texte: some View {
        Text("**\(Self.titre)** \(TexteBandeauSuspendue.texte)")
            .font(.footnote)
            .foregroundStyle(palette.warningTexte)
            .fixedSize(horizontal: false, vertical: true)
    }

    static let titre = "\(TexteBandeauSuspendue.titre)\(Separateur.tiret)\(TexteBandeauSuspendue.precision)."
    /// Ce que VoiceOver lit, d'une traite.
    static let phrase = "\(titre) \(TexteBandeauSuspendue.texte)"
}

extension View {
    /// Sous la barre de la page : l'installation suspendue, s'il y a lieu — rien sinon.
    func bandeauInstallation() -> some View {
        safeAreaInset(edge: .top, spacing: 0) { BandeauInstallation() }
    }
}
