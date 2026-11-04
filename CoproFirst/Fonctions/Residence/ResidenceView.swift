// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Ma résidence » : la Fiche, le Carnet d'entretien et le Règlement — ces deux
/// derniers réservés aux propriétaires et au conseil syndical, comme sur le site.
struct ResidenceView: View {
    let installation: Installation
    let titre: String
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille
    @State private var onglet = OngletResidence.fiche.rawValue
    @State private var accesReglement: Bool?

    private var droits: DroitsOnglet { DroitsOnglet(profil: parcours.ouverteAJour?.profil) }
    private var ouverts: [OngletDuSite] { OngletsResidence.ouverts(droits, accesReglement: accesReglement) }

    var body: some View {
        Group {
            if let service = parcours.service.residence {
                switch OngletResidence(rawValue: onglet) ?? .fiche {
                case .fiche: FicheView(installation: installation, service: service, droits: droits)
                case .carnet: CarnetView(installation: installation, service: service, droits: droits)
                case .reglement:
                    ReglementView(installation: installation, service: service, cs: droits.cs) {
                        onglet = OngletResidence.fiche.rawValue
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .navigationTitle(titre)
        .titreDeMenu()
        .barreDuHaut {
            VStack(spacing: 0) {
                if !reseau.enLigne { BandeauHorsLigne() }
                if ouverts.count > 1 { choixOnglet }
            }
        }
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        .navigationDestination(for: DestinationResidence.self) { destination in
            destination.ecran(installation)
        }
        .onChange(of: ouverts) { _, ouverts in
            // Un onglet qui se ferme (rôle, accès retiré) ramène sur la Fiche — `BarreOnglets`.
            if !ouverts.contains(where: { $0.id == onglet }) { onglet = OngletResidence.fiche.rawValue }
        }
        .task {
            await parcours.rafraichirProfil()
            guard droits.proprioOuCS, let service = parcours.service.residence else { return }
            // Une réponse en échec ne masque rien : l'onglet ouvert dira l'erreur.
            accesReglement = (try? await service.accesReglement(installation)) ?? true
        }
    }

    /// Les onglets : un segment, qui devient un menu aux très grandes tailles de texte
    /// (« Carnet d'entretien » ne tiendrait plus dans un tiers de largeur).
    @ViewBuilder
    private var choixOnglet: some View {
        let choix = Picker("Onglet", selection: $onglet) {
            ForEach(ouverts) { Text($0.libelle).tag($0.id) }
        }
        Group {
            if taille.isAccessibilitySize {
                choix.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                choix.pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, Mise.marge)
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: onglet)
        .accessibilityIdentifier("residence.onglets")
    }
}

private extension View {
    /// Une barre posée sous le titre : le contenu défile dessous, avec l'effet de bord
    /// du système (iOS 26) ; avant, un matériau qui s'arrête à la barre de navigation
    /// — sans quoi il recouvrirait le grand titre.
    @ViewBuilder
    func barreDuHaut(@ViewBuilder _ contenu: () -> some View) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0, content: contenu)
        } else {
            safeAreaInset(edge: .top, spacing: 0) { contenu().background(.bar, ignoresSafeAreaEdges: []) }
        }
    }
}

/// Ce qu'un écran de la résidence pousse dans la pile de son onglet.
enum DestinationResidence: Hashable {
    case document(id: Int, nom: String, titre: String)
    case affaire(Int)
    case question(QuestionReglement)
    /// L'annuaire, ouvert sur la section du syndic (« Syndic » de la Fiche → ici).
    case syndic

    /// Un document de la résidence, ouvert dans l'aperçu du système.
    static func document(_ document: DocumentResidence) -> Self {
        .document(id: document.id, nom: document.fichier, titre: document.titre)
    }

    @MainActor @ViewBuilder
    func ecran(_ installation: Installation) -> some View {
        switch self {
        case .document(let id, let nom, let titre):
            DocumentView(id: id, nom: nom, titre: titre, installation: installation)
        case .affaire(let id):
            DetailAffaireView(id: id, installation: installation)
        case .question(let question):
            QuestionReglementView(question: question, installation: installation)
        case .syndic:
            AnnuaireView(installation: installation, titre: TextesAnnuaire.titre, ancre: .syndic)
        }
    }
}

extension ResidenceView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre)
    }
}
