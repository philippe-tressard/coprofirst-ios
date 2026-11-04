// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Mes lots & accès » (page `mon-lot` du site, #13) : quatre onglets — Mes lots,
/// Mes badges d’accès (Vigik), Télécommandes de parking, Gestion locative (à qui la
/// gère). Les deux gestes d'accès sont en haut, sur les deux onglets d'accès.
struct AccesView: View {
    let contexte: ContexteDeMenu
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var etat = EtatAcces()
    @State private var onglet = "lots"
    @State private var feuille: FeuilleAcces?
    @State private var versionAcces = 0

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    var body: some View {
        Group {
            if let service = parcours.serviceAcces {
                page(service)
            } else {
                Bientot(page: contexte.page, installation: contexte.installation)
            }
        }
        .navigationTitle(contexte.page.titre)
    }

    private func page(_ service: any ServiceAcces) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BarreOngletsAcces(onglets: etat.onglets, actif: $onglet)
                if let descriptif = LibellesAcces.descriptifs[onglet] {
                    Text(descriptif).font(.subheadline).foregroundStyle(palette.textMuted)
                }
                contenu(service)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(palette.bg)
        .refreshable { await charger(service) }
        .toolbar {
            PastilleOuSuisJe(installation: contexte.installation, cloche: true)
            if onglet == "badges" || onglet == "telecommandes" {
                ToolbarItem(placement: .topBarLeading) { menuGestes }
            }
        }
        .sheet(item: $feuille) { quoi in
            feuilleDe(quoi, service: service)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .avisEphemere($etat.avis)
        .task { await charger(service) }
        .onChange(of: etat.onglets.map(\.id)) { _, ids in
            // Un onglet masqué ne s'atteint pas (la redirection du site).
            if !ids.contains(onglet) { onglet = "lots" }
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceAcces) -> some View {
        switch etat.phase {
        case .chargement:
            SqueletteLots().redacted(reason: .placeholder).accessibilityLabel("Chargement")
        case .erreur(let phrase) where onglet == "lots" || onglet == "location":
            VStack(alignment: .leading, spacing: 8) {
                Text(TextesAcces.erreurLots).font(.headline).foregroundStyle(palette.text)
                MessageErreur(texte: phrase) { Task { await charger(service) } }
            }
        default:
            switch onglet {
            case "badges", "telecommandes":
                OngletAccesDetenus(
                    type: onglet == "badges" ? .vigik : .telecommande, installation: contexte.installation,
                    service: service, etat: etat, version: versionAcces)
            case "location":
                OngletLocation(etat: etat)
            default:
                OngletLots(etat: etat)
            }
        }
    }

    /// « + » : les deux gestes, qui ne disent pas la même chose.
    private var menuGestes: some View {
        Menu {
            if etat.droits.peutDemander(lots: etat.lots) {
                Button { feuille = .demander } label: { Label(TextesAcces.nouvelAcces, systemImage: "plus.circle") }
            }
            Button { feuille = .declarer } label: {
                Label(TextesAcces.declarerUnAcces, systemImage: "checkmark.seal")
            }
        } label: {
            Image(systemName: "plus").font(.body.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(palette.primaryPlein)
        .accessibilityLabel("Nouvel accès ou déclaration")
        .accessibilityIdentifier("acces.gestes")
    }

    @ViewBuilder
    private func feuilleDe(_ quoi: FeuilleAcces, service: any ServiceAcces) -> some View {
        switch quoi {
        case .demander:
            DemanderAccesView(lots: etat.lots, installation: contexte.installation, service: service) {
                etat.annoncer($0)
            }
        case .declarer:
            DeclarerAccesView(installation: contexte.installation, service: service) {
                etat.annoncer($0)
                versionAcces += 1
            }
        }
    }

    private func charger(_ service: any ServiceAcces) async {
        await parcours.rafraichirProfil()
        let droits = DroitsAcces(parcours.ouverteAJour?.profil)
        await etat.charger(contexte.installation, avec: service, droits: droits)
    }
}

extension AccesView: EcranDeMenu {}

/// La barre d'onglets du site, en pastilles qui défilent : un onglet par pastille.
struct BarreOngletsAcces: View {
    let onglets: [(id: String, libelle: String)]
    @Binding var actif: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(onglets, id: \.id) { onglet in
                    Pastille(libelle: onglet.libelle, retenue: onglet.id == actif) {
                        withAnimation(.snappy(duration: 0.22)) { actif = onglet.id }
                    }
                    .accessibilityIdentifier("onglet.\(onglet.id)")
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: actif)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onglets")
    }
}

private struct SqueletteLots: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Carte {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Caractéristiques").font(.title3)
                    ForEach(0..<5, id: \.self) { _ in LigneFiche(libelle: "Libellé", valeur: "Une valeur") }
                }
            }
        }
    }
}
