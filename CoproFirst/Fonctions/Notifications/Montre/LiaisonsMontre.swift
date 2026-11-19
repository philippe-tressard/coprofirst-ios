// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// La liaison de l'iPhone à l'Apple Watch (#226), comme celle du téléphone à la montre Wear OS
/// (CoproFirst-Android #207) : à l'OUVERTURE d'une résidence, si une montre jumelée porte
/// l'app, l'iPhone lui obtient un jeton de montre (renouvelé s'il en a déjà un, émis sinon) et
/// le lui transmet avec l'adresse et le nom de la résidence ; à la FERMETURE, il le retire du
/// serveur et efface la montre.
///
/// Un abonné de la session (`AbonneSession`) ; la résidence se reconnaît à son adresse. Seul
/// l'identifiant de la montre se garde sur l'iPhone (`MontresGardees`), jamais le jeton : il
/// ne fait que passer. Liaison éteinte (`LiaisonMontre.active`), rien ne se fait. Un échec ne
/// se dit pas et ne se journalise pas : la montre attend l'ouverture suivante.
@MainActor
final class LiaisonsMontre: AbonneSession {
    private let fabriqueCanal: @MainActor () -> any CanalMontre
    /// Créé au premier geste seulement : liaison éteinte, WatchConnectivity ne s'active pas.
    private lazy var canal: any CanalMontre = fabriqueCanal()
    private let service: any ServiceMontres
    let gardees: MontresGardees
    private let active: Bool

    init(
        canal: @escaping @MainActor () -> any CanalMontre, service: any ServiceMontres,
        gardees: MontresGardees = MontresGardees(), active: Bool = LiaisonMontre.active
    ) {
        fabriqueCanal = canal
        self.service = service
        self.gardees = gardees
        self.active = active
    }

    func residenceOuverte(_ installation: Installation) async {
        guard active, await canal.montreJointe() else { return }
        do {
            var jeton = try await renouvele(installation)
            if jeton == nil { jeton = try await service.emettreMontre(dans: installation) }
            guard let jeton else { return }
            gardees.garder(jeton.id, pour: installation)
            await canal.transmettre(
                .liaison(
                    adresse: installation.adresse, residence: installation.nom, jeton: jeton.jeton,
                    expireLe: jeton.expireLe))
        } catch {
            // La montre garde ce qu'elle avait, ou attend : l'ouverture suivante réessaiera.
        }
    }

    /// Appelée AVANT la déconnexion (le DELETE part encore authentifié). Sur une session
    /// refusée, le retrait échoue : la montre s'efface quand même, et le serveur fera tomber
    /// le jeton (empreinte du compte, échéance).
    func residenceFermee(_ installation: Installation) async {
        guard active, let id = gardees.id(pour: installation) else { return }
        gardees.oublier(installation)
        try? await service.retirerMontre(id, dans: installation)
        await canal.transmettre(.effacement(adresse: installation.adresse))
    }

    /// Un identifiant gardé que le serveur ne connaît plus (retiré, échu, purgé) : `nil`, et
    /// un jeton neuf s'émet. Tout autre échec remonte.
    private func renouvele(_ installation: Installation) async throws -> JetonDeMontre? {
        guard let id = gardees.id(pour: installation) else { return nil }
        do {
            return try await service.renouvelerMontre(id, dans: installation)
        } catch ErreurService.introuvable {
            gardees.oublier(installation)
            return nil
        }
    }
}

/// L'identifiant de la montre reliée, par résidence (son hôte) — jamais le jeton.
struct MontresGardees: @unchecked Sendable {
    private let reglages: UserDefaults

    init(reglages: UserDefaults = .standard) {
        self.reglages = reglages
    }

    func id(pour installation: Installation) -> Int? {
        reglages.object(forKey: Self.cle(installation)) as? Int
    }

    func garder(_ id: Int, pour installation: Installation) {
        reglages.set(id, forKey: Self.cle(installation))
    }

    func oublier(_ installation: Installation) {
        reglages.removeObject(forKey: Self.cle(installation))
    }

    private static func cle(_ installation: Installation) -> String { "montre:\(installation.hote)" }
}
