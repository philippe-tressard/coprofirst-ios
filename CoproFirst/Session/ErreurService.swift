// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce qui peut empêcher d'entrer ou d'agir : chaque cas dit une phrase, jamais un
/// code brut — celle du serveur quand il en donne une (`refus`, #41).
enum ErreurService: Error, Equatable, Sendable {
    /// 421 : l'adresse répond, mais n'y sert aucune résidence.
    case hoteInconnu
    /// Pas de réseau, ou l'adresse ne répond pas.
    case injoignable
    /// Hors ligne : l'appareil n'a pas de connexion.
    case horsLigne
    /// L'adresse répond, mais ce n'est pas une installation de CoproFirst.
    case pasCoproFirst
    /// Adresse électronique ou mot de passe refusés.
    case identifiantsRefuses
    /// Trop d'essais : le serveur demande d'attendre.
    case tropDEssais
    /// La session a expiré : il faut se reconnecter.
    case sessionExpiree
    /// L'élément n'existe plus, ou n'est pas lisible par ce compte.
    case introuvable
    /// Un geste refusé, avec la phrase du serveur (`detail`) — la sienne, pas la nôtre.
    case refus(RefusDuServeur)
    /// Tout le reste — le code reste dans le journal, pas à l'écran.
    case inattendue(Int)

    var phrase: String {
        switch self {
        case .hoteInconnu:
            "Cette adresse répond, mais aucune résidence n'y est installée. Vérifiez-la sur votre fiche d'arrivée."
        case .injoignable:
            "Impossible de joindre cette adresse. Vérifiez-la, ou réessayez dans un instant."
        case .horsLigne:
            "Vous êtes hors ligne. Vérifiez votre connexion, puis réessayez."
        case .pasCoproFirst:
            "Cette adresse ne mène pas à une résidence CoproFirst."
        case .identifiantsRefuses:
            "Adresse électronique ou mot de passe incorrect."
        case .tropDEssais:
            "Trop d'essais. Patientez quelques minutes avant de réessayer."
        case .sessionExpiree:
            "Votre session a expiré. Connectez-vous de nouveau."
        case .introuvable:
            "Cet élément n'est plus disponible, ou vous n'y avez pas accès."
        case .refus(let refus):
            refus.phrase
        case .inattendue:
            "La résidence n'a pas pu répondre. Réessayez dans un instant."
        }
    }

    /// La phrase du serveur, s'il en a donné une : un écran qui écrit sa propre phrase
    /// d'échec (« Erreur lors de l'export. », celle du site) la cède à celle-ci.
    var phraseDuServeur: String? {
        if case .refus(let refus) = self { refus.phrase } else { nil }
    }

    /// La phrase d'échec d'un geste : celle du serveur, sinon celle de l'écran.
    static func phrase(_ erreur: any Error, sinon phraseDeLEcran: String) -> String {
        depuis(erreur).phraseDuServeur ?? phraseDeLEcran
    }

    /// Une erreur de transport ramenée à l'un des cas ci-dessus.
    ///
    /// Une réponse REÇUE mais illisible (`DecodingError`, type de contenu inattendu)
    /// n'est pas « pas une résidence CoproFirst » : le serveur a répondu, c'est
    /// `.inattendue` (#13 : un champ manquant faisait lire « Cette adresse ne mène pas à
    /// une résidence CoproFirst » dans une résidence ouverte). Ce jugement-là est
    /// réservé à l'ENTRÉE dans une installation : `depuisEntree(_:)`.
    static func depuis(_ erreur: any Error) -> ErreurService {
        if let propre = erreur as? ErreurService { return propre }
        let urlError = (erreur as? URLError) ?? ((erreur as NSError).underlyingErrors.first as? URLError)
        switch urlError?.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .horsLigne
        case .some: return .injoignable
        // 0 : aucun statut HTTP en cause — la réponse est arrivée, elle ne se lit pas.
        case .none: return .inattendue(0)
        }
    }

    /// À l'ENTRÉE dans une installation (GET /config d'une adresse saisie) : une
    /// réponse qui ne se lit pas dit que l'adresse ne sert pas CoproFirst.
    static func depuisEntree(_ erreur: any Error) -> ErreurService {
        if erreur is ErreurService { return depuis(erreur) }
        if case .inattendue = depuis(erreur) { return .pasCoproFirst }
        return depuis(erreur)
    }

    /// Un statut HTTP non documenté par le contrat, ramené à un cas.
    static func depuis(statut: Int) -> ErreurService {
        switch statut {
        case 401, 403: .identifiantsRefuses
        case 404: .pasCoproFirst
        case 421: .hoteInconnu
        case 429: .tropDEssais
        default: .inattendue(statut)
        }
    }
}
