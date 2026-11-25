// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation
import Observation

/// La diffusion de l'écran de hall (#218, lot 3) : les affiches de SON périmètre, que le
/// serveur choisit (`ecran_affiches` : non archivées, le lieu couvert, une liste blanche de
/// champs), l'une après l'autre, relues toutes les `RythmeTV.relecture`.
///
/// Le réseau manque : la dernière liste reste à l'écran. Le jeton est retiré ou échu (401) :
/// `retire` passe à vrai, et l'écran revient à l'appairage.
@MainActor @Observable
final class DiffusionTV {
    private(set) var affiches: [AfficheHall] = []
    /// L'affiche à l'écran, par son rang dans `affiches`.
    private(set) var rang = 0
    /// Une première lecture a répondu : avant, l'écran attend ; après, une liste vide se dit.
    private(set) var lue = false
    /// Le serveur ne reconnaît plus ce jeton : l'écran a été retiré, ou n'a rien lu depuis
    /// trente jours.
    private(set) var retire = false

    let residence: Installation
    private let jeton: JetonMasque
    private let service: any ServiceEcranTV
    private let attendre: @Sendable (Duration) async throws -> Void
    private var images: [Int: [Data]] = [:]

    init(
        residence: Installation, jeton: JetonMasque, service: any ServiceEcranTV,
        attendre: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.residence = residence
        self.jeton = jeton
        self.service = service
        self.attendre = attendre
    }

    var affiche: AfficheHall? { affiches.indices.contains(rang) ? affiches[rang] : nil }

    /// Lit, puis fait défiler et relit, jusqu'à l'arrêt de la tâche ou au retrait de l'écran.
    func diffuser() async {
        let parRelecture = max(1, Int(RythmeTV.relecture / RythmeTV.parAffiche))
        var tours = 0
        while !retire {
            if tours % parRelecture == 0 { await relire() }
            guard !retire else { return }
            do { try await attendre(RythmeTV.parAffiche) } catch { return }
            suivante()
            tours += 1
        }
    }

    /// GET /ecrans/moi/affiches : la liste remplace l'ancienne ; l'affiche à l'écran garde sa
    /// place si elle y est encore.
    func relire() async {
        do {
            let lues = try await service.affiches(residence.adresse, jeton: jeton)
            let courante = affiche?.id
            affiches = lues
            rang = lues.firstIndex { $0.id == courante } ?? 0
            images = images.filter { id, _ in lues.contains { $0.id == id } }
            lue = true
        } catch ErreurService.sessionExpiree {
            retire = true
        } catch {
            // Hors ligne ou serveur muet : la dernière liste reste, la prochaine relecture dira.
        }
    }

    func suivante() {
        guard !affiches.isEmpty else { return }
        rang = (rang + 1) % affiches.count
    }

    /// Les images d'une affiche, lues une fois avec le jeton. Une image illisible est sautée,
    /// et l'affiche se relira à son prochain passage.
    func imagesDe(_ affiche: AfficheHall) async -> [Data] {
        if let connues = images[affiche.id] { return connues }
        var lues: [Data] = []
        var complete = true
        for rang in 0..<affiche.images {
            do {
                lues.append(try await service.image(affiche.id, rang: rang, residence.adresse, jeton: jeton))
            } catch ErreurService.sessionExpiree {
                retire = true
                return []
            } catch {
                complete = false
            }
        }
        if complete { images[affiche.id] = lues }
        return lues
    }
}
