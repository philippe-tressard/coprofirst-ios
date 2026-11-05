// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'en-tête du conseil : l'AG qui l'a élu, la communauté WhatsApp — et le président,
/// choisi parmi les membres : un seul, par construction (`surPresident` du site).
struct FeuilleEnteteConseil: View {
    let conseil: ConseilCS
    let enregistrer: (ConseilCS) async throws -> Void
    @State private var annee = ""
    @State private var aUneDate = false
    @State private var date = Date.now
    @State private var whatsapp = ""
    @State private var president: Int?

    var body: some View {
        FeuilleAnnuaire(titre: TextesAnnuaire.conseil, identifiant: "cs.feuille.entete-conseil", envoyer: envoyer) {
            Section(TextesAnnuaireCS.voteEnAG) {
                TextField(TextesAnnuaireCS.anneeIndication, text: $annee)
                    .keyboardType(.numberPad)
                    .accessibilityLabel(TextesAnnuaireCS.voteEnAG)
                Toggle(TextesAnnuaireCS.dateAG, isOn: $aUneDate.animation(.snappy))
                if aUneDate {
                    DatePicker(TextesAnnuaireCS.dateAG, selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .environment(\.timeZone, FormatsDuSite.paris)
                }
            }
            Section(TextesAnnuaireCS.whatsapp) {
                TextField(TextesAnnuaireCS.whatsappIndication, text: $whatsapp)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if !conseil.membres.isEmpty {
                Section(TextesAnnuaire.president) {
                    Picker(TextesAnnuaire.president, selection: $president) {
                        Text(TextesAnnuaireCS.aucun).tag(Int?.none)
                        ForEach(Array(conseil.membres.enumerated()), id: \.offset) { rang, membre in
                            Text(FormatsDuSite.nom(membre.prenom, membre.nom)).tag(Int?.some(rang))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
        .onAppear {
            annee = conseil.agAnnee.map(String.init) ?? ""
            if let lue = FormatsDuSite.lire(conseil.agDate) {
                aUneDate = true
                date = lue
            }
            whatsapp = conseil.whatsappUrl ?? ""
            president = conseil.membres.firstIndex { $0.estPresident == true }
        }
    }

    private func envoyer() async throws {
        var nouveau = conseil.avecPresident(president)
        nouveau.agAnnee = Int(annee.trimmingCharacters(in: .whitespaces))
        nouveau.agDate = aUneDate ? AnnuaireCS.jour(date) : nil
        nouveau.whatsappUrl = whatsapp.nulSiVide
        try await enregistrer(nouveau)
    }
}

/// Un membre du conseil : sa civilité, son prénom, son nom. Son logement et l'inscrit
/// auquel il est lié sont conservés tels que le serveur les a.
struct FeuilleMembreConseil: View {
    @State var membre: MembreConseil
    let enregistrer: (MembreConseil) async throws -> Void

    var body: some View {
        FeuilleAnnuaire(
            titre: membre.id == nil ? TextesAnnuaireCS.nouveauMembreCS : TextesAnnuaireCS.ficheMembre,
            identifiant: "cs.feuille.membre-conseil", complete: AnnuaireCS.nomme(membre.prenom, membre.nom),
            envoyer: envoyer
        ) {
            ChampsIdentite(genre: $membre.genre, prenom: $membre.prenom, nom: $membre.nom)
        }
    }

    private func envoyer() async throws { try await enregistrer(membre) }
}

/// L'en-tête du syndic : son nom (désactivé quand le contrat de syndic fait foi), son
/// adresse, son espace client — et l'interlocuteur principal, un seul.
struct FeuilleEnteteSyndic: View {
    @State var syndic: SyndicCS
    let enregistrer: (SyndicCS) async throws -> Void
    @State private var principal: Int?

    var body: some View {
        FeuilleAnnuaire(titre: TextesAnnuaire.syndic, identifiant: "cs.feuille.entete-syndic", envoyer: envoyer) {
            Section {
                TextField(TextesAnnuaireCS.nomSyndicIndication, text: champ(\.nomSyndic))
                    .disabled(syndic.nomDuContrat)
                    .accessibilityLabel(TextesAnnuaireCS.nomSyndic)
            } header: {
                Text(TextesAnnuaireCS.nomSyndic)
            } footer: {
                Text(syndic.nomDuContrat ? TextesAnnuaireCS.nomDuContrat : TextesAnnuaireCS.nomSaisi)
            }
            Section(TextesAnnuaireCS.adresse) {
                TextField(TextesAnnuaireCS.adresseIndication, text: champ(\.adresse), axis: .vertical)
                    .lineLimit(2...4)
            }
            Section(TextesAnnuaireCS.siteWeb) {
                TextField("https://…", text: champ(\.siteWeb))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if !syndic.membres.isEmpty {
                Section(TextesAnnuaire.principal) {
                    Picker(TextesAnnuaire.principal, selection: $principal) {
                        Text(TextesAnnuaireCS.aucun).tag(Int?.none)
                        ForEach(Array(syndic.membres.enumerated()), id: \.offset) { rang, membre in
                            Text(FormatsDuSite.nom(membre.prenom, membre.nom)).tag(Int?.some(rang))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
        .onAppear { principal = syndic.membres.firstIndex { $0.estPrincipal == true } }
    }

    private func champ(_ chemin: WritableKeyPath<SyndicCS, String?>) -> Binding<String> {
        Binding { syndic[keyPath: chemin] ?? "" } set: { syndic[keyPath: chemin] = $0 }
    }

    private func envoyer() async throws {
        try await enregistrer(syndic.avecPrincipal(principal))
    }
}

/// Un interlocuteur du syndic : civilité, prénom, nom, fonction, courriel et numéros —
/// un champ par numéro.
struct FeuilleMembreSyndic: View {
    @State var membre: MembreSyndic
    let enregistrer: (MembreSyndic) async throws -> Void
    @State private var telephones: [String] = []

    var body: some View {
        FeuilleAnnuaire(
            titre: membre.id == nil ? TextesAnnuaireCS.nouveauMembreSyndic : TextesAnnuaireCS.ficheMembre,
            identifiant: "cs.feuille.membre-syndic", complete: AnnuaireCS.nomme(membre.prenom, membre.nom),
            envoyer: envoyer
        ) {
            ChampsIdentite(genre: $membre.genre, prenom: $membre.prenom, nom: $membre.nom)
            Section {
                TextField(TextesAnnuaireCS.fonctionIndication, text: champ(\.fonction))
                    .accessibilityLabel(TextesAnnuaireCS.fonction)
                TextField(TextesAnnuaireCS.email, text: champ(\.email))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section(TextesAnnuaireCS.telephones(telephones.count)) {
                ForEach(telephones.indices, id: \.self) { rang in
                    TextField(TextesAnnuaireCS.telephoneIndication, text: $telephones[rang])
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                .onDelete { telephones.remove(atOffsets: $0) }
                Button { telephones.append("") } label: {
                    Label(TextesAnnuaireCS.ajouterTelephone, systemImage: "plus")
                }
            }
        }
        .onAppear { telephones = AnnuaireCS.telephones(membre.telephone) }
    }

    private func champ(_ chemin: WritableKeyPath<MembreSyndic, String?>) -> Binding<String> {
        Binding { membre[keyPath: chemin] ?? "" } set: { membre[keyPath: chemin] = $0 }
    }

    private func envoyer() async throws {
        membre.telephone = AnnuaireCS.champTelephone(telephones)
        try await enregistrer(membre)
    }
}

/// Civilité, prénom et nom : les trois champs de toute fiche.
private struct ChampsIdentite: View {
    @Binding var genre: String?
    @Binding var prenom: String?
    @Binding var nom: String?

    var body: some View {
        Section {
            let civilite = Binding { genre ?? AnnuaireCS.civiliteParDefaut } set: { genre = $0 }
            Picker(TextesAnnuaireCS.civilite, selection: civilite) {
                ForEach(TablesEspaceCS.civilites, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            TextField(TextesAnnuaireCS.prenom, text: Binding { prenom ?? "" } set: { prenom = $0 })
                .textContentType(.givenName)
                .accessibilityIdentifier("cs.feuille.prenom")
            TextField(TextesAnnuaireCS.nom, text: Binding { nom ?? "" } set: { nom = $0 })
                .textContentType(.familyName)
                .accessibilityIdentifier("cs.feuille.nom")
        }
    }
}

/// Une feuille de l'annuaire : son formulaire, « Annuler » et « Enregistrer », et la
/// phrase du serveur si l'enregistrement est refusé.
private struct FeuilleAnnuaire<Champs: View>: View {
    let titre: String
    let identifiant: String
    var complete = true
    let envoyer: () async throws -> Void
    @ViewBuilder let champs: () -> Champs
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
                champs()
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(envoi: envoi, actif: complete, identifiant: identifiant) {
                    envoi = true
                    defer { envoi = false }
                    do {
                        try await envoyer()
                        fermer()
                    } catch {
                        withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
                    }
                }
            }
            .disabled(envoi)
        }
    }
}

extension AnnuaireCS {
    /// « 2026-06-12 » : le jour de l'AG, à Paris, tel que le serveur le reçoit.
    static func jour(_ date: Date) -> String {
        let format = Date.ISO8601FormatStyle(dateSeparator: .dash, timeZone: FormatsDuSite.paris)
        return date.formatted(format.year().month().day())
    }

    /// Une fiche se nomme : un prénom ou un nom, au moins.
    static func nomme(_ prenom: String?, _ nom: String?) -> Bool {
        prenom?.nulSiVide != nil || nom?.nulSiVide != nil
    }
}
