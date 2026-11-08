// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Reporting › Renouvellements (`VueRenouvellements.svelte`, #56) : les trois compteurs,
/// les contrats de prestataires à échéance, puis les diagnostics réglementaires — tels
/// que le serveur les sert et les ordonne. La frise du site devient une liste : la date
/// de fin et celle du préavis s'y lisent en clair.
struct VueRenouvellements: View {
    let releve: Renouvellements

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RangeeDeChiffres {
                Chiffre(
                    valeur: releve.contratsEnPreavis, libelle: TextesRenouvellements.contratsEnPreavis,
                    alerte: releve.contratsEnPreavis > 0)
                Chiffre(
                    valeur: releve.echeancesContratsAnnee,
                    libelle: TextesRenouvellements.echeancesAnnee(releve.annee))
                Chiffre(
                    valeur: releve.auditsAPlanifier, libelle: TextesRenouvellements.auditsAPlanifier,
                    alerte: releve.auditsAPlanifier > 0)
            }
            .accessibilityIdentifier("renouvellements.compteurs")
            SectionContrats(releve: releve)
            SectionDiagnostics(releve: releve)
        }
    }
}

/// Un titre de section et sa phrase d'introduction.
private struct TitreDeSection: View {
    let titre: String
    var intro: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre).font(.headline).foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            if let intro {
                Text(intro).font(.footnote).foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SectionContrats: View {
    let releve: Renouvellements
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitreDeSection(
                titre: TextesRenouvellements.contratsTitre(releve.annee),
                intro: TextesRenouvellements.contratsIntro(releve.annee, preavis: releve.preavisMois))
            if releve.contratsDeLAnnee.isEmpty {
                Text(TextesRenouvellements.aucuneEcheance(releve.annee))
                    .font(.subheadline).foregroundStyle(palette.textMuted)
            }
            ForEach(releve.contratsDeLAnnee) { LigneContrat(contrat: $0, dansLAnnee: true) }
            groupe(TextesRenouvellements.echeancesFutures, releve.contratsFuturs)
            groupe(TextesRenouvellements.datesManquantes, releve.contratsSansDate)
        }
    }

    @ViewBuilder
    private func groupe(_ titre: String, _ contrats: [ContratARenouveler]) -> some View {
        if !contrats.isEmpty {
            Text(TextesRenouvellements.groupe(titre, contrats.count))
                .styleLibelle()
                .padding(.top, 6)
            ForEach(contrats) { LigneContrat(contrat: $0, dansLAnnee: false) }
        }
    }
}

/// Un contrat : son libellé, son prestataire et sa note, son état, ses dates.
private struct LigneContrat: View {
    let contrat: ContratARenouveler
    let dansLAnnee: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 6) {
                Text(contrat.libelle).font(.headline).foregroundStyle(palette.text)
                Text(TextesRenouvellements.prestataire(contrat))
                    .font(.subheadline).foregroundStyle(palette.textMuted)
                FlowLayoutPastilles {
                    if dansLAnnee, contrat.urgence == "preavis" {
                        PastilleTeinte(libelle: TextesRenouvellements.preavisEnCours, badge: "badge-orange")
                    } else if dansLAnnee {
                        PastilleTeinte(libelle: TextesRenouvellements.actif, badge: "badge-blue")
                    }
                    if contrat.reconduit {
                        PastilleTeinte(libelle: TextesRenouvellements.reconduit, badge: "badge-purple")
                    }
                }
                if contrat.dateFin != nil {
                    Text(TextesRenouvellements.periode(contrat)).font(.footnote).foregroundStyle(palette.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("renouvellements.contrat.\(contrat.id)")
    }
}

/// Des pastilles côte à côte, qui passent à la ligne quand la place manque.
private struct FlowLayoutPastilles<Contenu: View>: View {
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { contenu() }
            VStack(alignment: .leading, spacing: 6) { contenu() }
        }
    }
}

private struct SectionDiagnostics: View {
    let releve: Renouvellements
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitreDeSection(
                titre: TextesRenouvellements.diagnosticsTitre(releve.annee),
                intro: TextesRenouvellements.diagnosticsIntro)
            if releve.diagnostics.isEmpty {
                ContentUnavailableView(
                    TextesRenouvellements.aucunDiagnostic, systemImage: "checkmark.seal",
                    description: Text(TextesRenouvellements.aucunDiagnosticDetail))
            }
            ForEach(releve.diagnosticsParAnnee, id: \.annee) { groupe in
                let courante = groupe.annee == String(releve.annee)
                HStack(spacing: 8) {
                    Text(groupe.annee.isEmpty ? FormatsDuSite.tiret : groupe.annee).font(.headline)
                    PastilleTeinte(
                        libelle: TextesRenouvellements.audits(groupe.diagnostics.count),
                        badge: courante ? "badge-orange" : "badge-blue", compacte: true)
                }
                .padding(.top, 6)
                ForEach(groupe.diagnostics) { LigneDiagnostic(diagnostic: $0, annee: releve.annee) }
            }
            if !releve.diagnosticsPermanents.isEmpty {
                TitreDeSection(
                    titre: TextesRenouvellements.permanent, intro: TextesRenouvellements.permanentIntro)
                    .padding(.top, 6)
                ForEach(releve.diagnosticsPermanents) { LigneDiagnostic(diagnostic: $0, annee: releve.annee) }
            }
        }
    }
}

/// Un diagnostic : son nom, son code et sa fréquence, ses dates, son état servi.
private struct LigneDiagnostic: View {
    let diagnostic: DiagnosticAEcheance
    let annee: Int
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(diagnostic.nom).font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 8)
                    etat
                }
                Text([diagnostic.code, diagnostic.frequence].compactMap(\.self).joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(palette.textMuted)
                Text(TextesRenouvellements.dernierRapport(diagnostic.dernierRapportLe))
                    .font(.footnote).foregroundStyle(palette.textMuted)
                if !diagnostic.permanent {
                    Text(TextesRenouvellements.prochaineEcheance(diagnostic.prochaineEcheance))
                        .font(.footnote).foregroundStyle(palette.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("renouvellements.diagnostic.\(diagnostic.id)")
    }

    /// L'état que le serveur classe (`urgence_echeance`) : l'app ne compare aucune date.
    @ViewBuilder private var etat: some View {
        if diagnostic.permanent {
            PastilleTeinte(libelle: TextesRenouvellements.permanentBadge, badge: "badge-green", compacte: true)
        } else if diagnostic.urgence == "depasse" {
            PastilleTeinte(libelle: TextesRenouvellements.depasse, badge: "badge-red", compacte: true)
        } else if diagnostic.urgence == "annee" {
            PastilleTeinte(libelle: TextesRenouvellements.aFaireEn(annee), badge: "badge-orange", compacte: true)
        } else if let echeance = diagnostic.prochaineEcheance {
            PastilleTeinte(libelle: String(echeance.prefix(4)), badge: "badge-blue", compacte: true)
        }
    }
}
