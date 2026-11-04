// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Observation
import SwiftUI

/// Les affaires d'une résidence, lues une fois et partagées par les trois onglets
/// (Liste, Kanban, Archives) : un geste fait dans l'un se voit dans les autres.
@MainActor @Observable
final class EtatAffaires {
    enum Phase: Equatable {
        case chargement
        case pret
        case erreur(ErreurAffaires)
    }

    /// En dessous, une frappe n'est pas encore une recherche (`RECHERCHE_MIN` du site).
    static let rechercheMinimale = 2
    /// Le temps de finir un mot avant d'interroger le serveur.
    static let delaiDeFrappe = Duration.milliseconds(250)

    private(set) var phase = Phase.chargement
    private(set) var affaires: [Affaire] = []
    var filtres = FiltresAffaires()
    var recherche = ""
    var avecArchives = false
    /// Les identifiants trouvés par le serveur, dans son ordre — `nil` sans recherche.
    private(set) var trouvees: [Int]?
    private(set) var rechercheEnCours = false
    private(set) var offrirMeConcerne = false
    /// La phrase d'un geste qui a échoué ; l'écran la montre, puis l'efface.
    var avis: String?

    /// Les options « Suivi » : celles des statuts présents parmi les affaires actives.
    var optionsDeSuivi: [OptionDeSuivi] { OptionDeSuivi.presentes(dans: affaires.filter { !$0.archivee }) }

    var liste: [Affaire] {
        affaires.liste(filtres: filtres, options: optionsDeSuivi, trouvees: trouvees, avecArchives: avecArchives)
    }

    var archives: [(annee: Int, affaires: [Affaire])] { affaires.archives(au: .now) }

    /// Les affaires suivies, rangées dans leur colonne.
    func cartes(de colonne: ColonneKanban) -> [Affaire] { affaires.auKanban.filter { $0.colonne == colonne.id } }

    var suiviesAuKanban: Int { affaires.auKanban.count }

    /// Combien d'affaires archivées la recherche a trouvées — pour les proposer.
    var archiveesTrouvees: Int {
        guard let trouvees else { return 0 }
        let archivees = Set(affaires.filter(\.archivee).map(\.id))
        return trouvees.filter(archivees.contains).count
    }

    func charger(_ installation: Installation, avec service: (any ServiceAffaires)?) async {
        guard let service else {
            phase = .erreur(.serviceAbsent)
            return
        }
        if affaires.isEmpty { phase = .chargement }
        async let offrir = service.offrirMeConcerne(installation)
        do {
            let lues = try await service.affaires(installation)
            withAnimation(.snappy) {
                affaires = lues
                phase = .pret
            }
        } catch {
            withAnimation(.snappy) { phase = .erreur(ErreurAffaires.depuis(error)) }
        }
        offrirMeConcerne = await offrir
        retomberSurUneOptionPresente()
    }

    /// Une recherche qui attend la fin de la frappe. Appelée par `.task(id:)` : une
    /// frappe neuve ANNULE la précédente, si bien que seule la dernière réponse compte.
    func chercher(_ installation: Installation, avec service: (any ServiceAffaires)?) async {
        let terme = recherche.trimmingCharacters(in: .whitespacesAndNewlines)
        guard terme.count >= Self.rechercheMinimale, let service else {
            trouvees = nil
            rechercheEnCours = false
            return
        }
        rechercheEnCours = true
        do {
            try await Task.sleep(for: Self.delaiDeFrappe)
            let ids = try await service.rechercher(terme, dans: installation)
            try Task.checkCancellation()
            withAnimation(.snappy) { trouvees = ids }
            rechercheEnCours = false
        } catch is CancellationError {
            return
        } catch {
            rechercheEnCours = false
            avis = ErreurAffaires.depuis(error).phrase
        }
    }

    /// 📦 Archiver, et non supprimer : la carte part aux Archives aussitôt, et y
    /// revient si le serveur refuse.
    func archiver(_ affaire: Affaire, dans installation: Installation, avec service: (any ServiceAffaires)?) async {
        guard let service else {
            avis = ErreurAffaires.serviceAbsent.phrase
            return
        }
        remplacer(affaire.id) { $0.archivee = true }
        do {
            let lue = try await service.archiver(affaire, dans: installation)
            remplacer(affaire.id) { $0 = lue }
        } catch {
            remplacer(affaire.id) { $0 = affaire }
            avis = ErreurAffaires.depuis(error).phrase
        }
    }

    /// Déplacer une carte au Kanban : une Suite d'état, sans texte, qui n'avertit personne.
    func deplacer(
        _ affaire: Affaire, vers statut: String, dans installation: Installation,
        avec service: (any ServiceAffaires)?
    ) async {
        guard statut != affaire.statut else { return }
        guard let service else {
            avis = ErreurAffaires.serviceAbsent.phrase
            return
        }
        remplacer(affaire.id) { $0.statut = statut }
        do {
            try await service.deplacer(affaire, vers: statut, dans: installation)
        } catch {
            remplacer(affaire.id) { $0 = affaire }
            avis = ErreurAffaires.depuis(error).phrase
        }
        retomberSurUneOptionPresente()
    }

    /// L'affaire créée par « Nouvelle affaire » : en tête de la liste.
    func ajouter(_ affaire: Affaire) {
        withAnimation(.snappy) { affaires.insert(affaire, at: 0) }
    }

    private func remplacer(_ id: Int, _ changer: (inout Affaire) -> Void) {
        guard let rang = affaires.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { changer(&affaires[rang]) }
    }

    /// ⚠️ Un filtre retenu sur un état qui vient de disparaître laisserait un écran
    /// vide ET plus aucune pastille pour en sortir : on retombe sur « Toutes ».
    private func retomberSurUneOptionPresente() {
        if let suivi = filtres.suivi, !optionsDeSuivi.contains(where: { $0.code == suivi }) {
            filtres.suivi = nil
        }
        if !offrirMeConcerne { filtres.meConcerne = false }
    }
}
