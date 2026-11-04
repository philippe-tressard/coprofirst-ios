// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Gestion locative » (`OngletGestionLocative.svelte`), en LECTURE :
/// baux actifs ou archives, une carte par locataire, l'inventaire de chaque bail.
/// Les gestes d'écriture restent sur le site, et l'écran le dit (coprofirst#2507).
struct OngletLocation: View {
    let etat: EtatAcces
    @State private var archives = false
    @Environment(\.palette) private var palette

    var body: some View {
        let baux = archives ? etat.bauxTermines : etat.bauxActifs
        let groupes = GroupesDeBaux.parLocataire(baux)
        VStack(alignment: .leading, spacing: 12) {
            Picker("Baux", selection: $archives.animation(.snappy(duration: 0.22))) {
                Text(TextesAcces.bauxActifs(etat.bauxActifs.count)).tag(false)
                Text(TextesAcces.archives(etat.bauxTermines.count)).tag(true)
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: archives)
            .accessibilityIdentifier("acces.location.sousOnglet")
            if groupes.isEmpty {
                NoteAcces(texte: archives ? TextesAcces.aucunBailTermine : TextesAcces.aucunBailActifPoint)
            } else {
                ForEach(groupes, id: \.cle) { groupe in
                    CarteBaux(groupe: groupe, lots: etat.lots)
                }
            }
            Text(TextesAcces.gestesLocationSurLeSite)
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .padding(.top, 4)
        }
    }
}

/// Un locataire et ses baux : coordonnées, statut, dates, notes, inventaire.
private struct CarteBaux: View {
    let groupe: GroupesDeBaux.Groupe
    let lots: [LotDuCompte]
    @Environment(\.palette) private var palette

    var body: some View {
        let premier = groupe.baux[0]
        let statut = LibellesAcces.statutBail(premier.statut)
        Carte {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(premier.nomLocataire)
                        .font(.headline)
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    PastilleTeinte(libelle: statut.libelle, badge: statut.badge)
                }
                CoordonneesView(email: premier.locataireEmail, telephone: premier.locataireTelephone)
                ForEach(groupe.baux) { bail in
                    Divider()
                    UnBail(bail: bail, lot: lots.first { $0.id == bail.lotId }, plusieurs: groupe.baux.count > 1)
                }
            }
        }
    }
}

private struct UnBail: View {
    let bail: Bail
    let lot: LotDuCompte?
    let plusieurs: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let lot {
                    Text(lot.intitule).font(.subheadline.weight(.semibold))
                    PastilleTeinte(
                        libelle: lot.typeLu, badge: "badge-gray",
                        compacte: true)
                }
                if plusieurs {
                    let statut = LibellesAcces.statutBail(bail.statut)
                    PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
                }
            }
            LigneFiche(libelle: TextesAcces.entree, valeur: FormatsDuSite.dateCourte(bail.dateEntree))
            LigneFiche(libelle: TextesAcces.sortiePrevue, valeur: FormatsDuSite.dateCourte(bail.dateSortiePrevue))
            if bail.dateSortieReelle != nil {
                LigneFiche(libelle: TextesAcces.sortieReelle, valeur: FormatsDuSite.dateCourte(bail.dateSortieReelle))
            }
            if let notes = bail.notes, !notes.isEmpty {
                Text(TexteDuSite.riche(notes))
                    .font(.subheadline)
                    .tint(palette.primary)
            }
            Inventaire(objets: bail.objets)
        }
    }
}

/// L'inventaire d'un bail (`InventaireBail.svelte`), en lecture.
private struct Inventaire: View {
    let objets: [ObjetRemis]
    @Environment(\.palette) private var palette

    var body: some View {
        DisclosureGroup {
            if objets.isEmpty {
                Text(TextesAcces.aucunObjet).font(.subheadline).foregroundStyle(palette.textMuted)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(objets) { objet in ligne(objet) }
                }
                .padding(.top, 6)
            }
        } label: {
            Text(TextesAcces.inventaire(objets.count)).font(.subheadline.weight(.semibold))
        }
        .tint(palette.primary)
    }

    private func ligne(_ objet: ObjetRemis) -> some View {
        let statut = LibellesAcces.statutObjet(objet.statut)
        var details = ["Qté \(FormatsDuSite.nombre(objet.quantite))"]
        if let reference = objet.reference, !reference.isEmpty { details.append(reference) }
        details.append("Remis le \(FormatsDuSite.date(objet.remisLe))")
        if objet.renduLe != nil { details.append("Rendu le \(FormatsDuSite.date(objet.renduLe))") }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TablesDesComposants.typesObjet[objet.type] ?? objet.type).font(.subheadline)
                Text(objet.libelle).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                Spacer(minLength: 0)
                PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
            }
            Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(palette.textMuted)
        }
        .accessibilityElement(children: .combine)
    }
}
