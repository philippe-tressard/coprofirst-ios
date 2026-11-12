// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Le LIEU d'un contenu, tel que le serveur le sert (`perimetre_libelle`, contrat 1.24.0,
/// coprofirst#2633, #130) : « Bât. 2 › Toit », `""` pour le périmètre par défaut, que le
/// badge tait (`BadgePerimetre` du site).
///
/// 🔴 Le SEUL endroit où l'app se replie quand une installation antérieure ne le sert
/// pas. La règle du serveur (`utils/perimetres/libelles.py` : chemins « › », groupes
/// « · » et « — », nœuds d'organisation tus) ne se recopie pas ; le repli d'un accès
/// garde le rendu d'avant, et disparaît quand le plancher atteint 1.24.0
/// (`scripts/verifier-regles-servies.py` le dispense ici, et nulle part ailleurs).
enum LieuServi {
    /// Le lieu à montrer : servi, il fait foi (`""` → rien) ; non servi, le `repli`.
    static func lieu(_ servi: String?, repli: String? = nil) -> String? {
        guard let servi else { return repli.flatMap { $0.isEmpty ? nil : $0 } }
        return servi.isEmpty ? nil : servi
    }

    /// Un accès d'une installation antérieure au contrat 1.24.0 : ses codes, nommés par
    /// l'arbre servi comme avant #130 — le défaut se tait, un code inconnu (nœud retiré,
    /// arbre pas encore lu) ne s'affiche jamais brut (« bat:2 »).
    static func lieu(_ servi: String?, codes: [String], arbre: [Perimetre]) -> String? {
        lieu(servi, repli: libelles(codes, parmi: arbre).joined(separator: ", "))
    }

    /// Le repli au plancher : les libellés de `codes` (`perimetre_cible`), lus dans l'arbre.
    static func libelles(_ codes: [String], parmi perimetres: [Perimetre]) -> [String] {
        codes.compactMap { code in
            perimetres.first { $0.code == code }.flatMap { $0.parDefaut ? nil : $0.libelle }
        }
    }
}
