// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import LocalAuthentication

/// Ce que l'appareil offre pour rouvrir une session gardée : le nom à dire au bouton
/// et son pictogramme. Sans biométrie inscrite, le Trousseau garde le jeton sous la
/// seule protection de l'appareil (`Trousseau.enregistrer`) : on dit « Ouvrir ».
struct Biometrie: Equatable {
    let nom: String?
    let symbole: String

    /// La biométrie qui rouvre VRAIMENT : celle de l'appareil, et inscrite.
    static var actuelle: Biometrie {
        let contexte = LAContext()
        guard contexte.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return aucune
        }
        return pour(contexte.biometryType)
    }

    /// La biométrie que l'appareil SAIT faire, inscrite ou non : pour nommer ce qu'on lui
    /// propose ou ce qu'il faudrait configurer — Touch ID sur un iPad Air ou mini, jamais
    /// « Face ID » d'office (#223). Le type n'est connu qu'après `canEvaluatePolicy`.
    static var materiel: Biometrie {
        let contexte = LAContext()
        _ = contexte.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return pour(contexte.biometryType)
    }

    static func pour(_ type: LABiometryType) -> Biometrie {
        switch type {
        case .faceID: Biometrie(nom: "Face ID", symbole: "faceid")
        case .touchID: Biometrie(nom: "Touch ID", symbole: "touchid")
        case .opticID: Biometrie(nom: "Optic ID", symbole: "opticid")
        default: aucune
        }
    }

    private static let aucune = Biometrie(nom: nil, symbole: "lock.open.fill")

    /// Le libellé du bouton : « Ouvrir avec Face ID », ou « Ouvrir mon espace ».
    var ouvrir: String { nom.map { "Ouvrir avec \($0)" } ?? "Ouvrir mon espace" }
}
