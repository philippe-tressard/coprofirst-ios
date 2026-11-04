// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Plus › Profil, dans l'ordre du site : la résidence et le statut, les informations
/// personnelles, la sécurité, l'apparence, ce que j'affiche, les droits RGPD — puis
/// tout en bas les gestes de sortie, « Se déconnecter » en rouge.
struct ProfilView: View {
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var geste: GesteDeSortie?
    @State private var compte: Compte?
    @State private var erreur: ErreurService?
    @State private var identite = false
    @State private var phrase: String?
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @AppStorage(ThemeChoisi.cle) private var theme = TablesProfil.themeParDefaut

    var body: some View {
        List {
            if let ouverte = parcours.ouverteAJour {
                sectionResidence(ouverte)
                if let erreur {
                    MessageErreur(texte: erreur.phrase) { Task { await charger(ouverte) } }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                if let compte {
                    sectionIdentite(compte)
                    sectionSecurite(ouverte)
                }
                sectionApparence
                if let compte {
                    Section {
                        NavigationLink {
                            PreferencesView(compte: compte, installation: ouverte) { self.compte = $0 }
                        } label: {
                            Label("Ce que j'affiche", systemImage: "bell.badge")
                        }
                        .listRowBackground(palette.surface)
                    }
                    SectionDroits(compte: compte, installation: ouverte) { self.compte = $0 }
                }
                sectionSortie(ouverte)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(tailleTexte.isAccessibilitySize ? .inline : .large)
        .confirmationDeSortie($geste, parcours: parcours)
        .sheet(isPresented: $identite) {
            if let compte, let ouverte = parcours.ouverteAJour {
                NavigationStack {
                    FormulaireIdentite(compte: compte, installation: ouverte) { message in
                        phrase = message
                        Task { await charger(ouverte) }
                    }
                }
            }
        }
        .alert(phrase ?? "", isPresented: Binding(get: { phrase != nil }, set: { if !$0 { phrase = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .task {
            await parcours.rafraichirProfil()
            if let ouverte = parcours.ouverteAJour { await charger(ouverte) }
        }
    }

    private func charger(_ installation: Installation) async {
        do {
            let lu = try await parcours.serviceProfil.compte(installation)
            withAnimation(.snappy) {
                compte = lu
                erreur = nil
            }
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }

    /// La résidence, puis « Résidence & statut » du site : profil d'utilisateur,
    /// bâtiment, état du compte, ancienneté.
    private func sectionResidence(_ ouverte: Installation) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(ouverte.nom).font(.headline).foregroundStyle(palette.text)
                if let logement = ouverte.profil?.libelleLogement, !logement.isEmpty {
                    Label(logement, systemImage: "mappin").font(.subheadline).foregroundStyle(palette.textMuted)
                }
                PastillesRoles(profil: ouverte.profil)
            }
            .padding(.vertical, 4)
            .listRowBackground(palette.surface)
            if let compte {
                Group {
                    LabeledContent("Profil d'utilisateur", value: RolesUtilisateur.libelleStatut(compte.statut))
                    LabeledContent("Bâtiment", value: compte.batimentNom ?? "—")
                    LabeledContent("Statut du compte", value: compte.actif ? "Actif" : "Inactif")
                    LabeledContent("Membre depuis", value: FormatsDuSite.date(compte.creeLe))
                    if let derniere = compte.derniereConnexion {
                        LabeledContent(
                            "Dernière connexion", value: derniere.formatted(date: .abbreviated, time: .shortened))
                    }
                    NavigationLink("Demander une modification (profil / bâtiment)") {
                        DemandeModificationView(installation: ouverte)
                    }
                    .foregroundStyle(palette.primary)
                }
                .listRowBackground(palette.surface)
            }
        } header: {
            Text("Résidence").styleLibelle()
        }
    }

    private func sectionIdentite(_ compte: Compte) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(compte.prenom) \(compte.nom)").font(.headline).foregroundStyle(palette.text)
                Text(compte.email).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            .padding(.vertical, 2)
            .listRowBackground(palette.surface)
            Group {
                if let telephone = compte.telephone { LabeledContent("Téléphone", value: telephone) }
                if let societe = compte.societe { LabeledContent("Société", value: societe) }
                if let fonction = compte.fonction { LabeledContent("Fonction", value: fonction) }
                Button("Modifier mes informations") { identite = true }
                    .accessibilityIdentifier("profil.modifierIdentite")
            }
            .listRowBackground(palette.surface)
        } header: {
            Text("Informations personnelles").styleLibelle()
        } footer: {
            Text("La photo de profil et l'étage de votre logement se règlent sur le site.")
        }
    }

    private func sectionSecurite(_ ouverte: Installation) -> some View {
        Section {
            NavigationLink {
                MotDePasseView(installation: ouverte)
            } label: {
                Label("Modifier le mot de passe", systemImage: "key")
            }
            .listRowBackground(palette.surface)
        } header: {
            Text("Sécurité").styleLibelle()
        }
    }

    /// Le thème de l'app, réglé pour CET appareil — comme le site, qui le retient
    /// dans le navigateur et pas dans le compte.
    private var sectionApparence: some View {
        Section {
            Picker("Thème", selection: $theme.animation(.smooth(duration: 0.35))) {
                ForEach(TablesProfil.optionsTheme, id: \.code) { option in
                    Text(option.libelle).tag(option.code).accessibilityHint(option.detail)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(palette.surface)
            .accessibilityIdentifier("profil.theme")
        } header: {
            Text("Apparence").styleLibelle()
        } footer: {
            Text("Ce choix vaut pour cet appareil : il est retenu par l'app, pas par votre compte.")
        }
        .sensoryFeedback(.selection, trigger: theme)
    }

    private func sectionSortie(_ ouverte: Installation) -> some View {
        Section {
            Button(role: .destructive) {
                geste = .deconnecter(ouverte)
            } label: {
                Text("Se déconnecter").frame(maxWidth: .infinity, minHeight: Mise.cible)
            }
            .accessibilityIdentifier("profil.deconnecter")
            .listRowBackground(palette.surface)
        } footer: {
            Button("Oublier toutes les résidences") { geste = .oublierTout }
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, minHeight: Mise.cible)
                .padding(.top, 8)
                .accessibilityIdentifier("profil.oublierTout")
        }
    }
}

/// « Vos droits (RGPD) » : la politique de confidentialité, le refus des statistiques
/// de navigation, leur export et leur effacement.
private struct SectionDroits: View {
    let compte: Compte
    let installation: Installation
    let modifie: (Compte) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var effacer = false
    @State private var export: URL?
    @State private var enCours = false
    @State private var phrase: String?

    var body: some View {
        Section {
            Text("""
                Conformément au RGPD, vous pouvez exercer vos droits d'accès, rectification, portabilité \
                et effacement en contactant le responsable de traitement à l'adresse indiquée dans la \
                politique de confidentialité.
                """)
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
            Link(
                "Politique de confidentialité",
                destination: installation.adresse.appending(path: "politique-de-confidentialite"))
            Toggle("Refuser la collecte de statistiques de navigation", isOn: refus)
            if let export {
                ShareLink(item: export) { Label("Partager l'export", systemImage: "square.and.arrow.up") }
            } else {
                Button { Task { await exporter() } } label: {
                    Label("Exporter mes données de navigation", systemImage: "square.and.arrow.down")
                }
                .disabled(enCours)
            }
            Button(role: .destructive) { effacer = true } label: {
                Label("Effacer mes données de navigation", systemImage: "trash")
            }
            if let phrase { Text(phrase).font(.footnote).foregroundStyle(palette.textMuted) }
        } header: {
            Text("Vos droits (RGPD)").styleLibelle()
        }
        .listRowBackground(palette.surface)
        .confirmationDialog("Effacer mes données de navigation", isPresented: $effacer, titleVisibility: .visible) {
            Button("Oui, effacer", role: .destructive) { Task { await effacerDonnees() } }
        }
    }

    private var refus: Binding<Bool> {
        Binding(
            get: { compte.refusTelemetrie },
            set: { valeur in
                var neuf = compte
                neuf.refusTelemetrie = valeur
                modifie(neuf)
                Task {
                    do {
                        try await parcours.serviceProfil.refuserTelemetrie(valeur, dans: installation)
                        phrase = valeur ? "Collecte de statistiques désactivée." : "Collecte de statistiques réactivée."
                    } catch {
                        modifie(compte)
                        phrase = "Erreur lors de la mise à jour."
                    }
                }
            })
    }

    private func exporter() async {
        enCours = true
        defer { enCours = false }
        do {
            export = try await parcours.serviceProfil.exporterTelemetrie(installation)
            phrase = "Export prêt."
        } catch {
            phrase = "Erreur lors de l'export."
        }
    }

    private func effacerDonnees() async {
        do {
            try await parcours.serviceProfil.effacerTelemetrie(installation)
            phrase = "Données de navigation effacées."
        } catch {
            phrase = "Erreur lors de la suppression."
        }
    }
}

extension ProfilView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init()
    }
}
