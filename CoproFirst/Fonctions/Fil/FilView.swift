// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 6 — le fil de la résidence, jour par jour : le premier écran après la connexion.
struct FilView: View {
    let installation: Installation
    @Binding var chemin: NavigationPath
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.palette) private var palette
    @State private var jours: [JourDuFil] = []
    @State private var phase = Phase.chargement
    @State private var resume: ElementDuFil?
    @Namespace private var zoom

    private enum Phase: Equatable {
        case chargement, pret
        case erreur(ErreurService)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                LigneLot(profil: parcours.ouverteAJour?.profil) { parcours.onglet = "mon-lot" }
                if phase == .chargement {
                    Section {
                        squelette
                    } header: {
                        EnTeteJour(texte: Chronologie.espacer("Aujourd'hui".uppercased()))
                    }
                }
                ForEach(jours) { jour in
                    Section {
                        ForEach(jour.elements) { element in
                            CarteOuvrable(element: element, zoom: zoom) { resume = element }
                                .padding(.horizontal, Mise.marge)
                        }
                    } header: {
                        EnTeteJour(texte: Chronologie.enteteAffiche(jour.jour))
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .background(palette.bg)
        .overlay { etatVide }
        .refreshable { await charger() }
        .navigationTitle(OrdrePages.libelleFil)
        .navigationDestination(for: ElementDuFil.self) { element in
            DestinationDuFil(element: element, installation: installation)
                .destinationZoom(id: element.id, dans: zoom)
        }
        .sheet(item: $resume) { element in
            ResumeFeuille(element: element, installation: installation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !reseau.enLigne { BandeauHorsLigne() }
        }
        .task {
            await charger()
            ouvrirDemande()
            await parcours.rafraichirProfil()
        }
    }

    private var squelette: some View {
        // Des identifiants à part : partagés avec les vrais éléments, SwiftUI
        // réutilisait les vues du squelette — encore grisées une fois le fil chargé.
        ForEach(0..<3, id: \.self) { rang in
            CarteDuFil(element: ServiceSimule.fil[rang]).padding(.horizontal, Mise.marge)
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var etatVide: some View {
        if case .erreur(let erreur) = phase {
            MessageErreur(texte: erreur.phrase) { Task { await charger() } }
                .padding(Mise.marge)
        } else if phase == .pret, jours.isEmpty {
            ContentUnavailableView(
                "Rien de neuf", systemImage: "sparkles",
                description: Text("Le fil se remplira des affaires, actualités et documents de la résidence."))
        }
    }

    /// L'élément demandé au lancement (`-ouvrir`), une fois le fil chargé.
    private func ouvrirDemande() {
        guard let id = parcours.aOuvrir else { return }
        parcours.aOuvrir = nil
        guard let element = jours.flatMap(\.elements).first(where: { $0.id == id }) else { return }
        if case .resume = element.cible { resume = element } else { chemin.append(element) }
    }

    private func charger() async {
        do {
            let elements = try await parcours.service.fil(installation)
            withAnimation(.snappy) {
                jours = Chronologie.parJour(elements)
                phase = .pret
            }
        } catch {
            withAnimation(.snappy) { phase = .erreur(ErreurService.depuis(error)) }
        }
    }
}

/// L'en-tête d'un jour, collé en haut tant que sa journée défile.
struct EnTeteJour: View {
    /// Déjà en capitales et espacé (`Chronologie.enteteAffiche`) : ni `textCase` ni
    /// `tracking` ici, qui s'appliqueraient aussi au « 1ᵉʳ ».
    let texte: AttributedString
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityAddTraits(.isHeader)
    }
}

extension FilView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, chemin: contexte.chemin)
    }
}
