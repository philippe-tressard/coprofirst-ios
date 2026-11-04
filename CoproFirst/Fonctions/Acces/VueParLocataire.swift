// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « 👥 Vue par locataire » (`OngletAcces.svelte`, bailleur seulement) : ce que
/// chaque locataire détient de ses accès, et « ↩ Tout récupérer ».
struct VueParLocataire: View {
    let baux: [Bail]
    let objets: [AccesDetenu]
    let installation: Installation
    let service: any ServiceAcces
    let etat: EtatAcces
    let recharger: () -> Void
    @State private var aRecuperer: GroupeAcces?
    @State private var erreur: String?
    @Environment(\.palette) private var palette

    var body: some View {
        let groupes = GroupeAcces.grouper(baux.filter(\.enCours), objets: objets)
        VStack(alignment: .leading, spacing: 12) {
            Intertitre(titre: TextesAcces.vueParLocataire)
            if let erreur { MessageErreur(texte: erreur) }
            if groupes.isEmpty {
                NoteAcces(texte: TextesAcces.aucunBailActifPoint)
            } else {
                Text(TextesAcces.vueParLocataireIntro).font(.subheadline).foregroundStyle(palette.textMuted)
                ForEach(groupes) { groupe in carte(groupe) }
            }
        }
        .confirmationDialog(
            TextesAcces.toutRecupererQuestion,
            isPresented: Binding(get: { aRecuperer != nil }, set: { if !$0 { aRecuperer = nil } }),
            titleVisibility: .visible, presenting: aRecuperer
        ) { groupe in
            Button(TextesAcces.toutRecuperer) { Task { await recuperer(groupe) } }
            Button(TextesAcces.annuler, role: .cancel) {}
        }
    }

    private func carte(_ groupe: GroupeAcces) -> some View {
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                Text(groupe.nom).font(.headline).foregroundStyle(palette.text)
                CoordonneesView(email: groupe.email, telephone: nil)
                if groupe.objets.isEmpty {
                    PastilleTeinte(libelle: TextesAcces.aucunAccesConfieBadge, badge: "badge-gray", compacte: true)
                } else {
                    HStack {
                        PastilleTeinte(
                            libelle: TextesAcces.accesConfiesCompte(groupe.objets.count), badge: "badge-yellow",
                            compacte: true)
                        Spacer(minLength: 8)
                        Button(TextesAcces.toutRecuperer) { aRecuperer = groupe }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primary)
                            .frame(minHeight: Mise.cible)
                    }
                    ForEach(groupe.objets) { objet in
                        let statut = LibellesAcces.statutAcces(objet.statut)
                        HStack(spacing: 8) {
                            Text(objet.code).font(.subheadline.monospaced())
                            // Écrit tel quel dans `OngletAcces.svelte` (vue par locataire).
                            PastilleTeinte(
                                libelle: objet.type == "vigik" ? "🏷️ Vigik" : "📡 TC",
                                badge: objet.type == "vigik" ? "badge-blue" : "badge-purple", compacte: true)
                            PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func recuperer(_ groupe: GroupeAcces) async {
        aRecuperer = nil
        do {
            for bail in groupe.bauxIds { try await service.recupererAcces(bail: bail, dans: installation) }
            erreur = nil
            etat.annoncer(TextesAcces.accesRecuperes)
            recharger()
        } catch {
            erreur = RefusDuServeur.phrase(error)
        }
    }
}

/// Un locataire, ses baux en cours et les objets qui lui sont confiés.
struct GroupeAcces: Identifiable, Hashable {
    let id: String
    let nom: String
    let email: String?
    var bauxIds: [Int]
    var objets: [AccesDetenu]

    /// Le groupement du site : courriel normalisé, sinon « prénom|nom » ; les objets
    /// d'un groupe sont ceux confiés (`chez_locataire`) au titre de l'un de ses baux.
    static func grouper(_ baux: [Bail], objets: [AccesDetenu]) -> [GroupeAcces] {
        var groupes: [GroupeAcces] = []
        for bail in baux {
            let email = bail.locataireEmail?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            let cle = email.isEmpty ? "\(bail.locatairePrenom ?? "")|\(bail.locataireNom ?? "")" : email
            if let i = groupes.firstIndex(where: { $0.id == cle }) {
                groupes[i].bauxIds.append(bail.id)
            } else {
                groupes.append(
                    GroupeAcces(
                        id: cle, nom: bail.nomLocataire, email: bail.locataireEmail, bauxIds: [bail.id], objets: []))
            }
        }
        for i in groupes.indices {
            let ids = Set(groupes[i].bauxIds)
            groupes[i].objets = objets.filter { ($0.chezLocataire ?? false) && ids.contains($0.bailId ?? -1) }
        }
        return groupes
    }
}
