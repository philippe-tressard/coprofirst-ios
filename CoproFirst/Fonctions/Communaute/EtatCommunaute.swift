// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// Une liste chargée : où elle en est, et ses éléments. Une erreur ne se montre
/// jamais comme une liste vide (le site non plus).
struct ListeChargee<Element: Sendable>: Sendable {
    enum Phase: Equatable, Sendable {
        case chargement
        case pret
        case erreur(ErreurService)
    }

    var phase = Phase.chargement
    var elements: [Element] = []
}

/// L'écran Communauté : qui regarde, quels onglets lui sont ouverts, et les quatre listes.
@MainActor @Observable
final class EtatCommunaute {
    /// Ce qui est ouvert à ce compte : la règle générée des onglets (un gestionnaire
    /// n'a que l'Avis), et la conclusion du serveur (`communaute_motif_refus`).
    enum Acces: Equatable {
        case verification
        case ouvert([OngletCommunaute])
        /// Tout est fermé ; la phrase est celle du serveur.
        case ferme(String)
        case erreur(ErreurService)
    }

    private(set) var acces = Acces.verification
    private(set) var moi: MoiCommunaute?
    var onglet = OngletCommunaute.sondages
    var sondages = ListeChargee<SondageResume>()
    var idees = ListeChargee<Idee>()
    var annonces = ListeChargee<Annonce>()
    var avis = ListeChargee<AvisResident>()
    private(set) var gestionnaireAvis = false
    private(set) var monAvisId: Int?
    /// La phrase d'un geste réussi ou manqué, montrée un instant en bas de l'écran.
    var bandeau: PhraseDuGeste?

    var onglets: [OngletCommunaute] {
        if case .ouvert(let onglets) = acces { return onglets }
        return []
    }

    /// GET /auth/me, puis les rubriques que la règle des onglets ouvre. Un motif de
    /// refus que la réserve n'explique pas (une suspension) ferme tout, l'Avis
    /// compris : l'écran dit alors la phrase du serveur, mot pour mot.
    func ouvrir(_ installation: Installation, avec service: any ServiceCommunaute) async {
        do {
            let lu = try await service.moiCommunaute(installation)
            moi = lu
            let ouverts = OngletCommunaute.ouverts(lu.droits)
            withAnimation(.snappy) {
                if let motif = lu.motifRefus, !lu.droits.gestionnaire || ouverts.isEmpty {
                    acces = .ferme(motif)
                } else {
                    acces = .ouvert(ouverts)
                    if !ouverts.contains(onglet), let premier = ouverts.first { onglet = premier }
                }
            }
        } catch {
            withAnimation(.snappy) { acces = .erreur(ErreurService.depuis(error)) }
        }
    }

    func charger(_ onglet: OngletCommunaute, _ installation: Installation, avec service: any ServiceCommunaute) async {
        switch onglet {
        case .sondages: await remplir(\.sondages) { try await service.sondagesCommunaute(installation) }
        case .idees: await remplir(\.idees) { try await service.idees(installation) }
        case .annonces: await remplir(\.annonces) { try await service.annonces(installation) }
        case .avis: await chargerAvis(installation, avec: service)
        }
    }

    private func chargerAvis(_ installation: Installation, avec service: any ServiceCommunaute) async {
        await remplir(\.avis) {
            let liste = try await service.avisCommunaute(installation)
            await MainActor.run {
                self.gestionnaireAvis = liste.gestionnaire
                self.monAvisId = liste.monAvisId
            }
            return liste.avis
        }
    }

    private func remplir<Element: Sendable>(
        _ chemin: ReferenceWritableKeyPath<EtatCommunaute, ListeChargee<Element>>,
        _ appel: () async throws -> [Element]
    ) async {
        if self[keyPath: chemin].elements.isEmpty { self[keyPath: chemin].phase = .chargement }
        do {
            let lus = try await appel()
            withAnimation(.snappy) {
                self[keyPath: chemin].elements = lus
                self[keyPath: chemin].phase = .pret
            }
        } catch {
            withAnimation(.snappy) { self[keyPath: chemin].phase = .erreur(ErreurService.depuis(error)) }
        }
    }

    /// Un geste : la phrase du site s'il réussit, celle de l'erreur sinon ; puis la
    /// liste de l'onglet se relit — elle dit ce que le serveur a retenu.
    func agir(
        _ reussite: String, recharger onglet: OngletCommunaute?, _ installation: Installation,
        avec service: any ServiceCommunaute, _ geste: () async throws -> String?
    ) async -> Bool {
        do {
            let phrase = try await geste()
            withAnimation(.snappy) { bandeau = PhraseDuGeste(texte: phrase ?? reussite, reussi: true) }
            if let onglet { await charger(onglet, installation, avec: service) }
            return true
        } catch {
            withAnimation(.snappy) { bandeau = PhraseDuGeste(texte: ErreurService.depuis(error).phrase, reussi: false) }
            return false
        }
    }

    /// Le vote sur une idée se voit tout de suite ; le serveur confirme ou défait.
    func basculerVote(_ idee: Idee, _ installation: Installation, avec service: any ServiceCommunaute) async {
        guard let rang = idees.elements.firstIndex(where: { $0.id == idee.id }) else { return }
        let avant = idees.elements
        withAnimation(.snappy) {
            idees.elements[rang].monVote.toggle()
            idees.elements[rang].nbVotes += idees.elements[rang].monVote ? 1 : -1
        }
        let reussi = await agir("Vote enregistré", recharger: .idees, installation, avec: service) {
            try await service.voterIdee(idee.id, dans: installation)
        }
        if !reussi { withAnimation(.snappy) { idees.elements = avant } }
    }

    /// « Signaler au conseil syndical » : rien ne change à l'écran, une phrase le confirme.
    func signaler(
        _ cible: CibleCommunaute, motif: String, _ installation: Installation, avec service: any ServiceCommunaute
    ) async {
        _ = await agir("Signalement transmis au conseil syndical", recharger: nil, installation, avec: service) {
            try await service.signalerAuConseil(cible, motif: motif, dans: installation)
            return nil
        }
    }

    /// Le compte peut-il retirer cette réponse ? L'auteur, le conseil, l'administration
    /// (`peutCommenter` du site, que le serveur applique à la suppression).
    func peutRetirer(_ reponse: ReponseCommunaute) -> Bool {
        guard let moi else { return false }
        return reponse.auteurId == moi.id || moi.estConseil
    }
}

/// Une phrase montrée un instant : « Vote enregistré », ou l'erreur.
struct PhraseDuGeste: Equatable, Identifiable {
    let id = UUID()
    let texte: String
    let reussi: Bool
}
