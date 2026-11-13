// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Les textes du fil d'une affaire (#178) — les titres sont ceux des rubriques du site
/// (`CorpsCarteTicket`, `ComptesRendusAffaire`, `SyntheseFil`).
enum TextesFil {
    static let demande = "La demande"
    static let suite = "La suite"
    static let comptesRendus = "Comptes rendus"
    static let synthese = "La synthèse"
    static let aucuneSuite = "Aucune suite pour l'instant."
    static let aucunCompteRendu = "Aucun pour l'instant."
    static let aucunCompteRenduClos = "Aucun compte rendu."
    static let comptesRendusIllisibles = "Comptes rendus indisponibles."
    static let aVenir = "À venir"
    static let brouillon = "Brouillon à relire, puis valider"
    static let csEtPresents = "CS et présents"
    static let partieSynthese = "Synthèse"
    static let difficultes = "Difficultés"
    static let amelioration = "Amélioration"
    static let garderOuvert = "Garder ouvert"
    static let nePlusGarderOuvert = "Ne plus garder ouvert"
    static let copier = "Copier le texte"

    static func suites(_ nombre: Int) -> String { nombre > 1 ? "\(nombre) suites" : "1 suite" }
    static func points(_ nombre: Int) -> String {
        nombre > 1 ? "\(nombre) points CS / Syndic" : "1 point CS / Syndic"
    }
    static func dernierPoint(_ debut: Date) -> String {
        "Dernier point CS / Syndic le \(FormatsDuSite.date(debut))"
    }
    static func point(_ debut: Date) -> String { "Point CS / Syndic du \(FormatsDuSite.dateHeure(debut))" }
    static func validee(_ le: Date?) -> String { le.map { "Validée le \(FormatsDuSite.date($0))" } ?? "Validée" }
}

/// Un élément du fil sous une section : une entrée de la suite, un compte rendu, une
/// partie de la synthèse. Plié, il tient en un titre, une ligne et un aperçu ; ouvert, il
/// montre son texte et ses pièces.
struct ElementFil: Identifiable, Hashable {
    let id: String
    let titre: String
    let ligne: String
    let apercu: String?
    let html: String?
    var precise: String?
    var pieces: PiecesJointes = .aucune
    var realise = true
    /// L'entrée de la suite qu'il montre : ses gestes servis (#91, #93) s'y posent.
    var suite: SuiteAffaire?
}

/// Une section du fil — un jalon sur le rail, ses éléments en retrait.
struct EtapeFil: Identifiable, Hashable {
    enum Cle: String, Hashable { case demande, suite, comptesRendus = "comptes-rendus", synthese }
    /// Pleine pour le réalisé, anneau de la charte pour ce qui avance, anneau gris à venir.
    enum Etat: Hashable { case realise, enCours, aVenir }

    let cle: Cle
    let titre: String
    let etat: Etat
    /// Ce qu'elle dit sous son titre : un compte, une date, ou son absence.
    let meta: String
    /// Ce qu'elle dit PLIÉE, sur une ligne — l'état, jamais l'invitation (`RubriqueEtape`).
    var resumePlie: String?
    var elements: [ElementFil] = []
    /// Le fil des suites d'une affaire ouverte reste ouvert : on n'en connaît pas le nombre.
    var ouverteALaSuite = false

    var id: Cle { cle }
    /// La suite et les comptes rendus se plient, quand ils ont de quoi l'être.
    var pliable: Bool { (cle == .suite || cle == .comptesRendus) && !elements.isEmpty }
}

extension EtapeFil {
    /// Les sections de l'affaire, dans l'ordre du site. Une actualité n'a ni compte rendu
    /// ni synthèse ; une affaire close sans synthèse n'en montre pas (`SyntheseFil`).
    static func du(_ affaire: DetailAffaire) -> [EtapeFil] {
        var etapes = [demande(affaire), suite(affaire)]
        guard !affaire.estActualite else { return etapes }
        etapes.append(comptesRendus(affaire.comptesRendus, close: affaire.close))
        if let synthese = synthese(affaire) { etapes.append(synthese) }
        return etapes
    }

    static func demande(_ affaire: DetailAffaire) -> EtapeFil {
        let meta = [FormatsDuSite.date(affaire.creeLe), affaire.auteur].compactMap(\.self).joined(separator: " · ")
        return EtapeFil(cle: .demande, titre: TextesFil.demande, etat: .realise, meta: meta)
    }

    static func suite(_ affaire: DetailAffaire) -> EtapeFil {
        // La Suite qui porte la synthèse n'est pas une étape : elle est sa conclusion
        // (`entreesDuFil` du site).
        let entrees = affaire.suites.filter { $0.type != "synthese" }
        let etat: Etat = affaire.close ? .realise : entrees.isEmpty ? .aVenir : .enCours
        var etape = EtapeFil(
            cle: .suite, titre: TextesFil.suite, etat: etat,
            meta: entrees.isEmpty ? TextesFil.aucuneSuite : TextesFil.suites(entrees.count))
        etape.elements = entrees.map { element($0, referentiels: affaire.referentiels) }
        etape.resumePlie = entrees.max { $0.date < $1.date }.map { resume($0, referentiels: affaire.referentiels) }
        etape.ouverteALaSuite = !affaire.close
        return etape
    }

    /// « Chez le syndic le 9 nov. 2026 — Le syndic est prévenu… » (`resumeEntree` du site).
    static func resume(_ suite: SuiteAffaire, referentiels: ReferentielsAffaires) -> String {
        let date = FormatsDuSite.date(suite.date)
        let tete =
            suite.nouveauStatut.map {
                "\(StatutsAffaire.libelle($0, servi: suite.nouveauStatutLibelle, dans: referentiels)) le \(date)"
            } ?? date
        guard let texte = suite.contenu.map(TexteDuSite.apercu), !texte.isEmpty else { return tete }
        return "\(tete) — \(texte)"
    }

    static func element(_ suite: SuiteAffaire, referentiels: ReferentielsAffaires) -> ElementFil {
        let changement = suite.changementDEtat(referentiels)
        let auteur = suite.auteur ?? "La résidence"
        let ligne = [changement == nil ? nil : auteur, FormatsDuSite.dateHeure(suite.date)].compactMap(\.self)
        return ElementFil(
            id: "suite.\(suite.id)", titre: changement ?? auteur, ligne: ligne.joined(separator: " · "),
            apercu: suite.contenu.map(TexteDuSite.apercu).flatMap(\.nulSiVide), html: suite.contenu,
            precise: suite.perimetrePrecise, pieces: suite.pieces, suite: suite)
    }

    static func comptesRendus(_ lus: [CompteRenduAffaire]?, close: Bool = false) -> EtapeFil {
        guard let lus else {
            return EtapeFil(
                cle: .comptesRendus, titre: TextesFil.comptesRendus, etat: .aVenir,
                meta: TextesFil.comptesRendusIllisibles)
        }
        guard let dernier = lus.max(by: { $0.debut < $1.debut }) else {
            return EtapeFil(
                cle: .comptesRendus, titre: TextesFil.comptesRendus, etat: .aVenir,
                meta: close ? TextesFil.aucunCompteRenduClos : TextesFil.aucunCompteRendu)
        }
        var etape = EtapeFil(
            cle: .comptesRendus, titre: TextesFil.comptesRendus, etat: .realise, meta: TextesFil.points(lus.count))
        etape.resumePlie = TextesFil.dernierPoint(dernier.debut)
        etape.elements = lus.sorted { $0.debut > $1.debut }.map { cr in
            ElementFil(
                id: "cr.\(cr.id)", titre: TextesFil.point(cr.debut),
                ligne: [cr.ou, cr.conseilSeul ? TextesFil.csEtPresents : nil].compactMap(\.self)
                    .joined(separator: " · "),
                apercu: TexteDuSite.apercu(cr.contenu).nulSiVide, html: cr.contenu)
        }
        return etape
    }

    static func synthese(_ affaire: DetailAffaire) -> EtapeFil? {
        guard let synthese = affaire.synthese else {
            return affaire.close
                ? nil : EtapeFil(cle: .synthese, titre: TextesFil.synthese, etat: .aVenir, meta: TextesFil.aVenir)
        }
        var etape = EtapeFil(
            cle: .synthese, titre: TextesFil.synthese, etat: synthese.validee ? .realise : .enCours,
            meta: synthese.validee ? TextesFil.validee(synthese.valideeLe) : TextesFil.brouillon)
        let parties = [
            partie("texte", TextesFil.partieSynthese, synthese.texte),
            partie("difficultes", TextesFil.difficultes, synthese.difficultes),
            partie("amelioration", TextesFil.amelioration, synthese.amelioration),
        ]
        etape.elements = parties.compactMap(\.self).map { partie in
            var lue = partie
            lue.realise = synthese.validee
            return lue
        }
        return etape
    }

    /// Une partie de la synthèse, si elle dit quelque chose.
    private static func partie(_ cle: String, _ titre: String, _ texte: String?) -> ElementFil? {
        guard let texte = texte?.nulSiVide else { return nil }
        return ElementFil(
            id: "synthese.\(cle)", titre: titre, ligne: "", apercu: TexteDuSite.apercu(texte), html: texte)
    }
}
