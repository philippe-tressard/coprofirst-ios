// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La Communauté : Sondages, Boîte à idées, Petites annonces et Avis, en segments
/// sous le titre. Ce que le serveur ferme ne s'offre pas : un gestionnaire ne voit
/// que l'Avis, un compte suspendu lit le motif du serveur.
struct CommunauteView: View {
    let installation: Installation
    var titre = "Communauté"
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var etat = EtatCommunaute()
    @State private var creation: OngletCommunaute?

    var body: some View {
        @Bindable var etat = etat
        contenu
            .background(palette.bg)
            .navigationTitle(titre)
            .titreDeMenu()
            .modifier(BarreEnHaut(visible: etat.onglets.count > 1) {
                BarreRubriques(onglets: etat.onglets, choisi: $etat.onglet)
            })
            .safeAreaInset(edge: .bottom, spacing: 0) { BandeauCommunaute(bandeau: $etat.bandeau) }
            .toolbar {
                PastilleOuSuisJe(installation: installation, cloche: true)
                ToolbarItem(placement: .topBarLeading) { boutonCreer }
            }
            .sheet(item: $creation) { onglet in
                NavigationStack { formulaire(onglet) }
                    .presentationDragIndicator(.visible)
            }
            .sensoryFeedback(.selection, trigger: etat.onglet)
            .task { await etat.ouvrir(installation, avec: parcours.serviceCommunaute) }
    }

    @ViewBuilder
    private var contenu: some View {
        switch etat.acces {
        case .verification:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ferme(let motif):
            ContentUnavailableView("Communauté", systemImage: "nosign", description: Text("⛔ \(motif)"))
        case .erreur(let erreur):
            MessageErreur(texte: erreur.phrase) {
                Task { await etat.ouvrir(installation, avec: parcours.serviceCommunaute) }
            }
            .padding(Mise.marge)
            .frame(maxHeight: .infinity, alignment: .top)
        case .ouvert:
            switch etat.onglet {
            case .sondages: OngletSondages(etat: etat, installation: installation)
            case .idees: OngletIdees(etat: etat, installation: installation)
            case .annonces: OngletAnnonces(etat: etat, installation: installation)
            case .avis: OngletAvis(etat: etat, installation: installation, modifier: { creation = .avis })
            }
        }
    }

    /// « + » : ce que l'onglet permet de créer, à ce compte. Un sondage se crée sur
    /// le site (conseil syndical) ; un deuxième avis ne se dépose pas.
    @ViewBuilder
    private var boutonCreer: some View {
        let possible: Bool = {
            switch etat.onglet {
            case .sondages: false
            case .idees, .annonces: etat.onglets.contains(etat.onglet)
            case .avis: etat.avis.phase == .pret && etat.monAvisId == nil
            }
        }()
        if possible {
            Button {
                creation = etat.onglet
            } label: {
                Image(systemName: "plus").font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(palette.primaryPlein)
            .accessibilityLabel(libelleCreer)
            .accessibilityIdentifier("communaute.creer")
        }
    }

    private var libelleCreer: String {
        switch etat.onglet {
        case .sondages: ""
        case .idees: "Nouvelle idée"
        case .annonces: "Déposer une annonce"
        case .avis: "Donner mon avis"
        }
    }

    @ViewBuilder
    private func formulaire(_ onglet: OngletCommunaute) -> some View {
        switch onglet {
        case .idees: FormulaireIdee(etat: etat, installation: installation)
        case .annonces: FormulaireAnnonce(etat: etat, installation: installation)
        case .avis: FormulaireAvis(etat: etat, installation: installation)
        case .sondages: EmptyView()
        }
    }
}

/// Les rubriques de la page, en barre qui défile : les libellés du site restent entiers
/// (« Petites annonces » ne tient pas dans un segment), la rubrique choisie est
/// soulignée comme sur le site, et le trait glisse de l'une à l'autre.
private struct BarreRubriques: View {
    let onglets: [OngletCommunaute]
    @Binding var choisi: OngletCommunaute
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @Namespace private var trait

    var body: some View {
        ScrollViewReader { defilement in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(onglets) { onglet in
                        let retenu = onglet == choisi
                        Button {
                            withAnimation(mouvementReduit ? .none : .snappy) { choisi = onglet }
                        } label: {
                            Text(onglet.libelle)
                                .font(.subheadline.weight(retenu ? .semibold : .regular))
                                .foregroundStyle(retenu ? palette.text : palette.textMuted)
                                .padding(.vertical, 10)
                                .frame(minHeight: Mise.cible)
                                .overlay(alignment: .bottom) {
                                    if retenu {
                                        Capsule()
                                            .fill(palette.primary)
                                            .frame(height: 3)
                                            .matchedGeometryEffect(id: "trait", in: trait)
                                    }
                                }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        // Une barre de navigation ne grandit pas sans fin : au-delà, la loupe
                        // d'accessibilité montre le libellé en grand (appui long).
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .accessibilityShowsLargeContentViewer()
                        .id(onglet)
                        .accessibilityAddTraits(retenu ? [.isSelected, .isHeader] : [])
                        .accessibilityIdentifier("communaute.onglet.\(onglet.rawValue)")
                    }
                }
                .padding(.horizontal, Mise.marge)
            }
            .onChange(of: choisi) { _, nouveau in
                withAnimation(mouvementReduit ? .none : .snappy) { defilement.scrollTo(nouveau, anchor: .center) }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(palette.border).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("communaute.onglets")
    }
}

/// La barre des rubriques sous le titre. Sous iOS 26, `safeAreaBar` : le contenu qui
/// défile dessous reçoit l'effet de bord du système. Avant, un encart au fond de la page,
/// qui s'arrête à la barre et ne remonte pas sous le grand titre.
private struct BarreEnHaut<Barre: View>: ViewModifier {
    let visible: Bool
    @ViewBuilder let barre: () -> Barre
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        if !visible {
            content
        } else if #available(iOS 26, *) {
            content.safeAreaBar(edge: .top, spacing: 0) { barre() }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                barre().background(palette.bg, ignoresSafeAreaEdges: [])
            }
        }
    }
}

extension CommunauteView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre)
    }
}
