// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le choix de plusieurs périmètres, en pastilles (`PerimetrePicker.svelte` du site) : la
/// rangée des têtes — le défaut, chaque bâtiment, le parking… —, puis « Préciser dans
/// Bâtiment 1 — facultatif » et ses espaces, pour une seule tête à la fois.
///
/// Il remplace l'arbre entier en interrupteurs (une ligne par nœud, sans règle entre un
/// bâtiment et ses espaces) : deux touchers suffisent pour « le hall du bâtiment 1 ». La
/// règle est `ChoixDePerimetres` ; cette vue ne fait que la dessiner.
struct ChoixPerimetres: View {
    let arbre: ArbreDesPerimetres
    @Binding var choix: ChoixDePerimetres
    /// Le préfixe des identifiants d'accessibilité (`nouvelle-annonce-hall.perimetre`).
    let identifiant: String
    @Environment(\.palette) private var palette

    var body: some View {
        let ouverte = choix.ouverte(arbre)
        VStack(alignment: .leading, spacing: 12) {
            FlowEtiquettes {
                if let defaut = arbre.defaut {
                    Pastille(libelle: defaut.libelle, retenue: choix.estDefaut(arbre)) {
                        changer { $0.choisirDefaut(arbre) }
                    }
                    .accessibilityIdentifier("\(identifiant).\(defaut.code)")
                }
                ForEach(arbre.tetes) { tete in
                    let retenus = choix.espacesRetenus(de: tete.code, arbre)
                    Pastille(
                        libelle: libelle(tete, retenus: retenus),
                        retenue: !choix.estDefaut(arbre) && (choix.codes.contains(tete.code) || !retenus.isEmpty)
                    ) {
                        changer { $0.basculer(tete.code, arbre) }
                    }
                    .accessibilityIdentifier("\(identifiant).\(tete.code)")
                }
            }
            if let ouverte, let tete = arbre.noeud(ouverte) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Préciser dans \(tete.libelle)\(Text(" — facultatif").foregroundStyle(palette.textMuted))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(palette.text)
                    FlowEtiquettes {
                        ForEach(arbre.espaces(de: ouverte)) { espace in
                            Pastille(libelle: espace.libelle, retenue: choix.codes.contains(espace.code)) {
                                changer { $0.basculer(espace.code, arbre) }
                            }
                            .accessibilityIdentifier("\(identifiant).\(espace.code)")
                        }
                    }
                }
                .padding(12)
                .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if choix.codes.count == 1, let seul = choix.codes.first,
                let aide = arbre.noeud(seul)?.description, !aide.isEmpty
            {
                Text(aide).font(.footnote).foregroundStyle(palette.textMuted)
            }
            // Le lieu retenu, nommé par le serveur (#130) — sous les pastilles : rien ne
            // bouge sous le doigt quand il arrive.
            LieuDeLaSaisie(codes: choix.codes, identifiant: "\(identifiant).lieu")
        }
        .sensoryFeedback(.selection, trigger: choix)
    }

    /// « Bâtiment 1 › Hall · Toit » : la tête porte ce qui y est retenu, rangée ouverte
    /// ou non — l'accusé de réception du toucher (site, 18/08/2026).
    private func libelle(_ tete: Perimetre, retenus: [Perimetre]) -> String {
        guard !retenus.isEmpty else { return tete.libelle }
        return "\(tete.libelle) › " + retenus.map { $0.libelleCourt ?? $0.libelle }.joined(separator: " · ")
    }

    private func changer(_ geste: (inout ChoixDePerimetres) -> Void) {
        withAnimation(.snappy) { geste(&choix) }
    }
}
