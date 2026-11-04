// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les préférences lues dans le JSON du compte : la valeur réglée, ou le défaut — et
/// la liste des clés jamais réglées (« réglage par défaut »).
struct LecturePreferences: Equatable {
    var valeurs: [String: Bool]
    var heritees: Set<String>

    init(_ json: String) {
        let lues = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
        var valeurs: [String: Bool] = [:]
        var heritees: Set<String> = []
        for (cle, defaut) in TablesProfil.defautsPreferences {
            if let valeur = lues[cle] as? Bool {
                valeurs[cle] = valeur
            } else {
                valeurs[cle] = defaut
                heritees.insert(cle)
            }
        }
        self.valeurs = valeurs
        self.heritees = heritees
    }

    /// Le JSON enregistré : les quatre clés, toutes réglées désormais.
    var json: String {
        let donnees = (try? JSONSerialization.data(withJSONObject: valeurs, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(bytes: donnees, encoding: .utf8) ?? "{}"
    }
}

/// « Ce que j'affiche » : la restriction aux bâtiments, puis les deux canaux de
/// notification, deux cases chacun. Ce qui concerne le compte arrive toujours.
struct PreferencesView: View {
    let compte: Compte
    let installation: Installation
    let enregistre: (Compte) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var lecture = LecturePreferences("{}")
    @State private var restreindre = false
    @State private var envoi = false
    @State private var phrase: (texte: String, reussi: Bool)?
    @State private var pret = false

    var body: some View {
        Form {
            Section {
                Toggle("N'afficher que les contenus de mon ou mes bâtiments", isOn: $restreindre)
            } footer: {
                Text("""
                    Décochée, vous voyez les actualités de toute la copropriété, sauf celles marquées \
                    confidentielles ; cochée, vous ne voyez que celles de votre bâtiment.
                    """)
            }
            ForEach(TablesProfil.canauxNotifications, id: \.mon) { canal in
                Section(canal.titre) {
                    caseDe("De mon ou mes bâtiments", cle: canal.mon)
                    caseDe("Des autres bâtiments", cle: canal.autres)
                }
            }
            Section {
                Button {
                    Task { await enregistrer() }
                } label: {
                    Text(envoi ? "Enregistrement…" : "Enregistrer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plein)
                .disabled(envoi)
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ce qui concerne votre compte — validation, rôle, demande traitée — vous parvient toujours.")
                    if !lecture.heritees.isEmpty {
                        Text("""
                            Les réglages marqués « par défaut » n'ont jamais été modifiés : enregistrez \
                            pour en faire votre choix.
                            """)
                    }
                    if let phrase {
                        Text(phrase.texte).foregroundStyle(phrase.reussi ? palette.successTexte : palette.danger)
                    }
                }
                .padding(.top, 8)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Ce que j'affiche")
        .sensoryFeedback(trigger: phrase?.texte) { _, _ in phrase.map { $0.reussi ? .success : .error } }
        .onAppear {
            guard !pret else { return }
            lecture = LecturePreferences(compte.preferences)
            restreindre = compte.restreindreAMesBatiments
            pret = true
        }
    }

    private func caseDe(_ libelle: String, cle: String) -> some View {
        Toggle(isOn: Binding(get: { lecture.valeurs[cle] ?? false }, set: { lecture.valeurs[cle] = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(libelle)
                if lecture.heritees.contains(cle) {
                    Text("réglage par défaut").font(.caption).foregroundStyle(palette.textMuted)
                }
            }
        }
    }

    private func enregistrer() async {
        envoi = true
        defer { envoi = false }
        let json = lecture.json
        do {
            try await parcours.serviceProfil.enregistrerPreferences(json, restreindre: restreindre, dans: installation)
            var neuf = compte
            neuf.preferences = json
            neuf.restreindreAMesBatiments = restreindre
            enregistre(neuf)
            withAnimation(.snappy) {
                lecture.heritees = []
                phrase = ("Préférences enregistrées", true)
            }
        } catch {
            withAnimation(.snappy) { phrase = ("Erreur lors de l'enregistrement", false) }
        }
    }
}

/// « Demander une modification (profil / bâtiment) » : la demande en attente, sinon le
/// formulaire ; l'historique en dessous. Le conseil syndical valide.
struct DemandeModificationView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var demandes: [DemandeModification] = []
    @State private var batiments: [BatimentResidence] = []
    @State private var statut: String?
    @State private var batiment: Int?
    @State private var motif = ""
    @State private var envoi = false
    @State private var phrase: (texte: String, reussi: Bool)?
    @State private var charge = false

    var body: some View {
        Form {
            if let attente = demandes.first(where: { $0.etat == "en_attente" }) {
                Section("Demande en attente") { Text(resume(attente)).foregroundStyle(palette.text) }
            } else if charge {
                formulaire
            }
            if !demandes.isEmpty {
                Section("Historique des demandes (\(demandes.count))") {
                    ForEach(demandes) { demande in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(demande.creeLe.formatted(date: .numeric, time: .omitted))
                                    .font(.caption).monospacedDigit()
                                Spacer()
                                Text(Self.etats[demande.etat] ?? demande.etat).font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(palette.textMuted)
                            Text(resume(demande))
                            if let refus = demande.motifRefus {
                                Text(refus).font(.footnote).foregroundStyle(palette.danger)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Demande de modification")
        .navigationBarTitleDisplayMode(.inline)
        .task { await charger() }
    }

    private var formulaire: some View {
        Section {
            Picker("Nouveau profil d'utilisateur", selection: $statut) {
                Text("Inchangé").tag(String?.none)
                ForEach(TablesProfil.statutsDemandables, id: \.self) {
                    Text(RolesUtilisateur.libelleStatut($0)).tag(Optional($0))
                }
            }
            Picker("Bâtiment souhaité", selection: $batiment) {
                Text("— Inchangé —").tag(Int?.none)
                ForEach(batiments) { Text("Bât. \($0.numero)").tag(Optional($0.id)) }
            }
            TextField("Motif / justification", text: $motif, prompt: Text("Expliquez brièvement…"), axis: .vertical)
                .lineLimit(2...6)
            Button(envoi ? "Envoi…" : "Envoyer la demande") { Task { await envoyer() } }
                .disabled(envoi || (statut == nil && batiment == nil))
            if let phrase { Text(phrase.texte).foregroundStyle(phrase.reussi ? palette.successTexte : palette.danger) }
        } footer: {
            Text("""
                Les modifications du profil d'utilisateur et du bâtiment sont soumises à validation du \
                conseil syndical.
                """)
        }
    }

    private static let etats = ["en_attente": "En attente", "approuvee": "Approuvée", "rejetee": "Rejetée"]

    private func resume(_ demande: DemandeModification) -> String {
        [
            demande.statutSouhaite.map { "changement de type vers « \(RolesUtilisateur.libelleStatut($0)) »" },
            demande.batimentSouhaite.map { "déménagement vers \($0)" },
        ].compactMap { $0 }.joined(separator: " + ").capitalisee
    }

    private func charger() async {
        let service = parcours.serviceProfil
        async let lues = service.demandesModification(installation)
        async let lus = service.batiments(installation)
        demandes = (try? await lues) ?? []
        batiments = (try? await lus) ?? []
        withAnimation(.snappy) { charge = true }
    }

    private func envoyer() async {
        envoi = true
        defer { envoi = false }
        do {
            try await parcours.serviceProfil.demanderModification(
                statut: statut, batiment: batiment, motif: motif, dans: installation)
            phrase = ("Demande envoyée au conseil syndical", true)
            await charger()
        } catch {
            phrase = (ErreurService.depuis(error).phrase, false)
        }
    }
}

private extension String {
    var capitalisee: String { prefix(1).uppercased() + dropFirst() }
}
