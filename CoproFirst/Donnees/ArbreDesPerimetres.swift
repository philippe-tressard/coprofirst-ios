// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// L'arbre des périmètres tel que le CHOIX le parcourt (`perimetresNiveau1` de
/// `#lib/perimetres/arbre.ts`, `PerimetrePicker.svelte`) : une rangée de TÊTES — le
/// défaut, puis chaque racine ciblable et chaque enfant d'un regroupement (« Bâtiments »
/// n'est pas une cible, on choisit un bâtiment) —, puis les ESPACES d'une seule tête.
///
/// Toute la règle tient ici, sans vue : l'écran ne fait que la dessiner.
struct ArbreDesPerimetres: Sendable {
    /// Les nœuds actifs, regroupements compris : sans eux, pas de têtes.
    let noeuds: [Perimetre]
    private let parCode: [String: Perimetre]
    /// Ce qui se PROPOSE : les nœuds sélectionnables jusqu'au niveau que le serveur admet
    /// (`Perimetre.aSaisir`, #88) — l'arbre entier, lui, reste pour trouver les têtes.
    private let proposables: Set<String>

    init(_ noeuds: [Perimetre]) {
        self.noeuds = noeuds
        parCode = Dictionary(noeuds.map { ($0.code, $0) }, uniquingKeysWith: { premier, _ in premier })
        proposables = Set(Perimetre.aSaisir(noeuds).map(\.code))
    }

    var defaut: Perimetre? { noeuds.first(where: \.parDefaut) }

    /// `estRegroupement` (`teinte.ts`) : une racine qui ne se cible pas.
    private func estRegroupement(_ code: String?) -> Bool {
        guard let code, let noeud = parCode[code] else { return false }
        return noeud.parent == nil && !noeud.selectionnable
    }

    /// Les têtes, hors le défaut (il a sa propre pastille).
    var tetes: [Perimetre] {
        noeuds.filter { noeud in
            proposables.contains(noeud.code) && !noeud.parDefaut
                && (noeud.parent == nil || estRegroupement(noeud.parent))
        }
    }

    /// Les espaces ciblables d'une tête : ses enfants directs, comme le site.
    func espaces(de tete: String) -> [Perimetre] {
        noeuds.filter { $0.parent == tete && proposables.contains($0.code) }
    }

    /// La tête dont dépend `code` (elle-même si c'en est une), s'il y en a une.
    func tete(de code: String) -> String? {
        let codesDesTetes = Set(tetes.map(\.code))
        var courant = parCode[code]
        var vus = Set<String>()
        while let noeud = courant, vus.insert(noeud.code).inserted {
            if codesDesTetes.contains(noeud.code) { return noeud.code }
            courant = noeud.parent.flatMap { parCode[$0] }
        }
        return nil
    }

    func noeud(_ code: String) -> Perimetre? { parCode[code] }
}

/// Une sélection de périmètres et la tête dont la rangée d'espaces est ouverte — la règle
/// `basculer()` du site, en cinq lignes, aucune ne dépendant de l'ordre des clics :
///
/// | Toucher | Sélection | Rangée |
/// |---|---|---|
/// | une tête qui a des espaces retenus | inchangée | s'ouvre |
/// | une tête sans espace retenu, non retenue | elle est ajoutée | s'ouvre |
/// | une tête retenue | elle est retirée | se ferme |
/// | un espace | il est basculé ; sa tête entière est retirée | reste ouverte |
/// | le défaut | tout est vidé | se ferme |
///
/// « Tout le bâtiment 3 » et « le toit du bâtiment 3 » sont deux cibles exclusives.
struct ChoixDePerimetres: Hashable, Sendable {
    /// Les codes retenus ; vide ou le seul défaut : « toute la copropriété ».
    var codes: Set<String> = []
    /// La tête touchée en dernier (`parentTouche`).
    private(set) var touchee: String?

    func estDefaut(_ arbre: ArbreDesPerimetres) -> Bool {
        codes.isEmpty || codes == Set([arbre.defaut?.code].compactMap(\.self))
    }

    /// La tête dont les espaces se montrent : la dernière touchée si elle en a, sinon celle
    /// d'une valeur retenue.
    func ouverte(_ arbre: ArbreDesPerimetres) -> String? {
        if let touchee, !arbre.espaces(de: touchee).isEmpty { return touchee }
        return codes.sorted().lazy.compactMap { arbre.tete(de: $0) }.first { !arbre.espaces(de: $0).isEmpty }
    }

    /// Les espaces retenus sous une tête — le résumé de sa pastille.
    func espacesRetenus(de tete: String, _ arbre: ArbreDesPerimetres) -> [Perimetre] {
        arbre.espaces(de: tete).filter { codes.contains($0.code) }
    }

    mutating func choisirDefaut(_ arbre: ArbreDesPerimetres) {
        touchee = nil
        codes = Set([arbre.defaut?.code].compactMap(\.self))
    }

    mutating func basculer(_ code: String, _ arbre: ArbreDesPerimetres) {
        let racine = arbre.tete(de: code)
        let estTete = racine == code
        var retenus = codes
        if let defaut = arbre.defaut?.code { retenus.remove(defaut) }
        let espaces = retenus.filter { $0 != code && arbre.tete(de: $0) == code }

        if estTete, !espaces.isEmpty, !retenus.contains(code) {
            touchee = code  // 1. on vient REVOIR ses espaces : rien ne bouge
            return
        }
        if retenus.contains(code) {
            retenus.remove(code)  // 2 et 3. retirer ; retirer une tête referme sa rangée
            if estTete { touchee = nil }
        } else {
            touchee = racine
            if !estTete, let racine { retenus.remove(racine) }  // 4. un espace remplace sa tête
            retenus.insert(code)
        }
        codes = retenus.isEmpty ? Set([arbre.defaut?.code].compactMap(\.self)) : retenus
    }
}
