// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// « Maintenance » (onglet `maintenance`), comme le site la partage (#1750, #2029) : la
/// supervision technique — la santé des tâches planifiées — à l'OPÉRATEUR de la
/// plateforme ; le dernier export de la copropriété à l'ADMINISTRATION. Chacun ne voit
/// que ce que sa route lui sert, et rien d'autre : aucun nœud, aucune adresse n'est écrit
/// dans l'app.
struct OngletMaintenance: OngletDePage {
    let contexte: ContexteOnglet
    @Environment(\.palette) private var palette

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(contexte.droits.operateur ? TextesMaintenance.introOperateur : TextesMaintenance.introAdmin)
                .font(.subheadline)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let service = contexte.serviceMaintenance {
                if contexte.droits.operateur {
                    SectionSanteTaches(contexte: contexte, service: service)
                }
                if contexte.droits.administrateur {
                    SectionDernierExport(contexte: contexte, service: service)
                }
            } else {
                MessageErreur(texte: TextesAdmin.serviceAbsent)
            }
            RenvoiAuSite(
                texte: TextesMaintenance.surLeSite, onglet: "maintenance", adresse: contexte.installation.adresse)
        }
    }
}

/// « Santé des tâches planifiées » : une ligne par tâche, son statut jugé par le serveur
/// (libellé, teinte et aide générés du site), sa dernière exécution, le nœud qui décroche.
private struct SectionSanteTaches: View {
    let contexte: ContexteOnglet
    let service: any ServiceMaintenance
    @State private var lecture = LectureDeSection<SanteTaches>()
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TitreSection(texte: TextesMaintenance.santeTitre)
            switch lecture.phase {
            case .chargement:
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            case .erreur(let phrase):
                MessageErreur(texte: phrase) { Task { await charger() } }
            case .pret:
                if let sante = lecture.valeur { contenu(sante) }
            }
        }
        .task(id: contexte.actualisation) { await charger() }
    }

    private func charger() async {
        await lecture.lire(sinon: TextesMaintenance.santeErreur) {
            try await service.santeTaches(contexte.installation)
        }
    }

    private func contenu(_ sante: SanteTaches) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sante.taches) { tache in LigneTache(tache: tache) }
            if !sante.anomaliesRecentes.isEmpty {
                Carte {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            TextesMaintenance.anomalies(sante.anomaliesRecentes.count, sante.anomaliesFenetreJours),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.danger)
                        ForEach(Array(sante.anomaliesRecentes.enumerated()), id: \.offset) { _, anomalie in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    [
                                        TextesMaintenance.tache(anomalie.tache), anomalie.noeud,
                                        FormatsDuSite.dateHeure(anomalie.creeLe),
                                    ].compactMap { $0 }.joined(separator: " · ")
                                )
                                .font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                                if let erreur = anomalie.erreur {
                                    Text(erreur).font(.footnote.monospaced()).foregroundStyle(palette.textMuted)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("admin.maintenance.anomalies")
            }
        }
    }
}

/// Une tâche : son nom, son statut, sa dernière exécution et, s'il en est un, le nœud
/// qui décroche alors que la synthèse est saine.
private struct LigneTache: View {
    let tache: SanteTaches.Tache
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(TextesMaintenance.tache(tache.tache)).font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 8)
                    PastilleTeinte(
                        libelle: TablesAdmin.libellesStatut[tache.statut] ?? tache.statut,
                        badge: TablesAdmin.teintesStatut[tache.statut] ?? "badge-gray", compacte: true)
                }
                Text(
                    [TextesMaintenance.dernierRapport(FormatsDuSite.dateHeure(tache.derniere)), tache.noeud]
                        .compactMap { $0 }.joined(separator: " · ")
                )
                .font(.footnote).foregroundStyle(palette.textMuted)
                if let noeud = tache.noeudEnRetard {
                    PastilleTeinte(libelle: TextesMaintenance.enRetard(noeud), badge: "badge-orange", compacte: true)
                }
                if tache.statut != "ok", let aide = TablesAdmin.aidesStatut[tache.statut] {
                    Text(aide).font(.footnote).foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("admin.tache.\(tache.tache)")
    }
}

/// Le dernier export de la copropriété : l'archive, sa taille, ses lignes et ses
/// fichiers, sa date — ou qu'il n'y en a aucun.
private struct SectionDernierExport: View {
    let contexte: ContexteOnglet
    let service: any ServiceMaintenance
    @State private var lecture = LectureDeSection<DernierExport>()
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TitreSection(texte: TextesMaintenance.exportTitre)
            switch lecture.phase {
            case .chargement:
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            case .erreur(let phrase):
                MessageErreur(texte: phrase) { Task { await charger() } }
            case .pret:
                if let export = lecture.valeur {
                    Carte {
                        Label {
                            Text(TextesMaintenance.dernierExport(export))
                                .font(.subheadline).foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: export.archive == nil ? "tray" : "archivebox")
                                .foregroundStyle(palette.primary)
                        }
                    }
                    .accessibilityIdentifier("admin.maintenance.export")
                }
            }
        }
        .task(id: contexte.actualisation) { await charger() }
    }

    private func charger() async {
        await lecture.lire(sinon: TextesMaintenance.exportErreur) {
            try await service.dernierExport(contexte.installation)
        }
    }
}

private struct TitreSection: View {
    let texte: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte).font(.titre(.title3)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
    }
}

/// Une lecture : sa phase et sa valeur. Une relecture qui échoue garde la valeur lue.
@MainActor
@Observable
final class LectureDeSection<Valeur: Sendable> {
    private(set) var phase = PhaseFile.chargement
    private(set) var valeur: Valeur?

    func lire(sinon phrase: String, _ lecture: () async throws -> Valeur) async {
        do {
            valeur = try await lecture()
            phase = .pret
        } catch {
            if phase != .pret { phase = .erreur(ErreurService.phrase(error, sinon: phrase)) }
        }
    }
}
