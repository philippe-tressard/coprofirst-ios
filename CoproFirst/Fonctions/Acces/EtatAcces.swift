// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'état de « Mes lots & accès » : ce que la page charge une fois et que ses
/// onglets partagent — les lots du compte, le bail du locataire, les baux gérés.
@MainActor
@Observable
final class EtatAcces {
    enum Phase: Equatable {
        case chargement
        case pret
        /// Non vide = on n'a PAS pu regarder — distinct de « aucun lot » (#816 du site).
        case erreur(String)
    }

    var phase = Phase.chargement
    var lots: [LotDuCompte] = []
    var bail: BailDuLocataire?
    var baux: [Bail] = []
    var droits = DroitsAcces(nil)
    /// Une phrase brève après un geste (le « toast » du site).
    var avis: String?

    var bauxActifs: [Bail] { baux.filter(\.enCours) }
    var bauxTermines: [Bail] { baux.filter(\.termine) }

    /// Les onglets du site, « Gestion locative » masqué à qui ne la gère pas
    /// (`masques` de `BarreOnglets`, page `mon-lot`).
    var onglets: [(id: String, libelle: String)] {
        LibellesAcces.onglets.filter { $0.id != "location" || droits.voitLocation(bauxTermines: bauxTermines.count) }
    }

    func charger(_ installation: Installation, avec service: any ServiceAcces, droits: DroitsAcces) async {
        self.droits = droits
        if lots.isEmpty { phase = .chargement }
        async let lus = service.mesLots(installation)
        // Le bail et les baux ne bloquent pas l'écran : le site les toaste à part.
        if droits.locataire { bail = try? await service.monBail(installation) }
        if let lecture = droits.baux {
            baux = (try? await service.baux(installation, tous: lecture == .tous)) ?? baux
        }
        do {
            lots = try await lus
            phase = .pret
        } catch {
            phase = .erreur(RefusDuServeur.phrase(error))
        }
    }

    func annoncer(_ texte: String) { avis = texte }
}
