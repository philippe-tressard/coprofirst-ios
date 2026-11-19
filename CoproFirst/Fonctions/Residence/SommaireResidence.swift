// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Ma résidence » dans le carnet de l'iPhone pliable (#278) : le SOMMAIRE à gauche, la
/// page choisie à droite (`ListeEtFiche`, `.proportion(0.5)`, coupé au pli). Le sommaire
/// reprend les rubriques de la Fiche dans l'ordre du site (`RubriqueFiche`), puis les autres
/// onglets que ce compte ouvre (`OngletsResidence.ouverts`) : rien n'y est réservé ni ouvert
/// autrement que sur le site. Le marque-page (`MarquesPages`) rouvre la page laissée.
///
/// Ailleurs (iPhone plié, iPad, barre latérale), « Ma résidence » garde ses onglets.
enum PageDeResidence: Hashable, Sendable {
    case rubrique(RubriqueFiche)
    /// Un onglet entier : le Carnet d'entretien, le Règlement et ses questions.
    case onglet(OngletResidence)

    /// Le sommaire de ce compte : les rubriques de la Fiche, puis les autres onglets ouverts.
    static func sommaire(_ droits: DroitsOnglet, accesReglement: Bool?) -> [PageDeResidence] {
        RubriqueFiche.ouvertes(droits).map(Self.rubrique)
            + OngletsResidence.ouverts(droits, accesReglement: accesReglement)
            .compactMap { OngletResidence(rawValue: $0.id) }
            .filter { $0 != .fiche }
            .map(Self.onglet)
    }

    /// Son titre, celui de la rubrique ou de l'onglet sur le site — écrit une fois ailleurs.
    var titre: String {
        switch self {
        case .rubrique(let rubrique): rubrique.titre
        case .onglet(let onglet):
            OngletsDuSite.parPage[OngletsResidence.page]?.first { $0.id == onglet.rawValue }?.libelle ?? onglet.rawValue
        }
    }
}

extension PageDeResidence: SelectionGardable {
    var cleGardee: String {
        switch self {
        case .rubrique(let rubrique): "rubrique.\(rubrique.rawValue)"
        case .onglet(let onglet): "onglet.\(onglet.rawValue)"
        }
    }

    init?(cleGardee: String) {
        let morceaux = cleGardee.split(separator: ".", maxSplits: 1).map(String.init)
        guard morceaux.count == 2 else { return nil }
        switch morceaux[0] {
        case "rubrique": guard let rubrique = RubriqueFiche(rawValue: morceaux[1]) else { return nil }
            self = .rubrique(rubrique)
        case "onglet": guard let onglet = OngletResidence(rawValue: morceaux[1]) else { return nil }
            self = .onglet(onglet)
        default: return nil
        }
    }
}

/// Le sommaire : une rangée par page, soulignée quand sa page est ouverte à droite. Rien
/// d'ouvert (première visite, page retirée) : la première page s'ouvre, jamais « Aucune
/// sélection » en face d'un sommaire.
struct SommaireResidence: View {
    let pages: [PageDeResidence]
    @Binding var choisie: PageDeResidence?
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Section {
                ForEach(pages, id: \.self) { page in
                    LienDeFiche(valeur: page, ligneDeListe: true) {
                        Text(page.titre).frame(maxWidth: .infinity, minHeight: Mise.cible, alignment: .leading)
                    }
                    .rangeeDeListeChoisie(page, fond: palette.surface)
                    .accessibilityIdentifier("residence.sommaire.\(page.cleGardee)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .task(id: pages) {
            if choisie.map(pages.contains) != true { choisie = pages.first }
        }
    }
}

/// La page de droite : la rubrique ou l'onglet choisi, dans la pile de sa colonne. Ce
/// qu'elle ouvre (un document, une question, le syndic) s'y pousse, au-dessus d'elle.
struct PageResidence: View {
    let page: PageDeResidence
    let installation: Installation
    let service: any ServiceResidence
    let droits: DroitsOnglet
    /// Une autre page du sommaire : « Voir le règlement dans la Fiche » ouvre la rubrique du
    /// règlement de copropriété, à sa place dans le sommaire.
    let ouvrir: (PageDeResidence) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch page {
            case .rubrique(let rubrique):
                FicheView(installation: installation, service: service, droits: droits, rubriques: [rubrique])
            case .onglet(.carnet):
                CarnetView(installation: installation, service: service, droits: droits)
            case .onglet(.reglement):
                ReglementView(installation: installation, service: service, cs: droits.cs) {
                    ouvrir(.rubrique(.reglement))
                }
            case .onglet(.fiche):
                FicheView(installation: installation, service: service, droits: droits)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .navigationTitle(page.titre)
        .navigationBarTitleDisplayMode(.inline)
        // Une rubrique porte son titre en tête (`EnTeteRubrique`) : la barre ne le répète
        // pas ; il reste le nom du retour quand un document se pousse au-dessus.
        .toolbar {
            if case .rubrique = page { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
        }
        .navigationDestination(for: DestinationResidence.self) { $0.ecran(installation) }
    }
}
