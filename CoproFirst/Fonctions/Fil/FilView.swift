// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 6 — le fil de la résidence, jour par jour : le premier écran après la connexion.
struct FilView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var jours: [JourDuFil] = []
    @State private var phase = Phase.chargement
    @State private var resume: ElementDuFil?
    /// L'élément ouvert : poussé sur iPhone, à côté du fil sur iPad (`ListeEtFiche`, #222).
    @State private var choisi: ElementDuFil?
    /// Dans le carnet du pliable (#119), le jour ouvert : son rang, du plus récent (0).
    @State private var rangDuJour = 0
    @Environment(\.selectionsDeLaPage) private var selections
    @Namespace private var zoom
    @Environment(\.dynamicTypeSize) private var taille
    @Environment(\.colonneDeFiche) private var colonne

    /// Le logement va dans la barre sous un grand titre seulement : un titre en ligne (tailles
    /// d'accessibilité) ou en tête (fiche ouverte à côté, la page à la largeur de sa liste)
    /// partage la rangée de la barre — iOS y coinçait le titre, et iOS 26 y retirait le
    /// logement (`PastilleLogement`, #279). Il passe alors sous le titre.
    private var logementDansLaBarre: Bool {
        TitreDeMenu.mode(colonneOuverte: colonne?.ouverte == true, taille: taille) == .grand
    }

    private enum Phase: Equatable {
        case chargement, pret
        case erreur(ErreurService)
    }

    /// Le carnet ouvert, le fil chargé : une journée par double page (`PageDuJour`).
    private var enDoublePage: Bool {
        parcours.presentation == .carnet && phase == .pret && !jours.isEmpty
    }

    var body: some View {
        // En mémoire seulement : un élément du fil ne se réécrit pas depuis son identifiant.
        ListeEtFiche(
            selection: $choisi, partage: parcours.presentation == .carnet ? .proportion(0.5) : .parDefaut,
            memoire: "fil"
        ) {
            if enDoublePage {
                VStack(spacing: 0) {
                    if !logementDansLaBarre { logementSousLeTitre }
                    PageDuJour(jours: jours, rang: $rangDuJour) { element in
                        CarteOuvrable(element: element, installation: installation, zoom: zoom) { ouvrir(element) }
                    }
                }
            } else {
                fil
            }
        } fiche: { element in
            DestinationDuFil(element: element, installation: installation)
                .destinationZoom(id: element.id, dans: zoom)
        }
        .navigationTitle(OrdrePages.libelleFil)
        .titreDeMenu()
        .sheet(item: $resume) { element in
            ResumeFeuille(element: element, installation: installation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            // Le logement à gauche, en face de la résidence : une ligne de gagnée sous le titre.
            if logementDansLaBarre {
                PastilleLogement.Barre(profil: parcours.ouverteAJour?.profil) { parcours.onglet = "mon-lot" }
            }
            PastilleOuSuisJe(
                installation: installation, cloche: true,
                largeurNom: PastilleLogement.largeurNom(
                    parcours.ouverteAJour?.profil, dansLaBarre: logementDansLaBarre))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BandeauHorsLigne()
        }
        // Demandé fil déjà chargé : une notification touchée, l'app ouverte (#17).
        .onChange(of: parcours.aOuvrir) { if phase == .pret { ouvrirDemande() } }
        // Le jour ouvert du carnet se retrouve au pli comme au retour à la page (#119).
        .onChange(of: rangDuJour) { _, rang in
            guard let selections else { return }
            selections.memoire.noter(jours[safe: rang]?.jour, sous: selections.cle("jour"))
        }
        .task {
            await charger()
            ouvrirDemande()
            await parcours.rafraichirProfil()
        }
    }

    /// Le logement quand la barre n'a pas de place pour lui (`logementDansLaBarre`).
    private var logementSousLeTitre: some View {
        PastilleLogement.Ligne(profil: parcours.ouverteAJour?.profil) { parcours.onglet = "mon-lot" }
    }

    /// Le fil, jour par jour : la liste de `ListeEtFiche`.
    private var fil: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: [.sectionHeaders]) {
                if !logementDansLaBarre { logementSousLeTitre }
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
                            CarteOuvrable(element: element, installation: installation, zoom: zoom) { ouvrir(element) }
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
    }

    /// Un résumé s'ouvre en feuille ; le reste, en fiche — et, dans le carnet, sur la page
    /// de son jour.
    private func ouvrir(_ element: ElementDuFil) {
        if let rang = jours.firstIndex(where: { $0.elements.contains(element) }) { rangDuJour = rang }
        if case .resume = element.cible { resume = element } else { choisi = element }
    }

    /// Le jour que le carnet avait ouvert, s'il est encore au fil ; sinon le plus récent.
    private func reprendreLeJour() {
        let repris = selections.flatMap { $0.memoire.reprendre(Date.self, sous: $0.cle("jour")) }
        rangDuJour = repris.flatMap { jour in jours.firstIndex { $0.jour == jour } } ?? 0
    }

    private var squelette: some View {
        // Des identifiants à part : partagés avec les vrais éléments, SwiftUI
        // réutilisait les vues du squelette — encore grisées une fois le fil chargé.
        ForEach(0..<3, id: \.self) { rang in
            CarteDuFil(element: Apercu.fil[rang]).padding(.horizontal, Mise.marge)
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

    /// L'élément demandé au lancement (`-ouvrir`, une notification), une fois le fil chargé.
    /// Pas avant : un fil quitté en plein chargement (au lancement d'un pliable déplié, la
    /// charnière arrive après le premier écran et le carnet reconstruit le Fil, #119)
    /// consommait la demande sans rien trouver — et la notification n'ouvrait rien.
    private func ouvrirDemande() {
        guard phase == .pret, let id = parcours.aOuvrir else { return }
        parcours.aOuvrir = nil
        guard let element = jours.flatMap(\.elements).first(where: { $0.id == id }) else { return }
        ouvrir(element)
    }

    private func charger() async {
        do {
            let elements = try await parcours.service.fil(installation)
            withAnimation(.snappy) {
                jours = Chronologie.parJour(elements)
                phase = .pret
            }
            reprendreLeJour()
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
        self.init(installation: contexte.installation)
    }
}
