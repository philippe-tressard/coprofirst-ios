// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un compte en attente : qui, quel statut, quel bâtiment, depuis quand — et ses deux
/// gestes.
struct CarteCompte: View {
    let compte: CompteEnAttente
    let enCours: Bool
    let approuver: () -> Void
    let rejeter: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        let nom = compte.nomAffiche
        CarteDeFile(enCours: enCours, approuver: approuver, rejeter: rejeter, id: "cs.compte.\(compte.id)") {
            Text(nom).font(.headline).foregroundStyle(palette.text)
            Text(
                [RolesUtilisateur.libelleStatut(compte.statut), compte.batimentNom].compactMap { $0 }
                    .joined(separator: " — ")
            )
            .font(.subheadline).foregroundStyle(palette.textMuted)
            if let aide = compte.nomAideAffiche {
                Label(TextesComptesCS.aide(aide), systemImage: "person")
                    .font(.subheadline).foregroundStyle(palette.textMuted)
            }
            Text(FormatsDuSite.dateCourte(compte.creeLe)).font(.footnote).foregroundStyle(palette.textMuted)
        }
    }
}

/// Une demande de badge ou de télécommande : le demandeur, le lot, le type, la quantité.
struct CarteCommande: View {
    let commande: CommandeEnAttente
    let enCours: Bool
    let approuver: () -> Void
    let rejeter: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        CarteDeFile(enCours: enCours, approuver: approuver, rejeter: rejeter, id: "cs.commande.\(commande.id)") {
            Text(commande.demandeurNom).font(.headline).foregroundStyle(palette.text)
            Text(
                [
                    commande.batiment, commande.lot, LibellesAcces.typeAcces(commande.type),
                    FormatsDuSite.nombre(commande.quantite),
                ].compactMap { $0 }.joined(separator: " · ")
            )
            .font(.subheadline).foregroundStyle(palette.textMuted)
            Text(FormatsDuSite.dateCourte(commande.creeLe)).font(.footnote).foregroundStyle(palette.textMuted)
        }
    }
}

/// La carte d'une ligne de la file : son contenu, puis « Approuver » et « Rejeter » —
/// côte à côte, l'un sous l'autre aux tailles d'accessibilité.
/// Celle de toute file de travail : comptes, commandes, demandes de profil (#16).
struct CarteDeFile<Contenu: View>: View {
    let enCours: Bool
    let approuver: () -> Void
    let rejeter: () -> Void
    let id: String
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) { contenu() }
                    .accessibilityElement(children: .combine)
                let disposition =
                    taille.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
                disposition {
                    Button(action: approuver) {
                        Label(TextesEspaceCS.approuver, systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.successPlein)
                    .accessibilityIdentifier("\(id).approuver")
                    Button(role: .destructive, action: rejeter) {
                        Label(TextesEspaceCS.rejeter, systemImage: "xmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.danger)
                    .accessibilityIdentifier("\(id).rejeter")
                }
                .controlSize(.large)
                .disabled(enCours)
                .overlay { if enCours { ProgressView() } }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }
}
