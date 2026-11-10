// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Reporting » de l'Espace CS (`OngletReporting.svelte`, #15) : le Suivi des
/// affaires, en lecture — ses chiffres, ses deux répartitions croisées et ses affaires,
/// la plus ancienne en tête. Deux modes : les affaires, ou les entretiens périodiques ;
/// puis la vue Renouvellements (#56), le relevé servi des échéances.
/// Ce que l'app laisse au site se dit sous la liste (`TextesReporting.surLeSite`).
struct OngletReporting: OngletDePage {
    let contexte: ContexteOnglet
    @Environment(\.palette) private var palette
    /// Les modes que l'app porte : la relance du syndic se compose sur le site ; puis la
    /// vue Renouvellements.
    private static let modes =
        TablesReporting.modes.filter { $0.code != "relance" }
        + [(code: renouvellements, libelle: TextesRenouvellements.titre)]
    private static let renouvellements = "renouvellements"
    @State private var mode = OngletReporting.modes.first?.code ?? "suivi"

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceReporting {
            contenu(service)
        } else {
            MessageErreur(texte: ErreurService.inattendue(501).phrase)
        }
    }

    private func contenu(_ service: any ServiceReportingCS) -> some View {
        let installation = contexte.installation
        let releve = ReleveSuivi(mode: mode)
        return VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.modes, id: \.code) { choix in
                        Pastille(libelle: choix.libelle, retenue: mode == choix.code) {
                            withAnimation(.snappy) { mode = choix.code }
                        }
                        .accessibilityIdentifier("reporting.mode.\(choix.code)")
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: mode)
            if mode == Self.renouvellements {
                Chargement(
                    charger: { try await service.renouvellements(installation) },
                    contenu: { releve, _ in VueRenouvellements(releve: releve) },
                    squelette: {
                        VueRenouvellements(releve: Self.squeletteRenouvellements).redacted(reason: .placeholder)
                    }
                )
                .id("renouvellements-\(contexte.actualisation)")
            } else {
                Chargement(
                    charger: { try await service.suiviAffaires(releve, dans: installation) },
                    contenu: { suivi, _ in
                        SuiviView(suivi: suivi, entretien: releve == .entretien, installation: installation)
                    },
                    squelette: { SuiviView(suivi: Self.squelette, entretien: false, installation: installation) }
                )
                // Un autre mode, ou « tirer pour actualiser » : le relevé se relit.
                .id("\(releve.rawValue)-\(contexte.actualisation)")
            }
            Text(TextesReporting.surLeSite)
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
        }
    }

    private static let squeletteRenouvellements = Renouvellements(
        annee: 2026, preavisMois: 3, contratsEnPreavis: 0, echeancesContratsAnnee: 0, auditsAPlanifier: 0,
        contrats: [], diagnostics: [])

    private static let squelette = SuiviAffaires(
        total: 3, anciennes: 1, delaiJours: 90, fusionnees: 0, parCategorie: [], parBatiment: [],
        affaires: (0..<3).map {
            AffaireSuivie(
                id: -$0 - 1, numero: "TK-A00000", titre: "Une affaire de la résidence", statut: "ouvert",
                libelleCategorie: "Catégorie", ouverteLe: "2026-01-01", ageJours: 10, anciennete: "recente",
                apercu: "L'aperçu de l'affaire arrive.", apercuIA: false, aEvolue: false, motifEvolution: nil,
                etatVisite: nil)
        })
}

/// Un relevé : les chiffres, les répartitions, puis les affaires.
private struct SuiviView: View {
    let suivi: SuiviAffaires
    let entretien: Bool
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chiffres
            if !suivi.parCategorie.isEmpty {
                RepartitionCroisee(titre: TextesReporting.parCategorie, barres: suivi.parCategorie)
            }
            if !suivi.parBatiment.isEmpty {
                RepartitionCroisee(titre: TextesReporting.parBatiment, barres: suivi.parBatiment)
            }
            if suivi.affaires.isEmpty {
                ContentUnavailableView(
                    entretien ? TextesReporting.aucunEntretien : TextesReporting.aucuneAffaire,
                    systemImage: "checkmark.circle")
                .accessibilityIdentifier("reporting.vide")
            }
            ForEach(suivi.affaires) { affaire in
                NavigationLink {
                    DetailAffaireView(id: affaire.id, installation: installation)
                } label: {
                    LigneAffaireSuivie(affaire: affaire, entretien: entretien)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Les trois chiffres du site, côte à côte — l'un sous l'autre aux grandes tailles.
    private var chiffres: some View {
        RangeeDeChiffres {
            Chiffre(valeur: suivi.total, libelle: TextesReporting.nonFermees(suivi.total, entretien: entretien))
                .accessibilityIdentifier("reporting.total")
            Chiffre(
                valeur: suivi.anciennes, libelle: TextesReporting.anciennes(suivi.delaiJours),
                alerte: suivi.anciennes > 0)
            Chiffre(valeur: suivi.fusionnees, libelle: TextesReporting.fusionnees(suivi.fusionnees))
        }
    }
}
