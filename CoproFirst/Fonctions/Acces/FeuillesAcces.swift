// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les deux gestes d'accès (`FormulairesAcces.svelte`), chacun dans sa feuille :
/// « Nouvel accès » DEMANDE au syndic ce qu'on n'a pas, « Déclarer » SIGNALE ce
/// qu'on détient déjà.
enum FeuilleAcces: String, Identifiable {
    case demander, declarer
    var id: String { rawValue }
}

/// « Nouvelle demande d'accès » : type, un de SES lots, quantité, motif.
struct DemanderAccesView: View {
    let lots: [LotDuCompte]
    let installation: Installation
    let service: any ServiceAcces
    let fait: (String) -> Void
    @State private var demande = DemandeAcces()
    @State private var envoi = false
    @State private var erreur: String?
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                }
                Section(TextesAcces.typeDAcces) {
                    Picker(TextesAcces.typeDAcces, selection: $demande.type) {
                        ForEach(TypeAcces.allCases) { Text($0.libelle).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Picker(TextesAcces.lotConcerne, selection: $demande.lotId) {
                        Text(TextesAcces.selectionner).tag(Int?.none)
                        // Seuls SES lots : `/lots/mes-lots` ne sert jamais celui d'un voisin.
                        ForEach(lots) { Text(TextesAcces.lot($0.numero)).tag(Int?.some($0.id)) }
                    }
                    .accessibilityIdentifier("acces.demande.lot")
                    Stepper(value: $demande.quantite, in: 1...5) {
                        LabeledContent(TextesAcces.quantite, value: demande.quantite.formatted())
                    }
                }
                Section(TextesAcces.motif) {
                    TextField(TextesAcces.motifIndication, text: $demande.motif, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(TextesAcces.nouvelleDemande)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BoutonsFeuille(envoi: envoi, envoyer: envoyer) }
            .disabled(envoi)
        }
        .onAppear { if lots.count == 1 { demande.lotId = lots[0].id } }
    }

    private func envoyer() async {
        guard demande.lotId != nil else {
            erreur = TextesAcces.choisirUnLot
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            try await service.demander(demande, dans: installation)
            fait(TextesAcces.demandeEnvoyee)
            fermer()
        } catch {
            withAnimation(.snappy) { erreur = RefusDuServeur.phrase(error) }
        }
    }
}

/// « Déclarer un accès existant » : type (télécommande par défaut) et code.
struct DeclarerAccesView: View {
    let installation: Installation
    let service: any ServiceAcces
    let fait: (String) -> Void
    @State private var type = TypeAcces.telecommande
    @State private var code = ""
    @State private var envoi = false
    @State private var erreur: String?
    @FocusState private var champ: Bool
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                }
                Section(TextesAcces.typeDAcces) {
                    Picker(TextesAcces.typeDAcces, selection: $type) {
                        ForEach(TypeAcces.allCases) { Text($0.libelle).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    TextField(TextesAcces.codeIndication, text: $code)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($champ)
                        .submitLabel(.done)
                        .onSubmit { Task { await envoyer() } }
                        .accessibilityIdentifier("acces.declarer.code")
                } header: {
                    Text(TextesAcces.codeReference)
                } footer: {
                    Text(TextesAcces.codeAide)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(TextesAcces.declarerExistant)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BoutonsFeuille(envoi: envoi, envoyer: envoyer) }
            .disabled(envoi)
        }
        .onAppear { champ = true }
    }

    private func envoyer() async {
        let saisi = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !saisi.isEmpty else {
            erreur = TextesAcces.saisirUnCode
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            let importResolu = try await service.declarer(type, code: saisi, dans: installation)
            fait(importResolu ? TextesAcces.accesEnregistreImport : TextesAcces.accesEnregistre)
            fermer()
        } catch {
            withAnimation(.snappy) { erreur = RefusDuServeur.phrase(error) }
        }
    }
}

/// « Annuler » et « Enregistrer » (« Enregistrement… » pendant l'envoi).
private struct BoutonsFeuille: ToolbarContent {
    let envoi: Bool
    let envoyer: () async -> Void
    @Environment(\.dismiss) private var fermer

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(TextesAcces.annuler) { fermer() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if envoi {
                ProgressView().accessibilityLabel("Enregistrement…")
            } else {
                Button(TextesAcces.enregistrer) { Task { await envoyer() } }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("acces.feuille.enregistrer")
            }
        }
    }
}
