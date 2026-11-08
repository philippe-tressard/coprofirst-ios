// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Annuaire CS & Syndic » (onglet `annuaire`, `OngletAnnuaireCS.svelte`) : le conseil
/// syndical puis le syndic, chacun avec son en-tête et ses fiches — à corriger, ajouter,
/// retirer, et pour le syndic à ordonner. Les cartes sont celles de l'Annuaire des
/// résidents (`CarteContact`) : un même objet, un même rendu.
struct OngletAnnuaireCS: OngletEspaceCS {
    let contexte: ContexteOngletCS
    @State private var etat = EtatAnnuaireCS()
    @State private var feuille: FeuilleAnnuaireCS?
    @State private var aRetirer: FeuilleAnnuaireCS?
    @State private var echec: String?

    init(contexte: ContexteOngletCS) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceAnnuaire {
            VStack(alignment: .leading, spacing: 28) {
                if let echec { MessageErreur(texte: echec).transition(.opacity) }
                SectionConseilCS(lecture: etat.conseil, installation: contexte.installation, ouvrir: ouvrir)
                SectionSyndicCS(
                    lecture: etat.syndic, installation: contexte.installation, ouvrir: ouvrir,
                    deplacer: { rang, sens in
                        if let syndic = etat.syndic.valeur {
                            let deplace = syndic.deplace(rang, de: sens)
                            geste(TextesAnnuaireCS.syndicEnregistre) {
                                try await etat.enregistrer(deplace, service, contexte.installation)
                            }
                        }
                    })
            }
            .task(id: contexte.actualisation) { await etat.charger(service, contexte.installation) }
            .sheet(item: $feuille, onDismiss: { contexte.avis.feuilleFermee() }, content: { quoi in
                feuilleDe(quoi, service)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            })
            .confirmationDialog(
                TextesAnnuaireCS.retirerTitre, isPresented: presente($aRetirer), titleVisibility: .visible,
                presenting: aRetirer
            ) { quoi in
                Button(TextesEspaceCS.supprimer, role: .destructive) { retirer(quoi, service) }
            } message: { _ in
                Text(TextesAnnuaireCS.retirerMessage)
            }
        } else {
            MessageErreur(texte: TextesEspaceCS.serviceAbsent)
        }
    }

    private func ouvrir(_ quoi: FeuilleAnnuaireCS, retirer: Bool) {
        if retirer { aRetirer = quoi } else { feuille = quoi }
    }

    @ViewBuilder
    private func feuilleDe(_ quoi: FeuilleAnnuaireCS, _ service: any ServiceAnnuaireCS) -> some View {
        let installation = contexte.installation
        switch quoi {
        case .enteteConseil:
            if let conseil = etat.conseil.valeur {
                FeuilleEnteteConseil(conseil: conseil) { nouveau in
                    try await etat.enregistrer(nouveau, service, installation)
                    annoncerApresFermeture(TextesAnnuaireCS.conseilEnregistre)
                }
            }
        case .membreConseil(let rang):
            if let conseil = etat.conseil.valeur {
                FeuilleMembreConseil(
                    membre: rang.map { conseil.membres[$0] } ?? MembreConseil(),
                    rapprocher: { try await service.rapprochement(nom: $0, localiser: true, dans: installation) },
                    enregistrer: { membre in
                        var nouveau = conseil
                        if let rang { nouveau.membres[rang] = membre } else { nouveau.membres.append(membre) }
                        try await etat.enregistrer(nouveau, service, installation)
                        annoncerApresFermeture(TextesAnnuaireCS.enregistre(membre.prenom, membre.nom))
                    })
            }
        case .enteteSyndic:
            if let syndic = etat.syndic.valeur {
                FeuilleEnteteSyndic(syndic: syndic) { nouveau in
                    try await etat.enregistrer(nouveau, service, installation)
                    annoncerApresFermeture(TextesAnnuaireCS.syndicEnregistre)
                }
            }
        case .membreSyndic(let rang):
            if let syndic = etat.syndic.valeur {
                FeuilleMembreSyndic(
                    membre: rang.map { syndic.membres[$0] } ?? MembreSyndic(),
                    rapprocher: { try await service.rapprochement(nom: $0, localiser: false, dans: installation) },
                    enregistrer: { membre in
                        var nouveau = syndic
                        if let rang { nouveau.membres[rang] = membre } else { nouveau.membres.append(membre) }
                        try await etat.enregistrer(nouveau, service, installation)
                        annoncerApresFermeture(TextesAnnuaireCS.enregistre(membre.prenom, membre.nom))
                    })
            }
        }
    }

    private func retirer(_ quoi: FeuilleAnnuaireCS, _ service: any ServiceAnnuaireCS) {
        let installation = contexte.installation
        switch quoi {
        case .membreConseil(let rang?):
            guard var conseil = etat.conseil.valeur, conseil.membres.indices.contains(rang) else { return }
            conseil.membres.remove(at: rang)
            geste(TextesAnnuaireCS.conseilEnregistre) { try await etat.enregistrer(conseil, service, installation) }
        case .membreSyndic(let rang?):
            guard var syndic = etat.syndic.valeur, syndic.membres.indices.contains(rang) else { return }
            syndic.membres.remove(at: rang)
            geste(TextesAnnuaireCS.syndicEnregistre) { try await etat.enregistrer(syndic, service, installation) }
        default:
            return
        }
    }

    private func geste(_ annonce: String, _ faire: @escaping () async throws -> Void) {
        Task {
            do {
                try await faire()
                annoncer(annonce)
            } catch {
                withAnimation(.snappy) { echec = ErreurService.depuis(error).phrase }
            }
        }
    }

    private func annoncer(_ annonce: String) {
        withAnimation(.snappy) { echec = nil }
        contexte.avis.dire(annonce)
    }

    /// Depuis une feuille : la phrase attend que la feuille soit fermée.
    private func annoncerApresFermeture(_ annonce: String) {
        withAnimation(.snappy) { echec = nil }
        contexte.avis.direApresFermeture(annonce)
    }

    private func presente<T>(_ element: Binding<T?>) -> Binding<Bool> {
        Binding { element.wrappedValue != nil } set: { if !$0 { element.wrappedValue = nil } }
    }
}

/// Ce que l'onglet ouvre : un en-tête, une fiche (son rang ; `nil` pour une neuve).
enum FeuilleAnnuaireCS: Identifiable, Hashable {
    case enteteConseil, membreConseil(Int?), enteteSyndic, membreSyndic(Int?)

    var id: String {
        switch self {
        case .enteteConseil: "entete-conseil"
        case .membreConseil(let rang): "conseil-\(rang.map(String.init) ?? "neuf")"
        case .enteteSyndic: "entete-syndic"
        case .membreSyndic(let rang): "syndic-\(rang.map(String.init) ?? "neuf")"
        }
    }
}
