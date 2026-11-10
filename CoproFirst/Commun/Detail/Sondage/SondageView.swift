// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La fiche d'un sondage, comme celle du site (`sondages/[id]/+page.svelte`, #38) :
/// l'en-tête, puis le vote s'il est ouvert (réponse, précision, commentaire, charte) ou
/// les résultats quand le serveur les rend visibles (`resultats_visibles`, sa décision),
/// puis le fil des commentaires.
struct SondageView: View {
    let id: Int
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette

    var body: some View {
        let service = parcours.serviceSondage
        let installation = installation
        Chargement(
            charger: { [id] in try await service.sondage(id, dans: installation) },
            contenu: { sondage, recharger in
                ContenuSondage(sondage: sondage, installation: installation, recharger: recharger)
            },
            squelette: { ContenuSondage(sondage: Self.squelette, installation: installation, recharger: {}) }
        )
        .background(palette.bg)
        .navigationTitle(TextesSondage.titre)
        .navigationBarTitleDisplayMode(.inline)
    }

    static let squelette = DetailSondage(
        id: 0, question: "Une question posée à la résidence", description: "Le sondage se charge.",
        options: (1...3).map {
            OptionSondage(id: $0, libelle: "Une réponse possible", champLibre: false, nbVotes: nil, reponsesLibres: [])
        },
        monVote: nil, cloture: false, clotureLe: nil, resultatsVisibles: false, commentaires: [], moi: nil)
}

private struct ContenuSondage: View {
    let sondage: DetailSondage
    let installation: Installation
    let recharger: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var vote = VoteSondage()
    @State private var envoi = false
    @State private var signale: ReponseCommunaute?
    @State private var avis = AvisDuGeste()
    @State private var retrait = RetraitDeReponse()

    var body: some View {
        List {
            Section { EnteteSondage(sondage: sondage) }
                .listRowBackground(palette.surface)
            if sondage.peutVoter {
                FormulaireVote(sondage: sondage, vote: $vote, envoi: envoi) { Task { await voter() } }
            } else {
                ResultatsSondage(sondage: sondage)
            }
            FilReponses(
                reponses: sondage.commentaires, moi: sondage.moi, gestes: gestes, retrait: retrait,
                invite: TextesSondage.commentaireInviteFil, entete: TextesSondage.commentaires)
        }
        .scrollContentBackground(.hidden)
        // Le clavier cacherait « Voter », au bas du formulaire : défiler le ferme, « OK » aussi.
        // Les champs sont multilignes, « Retour » y va à la ligne.
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("clavier.ok")
            }
        }
        .animation(.snappy, value: sondage.peutVoter)
        .confirmationDeRetrait(retrait, gestes: gestes)
        .signalementAuConseil($signale) { reponse, motif in Task { await signaler(reponse, motif) } }
        .avisEphemere(avis)
    }

    private var service: any ServiceSondage { parcours.serviceSondage }

    private var gestes: GestesReponses {
        GestesReponses(
            publier: { contenu in
                await geste(TextesSondage.commentairePublie) {
                    try await service.commenterSondage(contenu, au: sondage.id, dans: installation)
                }
            },
            retirer: { reponse in
                _ = await geste(TextesSondage.commentaireSupprime) {
                    try await service.supprimerCommentaireSondage(reponse.id, du: sondage.id, dans: installation)
                }
            },
            signaler: { signale = $0 })
    }

    private func voter() async {
        envoi = true
        defer { envoi = false }
        let envoye = vote
        let reussi = await geste(TextesSondage.voteEnregistre) {
            try await service.voter(envoye, au: sondage.id, dans: installation)
        }
        if reussi { vote = VoteSondage() }
    }

    private func signaler(_ reponse: ReponseCommunaute, _ motif: String) async {
        let cible = CibleSignalement(type: "commentaire", id: reponse.id)
        await geste(TextesSondage.signalementTransmis, relire: false) {
            try await service.signalerAuConseil(cible, motif: motif, dans: installation)
        }
    }

    /// Un geste : la phrase du site s'il réussit (puis la fiche se relit — elle dit ce que
    /// le serveur a retenu), celle du serveur sinon.
    @discardableResult
    private func geste(_ reussite: String, relire: Bool = true, _ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            avis.dire(reussite)
            if relire { recharger() }
            return true
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
            return false
        }
    }
}

/// L'état, la clôture, la question, la description et le nombre de votes.
private struct EnteteSondage: View {
    let sondage: DetailSondage
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowEtiquettes(espace: 8) {
                PastilleTeinte(
                    libelle: sondage.cloture ? TextesSondage.cloture : TextesSondage.ouvert,
                    badge: sondage.cloture ? "badge-gray" : "badge-green")
                if let fin = sondage.clotureLe {
                    Text(TextesSondage.clotureLe(fin, close: sondage.cloture))
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                }
            }
            Text(sondage.question)
                .font(.titre(.title2))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sondage.question")
            if let description = sondage.description.map(TexteRiche.init(html:)), !description.vide {
                description.font(.body).foregroundStyle(palette.textMuted).tint(palette.primary)
            }
            if sondage.totalVotes > 0 {
                Text(TextesSondage.votes(sondage.totalVotes))
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("sondage.total")
            }
        }
        .padding(.vertical, 6)
    }
}
