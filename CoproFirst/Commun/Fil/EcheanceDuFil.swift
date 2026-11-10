// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import OpenAPIRuntime

/// L'échéance d'une affaire DATÉE du fil (#75) : le délai, puis la ou les dates — la
/// vignette de la gouttière du site (`EcheanceGouttiere.svelte`, coprofirst v3.79.0,
/// coprofirst#2620).
///
/// 🔴 Le délai n'est PAS compté ici : le serveur le dérive en jours civils de Paris et
/// sert son libellé (`utils/echeance_affaire`) ; l'app l'affiche tel quel
/// (`standards/09` §8). Elle ne formate que les deux dates (`FormatsDuSite.jourCourt`).
///
/// Lu dans `meta.affaire` de GET /flux. Un serveur antérieur à v3.79.0 (contrat
/// 1.14.0 de la démo) n'y met ni `fin` ni `echeance` : pas d'échéance, et la carte
/// reste telle qu'avant.
struct EcheanceDuFil: Hashable, Sendable {
    /// « J-8 », « Jour J », « En cours », « Passé » — tel que servi ; `nil` pour une
    /// affaire close : la date seule dit quand c'était prévu.
    let libelle: String?
    /// `etat == "passee"` : il ne reste qu'un fait, le délai perd la teinte de la nature.
    let passee: Bool
    /// Le début, tel que servi (ISO) : formaté comme le site le lit (`new Date(d)`).
    let debut: String
    /// La fin, seulement quand elle tombe un autre jour (`plusieurs_jours`).
    let fin: String?

    /// `meta` d'un élément du fil — un dictionnaire libre du contrat, donc relu
    /// (`Relecture`) ; `nil` s'il ne porte pas d'affaire datée.
    init?(meta: OpenAPIObjectContainer?) {
        guard let meta else { return nil }
        // `Relecture` relit une liste d'objets libres : un seul, ici.
        guard let lu = (try? Relecture.lire([MetaServi].self, depuis: [meta]))?.first else { return nil }
        self.init(lu: lu)
    }

    /// Le même `meta`, en JSON — l'API simulée le sert ainsi, à la forme du serveur, et
    /// il passe par le même décodeur que celui du service réel.
    init?(metaJSON: String) {
        guard let lu = try? Relecture.lire(MetaServi.self, json: Data(metaJSON.utf8)) else { return nil }
        self.init(lu: lu)
    }

    /// La règle de la vignette du site : rien sans échéance ni début ; la fin, seulement
    /// sur plusieurs jours.
    private init?(lu: MetaServi) {
        guard let affaire = lu.affaire, let echeance = affaire.echeance, let debut = affaire.debut,
            !debut.isEmpty
        else { return nil }
        self.libelle = echeance.libelle
        self.passee = echeance.etat == "passee"
        self.debut = debut
        self.fin = echeance.plusieursJours == true ? affaire.fin : nil
    }

    /// Ce que la carte montre : « mar. 17 nov. », puis « → 19 nov. » sur plusieurs jours.
    func dates(maintenant: Date = .now) -> String {
        let premier = FormatsDuSite.jourCourt(debut, maintenant: maintenant)
        guard let fin else { return premier }
        return premier + Textes.fleche + FormatsDuSite.jourCourt(fin, semaine: false, maintenant: maintenant)
    }

    /// Ce que VoiceOver lit, comme le titre de la vignette du site : « J-8, prévu le
    /// 17 novembre 2026 », « prévu du 17 novembre 2026 au 19 novembre 2026 ».
    var enClair: String {
        let quand =
            fin.map { "du \(FormatsDuSite.dateLongue(debut)) au \(FormatsDuSite.dateLongue($0))" }
            ?? "le \(FormatsDuSite.dateLongue(debut))"
        return [libelle, "\(Textes.prevu) \(quand)"].compactMap { $0 }.joined(separator: ", ")
    }

    enum Textes {
        /// `SEPARATEUR.fleche` du site : une espace, la flèche, une espace insécable.
        static let fleche = " →\u{00A0}"
        static let prevu = "prévu"
    }

    // MARK: Relecture de `meta` (clés en snake_case, converties)

    private struct MetaServi: Decodable {
        let affaire: AffaireServie?
    }

    private struct AffaireServie: Decodable {
        let debut: String?
        let fin: String?
        let echeance: EcheanceServie?
    }

    private struct EcheanceServie: Decodable {
        let etat: String
        let libelle: String?
        let plusieursJours: Bool?
    }
}
