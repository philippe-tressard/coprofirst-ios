// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les avis du conseil syndical sur un prestataire, rangés par exercice et par intervention
/// (`NotationsPrestataire.svelte`, R3d, #207) — tels que l'API les SERT
/// (`GET /prestataires/{id}/interventions`). Un exercice par bloc, le plus récent ouvert ;
/// dedans, une ligne par affaire et le badge de chaque avis, « non notée » sinon. Un badge
/// porte un chevron (coprofirst#2745 : un avis replié se VOIT dépliable) et déplie, sous la
/// ligne, l'auteur, la date et le commentaire.
struct RecapitulatifAvis: View {
    let prestataire: Prestataire
    let installation: Installation
    let service: any ServicePrestataires
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var exercices: [ExerciceAvis] = []
    @State private var exerciceOuvert: Int?
    /// Un avis déplié à la fois, sinon la liste s'allonge.
    @State private var avisOuvert: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !exercices.isEmpty {
                Text(TextesPrestataires.avisDuConseil(prestataire.nbNotations)).styleLibelle()
                ForEach(exercices) { exercice in blocExercice(exercice) }
            }
        }
        .task(id: prestataire.id) { await charger() }
    }

    /// Illisible, le récapitulatif se tait : la fiche reste lisible sans lui.
    private func charger() async {
        let lus = (try? await service.interventions(de: prestataire.id, dans: installation)) ?? []
        exercices = lus
        if exerciceOuvert == nil { exerciceOuvert = lus.first?.annee }
    }

    private func basculer(_ action: () -> Void) {
        withAnimation(mouvementReduit ? nil : .snappy(duration: 0.2)) { action() }
    }

    private func blocExercice(_ exercice: ExerciceAvis) -> some View {
        let ouvert = exerciceOuvert == exercice.annee
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                basculer { exerciceOuvert = ouvert ? nil : exercice.annee }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(ouvert ? 90 : 0))
                            .foregroundStyle(palette.textMuted)
                            .accessibilityHidden(true)
                        // Le titre seul sur sa ligne, les nombres dessous : côte à côte, le très
                        // grand texte coupait « Exer-cice ».
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TextesAvisPrestataire.exercice(exercice.libelle))
                                .font(.subheadline.weight(.semibold))
                            Text(TextesAvisPrestataire.nombres(exercice))
                                .font(.caption).foregroundStyle(palette.textMuted)
                        }
                    }
                    FlowCapsules {
                        ForEach(exercice.comptes, id: \.etat) { compte in
                            PastilleTeinte(
                                libelle: TextesAvisPrestataire.compte(compte.nombre, compte.etat),
                                badge: EtatAvis.teinte(compte.etat), compacte: true)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(ouvert ? "Replie l'exercice" : "Déplie l'exercice")
            .accessibilityIdentifier("avis.exercice.\(exercice.annee)")
            if ouvert {
                ForEach(exercice.lignes) { ligne in ligneIntervention(ligne) }
                    .transition(.opacity)
            }
        }
    }

    private func ligneIntervention(_ ligne: LigneIntervention) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entete(ligne)).font(.subheadline).foregroundStyle(palette.text)
            FlowCapsules {
                if ligne.avis.isEmpty {
                    Text(TextesAvisPrestataire.nonNotee).font(.caption).italic().foregroundStyle(palette.textMuted)
                }
                ForEach(ligne.avis) { avis in badge(avis) }
            }
            ForEach(ligne.avis.filter { $0.id == avisOuvert }) { avis in detail(avis) }
        }
        .padding(.leading, 18)
        .padding(.vertical, 2)
    }

    private func entete(_ ligne: LigneIntervention) -> String {
        guard let date = ligne.date else { return ligne.titre }
        return "\(FormatsDuSite.date(date))\(Separateur.point)\(ligne.titre)"
    }

    /// Le badge d'un avis, et son chevron : il se lit dépliable avant qu'on le touche.
    private func badge(_ avis: AvisPrestataire) -> some View {
        let ouvert = avisOuvert == avis.id
        return Button {
            basculer { avisOuvert = ouvert ? nil : avis.id }
        } label: {
            HStack(spacing: 2) {
                PastilleTeinte(
                    libelle: EtatAvis.libelle(avis.etat), badge: EtatAvis.teinte(avis.etat), compacte: true)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(ouvert ? 180 : 0))
                    .foregroundStyle(palette.textMuted)
            }
            .frame(minHeight: Mise.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .elementIdentifie("avis.\(avis.id)", lu: TextesAvisPrestataire.badge(avis))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(TextesAvisPrestataire.indice(ouvert: ouvert))
    }

    private func detail(_ avis: AvisPrestataire) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text([avis.auteurNom ?? FormatsDuSite.tiret, FormatsDuSite.date(avis.creeLe)]
                .joined(separator: Separateur.point))
                .font(.caption).foregroundStyle(palette.textMuted)
            if let commentaire = avis.commentaire {
                Text(commentaire).font(.subheadline).foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.neutreFond, in: .rect(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("avis.\(avis.id).detail")
        .transition(.opacity)
    }
}
