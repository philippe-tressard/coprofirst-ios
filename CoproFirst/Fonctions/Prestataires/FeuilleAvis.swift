// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce que les gestes des avis demandent à l'écran qui les porte (#207) : le droit SERVI du
/// conseil syndical (`est_moderateur` — noter, retirer), l'avis qui suit un geste, et la
/// relecture de la liste (la moyenne et le nombre d'avis de la carte sont servis avec elle).
struct GestesAvis {
    let conseil: Bool
    let avis: AvisDuGeste
    let apres: () -> Void
}

/// Noter, ou corriger son avis.
enum ModeAvis: Identifiable, Hashable {
    case noter(contrat: Int?)
    case corriger(AvisPrestataire)

    var id: String {
        switch self {
        case .noter: "noter"
        case .corriger(let avis): "corriger.\(avis.id)"
        }
    }
}

/// La saisie d'un avis, en feuille (`GesteNoter.svelte` : « ⭐ Noter » et « Modifier cet
/// avis ») : l'affaire jugée, puis l'état, les motifs et le commentaire (`ChampsAvis`).
/// « Enregistrer » attend ce que le site exige — l'état, un commentaire pour « Mauvais »,
/// la confirmation de l'ajout — et la phrase du site dit ce qui manque.
struct FeuilleAvis: View {
    let mode: ModeAvis
    let prestataire: Prestataire
    let installation: Installation
    let service: any ServicePrestataires
    let envoye: (String) -> Void
    @State private var saisie: AvisSaisi
    @State private var affaires: [AffaireANoter] = []
    @State private var envoi = false
    @State private var erreur: String?
    @Environment(\.palette) private var palette

    init(
        mode: ModeAvis, prestataire: Prestataire, installation: Installation, service: any ServicePrestataires,
        envoye: @escaping (String) -> Void
    ) {
        (self.mode, self.prestataire, self.installation, self.service, self.envoye) =
            (mode, prestataire, installation, service, envoye)
        if case .corriger(let avis) = mode {
            _saisie = State(initialValue: AvisSaisi(corrigeant: avis))
        } else {
            _saisie = State(initialValue: AvisSaisi())
        }
    }

    /// L'affaire choisie n'a pas encore ce prestataire : noter l'y ajoute, s'il le confirme.
    private var choisie: AffaireANoter? { affaires.first { $0.id == saisie.affaire } }
    private var ajoutRequis: Bool { choisie.map { !$0.intervient } ?? false }

    var body: some View {
        NavigationStack {
            Form {
                if let erreur {
                    Section { MessageErreur(texte: erreur).listRowInsets(EdgeInsets()) }
                        .listRowBackground(Color.clear)
                }
                ChoixAffaireAvis(
                    affaires: affaires, affaire: $saisie.affaire, prestataire: prestataire.nom,
                    rechercher: rechercheDetaillee)
                if let choisie, ajoutRequis {
                    Section {
                        CaseACocher(
                            libelle: TextesSaisieAvis.ajouter(prestataire.nom, a: choisie.titre),
                            identifiant: "avis.confirmerAjout", coche: $saisie.confirmeAjout)
                    }
                }
                ChampsAvis(saisie: $saisie, refus: saisie.refus(ajoutRequis: ajoutRequis, prestataire: prestataire.nom))
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .animation(.snappy(duration: 0.2), value: ajoutRequis)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BoutonsFeuille(
                    envoi: envoi, actif: saisie.refus(ajoutRequis: ajoutRequis, prestataire: "") == nil,
                    identifiant: "avis.enregistrer", envoyer: envoyer)
            }
            .interactiveDismissDisabled(saisie != initiale)
            .task { affaires = (try? await service.affairesANoter(de: prestataire.id, dans: installation)) ?? [] }
        }
    }

    private var titre: String {
        if case .corriger = mode { return TextesSaisieAvis.modifier }
        return TextesSaisieAvis.titreNoter
    }

    private var initiale: AvisSaisi {
        if case .corriger(let avis) = mode { return AvisSaisi(corrigeant: avis) }
        return AvisSaisi()
    }

    /// La recherche de la page Affaires, quand le service la réalise (les deux services de l'app).
    private var rechercheDetaillee: ((String) async throws -> [Int])? {
        guard let affaires = service as? any ServiceAffaires else { return nil }
        let installation = installation
        return { try await affaires.rechercher($0, dans: installation) }
    }

    private func envoyer() async {
        let contrat: Int? =
            switch mode {
            case .noter(let contrat): contrat
            case .corriger(let avis): avis.contratId
            }
        guard let corps = saisie.envoi(prestataire: prestataire.id, contrat: contrat, ajoutRequis: ajoutRequis)
        else { return }
        envoi = true
        defer { envoi = false }
        do {
            switch mode {
            case .noter:
                try await service.noter(corps, dans: installation)
                envoye(TextesSaisieAvis.enregistree)
            case .corriger(let avis):
                try await service.corriger(avis.id, corps, dans: installation)
                envoye(TextesSaisieAvis.modifie)
            }
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error).phrase }
        }
    }
}

/// « ⭐ Noter » : le bouton du site, et la feuille qu'il ouvre — sur la fiche d'un
/// prestataire et sur la carte d'un contrat, le même geste (`GesteNoter`).
struct BoutonNoter: View {
    let prestataire: Prestataire
    let contrat: Int?
    let installation: Installation
    let service: any ServicePrestataires
    let gestes: GestesAvis
    /// Après l'envoi, en plus de la relecture de la liste (le récapitulatif de la fiche).
    var relire: () async -> Void = {}
    @State private var ouvert = false
    @Environment(\.palette) private var palette

    var body: some View {
        Button(TextesSaisieAvis.noter) { ouvert = true }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(palette.primary)
            .frame(minHeight: Mise.cible)
            .gesteEnLigne()
            .accessibilityIdentifier(contrat.map { "contrat.\($0).noter" } ?? "prestataire.\(prestataire.id).noter")
            .sheet(
                isPresented: $ouvert, onDismiss: { gestes.avis.feuilleFermee() },
                content: {
                    FeuilleAvis(
                        mode: .noter(contrat: contrat), prestataire: prestataire, installation: installation,
                        service: service,
                        envoye: { phrase in
                            gestes.avis.direApresFermeture(phrase)
                            ouvert = false
                            gestes.apres()
                            Task { await relire() }
                        })
                })
    }
}
