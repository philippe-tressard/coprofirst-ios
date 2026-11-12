// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Ajouter une suite » (`SUITE` du site) : le Suivi d'abord — l'état courant choisi,
/// le garder fait de l'entrée un commentaire —, puis le commentaire, requis s'il est seul.
///
/// Et sa CORRECTION, « Modifier la suite » (#91) : la même feuille, partie d'une entrée
/// de l'Historique (`corrigee`). Le Suivi part de l'état qu'elle a donné — revenir à
/// celui d'avant en refait un commentaire — ; seul ce qui a changé part
/// (`CorrectionSuite`), et un texte mis en forme sur le site se montre sans se modifier.
struct SuiteFeuille: View {
    let affaire: DetailAffaire
    let installation: Installation
    /// L'entrée que la feuille corrige ; `nil` : elle en ajoute une.
    let corrigee: SuiteAffaire?
    let envoyee: (String) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var saisie: SaisieSuite
    @State private var envoi = false
    @State private var erreur: String?
    @FocusState private var actif: Bool

    init(
        affaire: DetailAffaire, installation: Installation, corrigee: SuiteAffaire? = nil,
        envoyee: @escaping (String) -> Void
    ) {
        self.affaire = affaire
        self.installation = installation
        self.corrigee = corrigee
        self.envoyee = envoyee
        _saisie = State(
            initialValue: corrigee.map { SaisieSuite(corrigeant: $0, de: affaire) } ?? SaisieSuite(affaire: affaire))
    }

    var body: some View {
        // En correction, le Suivi ne se montre que si la liste sait dire les deux états de l'entrée.
        let proposes = SaisieSuite.etats(pour: affaire)
        let etats = corrigee == nil || saisie.suiviCorrigeable(parmi: proposes.map(\.code)) ? proposes : []
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                if !etats.isEmpty {
                    Section {
                        Picker("État", selection: $saisie.statut) {
                            ForEach(etats, id: \.code) { etat in
                                Text(etat.libelle).tag(etat.code)
                            }
                        }
                        .accessibilityIdentifier("suite.etat")
                    } header: {
                        Text("Suivi")
                    } footer: {
                        Text(piedDuSuivi)
                    }
                }
                commentaire
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            // Le mot court du site (`SUITE.court`) : le libellé entier se tronquait entre les boutons.
            .navigationTitle(corrigee == nil ? "Suite" : TextesSuite.titreCorrection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(envoi: envoi, actif: prete, identifiant: "suite.enregistrer", envoyer: envoyer)
            }
            .onAppear { actif = etats.isEmpty }
            // Une correction commencée ne se perd pas d'un glissement.
            .interactiveDismissDisabled(corrigee.map { !saisie.correction(depuis: $0, de: affaire).vide } ?? false)
        }
    }

    private var prete: Bool {
        corrigee.map { saisie.prete(depuis: $0, de: affaire) } ?? saisie.prete
    }

    private var piedDuSuivi: String {
        if corrigee != nil { return saisie.changeEtat ? TextesSuite.etatDonne : TextesSuite.etatDAvant }
        return saisie.changeEtat ? "L'affaire changera d'état." : "Garder l'état : un commentaire seul."
    }

    /// Le texte de l'entrée. Celui qu'on corrige et que l'app ne sait pas réécrire sans
    /// perte (gras, liste, lien) se montre tel quel, comme la description d'une affaire.
    @ViewBuilder private var commentaire: some View {
        if let fige = corrigee?.contenu, corrigee?.contenuSaisi == nil {
            Section {
                Text(TexteDuSite.riche(fige))
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("suite.texteFige")
            } header: {
                Text("Commentaire")
            } footer: {
                Text(TexteDuSite.miseEnFormeAuSite)
            }
        } else {
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
    }

    private func envoyer() async {
        guard let service = parcours.service.gestesAffaire else {
            erreur = TextesSuite.indisponible
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            // Les mots de l'avis du site (`affaires-en-liste.ts`).
            if let corrigee {
                let correction = saisie.correction(depuis: corrigee, de: affaire)
                try await service.corrigerSuite(correction, corrigee.id, de: affaire.id, dans: installation)
                envoyee(TextesSuite.corrigee)
            } else {
                try await service.ajouterSuite(saisie, a: affaire.id, dans: installation)
                envoyee(saisie.changeEtat ? "Statut mis à jour" : "Commentaire ajouté")
            }
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}
