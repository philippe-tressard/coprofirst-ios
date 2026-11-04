// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Prestataires » (page `prestataires` du site, #13) : trois onglets en lecture —
/// Prestataires, Contrats, Consommations.
struct PrestatairesView: View {
    let contexte: ContexteDeMenu
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var onglet = "prestataires"

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    var body: some View {
        Group {
            if let service = parcours.servicePrestataires {
                page(service)
            } else {
                Bientot(page: contexte.page, installation: contexte.installation)
            }
        }
        .navigationTitle(contexte.page.titre)
    }

    private func page(_ service: any ServicePrestataires) -> some View {
        let installation = contexte.installation
        let conseil = DroitsAcces(parcours.ouverteAJour?.profil).conseil
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BarreOngletsAcces(onglets: TablesPrestataires.onglets, actif: $onglet)
                if let descriptif = TablesPrestataires.onglets.first(where: { $0.id == onglet })?.descriptif {
                    Text(TexteDuSite.apercu(descriptif)).font(.subheadline).foregroundStyle(palette.textMuted)
                }
                Chargement(
                    charger: { try await DonneesPrestataires.lire(installation, service: service) },
                    contenu: { donnees, _ in
                        switch onglet {
                        case "contrats":
                            OngletContrats(donnees: donnees, installation: installation, service: service)
                        case "consommations":
                            OngletConsommations(
                                donnees: donnees, installation: installation, service: service, conseil: conseil)
                        default:
                            OngletPrestataires(donnees: donnees, installation: installation, service: service)
                        }
                    },
                    squelette: { SquelettePrestataires() }
                )
                if conseil {
                    Text(TextesPrestataires.gestesSurLeSite)
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(palette.bg)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }
}

extension PrestatairesView: EcranDeMenu {}

/// Ce que les trois onglets partagent, chargé une fois : les fiches, les contrats en
/// cours, les avis, les équipements (libellés et ordre, servis par l'API).
struct DonneesPrestataires: Sendable {
    var prestataires: [Prestataire]
    var contrats: [Contrat]
    var avis: [AvisPrestataire]
    var equipements: [Equipement]

    static func lire(
        _ installation: Installation, service: any ServicePrestataires
    ) async throws -> DonneesPrestataires {
        async let prestataires = service.prestataires(installation, archives: false)
        async let contrats = service.contrats(installation, archives: false)
        async let avis = service.avis(installation)
        async let equipements = service.equipements(installation)
        // Les avis et les équipements ne bloquent pas : sans eux, l'écran reste lisible.
        return try await DonneesPrestataires(
            prestataires: prestataires, contrats: contrats, avis: (try? await avis) ?? [],
            equipements: (try? await equipements) ?? [])
    }

    /// `equipLabel` : le libellé servi, ou le code brut s'il est inconnu.
    func equipement(_ code: String) -> String { equipements.first { $0.code == code }?.libelle ?? code }

    func contrats(de prestataire: Prestataire) -> [Contrat] { contrats.filter { $0.prestataireId == prestataire.id } }

    func avis(de prestataire: Prestataire) -> [AvisPrestataire] {
        avis.filter { $0.prestataireId == prestataire.id }.sorted { $0.creeLe > $1.creeLe }
    }
}

private struct SquelettePrestataires: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                Carte {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Un prestataire de la résidence").font(.headline)
                        Text("Maintenance · Ascenseurs").font(.subheadline)
                    }
                }
            }
        }
    }
}
