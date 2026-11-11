// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// Le menu Affaires sur l'installation simulée : aucune requête. Les gestes
/// (créer, déplacer, archiver) restent en mémoire le temps de la session.
extension ServiceSimule: ServiceAffaires {
    /// Les affaires de CETTE installation simulée : deux tests ne se marchent pas dessus.
    private var magasin: MagasinAffairesSimule { MagasinAffairesSimule.de(self) }

    func affaires(_ installation: Installation) async throws -> [Affaire] {
        try await Task.sleep(for: .milliseconds(450))
        return magasin.affaires
    }

    func referentiels(_ installation: Installation) async throws -> ReferentielsAffaires {
        try FixturesReferentielsAffaires.lus()
    }

    func rechercher(_ terme: String, dans installation: Installation) async throws -> [Int] {
        try await Task.sleep(for: .milliseconds(200))
        // La règle vit au serveur ; la simulation ne cherche que dans le titre et le numéro.
        return magasin.affaires
            .filter { $0.titre.localizedStandardContains(terme) || $0.numero.localizedStandardContains(terme) }
            .map(\.id)
    }

    func offrirMeConcerne(_ installation: Installation) async -> Bool { true }

    func creer(_ saisie: SaisieAffaire, dans installation: Installation) async throws -> Affaire {
        try await Task.sleep(for: .milliseconds(450))
        return magasin.creer(saisie)
    }

    func candidatesALaFusion(_ affaire: Affaire, dans installation: Installation) async throws -> Int {
        try await Task.sleep(for: .milliseconds(150))
        return affaire.id == 40 ? 1 : 0
    }

    func deplacer(_ affaire: Affaire, vers statut: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(250))
        magasin.modifier(affaire.id) {
            $0.statut = statut
            $0.close = MagasinAffairesSimule.close(statut)
            $0.colonne = MagasinAffairesSimule.colonne(statut)
        }
    }

    func archiver(_ affaire: Affaire, dans installation: Installation) async throws -> Affaire {
        try await Task.sleep(for: .milliseconds(250))
        return magasin.modifier(affaire.id) { $0.archivee = true } ?? affaire
    }
}

/// Les affaires de la simulation, modifiables par les gestes, derrière un verrou —
/// un magasin par service simulé (une extension ne peut pas y ranger de propriété).
final class MagasinAffairesSimule: @unchecked Sendable {
    private static let verrouGlobal = NSLock()
    /// Le service est retenu avec son magasin : un identifiant libéré puis réemployé
    /// rendrait le magasin d'un autre.
    nonisolated(unsafe) private static var parService: [ObjectIdentifier: (ServiceSimule, MagasinAffairesSimule)] = [:]

    static func de(_ service: ServiceSimule) -> MagasinAffairesSimule {
        verrouGlobal.withLock {
            if let existant = parService[ObjectIdentifier(service)] { return existant.1 }
            let neuf = MagasinAffairesSimule()
            parService[ObjectIdentifier(service)] = (service, neuf)
            return neuf
        }
    }

    /// Les référentiels du serveur simulé : il y lit ce qu'il SERT sur chaque affaire
    /// (`close`, `colonne_kanban`, `categorie_libelle`) — lui seul le calcule, comme le vrai.
    private static let referentiels = try? FixturesReferentielsAffaires.lus()

    static func close(_ statut: String) -> Bool {
        referentiels?.statuts.first { $0.code == statut }?.clos ?? false
    }

    static func colonne(_ statut: String) -> String? {
        referentiels?.statuts.first { $0.code == statut }?.colonne
    }

    static func libelle(_ categorie: String) -> String { referentiels?.categorie(categorie)?.libelle ?? categorie }

    private var contenu = Apercu.affaires
    private let verrou = NSLock()

    var affaires: [Affaire] { verrou.withLock { contenu } }

    func creer(_ saisie: SaisieAffaire) -> Affaire {
        verrou.withLock {
            let id = (contenu.map(\.id).max() ?? 0) + 1
            let actualite = saisie.categorie == TablesAffaires.categorieActualite
            let neuve = Affaire(
                id: id, numero: String(format: "A-%04d", id), titre: saisie.titre, apercu: saisie.descriptionHTML,
                creeLe: .now, misAJourLe: nil, statut: actualite ? "publie" : "ouvert", close: false,
                categorie: saisie.categorie, categorieLibelle: Self.libelle(saisie.categorie),
                urgente: saisie.urgente, meConcerne: true, archivee: false, suiviKanban: false,
                natures: [actualite ? "actualite" : "activite"], prestataire: nil,
                perimetres: saisie.perimetre.map { [$0] } ?? [], lieu: nil, messages: nil,
                colonne: Self.colonne(actualite ? "publie" : "ouvert"), peutDeplacer: false, peutArchiver: true)
            contenu.insert(neuve, at: 0)
            return neuve
        }
    }

    @discardableResult
    func modifier(_ id: Int, _ changer: (inout Affaire) -> Void) -> Affaire? {
        verrou.withLock {
            guard let rang = contenu.firstIndex(where: { $0.id == id }) else { return nil }
            changer(&contenu[rang])
            contenu[rang].misAJourLe = .now
            return contenu[rang]
        }
    }
}
#endif
