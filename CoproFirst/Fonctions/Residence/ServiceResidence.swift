// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import ClientAPI
import Foundation

/// Ce que « Ma résidence » demande à une installation — le service du menu, dans
/// son dossier : `Session/` et `Donnees/` ne grossissent pas (motif des sessions
/// parallèles de #10). Réalisé par le client généré et par l'API simulée ; un test
/// vérifie à la compilation que les deux s'y conforment.
protocol ServiceResidence: Sendable {
    /// La Fiche, en une vague : copropriété, bâtiments, règles, trois rubriques de
    /// documents, diagnostics et annexes.
    func fiche(_ installation: Installation) async throws -> ContenuFiche
    /// GET /diagnostics/rapports/{id}/télécharger : le rapport, écrit sur le disque.
    func rapport(_ id: Int, nom: String, dans installation: Installation) async throws -> URL
    /// GET /carnet-entretien, filtré par périmètre (`nil` : toute la résidence), et
    /// GET /equipements pour nommer les groupes.
    func carnet(perimetre: String?, dans installation: Installation) async throws -> ContenuCarnet
    /// GET /perimetres : les choix du filtre du carnet.
    func perimetres(_ installation: Installation) async throws -> [Perimetre]
    /// GET /reglement/acces : l'administration a-t-elle ouvert l'assistant aux
    /// copropriétaires ? `false` masque l'onglet, comme sur le site.
    func accesReglement(_ installation: Installation) async throws -> Bool
    /// GET /reglement et GET /reglement/questions.
    func reglement(_ installation: Installation) async throws -> (EtatReglement, [QuestionReglement])
    /// POST /reglement/questions : l'assistant lit le règlement et répond.
    func poser(_ question: String, dans installation: Installation) async throws -> QuestionReglement
}

extension ServiceCoproFirst {
    /// Le service du menu, quand la réalisation le porte (les deux le portent).
    var residence: (any ServiceResidence)? { self as? any ServiceResidence }
}

extension ServiceAPI: ServiceResidence {
    func fiche(_ installation: Installation) async throws -> ContenuFiche {
        let client = client(installation.adresse)
        func documents(_ categorie: String? = nil, annexes: String? = nil) async throws -> [DocumentResidence] {
            let sortie = try await appeler {
                try await client.getDocuments(query: .init(categorie: categorie, annexesDe: annexes))
            }
            switch sortie {
            case .ok(let ok): return try ok.body.json.map(DocumentResidence.init(lu:))
            case .unprocessableContent: throw ErreurService.inattendue(422)
            case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
            }
        }
        async let copropriete = appeler { try await client.getCopropriete() }
        async let batiments = appeler { try await client.getCoproprieteBatiments() }
        async let regles = appeler { try await client.getReglesResidence() }
        async let diagnostics = appeler { try await client.getDiagnosticsTypes() }
        async let plans = documents("plan_residence")
        async let reglements = documents("reglement_copropriete")
        async let comptesRendus = documents("pv_ag")
        async let annexesDocuments = documents(annexes: "document")
        async let annexesRegles = documents(annexes: "regle")
        async let annexesRapports = documents(annexes: "diagnostic")

        let fiche: FicheResidence
        switch try await copropriete {
        case .ok(let ok): fiche = FicheResidence(lue: try ok.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        var contenu = ContenuFiche(
            fiche: fiche, batiments: [], regles: [], plans: try await plans,
            reglements: try await reglements, comptesRendus: try await comptesRendus, diagnostics: [], annexes: [])
        // Une rubrique qui échoue ne vide pas les autres (#522 du site) : elle est vide.
        if case .ok(let ok) = try? await batiments, let lus = try? ok.body.json {
            contenu.batiments = lus.map(Batiment.init(lu:))
        }
        if case .ok(let ok) = try? await regles, let lues = try? ok.body.json {
            // La réponse n'est pas typée dans le contrat : relue telle quelle.
            contenu.regles = (try? JSONDecoder().decode([RegleResidence].self, from: JSONEncoder().encode(lues))) ?? []
        }
        if case .ok(let ok) = try? await diagnostics, let lus = try? ok.body.json {
            contenu.diagnostics = lus.map(TypeDiagnostic.init(lu:))
        }
        contenu.annexes =
            ((try? await annexesDocuments) ?? []) + ((try? await annexesRegles) ?? [])
            + ((try? await annexesRapports) ?? [])
        return contenu
    }

    func rapport(_ id: Int, nom: String, dans installation: Installation) async throws -> URL {
        let client = client(installation.adresse)
        return try await fichierServi(nom: nom, defaut: "rapport-\(id)") {
            let sortie = try await client.getDiagnosticsRapportsRapportIdTélécharger(
                path: .init(rapportId: id))
            if case .undocumented(let statut, _) = sortie { throw ErreurService.depuisLecture(statut) }
        }
    }

    func carnet(perimetre: String?, dans installation: Installation) async throws -> ContenuCarnet {
        let client = client(installation.adresse)
        async let equipements = appeler { try await client.getEquipements() }
        let sortie = try await appeler {
            try await client.getCarnetEntretien(query: .init(perimetre: perimetre))
        }
        var libelles: [String: String] = [:]
        if case .ok(let ok) = try? await equipements, let lus = try? ok.body.json {
            libelles = Dictionary(lus.map { ($0.code, $0.libelle) }, uniquingKeysWith: { premier, _ in premier })
        }
        switch sortie {
        case .ok(let ok):
            // Non typée dans le contrat (coprofirst#2505) : relue telle quelle.
            let carnet = try JSONDecoder().decode(Carnet.self, from: JSONEncoder().encode(try ok.body.json))
            return ContenuCarnet(entrees: carnet.entrees, libellesEquipements: libelles)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func perimetres(_ installation: Installation) async throws -> [Perimetre] {
        let sortie = try await appeler { try await client(installation.adresse).getPerimetres() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.filter(\.actif).map { Perimetre(code: $0.code, libelle: $0.libelle) }
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func accesReglement(_ installation: Installation) async throws -> Bool {
        let sortie = try await appeler { try await client(installation.adresse).getReglementAcces() }
        switch sortie {
        case .ok(let ok): return try ok.body.json.acces
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    func reglement(_ installation: Installation) async throws -> (EtatReglement, [QuestionReglement]) {
        let client = client(installation.adresse)
        async let etat = appeler { try await client.getReglement() }
        async let questions = appeler { try await client.getReglementQuestions() }
        let lu: Components.Schemas.EtatReglement
        switch try await etat {
        case .ok(let ok): lu = try ok.body.json
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        let lues: [QuestionReglement]
        switch try await questions {
        case .ok(let ok): lues = try ok.body.json.map(QuestionReglement.init(lue:))
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
        let etatLu = EtatReglement(
            disponible: lu.disponible, texteDisponible: lu.texteDisponible, lienReglement: lu.lienReglement)
        return (etatLu, lues)
    }

    func poser(_ question: String, dans installation: Installation) async throws -> QuestionReglement {
        let sortie = try await appeler {
            try await client(installation.adresse).postReglementQuestions(
                body: .json(.init(question: question)))
        }
        switch sortie {
        case .created(let cree): return QuestionReglement(lue: try cree.body.json)
        case .unprocessableContent: throw ErreurService.inattendue(422)
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }

    /// Une route qui sert un FICHIER (`FileResponse`) que le contrat déclare en JSON :
    /// le client généré le refuse, et l'erreur porte le corps — lu sur un 200 seulement.
    ///
    /// ⚠️ Même geste que `ServiceAPI.document` (Session/) : écrit ici, sous une forme
    /// générique, parce que ce lot ne touche pas aux fichiers partagés. Signalé à la
    /// coordination : `document` peut s'y ramener dans un lot de `Session/`.
    func fichierServi(nom: String, defaut: String, appel: () async throws -> Void) async throws -> URL {
        let donnees: Data
        do {
            try await appel()
            throw ErreurService.inattendue(200)
        } catch let erreur as ErreurService {
            throw erreur
        } catch {
            guard let fichier = try await ClientCoproFirst.fichierServi(error) else {
                throw ErreurService.depuis(ClientCoproFirst.cause(error))
            }
            donnees = fichier
        }
        let dossier = FileManager.default.temporaryDirectory.appending(path: "documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appending(path: Fichiers.nomSur(nom, defaut: defaut))
        try donnees.write(to: fichier, options: [.atomic, .completeFileProtection])
        return fichier
    }
}
