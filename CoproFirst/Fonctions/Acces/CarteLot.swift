// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les caractéristiques d'un lot (`CaracteristiquesLot.svelte`), dans l'ordre du
/// site : ce que la carte met avant, puis Type, Étage, Superficie, Porte ou place,
/// Situé dans, Desservi par — puis ce que le propriétaire doit savoir.
struct CaracteristiquesDuLot: View {
    let lot: LotDuCompte
    var avant: [(String, String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lignes.enumerated()), id: \.offset) { _, ligne in
                LigneFiche(libelle: ligne.0, valeur: ligne.1)
            }
            if let alertes = lot.alertes, !alertes.isEmpty {
                ConstatsDuLot(constats: alertes).padding(.top, 4)
            }
        }
    }

    private var lignes: [(String, String)] {
        var lignes = avant
        if lot.type != nil { lignes.append(("Type", lot.typeLu)) }
        // L'étage tel que l'API le sert (« -1 », « 2 ») : `etageLabel` n'est pas recopié.
        if let etage = lot.etage { lignes.append(("Étage", String(etage))) }
        // ⚠️ Le site écrit ici la valeur brute (« 64.5 m² ») et `fmtNombre` dans la vue
        // du bailleur (« 64,5 m² ») : l'app suit `fmtNombre` partout — écart signalé
        // dans le coprofirst#2507.
        if let superficie = lot.superficie { lignes.append(("Superficie", "\(FormatsDuSite.nombre(superficie)) m²")) }
        if let usage = lot.numeroUsage, !usage.isEmpty { lignes.append(("Porte ou place", usage)) }
        if let situe = lot.perimetres("situe_dans") { lignes.append(("Situé dans", situe)) }
        if let desservi = lot.perimetres("desservi_par") { lignes.append(("Desservi par", desservi)) }
        return lignes
    }
}

/// Les constats d'un lot (`ConstatsLots.svelte`) : ce qui bloque d'abord.
struct ConstatsDuLot: View {
    let constats: [ConstatDuLot]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ordonnes, id: \.self) { constat in
                let teinte =
                    TablesDesComposants.gravites.first { $0.code == constat.gravite }?.teinte ?? .brut(constat.gravite)
                VStack(alignment: .leading, spacing: 4) {
                    PastilleTeinte(libelle: teinte.libelle, badge: teinte.badge, compacte: true)
                    Text(constat.message).font(.subheadline).foregroundStyle(palette.text)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var ordonnes: [ConstatDuLot] {
        let rang = { (code: String) in TablesDesComposants.gravites.firstIndex { $0.code == code } ?? 9 }
        return constats.sorted { rang($0.gravite) < rang($1.gravite) }
    }
}

/// Une carte de lot : son intitulé (« Bât. A / 15 »), un complément en tête, ses
/// caractéristiques, un pied.
struct CarteLot<Complement: View, Pied: View>: View {
    let lot: LotDuCompte
    var avant: [(String, String)] = []
    @ViewBuilder var complement: () -> Complement
    @ViewBuilder var pied: () -> Pied
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lot.intitule)
                        .font(.headline)
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    complement()
                }
                CaracteristiquesDuLot(lot: lot, avant: avant)
                pied()
            }
        }
    }
}

extension CarteLot where Complement == EmptyView, Pied == EmptyView {
    init(lot: LotDuCompte, avant: [(String, String)] = []) {
        self.init(lot: lot, avant: avant, complement: { EmptyView() }, pied: { EmptyView() })
    }
}
