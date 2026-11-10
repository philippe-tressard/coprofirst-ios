// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le Paramétrage (page `admin` du site, #16), EN PARTIE : quatre onglets dans l'app —
/// À traiter, Utilisateurs, Télémétrie, Maintenance —, et « Sur le site » pour les
/// autres, chacun avec son lien (arbitrage du 03/11/2026). Le cadre est celui de l'Espace
/// CS (`CadreAOnglets`).
///
/// Réservé à l'administrateur et à l'opérateur de la plateforme (`PagesOuvertes`) ;
/// l'opérateur qui n'est pas administrateur n'y ouvre que l'Exploitation
/// (`OngletsDuSite.ouverts`), donc ici la seule Maintenance. Le serveur refuse chaque
/// route à qui n'a pas le rôle.
struct AdminView: View {
    let contexte: ContexteDeMenu

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    var body: some View {
        CadreAOnglets(
            contexte: contexte,
            page: PageAOnglets(
                id: "admin", ecrans: OngletsAdmin.ecrans, descriptifs: TablesAdmin.descriptifs,
                reserve: TextesAdmin.reserve, routes: TablesAdmin.routes, titre: \.titre))
    }
}

extension AdminView: EcranDeMenu {}

/// La table des onglets que l'app porte : l'identifiant d'un onglet du site
/// (`pages-roles.ts`) → sa vue. Un onglet absent d'ici paraît dans « Sur le site ».
///
/// ⚠️ UNE LIGNE PAR ONGLET, séparée des autres par une ligne vide. L'ordre et
/// l'ouverture se décident au site (`OngletsDuSite.ouverts(page: "admin", …)`, généré).
@MainActor
enum OngletsAdmin {
    static let ecrans: [String: any OngletDePage.Type] = [
        "a_traiter": OngletATraiter.self,

        "utilisateurs": OngletUtilisateursAdmin.self,

        "telemetry": OngletTelemetrie.self,

        "maintenance": OngletMaintenance.self,
    ]
}

/// Les mots du cadre et ce que les onglets partagent.
enum TextesAdmin {
    static let reserve = "Le paramétrage est réservé à l'administration et à l'opérateur de la plateforme."
    static let serviceAbsent = "Cet onglet n'est pas disponible avec cette résidence."
    static let surLeSite = "Sur le site"
}

/// Ce qu'un onglet du Paramétrage laisse au site : une phrase, et le lien vers l'onglet
/// du site qui le porte en entier.
struct RenvoiAuSite: View {
    let texte: String
    let onglet: String
    let adresse: URL
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(texte, systemImage: "safari")
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let route = TablesAdmin.routes[onglet], let lien = OngletSurLeSite.lien(route, sur: adresse) {
                Link(destination: lien) {
                    Label(TextesAdmin.surLeSite, systemImage: "arrow.up.forward.square")
                        .font(.footnote.weight(.semibold))
                }
                .tint(palette.primary)
                .accessibilityIdentifier("admin.\(onglet).sur-le-site")
            }
        }
        .padding(.top, 8)
    }
}
