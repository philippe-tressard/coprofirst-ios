// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les avis du conseil syndical sur un prestataire, rangés par exercice et par intervention
/// (`NotationsPrestataire.svelte`, R3d, #207) — tels que l'API les SERT
/// (`GET /prestataires/{id}/interventions`). Un exercice par bloc, le plus récent ouvert ;
/// dedans, une ligne par affaire et le badge de chaque avis, « non notée » sinon. Un badge
/// porte un chevron (coprofirst#2745 : un avis replié se VOIT dépliable) et déplie, sous la
/// ligne, l'auteur, la date et le commentaire — puis ses gestes : « Modifier cet avis »
/// selon `peut_modifier` (servi, l'auteur seul), « Retirer cet avis » pour le conseil
/// syndical (`est_moderateur` servi), comme le serveur. En tête, « ⭐ Noter » (le conseil,
/// sur une fiche non archivée). Après un geste, le récapitulatif ET la liste se relisent.
struct RecapitulatifAvis: View {
    let prestataire: Prestataire
    let installation: Installation
    let service: any ServicePrestataires
    let archive: Bool
    let gestes: GestesAvis
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var exercices: [ExerciceAvis] = []
    @State private var exerciceOuvert: Int?
    /// Un avis déplié à la fois, sinon la liste s'allonge.
    @State private var avisOuvert: Int?
    @State private var corrige: AvisPrestataire?
    @State private var aRetirer: AvisPrestataire?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if gestes.conseil && !archive {
                BoutonNoter(
                    prestataire: prestataire, contrat: nil, installation: installation, service: service,
                    gestes: gestes, relire: charger)
            }
            if !exercices.isEmpty {
                Text(TextesPrestataires.avisDuConseil(prestataire.nbNotations)).styleLibelle()
                ForEach(exercices) { exercice in blocExercice(exercice) }
            }
        }
        .task(id: prestataire.id) { await charger() }
        .sheet(item: $corrige, onDismiss: { gestes.avis.feuilleFermee() }, content: { avis in
            FeuilleAvis(
                mode: .corriger(avis), prestataire: prestataire, installation: installation, service: service,
                envoye: { phrase in
                    gestes.avis.direApresFermeture(phrase)
                    corrige = nil
                    apresGeste()
                })
        })
        .confirmationDialog(
            TextesSaisieAvis.retirer,
            isPresented: Binding(get: { aRetirer != nil }, set: { if !$0 { aRetirer = nil } }),
            titleVisibility: .visible, presenting: aRetirer
        ) { avis in
            Button(TextesSaisieAvis.confirmerRetrait, role: .destructive) { Task { await retirer(avis) } }
                .accessibilityIdentifier("avis.confirmerRetrait")
        } message: { avis in
            Text(TextesSaisieAvis.retrait(avis))
        }
    }

    /// La liste (moyenne servie) et le récapitulatif se relisent après un geste.
    private func apresGeste() {
        gestes.apres()
        Task { await charger() }
    }

    /// Retirer un avis : définitif, et la moyenne du prestataire se recalcule au serveur.
    private func retirer(_ avis: AvisPrestataire) async {
        do {
            try await service.retirer(avis.id, dans: installation)
            gestes.avis.dire(TextesSaisieAvis.retire)
            avisOuvert = nil
            apresGeste()
        } catch {
            gestes.avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
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
            .depliage(ouvert: ouvert, deplier: "Déplie l'exercice", replier: "Replie l'exercice")
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
        .depliage(ouvert: ouvert, deplier: TextesAvisPrestataire.deplier, replier: TextesAvisPrestataire.replier)
    }

    private func detail(_ avis: AvisPrestataire) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text([avis.auteurNom ?? FormatsDuSite.tiret, FormatsDuSite.date(avis.creeLe)]
                    .joined(separator: Separateur.point))
                    .font(.caption).foregroundStyle(palette.textMuted)
                if let commentaire = avis.commentaire {
                    Text(commentaire).font(.subheadline).foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("avis.\(avis.id).detail")
            GestesDeLAvis(
                avis: avis, retirable: gestes.conseil, modifier: { corrige = avis }, retirer: { aRetirer = avis })
        }
        .padding(10)
        .background(palette.neutreFond, in: .rect(cornerRadius: Mise.rayonTuile, style: .continuous))
        .transition(.opacity)
    }
}

/// Les gestes d'un avis déplié, chacun selon son droit SERVI — absent, aucun bouton. Deux
/// boutons nommés côte à côte, l'un sous l'autre quand le texte grandit ; le retrait,
/// définitif, se confirme (`NotationsPrestataire.supprimer`).
private struct GestesDeLAvis: View {
    let avis: AvisPrestataire
    let retirable: Bool
    let modifier: () -> Void
    let retirer: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        if avis.peutModifier || retirable {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { boutons }
                VStack(alignment: .leading, spacing: 8) { boutons }
            }
        }
    }

    @ViewBuilder private var boutons: some View {
        if avis.peutModifier {
            Button(action: modifier) {
                Label(TextesSaisieAvis.modifier, systemImage: "pencil")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(palette.primary)
            .frame(minHeight: Mise.cible)
            .gesteEnLigne()
            .accessibilityIdentifier("avis.\(avis.id).modifier")
        }
        if retirable {
            Button(role: .destructive, action: retirer) {
                Label(TextesSaisieAvis.retirer, systemImage: "trash")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(palette.danger)
            .frame(minHeight: Mise.cible)
            .gesteEnLigne()
            .accessibilityLabel(TextesSaisieAvis.retirerDe(avis))
            .accessibilityIdentifier("avis.\(avis.id).retirer")
        }
    }
}
