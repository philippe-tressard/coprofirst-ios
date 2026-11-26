// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La posture de l'appareil (#119) : un iPhone pliable est plié, entrouvert ou déplié ;
/// tout autre appareil n'a pas de pli. Elle distingue l'iPhone pliable déplié, qui ouvre
/// le carnet, d'un iPad, qui garde la barre latérale : les deux sont en classe RÉGULIÈRE,
/// et l'idiome de l'appareil ne se lit jamais (#221).
///
/// Lue par `UIHingeInteraction` (UIKit, iOS 27.1) : SwiftUI n'en a pas d'équivalent, et
/// l'API dit l'état de la charnière, jamais où passe le pli — la double page se coupe au
/// milieu de la fenêtre.
enum Posture: Equatable, Sendable {
    /// Pas de charnière (iPad, iPhone, iOS antérieur à 27.1), ou un état qu'iOS ne connaît pas.
    case sansPli
    case plie
    case entrouvert
    case deplie

    /// Ouvert comme un livre, à fond ou à moitié : le carnet s'y lit.
    var ouverte: Bool { self == .deplie || self == .entrouvert }
}

// La CI compile sous Xcode 26 (SDK 26.5), où `UIHinge` n'existe pas : tout ce qui le nomme
// se compile avec Swift 6.4 (Xcode 27) seulement, et ne se teste qu'au poste (#119).
#if compiler(>=6.4)
@available(iOS 27.1, *)
extension Posture {
    /// L'état de la charnière ; `nil` : l'appareil n'en a pas.
    init(_ statut: UIHinge.Status?) {
        self =
            switch statut {
            case .closed: .plie
            case .partiallyOpen: .entrouvert
            case .fullyOpen: .deplie
            case .unknown, nil: .sansPli
            @unknown default: .sansPli
            }
    }
}
#endif

extension View {
    /// Tient `posture` à jour de la charnière de l'appareil — `.sansPli` sans elle. En
    /// Debug, `-posture deplie|entrouvert|plie` la fixe (`LancementSimule.posture`).
    func lecturePosture(_ posture: Binding<Posture>) -> some View {
        background(LecteurDePosture(posture: posture).accessibilityHidden(true))
    }
}

/// Une vue vide qui porte l'interaction de la charnière : UIKit ne la donne qu'à une vue
/// de la fenêtre, et l'annonce à chaque pli ou dépli.
private struct LecteurDePosture: UIViewRepresentable {
    @Binding var posture: Posture

    func makeUIView(context: Context) -> UIView {
        let vue = UIView()
        vue.isUserInteractionEnabled = false
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let fixee = LancementSimule.posture(arguments) {
            let tardive = LancementSimule.charniereTardive(arguments)
            Task { @MainActor in
                if tardive { try? await Task.sleep(for: .seconds(2)) }
                posture = fixee
            }
            return vue
        }
        #endif
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            let lien = $posture
            vue.addInteraction(UIHingeInteraction { _, mise in lien.wrappedValue = Posture(mise.hinge?.status) })
        }
        #endif
        return vue
    }

    func updateUIView(_ vue: UIView, context: Context) {}
}
