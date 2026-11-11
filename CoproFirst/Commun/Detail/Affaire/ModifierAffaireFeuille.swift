// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Modifier l'affaire » (✏️ du bandeau) : l'Édition du cadre, en feuille — les mêmes
/// champs que la Création (`ChampsAffaire`), partis de l'affaire servie. N'envoie que
/// ce qui a changé (`EditionAffaire`).
///
/// Selon la saisie du compte, comme la Création (#110, arbitrage n° 80 de coprofirst) :
/// en Essentielle, ce qui n'est pas essentiel pour la catégorie se range dans « Plus de
/// détails », qui s'ouvre d'office si une section rangée porte une valeur. Les catégories
/// permises et les sections essentielles sont servies avec l'affaire (`referentiels`,
/// #105) : le formulaire s'ouvre composé, sans qu'une section change de place sous le pouce.
struct ModifierAffaireFeuille: View {
    let affaire: DetailAffaire
    let installation: Installation
    let envoyee: (String) -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var saisie: SaisieAffaire
    @State private var envoi = false
    @State private var erreur: String?

    /// Sans catégorie servie, rien ne se range : une forme sans sections laisse tout à son rang.
    private var forme: FormeDeSaisie? {
        let servis = affaire.referentiels
        return FormeDeSaisie(
            servi: parcours.ouverteAJour?.profil?.saisieAffaire,
            essentielles: servis.categories.isEmpty ? nil : servis.essentielles)
    }

    init(affaire: DetailAffaire, installation: Installation, envoyee: @escaping (String) -> Void) {
        self.affaire = affaire
        self.installation = installation
        self.envoyee = envoyee
        _saisie = State(initialValue: SaisieAffaire(modifiant: affaire))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                ChampsAffaire(
                    saisie: $saisie, categories: categories, installation: installation,
                    service: parcours.service as? any ServicePerimetres, prefixe: "modifier",
                    descriptionFigee: affaire.descriptionSaisie == nil ? affaire.description : nil,
                    lieuModifiable: affaire.lieuModifiable, forme: forme)
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            // Le mot du bouton (« Modifier ») : « Modifier l'affaire » se tronquait entre les boutons.
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(
                    envoi: envoi, actif: saisie.prete(depuis: affaire), identifiant: "modifier.enregistrer",
                    envoyer: envoyer)
            }
            .interactiveDismissDisabled(!saisie.edition(depuis: affaire).vide)
        }
    }

    /// Les catégories que ce lecteur peut poser, telles que le serveur les PERMET (#105,
    /// `FormulaireTicket` du site) : une actualité ne se convertit qu'au conseil — son auteur
    /// ne voit que la sienne. Une catégorie qu'il ne pourrait pas reposer ne se propose pas :
    /// elle resterait cochée sans se voir.
    private var categories: [CategorieAffaire] {
        let droits = DroitsAffaires(profil: parcours.ouverteAJour?.profil)
        let servies = affaire.referentiels.permises
        let permises =
            affaire.estActualite && !droits.moderateur
            ? servies.filter { $0.code == affaire.categorie } : servies
        return permises.contains { $0.code == affaire.categorie } ? permises : []
    }

    private func envoyer() async {
        guard let service = parcours.service.gestesAffaire else {
            erreur = "Ce geste n'est pas disponible ici."
            return
        }
        envoi = true
        defer { envoi = false }
        do {
            try await service.enregistrer(saisie.edition(depuis: affaire), de: affaire.id, dans: installation)
            envoyee(affaire.estActualite ? "Actualité modifiée" : "Affaire modifiée")
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}
