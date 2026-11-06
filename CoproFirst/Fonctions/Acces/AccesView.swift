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
        .titreDeMenu()
    }

    private func page(_ service: any ServiceAcces) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BarreOnglets(onglets: etat.onglets, actif: $onglet)
                // Les descriptifs des deux onglets d'accès décrivent la page web (« bouton …
                // en haut à droite », un lien de la FAQ) : ils égareraient dans l'app.
                if !["badges", "telecommandes"].contains(onglet),
                    let descriptif = TablesAcces.descriptifs[onglet]
                {
                    Text(TexteDuSite.apercu(descriptif)).font(.subheadline).foregroundStyle(palette.textMuted)
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
        .sheet(item: $feuille, onDismiss: { etat.avis.feuilleFermee() }, content: { quoi in
            feuilleDe(quoi, service: service)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        })
        .avisEphemere(etat.avis)
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
                    .accessibilityIdentifier("acces.geste.demander")
            }
            Button { feuille = .declarer } label: {
                Label(TextesAcces.declarerUnAcces, systemImage: "checkmark.seal")
            }
            .accessibilityIdentifier("acces.geste.declarer")
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
                etat.avis.direApresFermeture($0)
            }
        case .declarer:
            DeclarerAccesView(installation: contexte.installation, service: service) {
                etat.avis.direApresFermeture($0)
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
