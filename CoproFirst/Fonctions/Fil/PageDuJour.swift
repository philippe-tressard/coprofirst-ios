// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le Fil dans le carnet de l'iPhone pliable (#119) : UNE journée par double page. La page
/// de gauche porte la date en éphéméride et les cartes du jour ; la fiche de la carte
/// choisie s'ouvre à droite (`ListeEtFiche`, `.proportion(0.5)`).
///
/// On tourne la page vers la veille ou le lendemain par les deux boutons du pied de page, ou
/// d'un glissement horizontal qui ne part pas du bord (le bord gauche reste au geste du
/// système, standards/11 §10). Les jours sont ceux qui ont des cartes : `GET /flux` range une
/// carte au jour de sa publication. La semaine (pincer) attend que l'API la serve
/// (coprofirst#2834) : aucun geste avant.
struct PageDuJour<Carte: View>: View {
    let jours: [JourDuFil]
    /// Le rang du jour ouvert dans `jours`, du plus récent (0) au plus ancien.
    @Binding var rang: Int
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
                        ForEach(jour.elements) { element in
                            carte(element).padding(.horizontal, Mise.marge)
                        }
                    }
                    .padding(.bottom)
                }
                .id(jour.id)
                .transition(transition)
                .simultaneousGesture(glissement)
                Divider()
                piedDePage
            }
            .background(palette.bg)
        }
    }

    private var transition: AnyTransition {
        if mouvementReduit { return .opacity }
        return .asymmetric(
            insertion: .move(edge: reculer ? .leading : .trailing).combined(with: .opacity),
            removal: .move(edge: reculer ? .trailing : .leading).combined(with: .opacity))
    }

    /// Veille à gauche, lendemain à droite, comme les pages d'un carnet. Au très grand texte,
    /// les mots ne tiennent plus sur une demi-page sans se couper : les chevrons seuls, leur
    /// nom gardé pour VoiceOver.
    private var piedDePage: some View {
        ViewThatFits(in: .horizontal) {
            boutons(avecTitres: true)
            boutons(avecTitres: false)
        }
        .font(.subheadline.weight(.semibold))
        .tint(palette.primary)
        .padding(.horizontal, Mise.marge)
        .frame(minHeight: Mise.cible)
        .background(palette.surface)
    }

    private func boutons(avecTitres: Bool) -> some View {
        HStack {
            Button { tourner(reculer: true) } label: {
                etiquette(PageDuJourTextes.veille, "chevron.backward", avecTitre: avecTitres, titreAvant: false)
            }
            .disabled(rang + 1 >= jours.count)
            .accessibilityIdentifier("carnet.veille")
            Spacer(minLength: Mise.marge)
            Button { tourner(reculer: false) } label: {
                etiquette(PageDuJourTextes.lendemain, "chevron.forward", avecTitre: avecTitres, titreAvant: true)
            }
            .disabled(rang == 0)
            .accessibilityIdentifier("carnet.lendemain")
        }
    }

    /// « ‹ Veille », « Lendemain › », ou le chevron seul — son titre gardé pour VoiceOver.
    @ViewBuilder
    private func etiquette(_ titre: String, _ icone: String, avecTitre: Bool, titreAvant: Bool) -> some View {
        let label = Label(titre, systemImage: icone)
        Group {
            if !avecTitre {
                label.labelStyle(.iconOnly)
            } else if titreAvant {
                label.labelStyle(TitreAvantIcone())
            } else {
                label.labelStyle(.titleAndIcon)
            }
        }
        .frame(minWidth: Mise.cible, minHeight: Mise.cible)
        .contentShape(.rect)
    }

    /// Un glissement franchement horizontal, loin du bord : le doigt vers la droite ramène la
    /// veille, vers la gauche le lendemain — comme on tourne une page.
    private var glissement: some Gesture {
        DragGesture(minimumDistance: Mise.cible)
            .onEnded { geste in
                guard geste.startLocation.x > Mise.marge,
                    abs(geste.translation.width) > 2 * abs(geste.translation.height)
                else { return }
                tourner(reculer: geste.translation.width > 0)
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
