// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce qu'une page à onglets déclare au cadre : son identifiant du site, la table de
/// ses onglets, leurs descriptifs (générés) et la phrase qui dit à qui elle est réservée.
struct PageAOnglets {
    /// L'identifiant de la page du site (`pages.ts`) : `espace-cs`, `admin`.
    let id: String
    /// L'identifiant d'un onglet du site → sa vue, une ligne par onglet.
    let ecrans: [String: any OngletDePage.Type]
    let descriptifs: [String: String]
    let reserve: String
    /// La page dont l'app ne porte qu'une partie (le Paramétrage, #16) : sa barre n'offre
    /// que les onglets inscrits, puis « Sur le site », qui renvoie à chacun des autres par
    /// son adresse du site (`routes`, générées). Sans elles, un onglet non inscrit dit
    /// « Bientôt ».
    var routes: [String: String]?
    /// Le titre de l'écran : le libellé du menu par défaut — un grand titre ne passe pas
    /// à la ligne, « Espace Conseil Syndical (CS) » se tronquerait.
    var titre: KeyPath<PageDeNavigation, String> = \.libelle

    /// Parmi les onglets ouverts, ceux que l'app ne porte pas, sur une page qui renvoie au site.
    func ailleurs(_ ouverts: [OngletDuSite]) -> [OngletDuSite] {
        routes == nil ? [] : ouverts.filter { ecrans[$0.id] == nil }
    }

    /// La barre : les onglets ouverts ; sur une page qui renvoie au site, les inscrits
    /// puis « Sur le site », s'il reste un onglet que l'app ne porte pas.
    func barre(_ ouverts: [OngletDuSite]) -> [OngletDuSite] {
        guard routes != nil else { return ouverts }
        let portes = ouverts.filter { ecrans[$0.id] != nil }
        return ailleurs(ouverts).isEmpty ? portes : portes + [.surLeSite]
    }
}

/// Le CADRE d'une page à onglets (#15, #16) — titre, barre d'onglets dans l'ordre du
/// site, descriptif de l'onglet, défilement, « tirer pour actualiser » et avis — et
/// l'onglet choisi, que la table de la page inscrit. Écrit une fois : l'Espace CS et le
/// Paramétrage le partagent.
///
/// Une page réservée (`PagesOuvertes`) le redit si on l'atteint autrement que par la
/// barre ; le serveur, lui, refuse chaque route à qui n'a pas le rôle.
struct CadreAOnglets: View {
    let contexte: ContexteDeMenu
    let page: PageAOnglets
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var choisi: String?
    @State private var avis = AvisDuGeste()
    @State private var actualisation = 0

    private var droits: DroitsOnglet {
        DroitsOnglet(profil: parcours.ouverteAJour?.profil ?? contexte.installation.profil)
    }

    /// Les onglets que ce compte ouvre, dans l'ordre du site (`OngletsDuSite.ouverts`).
    private var ouverts: [OngletDuSite] { OngletsDuSite.ouverts(page: page.id, droits: droits) }

    private var ailleurs: [OngletDuSite] { page.ailleurs(ouverts) }

    private var barre: [OngletDuSite] { page.barre(ouverts) }

    var body: some View {
        Group {
            if PagesOuvertes.ouverte(page.id, droits: droits),
                let actif = barre.first(where: { $0.id == choisi }) ?? barre.first
            {
                contenu(actif)
            } else {
                ContentUnavailableView(
                    contexte.page.titre, systemImage: "lock.shield", description: Text(page.reserve))
            }
        }
        .background(palette.bg)
        .navigationTitle(contexte.page[keyPath: page.titre])
        .titreDeMenu()
        .toolbar { PastilleOuSuisJe(installation: contexte.installation, cloche: true) }
    }

    private func contenu(_ actif: OngletDuSite) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BarreOnglets(onglets: barre, actif: Binding { actif.id } set: { choisi = $0 })
                if let descriptif = page.descriptifs[actif.id] ?? OngletSurLeSite.descriptif(actif) {
                    Text(TexteDuSite.apercu(descriptif))
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ecran(actif)
                    .id(actif.id)
                    .transition(.opacity)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .animation(.snappy(duration: 0.22), value: actif.id)
        }
        .refreshable { actualisation += 1 }
        .avisEphemere(avis)
        // Un onglet se note comme le site (`trackTabView`) ; « Sur le site » n'en est pas un.
        .pageVue(actif == .surLeSite ? nil : CheminDuSite.onglet(actif.id, de: contexte.page.route))
    }

    @ViewBuilder
    private func ecran(_ onglet: OngletDuSite) -> some View {
        if onglet == .surLeSite, let routes = page.routes {
            OngletSurLeSite(
                onglets: ailleurs, descriptifs: page.descriptifs, routes: routes,
                adresse: contexte.installation.adresse)
        } else if let type = page.ecrans[onglet.id] {
            AnyView(type.init(contexte: contexteOnglet))
        } else {
            OngletBientot(onglet: onglet)
        }
    }

    private var contexteOnglet: ContexteOnglet {
        ContexteOnglet(
            installation: contexte.installation, service: parcours.service, droits: droits, avis: avis,
            actualisation: actualisation)
    }
}
