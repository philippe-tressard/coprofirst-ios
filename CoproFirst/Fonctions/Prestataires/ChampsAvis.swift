// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le corps de la saisie d'un avis (`FormulaireNotation.svelte`, #207) : les trois états,
/// les deux listes de motifs à cocher, la phrase qu'elles composent, le texte libre.
/// Des sections de `Form` : la feuille (`FeuilleAvis`) les pose sous le choix de l'affaire.
struct ChampsAvis: View {
    @Binding var saisie: AvisSaisi
    /// Ce qui retient l'avis, dit sous le dernier champ (« Choisissez l'état… »).
    let refus: String?
    @Environment(\.palette) private var palette

    var body: some View {
        Section(TextesSaisieAvis.etatGroupe) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { boutonsEtat }
                VStack(spacing: 8) { boutonsEtat }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            .sensoryFeedback(.selection, trigger: saisie.etat)
        }
        motifs(TextesSaisieAvis.pointsForts, TablesNotations.pointsForts, coches: $saisie.forts, cle: "fort")
        motifs(TextesSaisieAvis.pointsFaibles, TablesNotations.pointsFaibles, coches: $saisie.faibles, cle: "faible")
        Section(TextesSaisieAvis.commentaireGenere) {
            let genere = saisie.genere
            Text(genere.isEmpty ? TextesSaisieAvis.rienDeCoche : genere)
                .font(.subheadline)
                .foregroundStyle(genere.isEmpty ? palette.textMuted : palette.text)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.15), value: genere)
                .accessibilityIdentifier("avis.genere")
        }
        Section {
            TextField(TextesSaisieAvis.commentaireLibre, text: $saisie.libre, axis: .vertical)
                .lineLimit(3...8)
                .accessibilityIdentifier("avis.libre")
        } header: {
            Text("\(TextesSaisieAvis.commentaireLibre) \(TextesSaisieAvis.aideLibre)")
        } footer: {
            if let refus {
                Text(refus).accessibilityIdentifier("avis.refus")
            }
        }
    }

    private var boutonsEtat: some View {
        ForEach(TablesNotations.etats, id: \.self) { etat in
            BoutonEtat(etat: etat, choisi: saisie.etat == etat) { saisie.etat = etat }
        }
    }

    /// Une liste de motifs, une case par motif — dans l'ordre du site, qui est celui de la phrase.
    private func motifs(_ titre: String, _ liste: [String], coches: Binding<Set<String>>, cle: String) -> some View {
        Section(titre) {
            ForEach(Array(liste.enumerated()), id: \.element) { rang, motif in
                CaseACocher(
                    libelle: motif, identifiant: "avis.\(cle).\(rang)",
                    coche: Binding(
                        get: { coches.wrappedValue.contains(motif) },
                        set: { coche in
                            if coche { coches.wrappedValue.insert(motif) } else { coches.wrappedValue.remove(motif) }
                        }))
            }
        }
    }
}

/// Une case à cocher (`<input type="checkbox">` du site) : toute la rangée la bascule,
/// à hauteur de pouce — un interrupteur ne basculait pas au toucher de son libellé.
struct CaseACocher: View {
    let libelle: String
    let identifiant: String
    @Binding var coche: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            coche.toggle()
        } label: {
            Label {
                Text(libelle).foregroundStyle(palette.text).multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: coche ? "checkmark.square.fill" : "square")
                    .foregroundStyle(coche ? palette.primary : palette.textMuted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(maxWidth: .infinity, minHeight: Mise.cible, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: coche)
        .accessibilityAddTraits(coche ? .isSelected : [])
        .accessibilityIdentifier(identifiant)
    }
}

/// Un état à choisir (`.etat` du site) : le contour au repos, la teinte pleine de l'état
/// une fois choisi ; l'appui de la charte (`StyleAppui`).
private struct BoutonEtat: View {
    let etat: String
    let choisi: Bool
    let choisir: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    private var plein: Color {
        switch etat {
        case "mauvais": palette.dangerPlein
        case "excellent": palette.successPlein
        default: palette.textMuted
        }
    }

    var body: some View {
        Button {
            withAnimation(mouvementReduit ? nil : .easeOut(duration: 0.18)) { choisir() }
        } label: {
            Text(EtatAvis.libelle(etat))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(choisi ? palette.surPlein : palette.text)
                .frame(maxWidth: .infinity, minHeight: Mise.cible)
                .background(choisi ? plein : palette.surface, in: .rect(cornerRadius: Mise.rayonTuile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Mise.rayonTuile, style: .continuous)
                        .strokeBorder(choisi ? plein : palette.border, lineWidth: 2)
                }
                .contentShape(.rect)
        }
        .buttonStyle(StyleAppui())
        .accessibilityAddTraits(choisi ? .isSelected : [])
        .accessibilityIdentifier("avis.etat.\(etat)")
    }
}
