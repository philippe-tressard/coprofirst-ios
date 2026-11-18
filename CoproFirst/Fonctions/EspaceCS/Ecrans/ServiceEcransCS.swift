// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que l'onglet « Écrans du hall » de l'Espace CS demande (#295, serveur coprofirst#2770) :
/// les gestes du CONSEIL — lister, confirmer le code qu'affiche un écran, retirer. La part de
/// l'écran lui-même (`/ecrans/appairage*`, `/ecrans/moi/*`) est celle de l'Apple TV (#218).
/// Réalisé par `ServiceAPI` (client généré) et `ServiceSimule`, dans ce dossier ; le lieu
/// d'un écran se choisit parmi les périmètres (`ServicePerimetres`).
protocol ServiceEcransCS: ServicePerimetres {
    /// GET /ecrans : les écrans appairés, avec leur dernière lecture.
    func ecrans(dans installation: Installation) async throws -> [EcranDuHall]
    /// POST /ecrans : le code court que l'écran affiche, son nom et son périmètre.
    func appairer(_ saisie: SaisieAppairage, dans installation: Installation) async throws -> EcranAppaire
    /// DELETE /ecrans/{id} : son accès cesse aussitôt.
    func retirerEcran(_ id: Int, dans installation: Installation) async throws
}

extension ContexteOnglet {
    var serviceEcrans: (any ServiceEcransCS)? { service as? any ServiceEcransCS }
}

/// Un écran, tel que le conseil le voit (`EcranLu`) — jamais son jeton.
struct EcranDuHall: Hashable, Sendable, Identifiable {
    let id: Int
    var nom: String
    var perimetre: String
    /// Le badge servi (`perimetre_libelle`) : `""` pour le périmètre par défaut, qui se tait.
    var perimetreLibelle: String
    var creeLe: Date
    /// La dernière lecture des affiches — `nil` tant qu'il n'a rien lu.
    var vuLe: Date?
    var expireLe: Date
    /// Échu : il ne lit plus rien jusqu'à un nouvel appairage.
    var echu: Bool

    var lieu: String? { LieuServi.lieu(perimetreLibelle) }
}

extension EcranDuHall {
    init(_ lu: Components.Schemas.EcranLu) {
        self.init(
            id: lu.id, nom: lu.nom, perimetre: lu.perimetre, perimetreLibelle: lu.perimetreLibelle,
            creeLe: lu.creeLe, vuLe: lu.vuLe, expireLe: lu.expireLe, echu: lu.echu)
    }
}

/// Ce que deviendra l'écran (`AppairageConfirme`).
struct EcranAppaire: Hashable, Sendable {
    let nom: String
    let perimetreLibelle: String
}

/// La saisie de « Appairer un écran » (`OngletEcrans.svelte`) : le code, le nom, UN périmètre.
struct SaisieAppairage: Hashable, Sendable {
    /// Le code tel que l'écran l'affiche (`BCDF-GHJK`) : tiret, espaces et casse libres.
    var code = ""
    var nom = ""
    var perimetres = ChoixDePerimetres(unique: true)

    /// Les huit lettres du code, comme le site les lit (`lettres`) — le serveur normalise
    /// de nouveau, et refuse ce qui ne désigne aucune demande.
    var lettres: String { String(code.uppercased().filter { $0.isASCII && $0.isUppercase }) }

    var nomSaisi: String { nom.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// La règle `complet` du site : huit lettres, un nom, un périmètre.
    var complete: Bool { lettres.count == Self.longueurCode && !nomSaisi.isEmpty && perimetres.codes.count == 1 }

    /// La longueur du code court (`appairage_ecran.LONGUEUR_CODE`), que le site attend aussi.
    static let longueurCode = 8
}
