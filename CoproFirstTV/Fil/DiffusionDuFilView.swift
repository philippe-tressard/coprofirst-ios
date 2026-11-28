// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce que la diffusion du Fil accepte de l'extérieur, pour les captures et les tests au
/// simulateur (Debug : `LancementTVSimule`) ; rien en Release.
struct ReglagesDuHall: Equatable {
    /// Une tuile tenue agrandie (`-mise-en-avant <id>`), sans cadence.
    var tenue: String?
    /// Le mouvement réduit, en plus du réglage du système (`-mouvement-reduit`).
    var mouvementReduit = false
    /// Une taille de texte imposée (`-grand-texte`) : la plus grande que tient la grille.
    var grandTexte = false
}

extension EnvironmentValues {
    @Entry var reglagesDuHall = ReglagesDuHall()
}

/// Le Fil de la résidence en tuiles (#429, maquette 5.2), sur fond clair quel que soit le thème :
/// le nom et l'heure de l'Apple TV en tête ; en haut, l'urgence et les épinglés ; au milieu, la
/// communauté ; en bas, le reste du Fil qui avance par crans. Environ toutes les 30 s, une tuile
/// grandit depuis sa place, 10 s.
struct DiffusionDuFilView: View {
    @State private var diffusion: DiffusionDuFil
    let retire: () -> Void
    @Namespace private var espace
    @Environment(\.accessibilityReduceMotion) private var mouvementReduitDuSysteme
    @Environment(\.reglagesDuHall) private var reglages

    init(
        appairage: MemoireEcran.Appairage, service: any ServiceFilDuHall, reglages: ReglagesDuHall,
        retire: @escaping () -> Void
    ) {
        _diffusion = State(
            initialValue: DiffusionDuFil(
                residence: appairage.residence, jeton: appairage.jeton, service: service, tenue: reglages.tenue))
        self.retire = retire
    }

    private var reduit: Bool { mouvementReduitDuSysteme || reglages.mouvementReduit }

    var body: some View {
        GrilleDuHallView(diffusion: diffusion, reduit: reduit, espace: espace)
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(reglages.grandTexte ? .xxxLarge : .large)
            .gestesDuHall(retiree: diffusion.retire, retire: retire)
            .task { await diffusion.diffuser() }
    }
}

/// La grille elle-même, sous le thème clair que la racine lui impose : la palette se résout ici.
private struct GrilleDuHallView: View {
    let diffusion: DiffusionDuFil
    let reduit: Bool
    let espace: Namespace.ID
    @Environment(\.palette) private var palette

    var body: some View {
        let grille = diffusion.grille
        ZStack {
            VStack(alignment: .leading, spacing: MiseTV.joint) {
                EnTeteDuHall(residence: diffusion.residence.nom)
                if !diffusion.lue {
                    ProgressView(EcranDeHall.lectureDuFil).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if diffusion.fil.estVide {
                    ContentUnavailableView(
                        EcranDeHall.filVide, systemImage: "newspaper", description: Text(EcranDeHall.filVideMessage)
                    )
                    .accessibilityIdentifier("hall.filVide")
                } else {
                    rangee(grille.haut)
                    rangee(grille.milieu)
                    if !grille.reste.isEmpty { CarrouselDuFil(diffusion: diffusion, reduit: reduit, espace: espace) }
                }
            }
            if let tuile = diffusion.tuileEnAvant { miseEnAvant(tuile) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.bg.ignoresSafeArea())
        .animation(reduit ? .easeInOut(duration: RythmeTV.fondu) : .smooth(duration: 0.7), value: diffusion.enAvant)
        .animation(reduit ? .easeInOut(duration: RythmeTV.fondu) : .smooth(duration: 0.9), value: diffusion.premiere)
        .animation(.smooth(duration: RythmeTV.fondu), value: diffusion.fil)
        // Un conteneur : posé seul, l'identifiant écraserait celui de chaque tuile.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hall.fil")
    }

    @ViewBuilder
    private func rangee(_ tuiles: [TuileDuHall]) -> some View {
        if !tuiles.isEmpty {
            RangeeParPoids(ecart: MiseTV.joint) {
                ForEach(tuiles) { tuile in
                    TuileView(tuile: tuile, diffusion: diffusion)
                        .grandit(tuile.id, dans: espace, enAvant: diffusion.enAvant, reduit: reduit)
                        .layoutValue(key: PoidsDansLaRangee.self, value: tuile.poids)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// La tuile agrandie au centre, sur un voile : elle grandit depuis sa place et y retourne ;
    /// avec le mouvement réduit, elle paraît et s'efface en fondu.
    private func miseEnAvant(_ tuile: TuileDuHall) -> some View {
        ZStack {
            Rectangle().fill(palette.voileModale).ignoresSafeArea().transition(.opacity)
            Group {
                if reduit {
                    MiseEnAvantView(tuile: tuile, diffusion: diffusion)
                        .transition(.opacity)
                } else {
                    MiseEnAvantView(tuile: tuile, diffusion: diffusion)
                        .matchedGeometryEffect(id: tuile.id, in: espace, isSource: true)
                        .transition(.opacity.animation(.smooth(duration: 0.3)))
                }
            }
            .id(tuile.id)
        }
    }
}

/// Le nom de la résidence, puis la date et l'heure de l'Apple TV, relues chaque minute.
private struct EnTeteDuHall: View {
    let residence: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(residence)
                .font(.titre(.title3))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .accessibilityIdentifier("hall.residence")
            Spacer(minLength: MiseTV.joint)
            TimelineView(.everyMinute) { contexte in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(FormatsDuSite.jourCourt(contexte.date)).font(.headline)
                    Text(FormatsDuSite.heure(contexte.date)).font(.title3.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(palette.textMuted)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hall.heure")
            }
        }
    }
}
