// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une affaire telle que les onglets Liste, Kanban et Archives l'affichent —
/// lue dans `TicketRead` du contrat.
struct Affaire: Identifiable, Hashable, Sendable {
    let id: Int
    let numero: String
    let titre: String
    /// La description telle que l'API la sert : du HTML riche — `TexteDuSite.apercu` la lit.
    let apercu: String
    let creeLe: Date
    var misAJourLe: Date?
    var statut: String
    /// Close, au sens du SERVEUR (`TicketRead.close`, `utils/etat_affaire`) : l'app ne
    /// compare pas son statut à une liste d'états clos (#54).
    var close: Bool
    let categorie: String
    /// « Étude & travaux » : le libellé que le serveur SERT (`categorie_libelle`), jamais vide.
    let categorieLibelle: String
    /// Urgente, au sens du serveur (`TicketRead.urgente`) : l'app ne la déduit pas de la priorité.
    let urgente: Bool
    /// `nil` : le serveur ne le sait pas — la portée « me concerne » la garde (`selonPortee`).
    let meConcerne: Bool?
    /// Calculé par le SERVEUR (`app/utils/archivage.py`) : jamais recalculé ici.
    var archivee: Bool
    /// Suivie au Kanban (`suivi_kanban`).
    let suiviKanban: Bool
    /// Les natures que le serveur pose : actualité, calendrier, activité.
    let natures: [String]
    let prestataire: String?
    /// Les codes de périmètre visés (`perimetre_cible`).
    let perimetres: [String]
    /// Le lieu lisible (« Bât. 2 › Toit ») que le serveur SERT (`perimetre_libelle`) ;
    /// `nil` pour le périmètre par défaut, que le serveur tait.
    let lieu: String?
    /// Le nombre de messages du fil — absent tant que le contrat ne le sert pas.
    let messages: Int?
    /// La colonne du Kanban que le serveur SERT (`colonne_kanban`) ; `nil` hors tableau.
    var colonne: String?
    /// Glisser la carte au Kanban : ce que la route accepte de CE lecteur
    /// (`peut_deplacer_au_kanban`, le conseil seul) — servi, jamais déduit du profil.
    var peutDeplacer: Bool
    /// 📦 Archiver (`peut_archiver`, le conseil ou l'administration) — servi lui aussi.
    var peutArchiver: Bool
    /// « Qui la lit », servie (`lecture`, contrat 1.22.0, #129) ; `nil` d'une installation
    /// antérieure : aucune pastille.
    var lecture: Lecture?

    var estActualite: Bool { categorie == TablesAffaires.categorieActualite }
    /// La date qui range une affaire aux Archives : sa dernière activité.
    var dateDActivite: Date { misAJourLe ?? creeLe }
}

/// Une option du filtre « Suivi » : un statut, ou un groupe de statuts.
struct OptionDeSuivi: Identifiable, Hashable, Sendable {
    let code: String
    let libelle: String
    let statuts: Set<String>

    var id: String { code }

    /// Les options offertes : celles des statuts PRÉSENTS parmi les affaires actives,
    /// dans l'ordre du cycle, les statuts d'un groupe réunis — `statutsPresents` du site.
    static func presentes(dans affaires: [Affaire]) -> [OptionDeSuivi] {
        let presents = Set(affaires.map(\.statut))
        var options: [OptionDeSuivi] = []
        for statut in TablesAffaires.ordreDesStatuts where presents.contains(statut) {
            if let groupe = TablesAffaires.groupesDeSuivi.first(where: { $0.statuts.contains(statut) }) {
                if !options.contains(where: { $0.code == groupe.code }) {
                    options.append(.init(code: groupe.code, libelle: groupe.libelle, statuts: Set(groupe.statuts)))
                }
            } else {
                let libelle = StatutsAffaire.parCode[statut]?.libelle ?? statut
                options.append(.init(code: statut, libelle: libelle, statuts: [statut]))
            }
        }
        return options
    }
}

/// Ce que l'onglet Liste retient : état, nature, portée — la recherche à part.
struct FiltresAffaires: Hashable, Sendable {
    var suivi: String?
    var nature: String?
    var meConcerne = false

    var actifs: Int { (nature == nil ? 0 : 1) + (meConcerne ? 1 : 0) }
}

extension [Affaire] {
    /// Les affaires de la liste — `filtrerAffaires` puis `selonPortee` du site.
    ///
    /// Sans recherche : les affaires actives, dans l'ordre du serveur. Avec : celles
    /// que le serveur a trouvées, dans SON ordre (la pertinence), archives comprises
    /// si on les demande. Puis l'état, la nature et la portée.
    func liste(
        filtres: FiltresAffaires, options: [OptionDeSuivi], trouvees: [Int]?, avecArchives: Bool
    ) -> [Affaire] {
        let parId = Dictionary(map { ($0.id, $0) }, uniquingKeysWith: { premiere, _ in premiere })
        let base =
            trouvees.map { ids in ids.compactMap { parId[$0] }.filter { avecArchives || !$0.archivee } }
            ?? filter { !$0.archivee }
        let suivi = filtres.suivi.flatMap { code in options.first { $0.code == code } }
        return base.filter { affaire in
            (filtres.suivi == nil || suivi?.statuts.contains(affaire.statut) == true)
                && (filtres.nature.map { affaire.natures.contains($0) } ?? true)
                && (!filtres.meConcerne || affaire.meConcerne != false)
        }
    }

    /// Les Archives : closes depuis plus du délai (le serveur en décide), sur trois
    /// ans, la plus récente d'abord, par année — `historyTickets` et `ArchivesParAnnee`.
    func archives(au jour: Date, calendrier: Calendar = Chronologie.calendrier) -> [(annee: Int, affaires: [Affaire])] {
        let limite = calendrier.date(byAdding: .year, value: -3, to: jour) ?? jour
        let retenues = filter { $0.archivee && $0.dateDActivite >= limite }
            .sorted { $0.dateDActivite > $1.dateDActivite }
        let parAnnee = Dictionary(grouping: retenues) { calendrier.component(.year, from: $0.dateDActivite) }
        return parAnnee.keys.sorted(by: >).map { ($0, parAnnee[$0] ?? []) }
    }

    /// Le Kanban : les affaires suivies, non archivées, auxquelles le serveur sert une colonne.
    var auKanban: [Affaire] { filter { $0.suiviKanban && !$0.archivee && $0.colonne != nil } }
}

/// Qui peut quoi, ici — le même rôle que la route accepte.
///
/// « Modérer » = conseil syndical ou administration : `est_moderateur` du serveur
/// (`auth/deps.py`), `isCS` du site, lu par `DroitsOnglet.cs` (rôles GÉNÉRÉS). Il ne garde
/// plus que les catégories réservées et un conseil de saisie : glisser au Kanban et archiver se lisent sur
/// l'affaire (`peut_*`, #83) ; `permise` des référentiels le remplacera (#105, après #95).
struct DroitsAffaires: Equatable, Sendable {
    /// La page du site que porte ce menu (`pages.ts`).
    static let page = "mes-demandes"

    let moderateur: Bool
    /// Les onglets ouverts à ce compte (`OngletsDuSite.ouverts`, la règle du site).
    /// Profil pas encore lu : les seuls onglets sans réserve — un réservé reste caché.
    let onglets: [OngletDuSite]

    init(profil: ProfilResidence?) {
        let droits = DroitsOnglet(profil: profil)
        moderateur = profil != nil && droits.cs
        onglets =
            profil == nil
            ? (OngletsDuSite.parPage[Self.page] ?? []).filter { $0.reserve == nil }
            : OngletsDuSite.ouverts(page: Self.page, droits: droits)
    }

    /// Les catégories qu'il peut poser, dans l'ordre du site, « Actualité » en tête.
    var categories: [CategorieAffaire] {
        let permises = TablesAffaires.categories.filter { moderateur || !$0.reserveCS }
        return permises.filter(\.enTete) + permises.filter { !$0.enTete }
    }
}
