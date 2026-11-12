// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Supprimer mon compte », sous « Vos droits (RGPD) » du Profil — le même geste que le
/// site (`SuppressionCompte.svelte`, coprofirst#2699) et ce qu'exige la revue d'Apple
/// (#166) : la personne DEMANDE, l'administration de la résidence traite. Le délai et ce
/// qui sera effacé sont SERVIS ; l'app ne les écrit nulle part.
struct SectionSuppressionCompte: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var etat: EtatSuppressionCompte?
    @State private var erreur: String?
    @State private var formulaire = false
    @State private var envoi = false
    @State private var phrase: String?

    var body: some View {
        Section {
            if let erreur {
                Text("Impossible de lire l'état de votre demande : \(erreur)").font(.footnote)
            } else if let demande = etat?.demande {
                Text(demandeEnvoyee(demande)).font(.footnote).foregroundStyle(palette.textMuted)
                Button("Retirer ma demande") { Task { await retirer() } }
                    .disabled(envoi)
                    .accessibilityIdentifier("profil.suppression.retirer")
            } else if let etat {
                Text(invitation(etat)).font(.footnote).foregroundStyle(palette.textMuted)
                Button(role: .destructive) { formulaire = true } label: {
                    Label("Demander la suppression de mon compte", systemImage: "person.crop.circle.badge.xmark")
                }
                .accessibilityIdentifier("profil.suppression.demander")
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            if let phrase { Text(phrase).font(.footnote).foregroundStyle(palette.textMuted) }
        } header: {
            Text("Supprimer mon compte").styleLibelle()
        }
        .listRowBackground(palette.surface)
        .task(id: installation.adresse) { await lire() }
        .sheet(isPresented: $formulaire) {
            if let etat {
                DemandeSuppressionFeuille(etat: etat) { motDePasse, motif in
                    await demander(motDePasse: motDePasse, motif: motif)
                }
            }
        }
    }

    private func demandeEnvoyee(_ demande: DemandeSuppressionCompte) -> String {
        "Demande de suppression envoyée le \(FormatsDuSite.date(demande.creeLe))."
            + (demande.delaiJours.map { " L'administration de la résidence la traite sous \($0) jours au plus." } ?? "")
    }

    private func invitation(_ etat: EtatSuppressionCompte) -> String {
        "Vous pouvez demander la suppression de votre compte"
            + (etat.delaiJours.map { " ; l'administration de la résidence la traite sous \($0) jours au plus." } ?? ".")
    }

    private var service: any ServiceSuppressionCompte { parcours.serviceSuppressionCompte }

    private func lire() async {
        do {
            etat = try await service.etatSuppression(installation)
            erreur = nil
        } catch {
            erreur = ErreurService.depuis(error).phrase
        }
    }

    /// `nil` : la demande est partie ; sinon la phrase à montrer dans la feuille.
    private func demander(motDePasse: String, motif: String) async -> String? {
        do {
            _ = try await service.demanderSuppression(motDePasse: motDePasse, motif: motif, dans: installation)
            phrase = "Demande de suppression envoyée. Un accusé de réception vous est adressé."
            await lire()
            return nil
        } catch {
            return ErreurService.depuis(error).phrase
        }
    }

    private func retirer() async {
        envoi = true
        defer { envoi = false }
        do {
            try await service.retirerDemandeSuppression(installation)
            phrase = "Demande de suppression retirée : votre compte est conservé."
            await lire()
        } catch {
            phrase = ErreurService.depuis(error).phrase
        }
    }
}

/// La confirmation : ce qui sera effacé (servi), le mot de passe, un motif facultatif.
private struct DemandeSuppressionFeuille: View {
    let etat: EtatSuppressionCompte
    let demander: (String, String) async -> String?
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var motDePasse = ""
    @State private var motif = ""
    @State private var envoi = false
    @State private var refus: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(etat.consequences.enumerated()), id: \.offset) { _, consequence in
                        Text(consequence).font(.subheadline)
                    }
                }
                Section {
                    SecureField("Votre mot de passe, pour confirmer", text: $motDePasse)
                        .textContentType(.password)
                        .accessibilityIdentifier("suppression.motDePasse")
                    TextField("Motif (facultatif)", text: $motif, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("suppression.motif")
                }
                if let refus { MessageErreur(texte: refus) }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle("Supprimer mon compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(
                    envoi: envoi, libelle: "Confirmer la demande", actif: !motDePasse.isEmpty,
                    identifiant: "suppression.confirmer"
                ) {
                    envoi = true
                    defer { envoi = false }
                    refus = await demander(motDePasse, motif)
                    if refus == nil { fermer() }
                }
            }
        }
        .interactiveDismissDisabled(envoi)
    }
}
