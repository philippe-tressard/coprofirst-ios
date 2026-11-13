// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Ce que l'AFFAIRE a fait de la correction du Suivi d'une entrée, quand elle ne l'a pas
/// suivie (#187, coprofirst#2715) : la réponse du PATCH /tickets/{id}/evolutions/{evol_id}
/// le dit (`affaire_suivie: false`), avec SA phrase (`affaire_suivie_libelle`) et l'état
/// qu'elle propose d'appliquer à l'affaire (`etat_propose`, en clair :
/// `etat_propose_libelle`). L'app montre la phrase telle que servie et ne décide rien :
/// ni pourquoi l'affaire n'a pas suivi, ni quel état proposer.
///
/// Servis au-dessus du plancher (contrat 1.30.0) : relus dans le corps servi
/// (`Relecture.auDessusDuPlancher`). Absents — une installation antérieure —, l'écran ne
/// montre rien de plus qu'avant : l'avis « Entrée corrigée ».
struct IssueCorrection: Hashable, Sendable {
    /// La phrase du serveur, telle quelle.
    let phrase: String
    /// L'état proposé, son code ; `nil` : aucun geste ne le peut (le suivi d'une actualité).
    let etatPropose: String?
    /// Le même, en clair, tel que servi.
    let etatProposeLibelle: String?

    /// LA lecture de la réponse, pour le service réel comme pour l'API simulée : `nil`
    /// quand l'affaire a suivi, quand rien n'est servi, ou sans phrase — défaut fermé,
    /// l'app ne compose pas la sienne.
    static func lue(corps: Data?) -> IssueCorrection? {
        guard let lu = Relecture.auDessusDuPlancher(Servie.self, corps: corps), lu.affaireSuivie == false,
            let phrase = lu.affaireSuivieLibelle?.nulSiVide
        else { return nil }
        return IssueCorrection(
            phrase: phrase, etatPropose: lu.etatPropose?.nulSiVide,
            etatProposeLibelle: lu.etatProposeLibelle?.nulSiVide)
    }

    /// L'état à proposer sur CETTE affaire : celui que le serveur propose, si le compte peut
    /// changer l'état (`peut_changer_etat`, servi avec l'affaire) — sinon aucun geste.
    func proposition(pour affaire: DetailAffaire) -> SaisieSuite? {
        guard let etatPropose, affaire.droits.changerEtat else { return nil }
        var saisie = SaisieSuite(affaire: affaire)
        saisie.statut = etatPropose
        // Le serveur ne propose pas l'état où l'affaire est déjà ; s'il le faisait, rien à appliquer.
        return saisie.changeEtat ? saisie : nil
    }

    /// Le libellé du geste qui applique l'état proposé.
    func libelleProposition(pour affaire: DetailAffaire) -> String? {
        guard let code = proposition(pour: affaire)?.statut else { return nil }
        let etat = StatutsAffaire.libelle(code, servi: etatProposeLibelle, dans: affaire.referentiels)
        return TextesSuite.appliquer(etat)
    }

    /// Les champs relus, tous facultatifs : rien de servi, rien à dire.
    private struct Servie: Decodable {
        var affaireSuivie: Bool?
        var affaireSuivieLibelle: String?
        var etatPropose: String?
        var etatProposeLibelle: String?
    }
}
