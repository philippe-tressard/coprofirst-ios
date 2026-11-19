// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce que partagent les pages du Fil dans le carnet de l'iPhone pliable — le jour
/// (`PageDuJour`, #119) et la semaine (`PageDeLaSemaine`, #277) : le pied de page qui
/// tourne la page, le glissement qui la tourne aussi, et le zoom qui passe de l'une à
/// l'autre. Écrits une fois ici.

/// Le pied de page : la page d'avant à gauche, celle d'après à droite, comme dans un carnet.
/// Au très grand texte, les mots ne tiennent plus sur une demi-page sans se couper : les
/// chevrons seuls, leur nom gardé pour VoiceOver.
struct PiedDuCarnet: View {
    struct Bouton {
        let titre: String
        let identifiant: String
        let actif: Bool
    }

    let precedent: Bouton
    let suivant: Bouton
    /// `true` : vers la page d'avant.
    let tourner: (_ reculer: Bool) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
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
            bouton(precedent, "chevron.backward", avecTitre: avecTitres, titreAvant: false, reculer: true)
            Spacer(minLength: Mise.marge)
            bouton(suivant, "chevron.forward", avecTitre: avecTitres, titreAvant: true, reculer: false)
        }
    }

    /// « ‹ Veille », « Lendemain › », ou le chevron seul — son titre gardé pour VoiceOver.
    private func bouton(
        _ bouton: Bouton, _ icone: String, avecTitre: Bool, titreAvant: Bool, reculer: Bool
    ) -> some View {
        Button { tourner(reculer) } label: {
            let label = Label(bouton.titre, systemImage: icone)
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
        .disabled(!bouton.actif)
        .accessibilityIdentifier(bouton.identifiant)
    }
}

/// Le sens d'un zoom du carnet : PINCER resserre (le jour → la semaine), ÉCARTER les doigts
/// ouvre (un jour de la semaine → sa page).
enum SensDuZoom: Sendable {
    case resserrer, ecarter

    /// L'écart de l'échelle dans CE sens : positif quand les doigts vont où il faut.
    func voulu(_ echelle: CGFloat) -> CGFloat { self == .resserrer ? 1 - echelle : echelle - 1 }
}

/// Le zoom du carnet (#277), à la manière d'Apple : la page suit les doigts dès le premier
/// mouvement (1:1 au départ, puis de plus en plus ferme — elle ne disparaît pas sous eux), et
/// résiste à peine dans l'autre sens. Lâchée avant le seuil, elle revient d'un ressort
/// amorti (sans rebond, interruptible : un second pincement la reprend où elle est).
/// Franchi, ou lancé d'un geste vif dans le bon sens, le passage se fait.
///
/// Mouvement réduit : la page ne suit pas les doigts ; le passage se fait en fondu
/// (`TransitionDuCarnet`). L'action d'accessibilité, elle, se pose sur l'élément qui
/// annonce la page (l'éphéméride, l'en-tête d'un jour) : VoiceOver n'expose pas celle
/// d'un conteneur.
struct ZoomDuCarnet: ViewModifier {
    /// Ce que l'échelle parcourt au plus dans le sens voulu, et à rebours.
    static let course: CGFloat = 0.2
    static let resistance: CGFloat = 0.05
    /// L'écart qui décide, et l'écart minimal d'un geste vif (vitesse en échelle par seconde).
    static let seuil: CGFloat = 0.15
    static let seuilVif: CGFloat = 0.04
    static let vitesseVive: CGFloat = 1

    let sens: SensDuZoom
    let passer: () -> Void
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.35, bounce: 0)))
    private var echelle: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(mouvementReduit ? 1 : Self.suivie(echelle, sens: sens))
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($echelle) { valeur, etat, _ in etat = valeur.magnification }
                    .onEnded { valeur in
                        if Self.franchi(valeur.magnification, vitesse: valeur.velocity, sens: sens) { passer() }
                    })
    }

    /// L'échelle montrée : 1:1 près de 1, puis amortie vers `course` (ou `resistance` à
    /// rebours) — l'élastique d'Apple, `x·c / (c + x)`.
    static func suivie(_ echelle: CGFloat, sens: SensDuZoom) -> CGFloat {
        let ecart = echelle - 1
        let borne = sens.voulu(echelle) >= 0 ? course : resistance
        let amorti = borne * abs(ecart) / (borne + abs(ecart))
        return 1 + (ecart < 0 ? -amorti : amorti)
    }

    /// Le passage se fait-il ? L'écart franchi, ou un geste vif — décidé sur le SENS de la
    /// vitesse, jamais sur la position seule.
    static func franchi(_ echelle: CGFloat, vitesse: CGFloat, sens: SensDuZoom) -> Bool {
        let voulu = sens.voulu(echelle)
        let vitesseVoulue = sens == .resserrer ? -vitesse : vitesse
        return voulu >= seuil || (voulu >= seuilVif && vitesseVoulue >= vitesseVive)
    }
}

/// Le passage du jour à la semaine et retour : la semaine est PLUS LOIN que le jour.
/// Pincer, le jour recule et rapetisse, la semaine arrive de devant en se posant ; écarter,
/// le chemin inverse — chaque page entre et sort par le même chemin. Mouvement réduit : un
/// fondu.
enum TransitionDuCarnet {
    static func page(_ niveau: Niveau, mouvementReduit: Bool) -> AnyTransition {
        guard !mouvementReduit else { return .opacity }
        return .scale(scale: niveau == .jour ? 0.92 : 1.08).combined(with: .opacity)
    }

    static func animation(mouvementReduit: Bool) -> Animation {
        mouvementReduit ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
    }

    enum Niveau { case jour, semaine }
}

extension View {
    /// Le zoom du carnet, dans ce sens (`ZoomDuCarnet`).
    func zoomDuCarnet(_ sens: SensDuZoom, passer: @escaping () -> Void) -> some View {
        modifier(ZoomDuCarnet(sens: sens, passer: passer))
    }

    /// Un glissement franchement horizontal, loin du bord (le bord gauche reste au geste du
    /// système, standards/11 §10) : le doigt vers la droite ramène la page d'avant, vers la
    /// gauche celle d'après — comme on tourne une page.
    func tournerLaPage(_ tourner: @escaping (_ reculer: Bool) -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: Mise.cible)
                .onEnded { geste in
                    guard geste.startLocation.x > Mise.marge,
                        abs(geste.translation.width) > 2 * abs(geste.translation.height)
                    else { return }
                    tourner(geste.translation.width > 0)
                })
    }

    /// La page qui arrive en tournant : de gauche vers la page d'avant (`reculer`), où est
    /// son bouton ; de droite vers celle d'après. Mouvement réduit : un fondu.
    func pageTournee(reculer: Bool, mouvementReduit: Bool) -> some View {
        transition(
            mouvementReduit
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: reculer ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: reculer ? .trailing : .leading).combined(with: .opacity)))
    }
}
