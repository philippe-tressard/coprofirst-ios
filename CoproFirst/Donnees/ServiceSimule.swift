// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
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
    /// Le délai du détail d'une affaire ; `-delai-detail <ms>` l'allonge, pour jouer le
    /// runner lent de la CI (#98).
    var delaiDetail: Duration = .milliseconds(500)
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

    func connecter(_ hote: HoteConfirme, email: String, motDePasse: String) async throws {
        verrou.withLock { motsDePasseRecus.append(hote.installation.adresse) }
        try await Task.sleep(for: delai)
        if motDePasse == "refuse" { throw ErreurService.identifiantsRefuses }
        _ = verrou.withLock { deconnectes.remove(hote.installation.hote) }
    }

    /// Les adresses qui ont reçu un mot de passe, dans l'ordre (#82).
    var adressesAyantRecuUnMotDePasse: [URL] { verrou.withLock { motsDePasseRecus } }
    private var motsDePasseRecus: [URL] = []

    /// La résidence inventée et la démo déclarent l'app ; `sans-app.exemple.fr` sert un
    /// fichier qui ne la déclare pas ; tout autre hôte n'en sert aucun (#82).
    func preuve(_ adresse: URL) async -> PreuveHote {
        try? await Task.sleep(for: delai)
        switch adresse.host() {
        case residenceServie.hote, Self.demo.hote: return .declaree
        case "sans-app.exemple.fr": return .sansLApp
        default: return .absente
        }
    }

    func aUneSessionGardee(_ installation: Installation) -> Bool {
        verrou.withLock { gardees.contains(installation.hote) }
    }

    /// Les sessions « gardées » après Face ID — la simulation du Trousseau.
    private var gardees: Set<String> = []
    /// Face ID annulé à chaque demande (`-faceid-refuse`) : la session reste gardée,
    /// rien ne s'ouvre — comme `Trousseau.lire` qui rend `nil`.
    var refuserFaceID = false
    /// Ce qui protège la session gardée (`-protection appareil|aucune`, #84).
    var protectionSimulee: ProtectionSession = .biometrie("Face ID")

    /// Une session gardée d'un passage précédent (`-ecran retour`).
    func garder(_ installation: Installation) {
        verrou.withLock { _ = gardees.insert(installation.hote) }
    }

    func reprendre(_ installation: Installation) async throws {
        guard aUneSessionGardee(installation), !refuserFaceID else { throw ErreurService.sessionExpiree }
        _ = verrou.withLock { deconnectes.remove(installation.hote) }
    }

    func activerFaceID(_ installation: Installation) async -> ProtectionSession? {
        garder(installation)
        return protectionSimulee
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
        if !aUneSessionOuverte(installation) { throw ErreurService.sessionExpiree }
    }

    /// La session de cet hôte est-elle ouverte (pas de déconnexion depuis) ?
    func aUneSessionOuverte(_ installation: Installation) -> Bool {
        !verrou.withLock { deconnectes.contains(installation.hote) }
    }

    func fil(_ installation: Installation) async throws -> [ElementDuFil] {
        try await Task.sleep(for: delai)
        try exigerSession(installation)
        return Apercu.fil
    }

    func entrerEnDemo(_ code: String) async throws -> Installation? {
        try await Task.sleep(for: delai)
        return Self.demo
    }
}
#endif
