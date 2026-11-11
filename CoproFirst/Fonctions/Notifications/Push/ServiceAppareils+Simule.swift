// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation

#if DEBUG
/// La table `appareil` de l'installation simulée, à la forme du serveur
/// (`utils/push/appareils.enregistrer`, `routers/appareils`) : un abonnement par
/// appareil et par résidence ; un même abonnement se RAFRAÎCHIT (jeton, environnement) ;
/// le retrait d'un abonnement inconnu rend 404 « Appareil introuvable » ; sans session,
/// 401 comme `get_current_user`. Les deux routes répondent 204, sans corps.
extension ServiceSimule: ServiceAppareils {
    /// Par hôte, les appareils enregistrés, rangés par abonnement.
    private var appareils: MagasinSimuleCS<[String: [String: AppareilPush]]> { MagasinSimuleCS.de(self) { [:] } }

    /// Ce que l'installation simulée garde pour cet hôte — lu par les tests.
    func appareilsEnregistres(_ installation: Installation) -> [AppareilPush] {
        Array((appareils.valeur[installation.hote] ?? [:]).values)
    }

    func enregistrerAppareil(_ appareil: AppareilPush, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(100))
        try exigerSessionOuverte(installation)
        appareils.modifier { tables in
            var table = tables[installation.hote] ?? [:]
            // Un même jeton sous un autre abonnement change de main : une ligne par jeton.
            table = table.filter { $0.value.jeton != appareil.jeton }
            table[appareil.abonnement] = appareil
            tables[installation.hote] = table
        }
    }

    func retirerAppareil(_ abonnement: String, dans installation: Installation) async throws {
        try await Task.sleep(for: .milliseconds(100))
        try exigerSessionOuverte(installation)
        let retire = appareils.modifier { $0[installation.hote]?.removeValue(forKey: abonnement) }
        if retire == nil { throw ErreurService.refus(.init(phrase: "Appareil introuvable")) }
    }

    /// Une installation simulée dont on s'est déconnecté refuse, comme `get_current_user`.
    private func exigerSessionOuverte(_ installation: Installation) throws {
        guard aUneSessionOuverte(installation) else { throw ErreurService.sessionExpiree }
    }
}
#endif
