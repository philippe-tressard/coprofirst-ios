// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import LocalAuthentication

/// Ce que l'appareil offre pour rouvrir une session gardée : le nom à dire au bouton
/// et son pictogramme. Sans biométrie inscrite, le Trousseau garde le jeton sous la
/// seule protection de l'appareil (`Trousseau.enregistrer`) : on dit « Ouvrir ».
struct Biometrie: Equatable {
    let nom: String?
    let symbole: String

    static var actuelle: Biometrie {
        let contexte = LAContext()
        guard contexte.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return Biometrie(nom: nil, symbole: "lock.open.fill")
        }
        switch contexte.biometryType {
        case .faceID: return Biometrie(nom: "Face ID", symbole: "faceid")
        case .touchID: return Biometrie(nom: "Touch ID", symbole: "touchid")
        case .opticID: return Biometrie(nom: "Optic ID", symbole: "opticid")
        default: return Biometrie(nom: nil, symbole: "lock.open.fill")
        }
    }

    /// Le libellé du bouton : « Ouvrir avec Face ID », ou « Ouvrir mon espace ».
    var ouvrir: String { nom.map { "Ouvrir avec \($0)" } ?? "Ouvrir mon espace" }
}
