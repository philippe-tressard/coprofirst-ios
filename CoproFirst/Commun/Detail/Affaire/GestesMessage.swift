// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un geste sur SON message du fil d'une affaire (#211, coprofirst#2722) : le modifier, le
/// retirer. L'ORDRE est celui du site (`FilMessagesTicket.svelte`) : ✏️ puis 🗑️.
enum GesteMessage: String, CaseIterable, Identifiable, Sendable, GesteDeMenu {
    case modifier, supprimer

    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .modifier: "Modifier mon message"
        case .supprimer: "Supprimer mon message"
        }
    }

    var symbole: String {
        switch self {
        case .modifier: "pencil"
        case .supprimer: "trash"
        }
    }

    var destructif: Bool { self == .supprimer }

    /// Les gestes offerts sur ce message : la règle du site ET de la route
    /// (`messages._message_de_l_auteur`) — son auteur, tel que le serveur le juge
    /// (`est_auteur`), tant que l'affaire n'est pas close (`close`, servi). Le serveur refuse
    /// le reste. « Modifier » demande aussi un texte que l'app sait réécrire sans rien en
    /// perdre (`TexteDuSite.saisi(html:)`) : une mise en forme du site (gras, liste, lien) se
    /// modifie depuis le site, et ne s'efface pas en silence.
    static func offerts(pour message: MessageAffaire, dans affaire: DetailAffaire) -> [GesteMessage] {
        guard message.deMoi, !affaire.close else { return [] }
        return TexteDuSite.saisi(html: message.contenu) == nil ? [.supprimer] : allCases
    }
}

/// Les mots des gestes d'un message, ceux du site (`FilMessagesTicket.svelte`), écrits une fois.
enum TextesMessage {
    /// Le bouton « ⋯ » d'un message, pour VoiceOver.
    static let gestes = "Actions sur mon message"
    /// La question avant de retirer : le message part aussi de l'Historique (son miroir).
    static let question = "Supprimer ce message ? Il disparaît aussi de l’Historique."
    static let confirmer = "Supprimer"
    static let corrige = "Message modifié"
    static let supprime = "Message supprimé"
    /// Le titre de la feuille, et son bouton.
    static let titreCorrection = "Modifier"
    static let enregistrer = "Enregistrer"
}

/// Un geste d'un menu « ⋯ » : celui d'une entrée de l'Historique (`GesteSuite`), celui
/// d'un message (`GesteMessage`) — un seul bouton les présente (`BoutonDesGestes`).
protocol GesteDeMenu: Identifiable, Hashable {
    var rawValue: String { get }
    var libelle: String { get }
    var symbole: String { get }
    var destructif: Bool { get }
}

/// Le bouton « ⋯ » des gestes d'un élément : visible — un appui long seul serait un geste
/// caché —, il ouvre le menu du système. Le « ⋯ » des cartes de l'app (`CarteAnnonceHall`) ;
/// la cible fait 44 pt et déborde dans la marge, pour rester sur la première ligne de
/// l'élément sans l'épaissir. `prefixe` nomme ses identifiants (`<prefixe>.gestes.<id>`,
/// `<prefixe>.geste.<geste>`).
struct BoutonDesGestes<Geste: GesteDeMenu>: View {
    let gestes: [Geste]
    let prefixe: String
    let id: Int
    let libelleVocal: String
    let choisir: (Geste) -> Void
    @Environment(\.palette) private var palette
    /// La hauteur de la première ligne de l'élément : le bouton s'y aligne.
    @ScaledMetric(relativeTo: .subheadline) private var ligne: CGFloat = 20

    var body: some View {
        Menu {
            ForEach(gestes) { geste in
                Button(role: geste.destructif ? .destructive : nil) {
                    choisir(geste)
                } label: {
                    Label(geste.libelle, systemImage: geste.symbole)
                }
                .accessibilityIdentifier("\(prefixe).geste.\(geste.rawValue)")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(palette.primary)
                .frame(minWidth: Mise.cible, minHeight: Mise.cible)
                .contentShape(.rect)
                .padding(-max(0, (Mise.cible - ligne) / 2))
        }
        .accessibilityLabel(libelleVocal)
        .gesteEnLigne()
        .accessibilityIdentifier("\(prefixe).gestes.\(id)")
    }
}

/// Ce que les gestes d'un message présentent, posé par l'écran (`gestesHistorique`) avec le
/// même choix et le même avis que l'Historique : « Modifier » dans la feuille de « Répondre »
/// (`RepondreFeuille`, `corrige`), « Supprimer » après la question du site.
struct GestesDesMessages: ViewModifier {
    let affaire: DetailAffaire
    let installation: Installation
    let recharger: () -> Void
    let choix: ChoixDeSuite
    let avis: AvisDuGeste
    let fermee: () -> Void
    @Environment(Parcours.self) private var parcours

    func body(content: Content) -> some View {
        @Bindable var choix = choix
        content
            .sheet(item: $choix.messageACorriger, onDismiss: fermee) { message in
                RepondreFeuille(affaire: affaire, installation: installation, corrige: message) {
                    avis.direApresFermeture(TextesMessage.corrige)
                    choix.messageACorriger = nil
                    recharger()
                }
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                TextesMessage.question,
                isPresented: Binding(
                    get: { choix.messageASupprimer != nil }, set: { if !$0 { choix.messageASupprimer = nil } }),
                titleVisibility: .visible, presenting: choix.messageASupprimer
            ) { message in
                Button(TextesMessage.confirmer, role: .destructive) { Task { await retirer(message) } }
                    .gesteEnLigne()
                    .accessibilityIdentifier("message.confirmerSuppression")
            }
    }

    private func retirer(_ message: MessageAffaire) async {
        guard let service = parcours.service.gestesAffaire else {
            avis.dire(TextesSuite.indisponible, ton: .error)
            return
        }
        do {
            try await service.supprimerMessage(message.id, de: affaire.id, dans: installation)
            avis.dire(TextesMessage.supprime)
            recharger()
        } catch {
            avis.dire(ErreurService.depuis(error).phrase, ton: .error)
        }
    }
}
