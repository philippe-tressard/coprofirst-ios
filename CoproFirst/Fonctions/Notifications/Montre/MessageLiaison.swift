// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Le drapeau de la liaison iPhone ↔ Apple Watch (#226) — UN drapeau pour les deux côtés :
/// éteint, l'iPhone ne demande ni ne transmet rien, la montre n'ouvre rien et dit de la
/// relier par l'iPhone. Comme `LiaisonMontre.ACTIF` de CoproFirst-Android (#207).
///
/// Le lot 2 de #226 la construit entière : le plancher sert les routes `/montres` (contrat
/// 2.4.0, coprofirst#2771), et le manifeste comme la fiche de confidentialité disent ce que la
/// montre reçoit et lit (`scripts/verifier-confidentialite.py`). Elle reste ÉTEINTE : Philippe a
/// reporté l'allumage côté Wear OS (#207, 18/11/2026 : « le wear n'est pas prioritaire ») ; les
/// deux s'allument ensemble, sur son geste. Les tests l'allument par `active:`.
enum LiaisonMontre {
    static let active = false
}

/// Ce que l'iPhone transmet à la montre par WatchConnectivity (#226) : la résidence (adresse,
/// nom) et son jeton de montre (coprofirst#2771 : `GET /notifications` seul, révocable,
/// 30 jours) ; ou l'effacement, quand la résidence se ferme. Écrit UNE fois pour les deux
/// côtés : l'iPhone l'écrit, la montre le lit — à la forme de `MessageLiaison` de Wear OS.
enum MessageLiaison: Equatable, Sendable {
    case liaison(adresse: URL, residence: String, jeton: JetonMasque, expireLe: Date)
    /// La résidence se ferme sur l'iPhone : la montre oublie la liaison de cette adresse.
    case effacement(adresse: URL)

    // MARK: - Le transport ne connaît que des valeurs de liste de propriétés

    private enum Cle {
        static let geste = "geste"
        static let adresse = "adresse"
        static let residence = "residence"
        static let jeton = "jeton"
        static let expireLe = "expire_le"
    }

    private enum Geste {
        static let liaison = "liaison"
        static let effacement = "effacement"
    }

    var donnees: [String: Any] {
        switch self {
        case .liaison(let adresse, let residence, let jeton, let expireLe):
            [
                Cle.geste: Geste.liaison, Cle.adresse: adresse.absoluteString, Cle.residence: residence,
                Cle.jeton: jeton.enClair, Cle.expireLe: expireLe,
            ]
        case .effacement(let adresse):
            [Cle.geste: Geste.effacement, Cle.adresse: adresse.absoluteString]
        }
    }

    /// Un message incomplet, inconnu, ou dont l'adresse n'est pas celle d'une installation
    /// (https, avec un hôte) ne se lit pas : `nil`, jamais une liaison à moitié — le jeton ne
    /// partira que vers une adresse sûre.
    init?(_ donnees: [String: Any]) {
        guard let adresse = adresseSure(donnees[Cle.adresse]) else { return nil }
        switch donnees[Cle.geste] as? String {
        case Geste.liaison:
            guard let residence = donnees[Cle.residence] as? String, !residence.isEmpty,
                let jeton = donnees[Cle.jeton] as? String, !jeton.isEmpty,
                let expireLe = donnees[Cle.expireLe] as? Date
            else { return nil }
            self = .liaison(adresse: adresse, residence: residence, jeton: JetonMasque(jeton), expireLe: expireLe)
        case Geste.effacement:
            self = .effacement(adresse: adresse)
        default:
            return nil
        }
    }
}

/// « Continuer sur l'iPhone » (Handoff, #226) : watchOS ne peut pas ouvrir l'app iPhone, mais
/// la montre peut annoncer ce qu'elle montre — la cloche de la résidence reliée. L'iPhone
/// l'ouvre par sa porte commune (`Parcours.suivre`), sur une résidence qu'il CONNAÎT déjà :
/// aucune découverte (`decouvrir: false`).
enum ClocheSurLiPhone {
    /// Déclaré dans `NSUserActivityTypes` de l'app iPhone (`project.yml`).
    static let type = "fr.coprofirst.app.cloche"
    private static let cleAdresse = "adresse"

    static func userInfo(_ adresse: URL) -> [String: String] {
        [cleAdresse: adresse.absoluteString]
    }

    /// L'adresse annoncée, en https seulement — `nil` sinon.
    static func adresse(_ userInfo: [AnyHashable: Any]?) -> URL? {
        adresseSure(userInfo?[cleAdresse])
    }
}

/// Une adresse reçue d'ailleurs (l'iPhone, la montre) : https, avec un hôte — sinon `nil`.
private func adresseSure(_ valeur: Any?) -> URL? {
    guard let texte = valeur as? String, let adresse = URL(string: texte), adresse.scheme == "https",
        adresse.host() != nil
    else { return nil }
    return adresse
}
