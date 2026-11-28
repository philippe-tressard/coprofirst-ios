// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Observation

/// La diffusion du Fil en tuiles (#429) : la dernière lecture, la carte du carrousel en tête,
/// la tuile mise en avant — et le rythme (`CadenceDuHall`) qui les fait avancer.
///
/// Le réseau manque : la dernière lecture reste à l'écran. Le jeton est retiré ou échu (401) :
/// `retire` passe à vrai, et l'écran revient à l'appairage — comme `DiffusionTV`.
@MainActor @Observable
final class DiffusionDuFil {
    private(set) var fil: FilDuHall = .vide
    /// Une première lecture a répondu : avant, l'écran attend ; après, un Fil vide se dit.
    private(set) var lue = false
    private(set) var retire = false
    /// La carte du carrousel en tête, par son rang dans le reste du Fil.
    private(set) var premiere = 0
    /// La tuile agrandie, par son identifiant (`TuileDuHall.id`).
    private(set) var enAvant: String?

    let residence: Installation
    private let jeton: JetonMasque
    private let service: any ServiceFilDuHall
    private let attendre: @Sendable (Duration) async throws -> Void
    /// Une tuile tenue agrandie, sans cadence (Debug : `-mise-en-avant`, pour les captures).
    private let tenue: String?
    private var cadence = CadenceDuHall()
    /// Le rang de la prochaine tuile à mettre en avant, dans `grille.tour`.
    private var tour = 0
    private var photos: [SourcePhoto: [Data]] = [:]

    init(
        residence: Installation, jeton: JetonMasque, service: any ServiceFilDuHall, tenue: String? = nil,
        attendre: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.residence = residence
        self.jeton = jeton
        self.service = service
        self.tenue = tenue
        self.attendre = attendre
    }

    var grille: GrilleDuHall { GrilleDuHall(fil) }

    /// Les cartes du carrousel à l'écran.
    var carrousel: [ElementDuHall] { grille.carrousel(depuis: premiere, places: MiseTV.placesCarrousel) }

    /// La tuile agrandie, telle qu'elle est à l'écran ; `nil` si elle n'y est plus.
    var tuileEnAvant: TuileDuHall? {
        guard let enAvant else { return nil }
        let grille = grille
        return (grille.haut + grille.milieu + carrousel.map(TuileDuHall.carte)).first { $0.id == enAvant }
    }

    /// Lit, puis suit la cadence jusqu'à l'arrêt de la tâche ou au retrait de l'écran.
    func diffuser() async {
        await relire()
        if let tenue { enAvant = tenue }
        while !retire {
            var (geste, attente) = cadence.prochain()
            // Une tuile tenue ne s'ouvre ni ne se ferme : seule la lecture continue.
            while tenue != nil, geste != .relire { (geste, attente) = cadence.prochain() }
            do { try await attendre(attente) } catch { return }
            switch geste {
            case .relire: await relire()
            case .ouvrir: ouvrir()
            case .fermer: enAvant = nil
            case .cran: cran()
            }
        }
    }

    /// Le Fil relu remplace l'ancien ; la carte en tête du carrousel garde sa place si elle y est
    /// encore. La tuile agrandie se referme si elle n'est plus servie.
    func relire() async {
        do {
            let lu = try await service.fil(residence.adresse, jeton: jeton)
            let enTete = carrousel.first?.id
            fil = lu
            premiere = grille.reste.firstIndex { $0.id == enTete } ?? 0
            if tuileEnAvant == nil, tenue == nil { enAvant = nil }
            photos = photos.filter { source, _ in sert(source) }
            lue = true
        } catch ErreurService.sessionExpiree {
            retire = true
        } catch {
            // Hors ligne ou serveur muet : la dernière lecture reste, la prochaine dira.
        }
    }

    /// Une carte de plus : la première sort à gauche, la suivante entre à droite.
    func cran() {
        guard grille.defile(places: MiseTV.placesCarrousel) else { return }
        premiere = (premiere + 1) % grille.reste.count
    }

    /// La tuile suivante du tour s'agrandit ; sans tuile, rien ne s'ouvre.
    func ouvrir() {
        let tuiles = grille.tour(premiere: premiere, places: MiseTV.placesCarrousel)
        guard !tuiles.isEmpty else { return }
        enAvant = tuiles[tour % tuiles.count].id
        tour += 1
        cadence.ouverte()
    }

    /// Les photos d'un élément, lues une fois avec le jeton. Une photo illisible est sautée, et
    /// l'élément se relira à son prochain passage.
    func photosDe(_ source: SourcePhoto, nombre: Int) async -> [Data] {
        if let connues = photos[source] { return connues }
        var lues: [Data] = []
        var complete = true
        for rang in 0..<nombre {
            do {
                lues.append(try await service.photo(source, rang: rang, residence.adresse, jeton: jeton))
            } catch ErreurService.sessionExpiree {
                retire = true
                return []
            } catch {
                complete = false
            }
        }
        if complete { photos[source] = lues }
        return lues
    }

    /// L'adresse que porte le QR code d'un élément : son chemin servi, sur le site de la résidence
    /// — un lien universel, que l'app ouvre ; le site sinon, après connexion.
    func adresse(_ lien: String) -> URL? { URL(string: lien, relativeTo: residence.adresse)?.absoluteURL }

    private func sert(_ source: SourcePhoto) -> Bool {
        switch source {
        case .element(let id): fil.elements.contains { $0.id == id }
        case .annonce(let id): fil.communaute.annonce?.id == id
        }
    }
}
