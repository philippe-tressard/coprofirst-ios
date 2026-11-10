// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

/// Une installation simulée, pour les aperçus et les tests d'interface : aucune
/// requête ne part. Tout y est inventé — aucun nom de personne, aucune adresse réelle.
final class ServiceSimule: ServiceCoproFirst, @unchecked Sendable {
    /// Une résidence inventée, à sa palette (bouteille), avec la barre par défaut du site.
    static let residence = Installation(
        adresse: URL(string: "https://tilleuls.exemple.fr")!, nom: "Résidence Les Tilleuls", aUnLogo: false,
        codePalette: "bouteille", versionContrat: "1.15.0")
    /// La démonstration, telle que la simule l'app (sans requête) — au contrat qu'elle sert.
    static let demo = Installation(
        adresse: URL(string: "https://demo.coprofirst.fr")!, nom: "Résidence Les Glycines", aUnLogo: false,
        versionContrat: "1.14.0")

    /// La résidence que sert la découverte (GET /config simulé) : `residence`, ou celle
    /// qu'un argument de lancement a changée (`-logo-residence`, #70).
    var residenceServie = ServiceSimule.residence
    /// Le délai d'une réponse : assez pour voir le squelette, pas pour attendre.
    private let delai: Duration
    /// Les hôtes dont on s'est déconnecté : leur fil n'est plus lisible.
    private var deconnectes: Set<String> = []
    private let verrou = NSLock()
    /// Le profil servi par la résidence inventée (un compte du conseil syndical).
    var profilSimule = ProfilResidence(
        statut: "copropriétaire_résident", roles: ["résident", "propriétaire", "conseil_syndical"],
        libelleLogement: "Bât. A, T3, 2ème")

    init(delai: Duration = .milliseconds(450)) {
        self.delai = delai
    }

    func decouvrir(_ adresse: URL) async throws -> Installation {
        try await Task.sleep(for: delai)
        switch adresse.host() {
        case "inconnue.exemple.fr": throw ErreurService.hoteInconnu
        case "injoignable.exemple.fr": throw ErreurService.injoignable
        case "ancienne.exemple.fr":
            // Une installation sous le plancher (#83) : la découverte doit le dire.
            var ancienne = residenceServie
            (ancienne.adresse, ancienne.versionContrat) = (adresse, "1.12.0")
            return ancienne
        case "demo.coprofirst.fr": return Self.demo
        default:
            var installation = residenceServie
            installation.adresse = adresse
            return installation
        }
    }

    func connecter(_ installation: Installation, email: String, motDePasse: String) async throws {
        try await Task.sleep(for: delai)
        if motDePasse == "refuse" { throw ErreurService.identifiantsRefuses }
        _ = verrou.withLock { deconnectes.remove(installation.hote) }
    }

    func aUneSessionGardee(_ installation: Installation) -> Bool {
        verrou.withLock { gardees.contains(installation.hote) }
    }

    /// Les sessions « gardées » après Face ID — la simulation du Trousseau.
    private var gardees: Set<String> = []
    /// Face ID annulé à chaque demande (`-faceid-refuse`) : la session reste gardée,
    /// rien ne s'ouvre — comme `Trousseau.lire` qui rend `nil`.
    var refuserFaceID = false

    /// Une session gardée d'un passage précédent (`-ecran retour`).
    func garder(_ installation: Installation) {
        verrou.withLock { _ = gardees.insert(installation.hote) }
    }

    func reprendre(_ installation: Installation) async throws {
        guard aUneSessionGardee(installation), !refuserFaceID else { throw ErreurService.sessionExpiree }
        _ = verrou.withLock { deconnectes.remove(installation.hote) }
    }

    func activerFaceID(_ installation: Installation) async -> Bool {
        garder(installation)
        return true
    }

    func profil(_ installation: Installation) async throws -> ProfilResidence {
        try await Task.sleep(for: .milliseconds(200))
        try exigerSession(installation)
        return profilSimule
    }

    func deconnecter(_ installation: Installation) async -> Bool {
        try? await Task.sleep(for: .milliseconds(200))
        verrou.withLock {
            deconnectes.insert(installation.hote)
            gardees.remove(installation.hote)
        }
        return true
    }

    private func exigerSession(_ installation: Installation) throws {
        if verrou.withLock({ deconnectes.contains(installation.hote) }) { throw ErreurService.sessionExpiree }
    }

    func fil(_ installation: Installation) async throws -> [ElementDuFil] {
        try await Task.sleep(for: delai)
        try exigerSession(installation)
        return Self.fil
    }

    func entrerEnDemo(_ code: String) async throws -> Installation? {
        try await Task.sleep(for: delai)
        return Self.demo
    }
}

extension ServiceSimule {
    /// Le fil inventé : trois jours, toutes les natures, une urgence.
    static let fil: [ElementDuFil] = {
        let calendrier = Chronologie.calendrier
        let aujourdhui = calendrier.startOfDay(for: .now)
        func le(_ jours: Int, _ heure: Int) -> Date {
            let jour = calendrier.date(byAdding: .day, value: -jours, to: aujourdhui) ?? aujourdhui
            return calendrier.date(byAdding: .hour, value: heure, to: jour) ?? jour
        }
        // Le constructeur des éléments inventés : un paramètre par champ du fil.
        // swiftlint:disable:next function_parameter_count
        func element(
            _ id: String, _ type: String, _ date: Date, _ titre: String, _ detail: String?,
            badges: [String] = [], meConcerne: Bool = false, cible: CibleDuFil, meta: String? = nil
        ) -> ElementDuFil {
            ElementDuFil(
                id: "\(type):\(id)", type: type, date: date, titre: titre, detail: detail, badges: badges,
                publicationUrgente: false, statut: nil, meConcerne: meConcerne, cible: cible,
                echeance: meta.flatMap(EcheanceDuFil.init(metaJSON:)),
                natures: meta.flatMap(MetaDuFil.init(json:))?.affaire?.natures ?? [])
        }
        return [
            element(
                "41", "ticket_ouvert", le(0, 9), "Fuite d'eau au plafond du parking",
                "<p>Niveau -1, place 12. Le plombier passe dans la <em>matinée</em>.</p>", badges: ["urgent"],
                meConcerne: true,
                cible: .affaire(id: 41), meta: #"{"affaire": {"natures": ["activite"]}}"#),
            element(
                "12", "publication", le(0, 8), "Coupure d'eau jeudi de 9 h à 12 h",
                "Remplacement d'une vanne dans la cave du bâtiment A.", cible: .affaire(id: 12),
                meta: metaAffaire(
                    dans: 2, etat: "a_venir", libelle: "J-2", natures: ["actualite", "calendrier"])),
            element(
                "44", "ticket_mis_a_jour", le(0, 7), "Ramonage des conduits de cheminée",
                "Le ramoneur passe dans les caves du bâtiment B.", cible: .affaire(id: 44),
                meta: metaAffaire(dans: 0, etat: "jour_j", libelle: "Jour J")),
            element(
                "3", "sondage_ouvert", le(1, 18), "Quel jour pour la fête des voisins ?",
                "Trois dates proposées, réponses jusqu'à vendredi.", cible: .sondage(id: 3)),
            element(
                "7", "document", le(1, 11), "Procès-verbal de l'assemblée générale",
                "Ajouté dans Documents › Assemblées.", cible: .document(id: 7, nom: "proces-verbal-ag.pdf")),
            element(
                "2", "point_conseil", le(2, 17), "Point avec le syndic",
                "Ordre du jour : ascenseur, ravalement, contrat d'entretien.", cible: .resume(lien: nil)),
            element(
                "38", "ticket_mis_a_jour", le(2, 10), "Ravalement de la façade côté rue",
                "Le devis retenu sera présenté au conseil syndical.", meConcerne: true, cible: .affaire(id: 38),
                meta: metaAffaire(dans: 8, jusquA: 10, etat: "a_venir", libelle: "J-8")),
            element(
                "45", "ticket_mis_a_jour", le(3, 16), "Contrôle annuel de l'ascenseur",
                "Le rapport du contrôleur est attendu.", cible: .affaire(id: 45),
                meta: metaAffaire(dans: -3, etat: "passee", libelle: "Passé")),
            element(
                "31", "ticket_resolu", le(4, 15), "Portail du garage remis en service",
                "La carte électronique a été remplacée.", cible: .affaire(id: 31),
                meta: metaAffaire(dans: -4, etat: "close", libelle: nil)),
        ]
    }()

    /// `meta` d'une affaire datée, à la forme que sert coprofirst v3.79.0 (`meta.affaire`,
    /// `flux/commun.pastilles_affaire`) : début à 9 h, à `dans` jours d'aujourd'hui, et
    /// fin le jour `jusquA`. Le délai est celui du serveur simulé, écrit comme lui ; les natures,
    /// celles que `utils/nature_affaire` dérive (une actualité datée en porte deux).
    private static func metaAffaire(
        dans: Int, jusquA: Int? = nil, etat: String, libelle: String?, natures: [String] = ["calendrier"]
    ) -> String {
        let calendrier = Chronologie.calendrier
        func iso(_ jours: Int, heure: Int) -> String {
            let jour = calendrier.date(byAdding: .day, value: jours, to: calendrier.startOfDay(for: .now)) ?? .now
            let instant = calendrier.date(byAdding: .hour, value: heure, to: jour) ?? jour
            // UTC naïf, comme le serveur sérialise ses colonnes de date.
            return instant.formatted(
                Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day().dateTimeSeparator(.standard)
                    .time(includingFractionalSeconds: false))
        }
        let fin = jusquA.map { "\"\(iso($0, heure: 17))\"" } ?? "null"
        let delai = libelle.map { "\"\($0)\"" } ?? "null"
        return #"""
            {"affaire": {"debut": "\#(iso(dans, heure: 9))",
             "fin": \#(fin), "echeance": {"etat": "\#(etat)", "jours": \#(dans), "libelle": \#(delai),
             "plusieurs_jours": \#(jusquA != nil)},
             "natures": [\#(natures.map { "\"\($0)\"" }.joined(separator: ", "))]}}
            """#
    }
}
