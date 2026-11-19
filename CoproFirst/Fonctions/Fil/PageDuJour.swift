// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le Fil dans le carnet de l'iPhone pliable (#119) : UNE journée par double page. La page
/// de gauche porte la date en éphéméride et les cartes du jour ; la fiche de la carte
/// choisie s'ouvre à droite (`ListeEtFiche`, `.proportion(0.5)`).
///
/// On tourne la page vers la veille ou le lendemain par les deux boutons du pied de page, ou
/// d'un glissement horizontal qui ne part pas du bord (`FeuilletDuCarnet`). Les jours sont
/// ceux qui ont des cartes : sans période, `GET /flux` range une carte au jour de sa
/// publication. PINCER ouvre la semaine (`PageDeLaSemaine`, #277) ; VoiceOver a la même
/// action sur l'éphéméride.
struct PageDuJour<Carte: View>: View {
    let jours: [JourDuFil]
    /// Le rang du jour ouvert dans `jours`, du plus récent (0) au plus ancien.
    @Binding var rang: Int
    /// Pincer : la semaine de ce jour.
    let voirLaSemaine: () -> Void
    @ViewBuilder let carte: (ElementDuFil) -> Carte
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// Le sens de la dernière page tournée : vers la veille (`reculer`), la page arrive de
    /// gauche, où est le bouton « Veille » ; vers le lendemain, de droite.
    @State private var reculer = true

    var body: some View {
        if let jour = jours[safe: rang] {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Ephemeride(jour: jour.jour)
                            .accessibilityAction(named: TextesSemaine.voirLaSemaine, voirLaSemaine)
                        ForEach(jour.elements) { element in
                            carte(element).padding(.horizontal, Mise.marge)
                        }
                    }
                    .padding(.bottom)
                }
                .id(jour.id)
                .pageTournee(reculer: reculer, mouvementReduit: mouvementReduit)
                .tournerLaPage(tourner)
                .zoomDuCarnet(.resserrer, passer: voirLaSemaine)
                .accessibilityIdentifier("carnet.jour")
                Divider()
                PiedDuCarnet(
                    precedent: .init(
                        titre: PageDuJourTextes.veille, identifiant: "carnet.veille", actif: rang + 1 < jours.count),
                    suivant: .init(titre: PageDuJourTextes.lendemain, identifiant: "carnet.lendemain", actif: rang > 0),
                    tourner: tourner)
            }
            .background(palette.bg)
        }
    }

    private func tourner(reculer: Bool) {
        let cible = rang + (reculer ? 1 : -1)
        guard jours.indices.contains(cible) else { return }
        self.reculer = reculer
        withAnimation(mouvementReduit ? .easeInOut(duration: 0.2) : .snappy) { rang = cible }
    }
}

/// La date du jour en éphéméride : le quantième en grand, le mois et l'année dessous, et la
/// ligne d'en-tête du fil (« AUJOURD'HUI · MARDI 17 ») au-dessus.
private struct Ephemeride: View {
    let jour: Date
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Chronologie.enteteAffiche(jour))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textMuted)
            Text(String(Chronologie.calendrier.component(.day, from: jour)))
                .font(.titre(.largeTitle))
                .foregroundStyle(palette.text)
            Text(FormatsDuSite.moisAnnee(jour))
                .font(.subheadline)
                .foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Mise.marge)
        .padding(.vertical)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FormatsDuSite.dateLongue(jour))
        .accessibilityAddTraits(.isHeader)
    }
}

enum PageDuJourTextes {
    static let veille = "Veille"
    static let lendemain = "Lendemain"
}

extension Array {
    /// L'élément de ce rang, s'il existe.
    subscript(safe rang: Int) -> Element? { indices.contains(rang) ? self[rang] : nil }
}
