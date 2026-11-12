// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// « À traiter » (onglet `a_traiter`) : ce qui attend un geste de l'administrateur —
/// la file des comptes et des commandes d'accès, la MÊME que celle du conseil
/// (`OngletComptesCS`, mêmes routes), puis les demandes de modification de profil.
struct OngletATraiter: OngletDePage {
    let contexte: ContexteOnglet

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            OngletComptesCS(contexte: contexte)
            FileDemandesProfil(contexte: contexte)
        }
    }
}

/// Les mots d'« À traiter », repris du site (`OngletATraiter.svelte`).
enum TextesATraiter {
    static let titre = "Demandes de profil"
    static let aucune = "Aucune demande en attente."
    static let erreur = "Impossible d’afficher les demandes de profil"
    static let statutSouhaite = "Type"
    static let batimentSouhaite = "Bât."
    static func rejeter(_ nom: String) -> String { "Rejeter la demande de \(nom) ?" }
    static let motif = "Motif du refus (facultatif)"
    static let motifIndication = "Motif…"
}

/// La file des demandes de profil : chargée, puis approuvée ou rejetée ligne à ligne.
@MainActor
@Observable
final class EtatDemandesProfil {
    private(set) var phase = PhaseFile.chargement
    private(set) var demandes: [DemandeProfil] = []
    private(set) var enCours: Int?

    func charger(_ service: any ServiceDemandesProfil, _ installation: Installation) async {
        do {
            demandes = try await service.demandesProfil(installation)
            phase = .pret
        } catch {
            if phase != .pret { phase = .erreur(ErreurService.phrase(error, sinon: TextesATraiter.erreur)) }
        }
    }

    func traiter(
        _ demande: DemandeProfil, approuver: Bool, motif: String?, _ service: any ServiceDemandesProfil,
        _ installation: Installation
    ) async throws -> PhraseAvis {
        enCours = demande.id
        defer { enCours = nil }
        // L'annonce est celle du SERVEUR (`DemandeProfilTraitee.annonce`, #87).
        let annonce = try await service.traiterDemandeProfil(
            demande.id, approuver: approuver, motif: motif, dans: installation)
        demandes.removeAll { $0.id == demande.id }
        return annonce
    }
}

/// Les trois états d'une file de travail.
enum PhaseFile: Equatable {
    case chargement, pret
    case erreur(String)
}

private struct FileDemandesProfil: View {
    let contexte: ContexteOnglet
    @State private var etat = EtatDemandesProfil()
    @State private var aRejeter: DemandeProfil?
    @State private var motif = ""
    @State private var echec: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TextesATraiter.titre)
                .font(.titre(.title3))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            if let service = contexte.serviceDemandesProfil {
                contenu(service)
                    .task(id: contexte.actualisation) { await etat.charger(service, contexte.installation) }
            } else {
                MessageErreur(texte: TextesAdmin.serviceAbsent)
            }
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceDemandesProfil) -> some View {
        switch etat.phase {
        case .chargement:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
        case .erreur(let phrase):
            MessageErreur(texte: phrase) { Task { await etat.charger(service, contexte.installation) } }
        case .pret:
            liste(service)
        }
    }

    private func liste(_ service: any ServiceDemandesProfil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let echec { MessageErreur(texte: echec).transition(.opacity) }
            if etat.demandes.isEmpty {
                Text(TextesATraiter.aucune).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            ForEach(etat.demandes) { demande in
                CarteDeFile(
                    enCours: etat.enCours == demande.id,
                    approuver: {
                        geste {
                            try await etat.traiter(demande, approuver: true, motif: nil, service, contexte.installation)
                        }
                    },
                    rejeter: {
                        motif = ""
                        aRejeter = demande
                    },
                    id: "admin.demande.\(demande.id)",
                    contenu: { LigneDemandeProfil(demande: demande) })
            }
        }
        .animation(.snappy(duration: 0.25), value: etat.demandes)
        .alert(
            aRejeter.map { TextesATraiter.rejeter($0.utilisateurNom) } ?? "",
            isPresented: Binding { aRejeter != nil } set: { if !$0 { aRejeter = nil } },
            presenting: aRejeter
        ) { demande in
            TextField(TextesATraiter.motifIndication, text: $motif)
                .accessibilityIdentifier("admin.demande.motif")
            Button(TextesEspaceCS.annuler, role: .cancel) {}
            Button(TextesEspaceCS.rejeter, role: .destructive) {
                let saisi = motif
                geste {
                    try await etat.traiter(demande, approuver: false, motif: saisi, service, contexte.installation)
                }
            }
        } message: { _ in
            Text(TextesATraiter.motif)
        }
    }

    /// Un geste : son annonce en cas de succès, la phrase du serveur sinon.
    private func geste(_ faire: @escaping () async throws -> PhraseAvis) {
        Task {
            do {
                let annonce = try await faire()
                withAnimation(.snappy) { echec = nil }
                contexte.avis.dire(annonce)
            } catch {
                withAnimation(.snappy) { echec = ErreurService.depuis(error).phrase }
            }
        }
    }
}

/// Ce qu'une demande change : le demandeur, son statut et son bâtiment actuels, ce qu'il
/// souhaite, son motif et sa date.
private struct LigneDemandeProfil: View {
    let demande: DemandeProfil
    @Environment(\.palette) private var palette

    var body: some View {
        Text(demande.utilisateurNom).font(.headline).foregroundStyle(palette.text)
        if let email = demande.utilisateurEmail {
            Text(email).font(.subheadline).foregroundStyle(palette.textMuted)
        }
        Text(
            [demande.statutActuel.map(RolesUtilisateur.libelleStatut), demande.batimentActuel]
                .compactMap { $0 }.joined(separator: " — ")
        )
        .font(.subheadline).foregroundStyle(palette.textMuted)
        if let statut = demande.statutSouhaite {
            souhait(TextesATraiter.statutSouhaite, RolesUtilisateur.libelleStatut(statut))
        }
        if let batiment = demande.batimentNomSouhaite {
            souhait(TextesATraiter.batimentSouhaite, batiment)
        }
        if let motif = demande.motif, !motif.isEmpty {
            Text(motif).font(.subheadline).italic().foregroundStyle(palette.textMuted)
        }
        Text(FormatsDuSite.dateHeureCourte(demande.creeLe)).font(.footnote).foregroundStyle(palette.textMuted)
    }

    private func souhait(_ libelle: String, _ valeur: String) -> some View {
        Label {
            Text("\(libelle) : \(Text(valeur).bold().foregroundStyle(palette.text))")
                .foregroundStyle(palette.textMuted)
        } icon: {
            Image(systemName: "arrow.right").foregroundStyle(palette.primary)
        }
        .font(.subheadline)
    }
}
