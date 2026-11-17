// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Ce que montre le choix de l'affaire (`ChoixAffaireAvis.svelte`) — pur, testé.
///
/// Deux groupes, dans cet ordre : les affaires où le prestataire intervient, puis les autres
/// (servies déjà triées). Une frappe filtre sur le numéro et le titre, tout de suite, ET
/// demande la recherche DÉTAILLÉE de la page Affaires (`GET /tickets/recherche`) : ce
/// qu'elle trouve s'ajoute, à son rang. Rien n'est recherché ici avec une seconde règle.
enum ChoixAffaires {
    /// Sans recherche, les plus récentes de chaque groupe ; au-delà, on cherche.
    static let parGroupe = 6
    static let parGroupeTrouve = 20

    struct Groupe: Hashable, Identifiable {
        let id: String
        let titre: String
        let affaires: [AffaireANoter]
    }

    /// `termeAffaire` : sans le « # » que l'écran écrit devant un numéro (« Affaire #A-0045 »).
    static func terme(_ texte: String) -> String {
        texte.replacing(/(^|\s)#+/) { $0.output.1 }.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `idAffaireDepuisLien` : un lien collé vers une affaire (`…/tickets/45`).
    static func idDepuisLien(_ texte: String) -> Int? {
        texte.firstMatch(of: /\/tickets\/(\d+)(?:[\/?#]|$)/).flatMap { Int($0.output.1) }
    }

    /// Une recherche est active dès `minimum` caractères (`RECHERCHE_MIN`), ou un lien.
    static func actif(_ recherche: String, minimum: Int) -> Bool {
        terme(recherche).count >= minimum || idDepuisLien(recherche) != nil
    }

    /// Les groupes à montrer. `trouvees` : les identifiants de la recherche détaillée, dans
    /// son ordre de pertinence — le groupe du prestataire reste devant.
    static func groupes(
        _ affaires: [AffaireANoter], recherche: String, minimum: Int, trouvees: [Int], prestataire: String
    ) -> [Groupe] {
        let actif = actif(recherche, minimum: minimum)
        let cherche = terme(recherche).lowercased()
        let lien = idDepuisLien(recherche)
        let rang = Dictionary(trouvees.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        var ordonnees = affaires
        if actif {
            ordonnees = affaires.filter { affaire in
                if let lien { return affaire.id == lien }
                return "\(affaire.numero) \(affaire.titre)".lowercased().contains(cherche) || rang[affaire.id] != nil
            }
            // Stable : à égalité, l'ordre servi.
            ordonnees = ordonnees.enumerated().sorted { x, y in
                let (cx, cy) = (x.element, y.element)
                if cx.intervient != cy.intervient { return cx.intervient }
                let (rx, ry) = (rang[cx.id] ?? -1, rang[cy.id] ?? -1)
                return rx != ry ? rx < ry : x.offset < y.offset
            }.map(\.element)
        }
        let plafond = actif ? parGroupeTrouve : parGroupe
        return [
            Groupe(
                id: "siennes", titre: TextesSaisieAvis.avec(prestataire),
                affaires: Array(ordonnees.filter(\.intervient).prefix(plafond))),
            Groupe(
                id: "autres", titre: TextesSaisieAvis.autresAffaires,
                affaires: Array(ordonnees.filter { !$0.intervient }.prefix(plafond))),
        ].filter { !$0.affaires.isEmpty }
    }

    /// L'aide sous le champ : la recherche en cours, rien de trouvé, ou l'avis général.
    static func aide(actif: Bool, enCours: Bool, vide: Bool) -> String? {
        if enCours { return TextesSaisieAvis.rechercheEnCours }
        if actif && vide { return TextesSaisieAvis.aucuneAffaire }
        return actif ? nil : TextesSaisieAvis.sansAffaire
    }
}

/// « Affaire concernée » : l'affaire retenue et « Changer », ou la recherche et les deux
/// groupes. Des sections de `Form`, posées en tête de la feuille (`FeuilleAvis`).
struct ChoixAffaireAvis: View {
    let affaires: [AffaireANoter]
    @Binding var affaire: Int?
    let prestataire: String
    /// La recherche détaillée de la page Affaires ; `nil` : le filtre local seul.
    let rechercher: ((String) async throws -> [Int])?
    @State private var recherche = ""
    @State private var trouvees: [Int] = []
    @State private var enCours = false
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    /// Le numéro, puis le titre : côte à côte, l'un sous l'autre aux tailles d'accessibilité
    /// — côte à côte, le très grand texte coupait le numéro (« A-005 »).
    private var ligne: AnyLayout {
        taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    private func numeroEtTitre(_ affaire: AffaireANoter) -> some View {
        ligne {
            Text(affaire.numero).font(.subheadline.weight(.bold)).foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: true, vertical: false)
            Text(affaire.titre).font(.subheadline).foregroundStyle(palette.text)
        }
    }

    var body: some View {
        let actif = ChoixAffaires.actif(recherche, minimum: EtatAffaires.rechercheMinimale)
        let groupes = ChoixAffaires.groupes(
            affaires, recherche: recherche, minimum: EtatAffaires.rechercheMinimale, trouvees: trouvees,
            prestataire: prestataire)
        Section(TextesSaisieAvis.affaireConcernee) {
            if let choisie = affaires.first(where: { $0.id == affaire }) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        numeroEtTitre(choisie)
                        Spacer(minLength: 8)
                        changer
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        numeroEtTitre(choisie)
                        changer
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("avis.affaire.retenue")
            } else {
                ChampRecherche(
                    texte: $recherche, indication: TextesSaisieAvis.rechercheAffaire,
                    identifiant: "avis.affaire.recherche")
                if let aide = ChoixAffaires.aide(actif: actif, enCours: enCours, vide: groupes.isEmpty) {
                    Text(aide).font(.footnote).foregroundStyle(palette.textMuted)
                }
            }
        }
        .task(id: recherche) { await chercher() }
        if affaires.first(where: { $0.id == affaire }) == nil {
            ForEach(groupes) { groupe in
                Section(groupe.titre) {
                    ForEach(groupe.affaires) { proposition($0) }
                }
            }
        }
    }

    private var changer: some View {
        Button(TextesSaisieAvis.changer) { affaire = nil }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("avis.affaire.changer")
    }

    private func proposition(_ candidate: AffaireANoter) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                affaire = candidate.id
                recherche = ""
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                numeroEtTitre(candidate)
                if !candidate.intervient && !candidate.intervenants.isEmpty {
                    Text(candidate.intervenants).font(.caption).foregroundStyle(palette.textMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Mise.cible, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("avis.affaire.\(candidate.id)")
    }

    /// La recherche détaillée, une fois la frappe finie : une frappe neuve annule la précédente.
    private func chercher() async {
        let terme = ChoixAffaires.terme(recherche)
        guard let rechercher, terme.count >= EtatAffaires.rechercheMinimale else {
            (trouvees, enCours) = ([], false)
            return
        }
        enCours = true
        do {
            try await Task.sleep(for: EtatAffaires.delaiDeFrappe)
            let lus = try await rechercher(terme)
            try Task.checkCancellation()
            (trouvees, enCours) = (lus, false)
        } catch is CancellationError {
            return
        } catch {
            // Illisible, la recherche détaillée se tait : le filtre du numéro et du titre reste.
            (trouvees, enCours) = ([], false)
        }
    }
}
