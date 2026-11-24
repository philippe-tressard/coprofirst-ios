// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Appairer un écran » (`FormulaireCreation` de `OngletEcrans.svelte`) : le code que
/// l'écran affiche, son nom, UN périmètre (`PerimetrePicker mode="single"`). « Enregistrer »
/// reste grisé tant que le site refuserait ; un code inconnu rend la phrase du serveur.
struct FeuilleAppairage: View {
    let service: any ServiceEcransCS
    let installation: Installation
    let appaire: (EcranAppaire) -> Void
    @State private var saisie = SaisieAppairage()
    @State private var arbre = ArbreDesPerimetres([])
    @State private var envoi = false
    @State private var erreur: String?
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette

    var body: some View {
        FeuilleDeSaisie(titre: TextesEcransCS.appairer, erreur: erreur) {
            Section {
                TextField(TextesEcransCS.codeExemple, text: $saisie.code)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                    .accessibilityLabel(TextesEcransCS.code)
                    .accessibilityIdentifier("ecrans.feuille.code")
            } header: {
                Text(TextesEcransCS.code)
            } footer: {
                Text(TextesEcransCS.aideCode)
            }
            Section(TextesEcransCS.nom) {
                TextField(TextesEcransCS.nomExemple, text: $saisie.nom)
                    .accessibilityLabel(TextesEcransCS.nom)
                    .accessibilityIdentifier("ecrans.feuille.nom")
            }
            if !arbre.noeuds.isEmpty {
                Section {
                    ChoixPerimetres(
                        arbre: arbre, choix: $saisie.perimetres, identifiant: "ecrans.feuille.perimetre")
                } header: {
                    Text(TextesEcransCS.perimetre)
                } footer: {
                    Text(TextesEcransCS.aidePerimetre)
                }
            }
        } barre: {
            BoutonsFeuille(envoi: envoi, actif: saisie.complete, identifiant: "ecrans.feuille.enregistrer") {
                await envoyer()
            }
        }
        .disabled(envoi)
        .animation(.snappy, value: erreur)
        .task {
            // Le défaut d'abord (`perimetreDefautListe` du site) : un écran de toute la
            // copropriété se confirme sans toucher au choix.
            arbre = ArbreDesPerimetres((try? await service.perimetres(installation)) ?? [])
            if saisie.perimetres.codes.isEmpty { saisie.perimetres.choisirDefaut(arbre) }
        }
    }

    private func envoyer() async {
        envoi = true
        defer { envoi = false }
        do {
            let resultat = try await service.appairer(saisie, dans: installation)
            appaire(resultat)
            fermer()
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}
