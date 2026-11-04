// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le pied commun des trois formulaires : « Annuler », « Enregistrer » (désactivé
/// tant que la saisie est incomplète), l'erreur du serveur en une phrase.
private struct PiedFormulaire: ViewModifier {
    let titre: String
    let complet: Bool
    let envoi: Bool
    let erreur: ErreurService?
    let enregistrer: () -> Void
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(envoi)
            .safeAreaInset(edge: .top) {
                if let erreur { MessageErreur(texte: erreur.phrase).padding(.horizontal, Mise.marge) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    if envoi {
                        ProgressView()
                    } else {
                        Button("Enregistrer", action: enregistrer).fontWeight(.semibold).disabled(!complet)
                            .accessibilityIdentifier("formulaire.enregistrer")
                    }
                }
            }
    }
}

/// Ce qu'un envoi réussi annonce et relit.
private struct Envoi {
    let etat: EtatCommunaute
    let reussite: String
    let onglet: OngletCommunaute
    let installation: Installation
    let service: any ServiceCommunaute

    init(
        _ etat: EtatCommunaute, _ reussite: String, _ onglet: OngletCommunaute, _ installation: Installation,
        _ service: any ServiceCommunaute
    ) {
        (self.etat, self.reussite, self.onglet, self.installation, self.service) =
            (etat, reussite, onglet, installation, service)
    }
}

/// L'envoi d'un formulaire : le geste, puis la fermeture et la liste relue — ou
/// l'erreur affichée, le formulaire gardé.
@MainActor
private func envoyer(
    _ envoi: Envoi, _ enCours: Binding<Bool>, _ erreur: Binding<ErreurService?>, _ fermer: DismissAction,
    _ geste: @escaping () async throws -> Void
) {
    enCours.wrappedValue = true
    erreur.wrappedValue = nil
    Task {
        do {
            try await geste()
            withAnimation(.snappy) { envoi.etat.bandeau = PhraseDuGeste(texte: envoi.reussite, reussi: true) }
            fermer()
            await envoi.etat.charger(envoi.onglet, envoi.installation, avec: envoi.service)
        } catch {
            withAnimation(.snappy) { erreur.wrappedValue = ErreurService.depuis(error) }
        }
        enCours.wrappedValue = false
    }
}

/// « Nouvelle idée » : un titre et une description, tous deux obligatoires.
struct FormulaireIdee: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.dismiss) private var fermer
    @State private var titre = ""
    @State private var description = ""
    @State private var envoi = false
    @State private var erreur: ErreurService?

    var body: some View {
        Form {
            Section("Titre") { TextField("Ex. Vélos électriques en libre-service", text: $titre) }
            Section("Description") {
                TextField("Décrivez votre idée…", text: $description, axis: .vertical).lineLimit(5...12)
            }
        }
        .modifier(PiedFormulaire(titre: "Nouvelle idée", complet: complet, envoi: envoi, erreur: erreur) {
            let service = parcours.serviceCommunaute
            let (titre, texte) = (titre.trimmingCharacters(in: .whitespaces), HTMLDeSaisie.depuis(description))
            envoyer(Envoi(etat, "Idée soumise !", .idees, installation, service), $envoi, $erreur, fermer) {
                try await service.proposerIdee(titre: titre, description: texte, dans: installation)
            }
        })
    }

    private var complet: Bool {
        ![titre, description].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

/// « Déposer une annonce » : le titre, l'objet (type, catégorie, prix pour une vente),
/// la description et le contact. Les photos s'ajoutent sur le site.
struct FormulaireAnnonce: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.dismiss) private var fermer
    @State private var saisie = SaisieAnnonce()
    @State private var envoi = false
    @State private var erreur: ErreurService?

    var body: some View {
        Form {
            Section("Titre") { TextField("Ex. Lave-linge presque neuf", text: $saisie.titre) }
            Section("L'objet") {
                Picker("Type", selection: $saisie.type.animation(.snappy)) {
                    ForEach(RegleCommunaute.typesAnnonce, id: \.code) { Text($0.libelle).tag($0.code) }
                }
                Picker("Catégorie", selection: $saisie.categorie) {
                    ForEach(RegleCommunaute.categoriesAnnonce, id: \.code) { Text($0.libelle).tag($0.code) }
                }
                if saisie.type == "vente" {
                    TextField("Prix (€)", value: $saisie.prix, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                    Toggle("Prix négociable", isOn: $saisie.negociable)
                }
            }
            Section("Description") {
                TextField("""
                    Décrivez l'objet, son état, conditions de remise…
                    """, text: $saisie.description, axis: .vertical)
                    .lineLimit(5...12)
            }
            Section {
                Toggle("Afficher mes coordonnées aux autres résidents", isOn: $saisie.coordonneesVisibles)
            } footer: {
                Text("Les photos s'ajoutent ensuite, depuis l'annonce sur le site.")
            }
        }
        .modifier(PiedFormulaire(titre: "Déposer une annonce", complet: complet, envoi: envoi, erreur: erreur) {
            let service = parcours.serviceCommunaute
            var envoyee = saisie
            envoyee.titre = saisie.titre.trimmingCharacters(in: .whitespaces)
            envoyee.description = HTMLDeSaisie.depuis(saisie.description)
            envoyer(Envoi(etat, "Annonce publiée !", .annonces, installation, service), $envoi, $erreur, fermer) {
                try await service.deposerAnnonce(envoyee, dans: installation)
            }
        })
    }

    private var complet: Bool {
        let prixValide = saisie.prix.map { $0 >= 0 } ?? true
        return prixValide
            && ![saisie.titre, saisie.description].contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }
}

/// « Donner mon avis » — ou « Modifier l'avis » quand le compte en a déjà un. Sous
/// le seuil, ce qui a manqué ; à partir de l'autre, l'accord de diffusion (sans
/// réponse par défaut, comme sur le site).
struct FormulaireAvis: View {
    let etat: EtatCommunaute
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @State private var saisie = SaisieAvis()
    @State private var envoi = false
    @State private var erreur: ErreurService?

    private var existant: AvisResident? {
        etat.monAvisId.flatMap { id in etat.avis.elements.first { $0.id == id } }
    }

    var body: some View {
        Form {
            Section("Titre") {
                TextField("Ex. Enfin une résidence où l'on sait ce qui se passe", text: $saisie.titre)
            }
            Section {
                ChoixEtoiles(note: $saisie.note)
            } header: {
                Text("Note")
            } footer: {
                Text("""
                    Votre avis se lit de vous et du conseil syndical. À partir de \
                    \(RegleCommunaute.notePubliable) étoiles, vous pourrez accepter qu'il se lise de \
                    tous.
                    """)
            }
            if RegleCommunaute.demandeRemarque(saisie.note) {
                Section("Ce qui vous a manqué") {
                    TextField(
                        "Dites-nous ce qui ne va pas : c'est ce qui fait progresser le site.", text: $saisie.remarque,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }
            }
            Section("Description") {
                TextField("Votre avis…", text: $saisie.description, axis: .vertical).lineLimit(4...12)
            }
            if RegleCommunaute.demandeConsentement(saisie.note) {
                Section("Diffusion sur coprofirst.fr") {
                    Picker(
                        "Acceptez-vous que cet avis soit lu de tous et publié sur coprofirst.fr ?",
                        selection: $saisie.consentement
                    ) {
                        Text("Oui").tag(Bool?.some(true))
                        Text("Non").tag(Bool?.some(false))
                    }
                    .pickerStyle(.inline)
                }
            }
        }
        .animation(.snappy, value: saisie.note)
        .onAppear(perform: preremplir)
        .modifier(
            PiedFormulaire(
                titre: existant == nil ? "Donner mon avis" : "Modifier l'avis", complet: saisie.complete, envoi: envoi,
                erreur: erreur
            ) {
                let service = parcours.serviceCommunaute
                var envoyee = saisie
                envoyee.description = HTMLDeSaisie.depuis(saisie.description)
                let id = existant?.id
                let merci =
                    id != nil
                    ? "Avis mis à jour"
                    : (envoyee.consentementEnvoye == true
                        ? """
                            Merci ! Votre témoignage nous aide à faire connaître CoproFirst. Il sera \
                            relu avant de paraître sur coprofirst.fr.
                            """
                        : "Merci pour votre avis : il nous aide à améliorer CoproFirst.")
                envoyer(Envoi(etat, merci, .avis, installation, service), $envoi, $erreur, fermer) {
                    if let id {
                        try await service.corrigerAvis(id, envoyee, dans: installation)
                    } else {
                        try await service.deposerAvis(envoyee, dans: installation)
                    }
                }
            })
    }

    /// Corriger part du texte servi : le HTML redevient du texte à éditer.
    private func preremplir() {
        guard let avis = existant, saisie.titre.isEmpty else { return }
        saisie = SaisieAvis(
            note: avis.note, titre: avis.titre, description: TexteDuSite.apercu(avis.description),
            remarque: avis.remarque ?? "", consentement: avis.consentement)
    }
}

/// Cinq étoiles à toucher ; VoiceOver les règle comme un curseur.
private struct ChoixEtoiles: View {
    @Binding var note: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { rang in
                Button {
                    withAnimation(.snappy) { note = rang }
                } label: {
                    Image(systemName: rang <= note ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(rang <= note ? palette.warning : palette.textMuted)
                        .frame(minWidth: Mise.cible, minHeight: Mise.cible)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: note)
        .accessibilityElement()
        .accessibilityLabel("Note")
        .accessibilityValue(note == 0 ? "Aucune" : "\(note) sur 5")
        .accessibilityAdjustableAction { sens in
            switch sens {
            case .increment: note = min(5, note + 1)
            case .decrement: note = max(1, note - 1)
            @unknown default: break
            }
        }
    }
}
