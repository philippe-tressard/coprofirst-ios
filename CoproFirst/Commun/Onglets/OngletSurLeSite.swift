// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

extension OngletDuSite {
    /// La dernière pastille d'une page dont l'app ne porte qu'une partie : les autres
    /// onglets, chacun avec son lien vers le site. Ce n'est pas un onglet du site — il n'a
    /// ni réserve ni descriptif servi, et ne s'ouvre que là où il en reste (`CadreAOnglets`).
    static let surLeSite = OngletDuSite(
        id: "sur-le-site", libelle: "Sur le site", reserve: nil, ouvertOperateur: true)
}

/// « Sur le site » : les onglets que ce compte ouvre sur le site et que l'app ne porte
/// pas, dans l'ordre du site, avec leur descriptif et un lien vers chacun (arbitrage du
/// 03/11/2026, #16). L'app ne les cache pas : elle dit où ils sont.
struct OngletSurLeSite: View {
    let onglets: [OngletDuSite]
    let descriptifs: [String: String]
    /// L'adresse de chaque onglet sur le site (`/admin?onglet=…`), générée.
    let routes: [String: String]
    let adresse: URL
    @Environment(\.palette) private var palette

    static let descriptifPropre =
        "Ces onglets se règlent sur le site de la résidence : chacun s'y ouvre dans le navigateur."

    /// Le descriptif de la pastille, sous la barre.
    static func descriptif(_ onglet: OngletDuSite) -> String? {
        onglet == .surLeSite ? descriptifPropre : nil
    }

    /// L'adresse d'un onglet sur le site de la résidence : sa route, sous l'adresse de
    /// l'installation (qui peut porter un chemin).
    static func lien(_ route: String, sur adresse: URL) -> URL? {
        guard var composants = URLComponents(url: adresse, resolvingAgainstBaseURL: true),
            let cible = URLComponents(string: route)
        else { return nil }
        let base = composants.path.hasSuffix("/") ? String(composants.path.dropLast()) : composants.path
        composants.path = base + cible.path
        composants.queryItems = cible.queryItems
        return composants.url
    }

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(onglets.enumerated()), id: \.element.id) { rang, onglet in
                    if rang > 0 { Divider().overlay(palette.border) }
                    ligne(onglet)
                }
            }
        }
    }

    @ViewBuilder
    private func ligne(_ onglet: OngletDuSite) -> some View {
        let contenu = HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(onglet.libelle).font(.headline).foregroundStyle(palette.text)
                if let descriptif = descriptifs[onglet.id] {
                    Text(TexteDuSite.apercu(descriptif))
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.forward.square")
                .foregroundStyle(palette.primary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        if let route = routes[onglet.id], let lien = Self.lien(route, sur: adresse) {
            Link(destination: lien) { contenu }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvre le site de la résidence")
                .accessibilityIdentifier("site.onglet.\(onglet.id)")
        } else {
            contenu.accessibilityElement(children: .combine)
        }
    }
}
