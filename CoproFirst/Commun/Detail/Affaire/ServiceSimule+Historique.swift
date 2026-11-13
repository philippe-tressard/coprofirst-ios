// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Les gestes d'une entrée de l'Historique sur l'API simulée (#91, #93) : ce faux serveur
/// sert à chaque compte les gestes que le vrai lui servirait, et refuse ce qu'il n'a pas
/// servi. Sa règle imite `auth/gestes_evolution.py` de coprofirst pour le compte simulé —
/// l'app, elle, ne la lit que servie (`DroitsServisSuite`).
extension ServiceSimule {
    /// Les types qu'une personne saisit (`TYPES_SAISIS`) : les seuls qui se corrigent et
    /// s'effacent — une réponse appartient à son auteur.
    private static let typesSaisis: Set<String> = ["commentaire", "etat"]

    /// L'entrée telle que servie à `lecteur` : corriger au conseil ou à l'administration
    /// (le compte simulé est l'auteur des entrées du conseil), hors d'une affaire absorbée ;
    /// effacer, à l'administrateur seul.
    static func servie(_ suite: SuiteAffaire, a lecteur: DroitsOnglet, fusionnee: Bool) -> SuiteAffaire {
        var servie = suite
        let saisie = typesSaisis.contains(suite.type)
        servie.droits = DroitsServisSuite(
            modifier: saisie && lecteur.cs && !fusionnee, supprimer: saisie && lecteur.administrateur)
        return servie
    }

    @discardableResult
    func corrigerSuite(
        _ correction: CorrectionSuite, _ suite: Int, de affaire: Int, dans installation: Installation
    ) async throws -> IssueCorrection? {
        try await Task.sleep(for: .milliseconds(300))
        var servi: Data?
        try changerAffaireSimulee(affaire) { detail in
            guard let rang = detail.suites.firstIndex(where: { $0.id == suite }), detail.suites[rang].droits.modifier
            else { throw ErreurService.refus(.init(phrase: "Accès refusé")) }
            servi = try Self.corriger(&detail, rang, correction)
        }
        return IssueCorrection.lue(corps: servi)
    }

    func supprimerSuite(_ suite: Int, de affaire: Int, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        try changerAffaireSimulee(affaire) { detail in
            guard detail.suites.first(where: { $0.id == suite })?.droits.supprimer == true else {
                throw ErreurService.refus(
                    .init(phrase: "Cette entrée ne peut pas être supprimée : une réponse appartient à son auteur."))
            }
            // L'état de l'affaire ne change pas : le fil n'en est que le récit.
            detail.suites.removeAll { $0.id == suite }
        }
    }

    /// La correction, comme `suite_sections.corriger_suivi` : l'entrée garde sa date et
    /// son auteur ; son Suivi se déduit de l'état d'avant elle. L'affaire suit si elle est
    /// déjà dans l'état que l'entrée donne, ou si aucune transition ne suit l'entrée et que
    /// l'affaire porte encore son ancien état — ou que l'entrée en donne un
    /// (`utils/suivi_fil.py`, coprofirst#2715). Sinon rien n'est écrasé : la réponse le dit
    /// (`FixturesCorrectionSuite`), et c'est elle que la fonction rend.
    private static func corriger(
        _ detail: inout DetailAffaire, _ rang: Int, _ correction: CorrectionSuite
    ) throws -> Data? {
        let entree = detail.suites[rang]
        let avant = entree.ancienStatut ?? detail.statut
        let resultatAvant = entree.nouveauStatut ?? avant
        var (type, nouveau) = (entree.type, entree.nouveauStatut)
        if let suivi = correction.suivi {
            let transition = suivi.type == "etat" && suivi.statut != nil && suivi.statut != avant
            (type, nouveau) = transition ? ("etat", suivi.statut) : ("commentaire", nil)
        }
        var corrigee = SuiteAffaire(
            id: entree.id, type: type, date: entree.date, auteur: entree.auteur,
            contenu: correction.contenuHTML.map { $0.isEmpty ? nil : $0 } ?? entree.contenu, ancienStatut: avant,
            nouveauStatut: nouveau)
        corrigee.droits = entree.droits
        corrigee.pieces = entree.pieces
        corrigee.perimetrePrecise = entree.perimetrePrecise
        detail.suites[rang] = corrigee
        let resultatApres = nouveau ?? avant
        guard correction.suivi != nil, (type, nouveau) != (entree.type, entree.nouveauStatut),
            resultatApres != detail.statut
        else { return nil }
        let suivie = detail.suites[(rang + 1)...].contains { $0.type == "etat" }
        if !suivie, detail.statut == resultatAvant || type == "etat" {
            detail.statut = resultatApres
            detail.statutLibelle = MagasinAffairesSimule.libelle(statut: resultatApres)
            return nil
        }
        // La phrase du faux serveur, à l'image de celle du vrai : l'app la montre sans la lire.
        let reste = MagasinAffairesSimule.libelle(statut: detail.statut)
        let raison =
            suivie
            ? "une Suite plus récente a changé son état depuis."
            : "son état a été corrigé depuis, hors de l'Historique."
        return try FixturesCorrectionSuite.servie(
            phrase: "L'affaire est restée « \(reste) » : \(raison)",
            etatPropose: detail.estActualite ? nil : resultatApres,
            libelle: MagasinAffairesSimule.libelle(statut: resultatApres))
    }
}
#endif
