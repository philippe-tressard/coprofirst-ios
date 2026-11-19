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
    /// La semaine ouverte d'un pincement (#277) ; `nil` : le jour.
    @State private var semaine: SemaineDuFil?
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
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
        Group {
            // La semaine sur toute la double page : sans `ListeEtFiche`, la colonne de fiche se
            // ferme (`PageEtColonneDeFiche`).
            // Jamais `Binding($semaine)` : la semaine qui s'en va relit son lien pendant sa
            // transition de sortie, quand `semaine` vaut déjà `nil` — un déballage forcé, et
            // l'app tombait au retour au jour (constaté au simulateur, iOS 26.5).
            if enDoublePage, let ouverte = semaine {
                PageDeLaSemaine(
                    installation: installation,
                    semaine: Binding(get: { self.semaine ?? ouverte }, set: { self.semaine = $0 }),
                    plusAncienne: SemaineDuFil(contenant: jours.last?.jour ?? .now), ouvrirLeJour: ouvrirLeJour
                ) { element in
                    CarteOuvrable(element: element, installation: installation, zoom: zoom) { ouvrir(element) }
                }
                .transition(TransitionDuCarnet.page(.semaine, mouvementReduit: mouvementReduit))
            } else {
                jourOuFil.transition(TransitionDuCarnet.page(.jour, mouvementReduit: mouvementReduit))
            }
        }
        .sensoryFeedback(.selection, trigger: semaine == nil)
        .navigationTitle(OrdrePages.libelleFil)
        .titreDeMenu()
        .sheet(item: $resume) { element in
            ResumeFeuille(element: element, installation: installation)
                .feuilleACrans()
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

    /// Le fil et sa fiche ; dans le carnet, la page du jour (`PageDuJour`).
    private var jourOuFil: some View {
        // En mémoire seulement : un élément du fil ne se réécrit pas depuis son identifiant.
        ListeEtFiche(
            selection: $choisi, partage: parcours.presentation == .carnet ? .proportion(0.5) : .parDefaut,
            memoire: "fil"
        ) {
            if enDoublePage {
                VStack(spacing: 0) {
                    if !logementDansLaBarre { logementSousLeTitre }
                    PageDuJour(jours: jours, rang: $rangDuJour, voirLaSemaine: voirLaSemaine) { element in
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
    }

    /// Pincer la page du jour : sa semaine (#277).
    private func voirLaSemaine() {
        guard let jour = jours[safe: rangDuJour] else { return }
        withAnimation(TransitionDuCarnet.animation(mouvementReduit: mouvementReduit)) {
            semaine = SemaineDuFil(contenant: jour.jour)
        }
    }

    /// Écarter les doigts sur un jour de la semaine : sa page — ou, s'il n'a aucune carte
    /// publiée ce jour-là (une échéance seule), le jour du fil le plus proche. Une fiche
    /// ouverte d'un autre jour se referme : elle ne s'affiche jamais à côté d'un jour qui
    /// ne la porte pas.
    private func ouvrirLeJour(_ jour: Date) {
        let rang = rangLePlusProche(jour)
        let duJour = jours[safe: rang]?.elements ?? []
        if let ouvert = choisi, !duJour.contains(where: { $0.id == ouvert.id }) { choisir(nil) }
        withAnimation(TransitionDuCarnet.animation(mouvementReduit: mouvementReduit)) {
            rangDuJour = rang
            semaine = nil
        }
    }

    /// La sélection, notée tout de suite : quand la semaine est ouverte, la liste n'est pas là
    /// pour la noter, et la reprendrait périmée à son retour (`ListeEtFiche.reprendre`).
    private func choisir(_ element: ElementDuFil?) {
        choisi = element
        if let selections { selections.memoire.noter(element, sous: selections.cle("fil")) }
    }

    /// Le rang du jour du fil le plus proche de `jour` — lui-même s'il a des cartes.
    private func rangLePlusProche(_ jour: Date) -> Int {
        jours.indices.min { abs(jours[$0].jour.timeIntervalSince(jour)) < abs(jours[$1].jour.timeIntervalSince(jour)) }
            ?? 0
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
        .actualisable { await charger() }
    }

    /// Un résumé s'ouvre en feuille ; le reste, en fiche — et, dans le carnet, sur la page
    /// de son jour, d'où qu'on la touche (la semaine se referme alors). Une carte de la
    /// semaine se retrouve au fil par son identifiant : son jour servi la distingue.
    private func ouvrir(_ element: ElementDuFil) {
        let rang = jours.firstIndex { $0.elements.contains { $0.id == element.id } }
        let auFil = rang.flatMap { jours[$0].elements.first { $0.id == element.id } } ?? element
        guard semaine != nil else {
            if let rang { rangDuJour = rang }
            if case .resume = auFil.cible { resume = auFil } else { choisi = auFil }
            return
        }
        if case .resume = auFil.cible {
            resume = auFil
            return
        }
        choisir(auFil)
        withAnimation(TransitionDuCarnet.animation(mouvementReduit: mouvementReduit)) {
            rangDuJour = rang ?? rangLePlusProche(element.date)
            semaine = nil
        }
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
            let elements = try await parcours.service.fil(installation, periode: nil)
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
