// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Ajouter une suite » (`SUITE` du site) : le Suivi d'abord — l'état courant choisi,
/// le garder fait de l'entrée un commentaire —, puis le commentaire, requis s'il est seul.
struct SuiteFeuille: View {
    let affaire: DetailAffaire
    let installation: Installation
    let envoyee: (String) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var saisie: SaisieSuite
    @State private var envoi = false
    @State private var erreur: String?
    @FocusState private var actif: Bool

    init(affaire: DetailAffaire, installation: Installation, envoyee: @escaping (String) -> Void) {
        self.affaire = affaire
        self.installation = installation
        self.envoyee = envoyee
        _saisie = State(initialValue: SaisieSuite(affaire: affaire))
    }

    var body: some View {
        let etats = SaisieSuite.etats(pour: affaire)
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                if !etats.isEmpty {
                    Section {
                        Picker("État", selection: $saisie.statut) {
                            ForEach(etats, id: \.self) { code in
                                Text(StatutsAffaire.libelle(code, servi: nil)).tag(code)
                            }
                        }
                        .accessibilityIdentifier("suite.etat")
                    } header: {
                        Text("Suivi")
                    } footer: {
                        Text(saisie.changeEtat ? "L'affaire changera d'état." : "Garder l'état : un commentaire seul.")
                    }
                }
                Section("Commentaire") {
                    TextField(
                        saisie.changeEtat
                            ? "Un mot sur ce changement (facultatif)" : "Ajoutez un commentaire de suivi…",
                        text: $saisie.contenu, axis: .vertical
                    )
                    .lineLimit(4...12)
                    .focused($actif)
                    .accessibilityIdentifier("suite.texte")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            // Le mot court du site (`SUITE.court`) : le libellé entier se tronquait entre les boutons.
            .navigationTitle("Suite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(envoi: envoi, actif: saisie.prete, identifiant: "suite.enregistrer", envoyer: envoyer)
            }
            .onAppear { actif = etats.isEmpty }
        }
    }

    private func envoyer() async {
        guard let service = parcours.service.gestesAffaire else {
            erreur = "Ce geste n'est pas disponible ici."
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            try await service.ajouterSuite(saisie, a: affaire.id, dans: installation)
            // Les mots de l'avis du site (`affaires-en-liste.ts`).
            envoyee(saisie.changeEtat ? "Statut mis à jour" : "Commentaire ajouté")
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}
