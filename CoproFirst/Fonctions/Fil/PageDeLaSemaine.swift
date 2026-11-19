// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La semaine du Fil dans le carnet de l'iPhone pliable (#277), ouverte d'un PINCEMENT sur la
/// page du jour : du lundi au jeudi à gauche, du vendredi au dimanche à droite, sur toute la
/// double page. Chaque carte à son jour tel que le SERVEUR l'y range (`GET /flux?du=&au=`,
/// `SemaineDuFil`) : une coupure d'eau publiée lundi pour jeudi est au jeudi.
///
/// ÉCARTER les doigts sur un jour, ou toucher son en-tête, rouvre la page de ce jour ; une
/// carte touchée s'ouvre sur la page de son jour, sa fiche à droite. Les semaines se tournent
/// comme les jours (`FeuilletDuCarnet`). Une semaine lue reste en mémoire le temps de l'écran :
/// y revenir ne recharge rien.
struct PageDeLaSemaine<Carte: View>: View {
    let installation: Installation
    @Binding var semaine: SemaineDuFil
    /// La plus ancienne semaine que le fil connaît : on ne tourne pas au-delà.
    let plusAncienne: SemaineDuFil
    let ouvrirLeJour: (Date) -> Void
    @ViewBuilder let carte: (ElementDuFil) -> Carte
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var lues: [SemaineDuFil: [ElementDuFil]] = [:]
    @State private var erreur: ErreurService?
    @State private var reculer = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                page(0..<4, avecTitre: true)
                // Le pli : la double page se coupe au milieu de la fenêtre (`Posture`).
                Divider()
                page(4..<7, avecTitre: false)
            }
            .id(semaine)
            .pageTournee(reculer: reculer, mouvementReduit: mouvementReduit)
            .tournerLaPage(tourner)
            Divider()
            PiedDuCarnet(
                precedent: .init(
                    titre: TextesSemaine.precedente, identifiant: "carnet.semaine.precedente",
                    actif: semaine.lundi > plusAncienne.lundi),
                suivant: .init(titre: TextesSemaine.suivante, identifiant: "carnet.semaine.suivante", actif: true),
                tourner: tourner)
        }
        .background(palette.bg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("carnet.semaine")
        .task(id: semaine) { await charger() }
    }

    private func page(_ rangs: Range<Int>, avecTitre: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if avecTitre {
                    Text(semaine.titre)
                        .font(.titre(.title2))
                        .foregroundStyle(palette.text)
                        .padding(.horizontal, Mise.marge)
                        .accessibilityAddTraits(.isHeader)
                }
                if let erreur, avecTitre {
                    MessageErreur(texte: erreur.phrase) { Task { await charger() } }
                        .padding(.horizontal, Mise.marge)
                }
                ForEach(rangs, id: \.self) { rang in
                    jour(semaine.jours[rang], cartes: lues[semaine].map { semaine.ranger($0)[rang] })
                }
            }
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity)
    }

    /// Un jour : son en-tête, qui rouvre sa page, et ses cartes — `nil` pendant le chargement.
    private func jour(_ jour: Date, cartes: [ElementDuFil]?) -> some View {
        let aujourdhui = Chronologie.calendrier.isDateInToday(jour)
        return VStack(alignment: .leading, spacing: 8) {
            Button { ouvrirLeJour(jour) } label: {
                Text(Chronologie.enteteAffiche(jour))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(aujourdhui ? palette.primary : palette.textMuted)
                    .frame(maxWidth: .infinity, minHeight: Mise.cible, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Mise.marge)
            .accessibilityLabel(FormatsDuSite.dateLongue(jour))
            .accessibilityHint(TextesSemaine.ouvrirCeJour)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("carnet.semaine.\(FormatsDuSite.jourISO(jour))")
            if let cartes {
                if cartes.isEmpty {
                    Text(TextesSemaine.rien)
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .padding(.horizontal, Mise.marge)
                }
                ForEach(cartes) { carte($0).padding(.horizontal, Mise.marge) }
            } else if erreur == nil {
                ProgressView().padding(.horizontal, Mise.marge).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .zoomDuCarnet(.ecarter) { ouvrirLeJour(jour) }
    }

    private func tourner(reculer: Bool) {
        let cible = semaine.decalee(de: reculer ? -1 : 1)
        guard !reculer || cible.lundi >= plusAncienne.lundi else { return }
        self.reculer = reculer
        withAnimation(mouvementReduit ? .easeInOut(duration: 0.2) : .snappy) { semaine = cible }
    }

    private func charger() async {
        let demandee = semaine
        guard lues[demandee] == nil else { return erreur = nil }
        erreur = nil
        do {
            let cartes = try await parcours.service.fil(installation, periode: demandee.periode)
            withAnimation(.snappy) {
                lues[demandee] = cartes
                erreur = nil
            }
        } catch {
            guard demandee == semaine else { return }
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}
