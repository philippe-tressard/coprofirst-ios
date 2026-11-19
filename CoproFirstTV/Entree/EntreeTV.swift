// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Observation

/// L'entrée de l'écran de hall dans SA résidence (#218, lot 2) : l'adresse saisie — le
/// clavier de l'iPhone s'offre à l'Apple TV — ou la démo. Ni QR, ni lien universel, ni
/// Face ID : l'Apple TV n'a pas de caméra, et tvOS ne gère ni ces liens ni la biométrie.
/// Aucun mot de passe ne part d'ici : l'écran n'a pas de compte, il est appairé (lot 3).
@MainActor @Observable
final class EntreeTV {
    /// L'adresse en cours de saisie.
    var saisie = ""
    /// La résidence reconnue (GET /config, au plancher) — `nil` tant qu'il n'y en a pas.
    private(set) var residence: Installation?
    /// La vérification en cours, ou sa phrase d'échec — celle de l'iPhone.
    let decouverte = EtatDecouverte()
    private let service: any DecouvreInstallation

    init(service: any DecouvreInstallation = DecouverteAPI()) {
        self.service = service
    }

    /// L'adresse saisie, ramenée à `https://<hôte>` — `nil` tant qu'elle n'en est pas une :
    /// « Continuer » reste alors grisé.
    var adresseSaisie: URL? { AdresseInstallation.normaliser(saisie) }

    /// « Continuer » : la résidence de l'adresse saisie.
    func entrer() async {
        guard let adresse = adresseSaisie else { return }
        await reconnaitre(adresse)
    }

    /// « Essayer la démo » : la démonstration de CoproFirst, écrite dans l'app.
    func entrerEnDemo() async {
        guard let adresse = AdresseInstallation.normaliser(ContenuVitrine.adresseDemo) else { return }
        await reconnaitre(adresse)
    }

    /// « Changer de résidence » : retour à la saisie, l'adresse d'avant pré-remplie.
    func changer() {
        if let residence { saisie = AdresseInstallation.enSaisie(residence.adresse) }
        residence = nil
        decouverte.signaler(nil)
    }

    /// La résidence d'un écran retiré (lot 3) : l'appairage reprend, sans nouvelle saisie.
    func reprendre(_ residence: Installation) {
        self.residence = residence
        decouverte.signaler(nil)
    }

    private func reconnaitre(_ adresse: URL) async {
        guard !decouverte.enCours else { return }
        residence = await decouverte.decouvrir(adresse, avec: service)
    }
}
