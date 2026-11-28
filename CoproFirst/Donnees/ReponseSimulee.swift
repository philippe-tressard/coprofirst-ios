// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

#if DEBUG
/// Une réponse de l'API simulée et le schéma de sa route (`components/schemas`), que
/// `scripts/verifier-fixtures.py` confronte au contrat. Chaque `Fixtures*.swift` la déclare
/// sous le nom `Reponse` ; l'iPhone et l'écran de hall (#429) la compilent.
struct ReponseSimulee: Sendable {
    let nom: String
    let schema: String
    let json: String
}
#endif
