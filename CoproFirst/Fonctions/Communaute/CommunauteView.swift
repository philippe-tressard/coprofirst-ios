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
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        @Bindable var etat = etat
        contenu
            .background(palette.bg)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(tailleTexte.isAccessibilitySize ? .inline : .large)
            .safeAreaInset(edge: .top, spacing: 0) {
                if etat.onglets.count > 1 {
                    Picker("Rubrique", selection: $etat.onglet.animation(.snappy)) {
                        ForEach(etat.onglets) { onglet in
                            Text(onglet.court).tag(onglet).accessibilityLabel(onglet.libelle)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Mise.marge)
                    .padding(.vertical, 8)
                    // Le fond s'arrête au sélecteur : il ne remonte pas sous le grand titre.
                    .background(palette.bg, ignoresSafeAreaEdges: [])
                    .accessibilityIdentifier("communaute.onglets")
                }
            }
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
        case .complet, .avisSeul:
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
            case .idees, .annonces: etat.acces == .complet
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

extension CommunauteView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre)
    }
}
