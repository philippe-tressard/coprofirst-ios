// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.103.0 (commit 1d1ed30cb3fa2128692ce2be0fe34ded87d72c69), openapi.json de la release (info.version).

/// Le contrat du PLANCHER : celui sur lequel l'app se génère (`scripts/generateurs/_plancher.py`).
extension VersionContrat {
    /// Une installation qui sert un contrat plus ancien ne se décode plus : la découverte
    /// le dit (« cette résidence doit être mise à jour »), au lieu d'une erreur muette.
    static let plancher = VersionContrat(2, 0, 0)
}
