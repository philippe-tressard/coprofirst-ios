// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Informations personnelles » : prénom, nom, adresse, téléphone, société, fonction.
/// Une nouvelle adresse demande le mot de passe actuel et ne vaut qu'une fois confirmée.
struct FormulaireIdentite: View {
    let compte: Compte
    let installation: Installation
    let enregistre: (String) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var saisie = SaisieIdentite()
    @State private var envoi = false
    @State private var erreur: ErreurService?

    var body: some View {
        Form {
            if let erreur { MessageErreur(texte: erreur.phrase).listRowBackground(Color.clear).listRowInsets(.init()) }
            Section {
                TextField("Prénom", text: $saisie.prenom).textContentType(.givenName)
                TextField("Nom", text: $saisie.nom).textContentType(.familyName)
            }
            Section {
                TextField("Adresse e-mail", text: $saisie.email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if saisie.changeAdresse(compte.email) {
                    SecureField("Mot de passe actuel", text: $saisie.motDePasseActuel).textContentType(.password)
                }
            } footer: {
                if saisie.changeAdresse(compte.email) {
                    Text("""
                        Un lien de confirmation partira à la nouvelle adresse et un avis à l’actuelle, \
                        qui reste celle de votre compte — connexion comprise — jusqu’à ce que vous \
                        cliquiez sur le lien.
                        """)
                }
            }
            Section {
                TextField("Téléphone", text: $saisie.telephone, prompt: Text("+33 6 00 00 00 00"))
                    .textContentType(.telephoneNumber).keyboardType(.phonePad)
                TextField("Société", text: $saisie.societe, prompt: Text("Ex : Agence Dupont, Cabinet ABC…"))
                    .textContentType(.organizationName)
                TextField("Fonction", text: $saisie.fonction, prompt: Text("Ex : Gestionnaire, Mandataire…"))
                    .textContentType(.jobTitle)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .animation(.snappy, value: saisie.changeAdresse(compte.email))
        .navigationTitle("Informations personnelles")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(envoi)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
            ToolbarItem(placement: .confirmationAction) {
                if envoi {
                    ProgressView()
                } else {
                    Button("Enregistrer") { Task { await enregistrer() } }
                        .fontWeight(.semibold)
                        .disabled(!saisie.complete(compte.email))
                }
            }
        }
        .onAppear { if saisie.email.isEmpty { saisie = SaisieIdentite(compte) } }
    }

    private func enregistrer() async {
        envoi = true
        defer { envoi = false }
        do {
            let service = parcours.serviceProfil
            let lien = try await service.modifierIdentite(saisie, ancienne: compte.email, dans: installation)
            fermer()
            enregistre(
                lien
                    ? """
                        Un lien de confirmation a été envoyé à \(saisie.email). Votre adresse actuelle \
                        reste celle du compte jusqu’à ce que vous cliquiez dessus.
                        """
                    : "Profil mis à jour")
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}

/// « Modifier le mot de passe » : l'actuel, puis le nouveau saisi deux fois. Le bouton
/// dit pourquoi il attend, dans l'ordre du site.
struct MotDePasseView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var actuel = ""
    @State private var nouveau = ""
    @State private var confirmation = ""
    @State private var envoi = false
    /// Un refus (actuel incorrect, nouveau trop faible) porte la phrase du serveur.
    @State private var erreur: ErreurService?
    @State private var reussi = false

    var body: some View {
        Form {
            Section {
                SecureField("Mot de passe actuel", text: $actuel).textContentType(.password)
            } footer: {
                Text("Il vous faut votre mot de passe actuel, puis le nouveau saisi deux fois.")
            }
            Section {
                SecureField("Nouveau mot de passe", text: $nouveau).textContentType(.newPassword)
                SecureField("Confirmation", text: $confirmation).textContentType(.newPassword)
            } footer: {
                if !confirmation.isEmpty, confirmation != nouveau {
                    Text("Cette saisie diffère du nouveau mot de passe.").foregroundStyle(palette.danger)
                } else if let attente {
                    Text(attente)
                }
            }
            if let message = erreur?.phrase {
                MessageErreur(texte: message).listRowBackground(Color.clear).listRowInsets(.init())
            }
            Section {
                Button {
                    Task { await modifier() }
                } label: {
                    Text(envoi ? "Modification…" : "Modifier le mot de passe").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plein)
                .disabled(attente != nil || envoi)
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Mot de passe")
        .sensoryFeedback(.success, trigger: reussi)
        .alert("Mot de passe modifié", isPresented: $reussi) { Button("OK") { fermer() } }
    }

    /// Ce qui manque encore, ou rien quand le bouton peut s'ouvrir.
    private var attente: String? {
        if actuel.isEmpty { return "Saisissez d’abord votre mot de passe actuel." }
        if nouveau.count < TablesProfil.longueurMinimaleMotDePasse {
            let minimum = TablesProfil.longueurMinimaleMotDePasse
            return "Le nouveau mot de passe doit faire \(minimum) caractères au minimum."
        }
        if nouveau != confirmation { return "Les deux saisies du nouveau mot de passe doivent être identiques." }
        return nil
    }

    private func modifier() async {
        envoi = true
        defer { envoi = false }
        do {
            try await parcours.serviceProfil.changerMotDePasse(actuel: actuel, nouveau: nouveau, dans: installation)
            erreur = nil
            reussi = true
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}
