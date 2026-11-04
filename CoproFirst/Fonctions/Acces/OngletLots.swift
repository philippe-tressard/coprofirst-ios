// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Mes lots » : la vue dépend de ce que l'on est, comme sur le site
/// (`mon-lot/+page.svelte`) — locataire, bailleur, ou la vue de tous les autres.
struct OngletLots: View {
    let etat: EtatAcces

    var body: some View {
        if etat.lots.isEmpty && !etat.droits.locataire {
            NoteAcces(
                titre: TextesAcces.aucunLot,
                texte: "\(TextesAcces.aucunLotDetail)\n\n\(TextesAcces.aucunLotAide)",
                pictogramme: "house")
        } else if etat.droits.locataire {
            LotsDuLocataire(bail: etat.bail, lots: etat.lots)
        } else if etat.droits.bailleur {
            LotsDuBailleur(lots: etat.lots, bauxActifs: etat.bauxActifs)
        } else {
            LotsStandard(lots: etat.lots)
        }
    }
}

/// La note qui tient la place du tableau des charges (calculé dans le front du site).
private struct ChargesSurLeSite: View {
    var body: some View {
        NoteAcces(titre: TextesAcces.charges, texte: TextesAcces.chargesSurLeSite, pictogramme: "chart.pie")
    }
}

/// Vue standard : un sélecteur de lot s'il y en a plusieurs, puis sa carte.
struct LotsStandard: View {
    let lots: [LotDuCompte]
    @State private var choisi: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if lots.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(TextesAcces.lotAffiche).styleLibelle()
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(lots) { lot in
                                Pastille(libelle: libelle(lot), retenue: lot.id == selection?.id) {
                                    withAnimation(.snappy(duration: 0.2)) { choisi = lot.id }
                                }
                                .accessibilityIdentifier("acces.lot.\(lot.id)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .sensoryFeedback(.selection, trigger: choisi)
                }
            }
            ChargesSurLeSite()
            if let lot = selection {
                Carte {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(TextesAcces.caracteristiques)
                            .font(.titre(.title3))
                            .foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                        CaracteristiquesDuLot(
                            lot: lot,
                            avant: [("Lot", lot.numero), ("Bâtiment", lot.batimentNom ?? FormatsDuSite.tiret)])
                    }
                }
                .id(lot.id)
                .transition(.opacity)
            }
        }
    }

    private var selection: LotDuCompte? { lots.first { $0.id == choisi } ?? lots.first }

    /// « Bât. A / Appartement - 15 » (`optionsLots` du site).
    private func libelle(_ lot: LotDuCompte) -> String {
        "\(lot.batimentNom ?? FormatsDuSite.tiret) / \(lot.type ?? FormatsDuSite.tiret) - \(lot.numero)"
    }
}

/// Vue locataire (`LotsLocataire.svelte`) : le lot loué par bail, puis ses lots.
struct LotsDuLocataire: View {
    let bail: BailDuLocataire?
    let lots: [LotDuCompte]
    @Environment(\.palette) private var palette

    var body: some View {
        let loues = lots.filter(\.loue)
        let possedes = lots.filter { !$0.loue }
        VStack(alignment: .leading, spacing: 12) {
            if let bail {
                Intertitre(titre: TextesAcces.lotLoue)
                carteDuBail(bail)
            } else if loues.isEmpty {
                NoteAcces(
                    titre: TextesAcces.aucunBailActif,
                    texte: "\(TextesAcces.aucunBailActifAide)\n\n\(TextesAcces.questionsLocationSurLeSite)",
                    pictogramme: "key")
            }
            if bail == nil, !loues.isEmpty {
                Intertitre(titre: TextesAcces.lotsLoues, compte: loues.count)
                ForEach(loues) { CarteLot(lot: $0) }
            }
            if !possedes.isEmpty {
                Intertitre(titre: TextesAcces.lotsEnPropriete, compte: possedes.count)
                ChargesSurLeSite()
                ForEach(possedes) { CarteLot(lot: $0) }
            }
        }
    }

    private func carteDuBail(_ bail: BailDuLocataire) -> some View {
        let lot = LotDuCompte(
            id: bail.id, numero: bail.lotNumero ?? FormatsDuSite.tiret, type: bail.lotType,
            typeAppartement: bail.lotTypeAppartement, etage: bail.lotEtage, superficie: bail.lotSuperficie,
            batimentNom: bail.lotBatimentNom)
        var apres = [("Entrée", FormatsDuSite.dateCourte(bail.dateEntree))]
        if bail.dateSortiePrevue != nil {
            apres.append(("Sortie prévue", FormatsDuSite.dateCourte(bail.dateSortiePrevue)))
        }
        let statut = LibellesAcces.statutBail(bail.statut)
        let proprietaire = LibellesAcces.nom(bail.bailleurPrenom, bail.bailleurNom)
        return Carte {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(lot.intitule).font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 8)
                    PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
                }
                CaracteristiquesDuLot(lot: lot, avant: [("Bâtiment", bail.lotBatimentNom ?? FormatsDuSite.tiret)])
                ForEach(Array(apres.enumerated()), id: \.offset) { _, ligne in
                    LigneFiche(libelle: ligne.0, valeur: ligne.1)
                }
                if proprietaire != FormatsDuSite.tiret {
                    Divider()
                    CoordonneesView(
                        titre: "\(TextesAcces.proprietaire) \(proprietaire)", email: bail.bailleurEmail,
                        telephone: bail.bailleurTelephone)
                }
            }
        }
    }
}

/// Vue bailleur (`LotsBailleur.svelte`) : ses lots, occupés ou vacants, et ses locataires.
struct LotsDuBailleur: View {
    let lots: [LotDuCompte]
    let bauxActifs: [Bail]
    @Environment(\.palette) private var palette

    var body: some View {
        let vacants = lots.filter { bail(du: $0) == nil }
        VStack(alignment: .leading, spacing: 12) {
            ChargesSurLeSite()
            Intertitre(titre: TextesAcces.lotsPossedes, compte: lots.count)
            ForEach(lots) { lot in
                let bail = bail(du: lot)
                CarteLot(lot: lot) {
                    PastilleTeinte(
                        libelle: bail == nil ? TextesAcces.vacant : TextesAcces.occupe,
                        badge: bail == nil ? "badge-gray" : "badge-green", compacte: true)
                } pied: {
                    if let bail {
                        Label(bail.nomLocataire, systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            let groupes = GroupesDeBaux.parLocataire(bauxActifs)
            if !groupes.isEmpty {
                Intertitre(titre: TextesAcces.locataires, compte: groupes.count)
                ForEach(groupes, id: \.cle) { groupe in
                    CarteLocataire(groupe: groupe, lots: lots)
                }
            }
            if !vacants.isEmpty {
                Intertitre(titre: TextesAcces.lotsVacants, compte: vacants.count)
                Text(TextesAcces.lotsVacantsAide).font(.subheadline).foregroundStyle(palette.textMuted)
            }
        }
    }

    private func bail(du lot: LotDuCompte) -> Bail? { bauxActifs.first { $0.lotId == lot.id } }
}

/// Un locataire et ses baux, dans la vue du bailleur.
private struct CarteLocataire: View {
    let groupe: GroupesDeBaux.Groupe
    let lots: [LotDuCompte]
    @Environment(\.palette) private var palette

    var body: some View {
        let premier = groupe.baux[0]
        let statut = LibellesAcces.statutBail(premier.statut)
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("👤 \(premier.nomLocataire)").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 8)
                    PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
                }
                CoordonneesView(email: premier.locataireEmail, telephone: premier.locataireTelephone)
                ForEach(groupe.baux) { bail in
                    VStack(alignment: .leading, spacing: 2) {
                        if let lot = lots.first(where: { $0.id == bail.lotId }) {
                            Text("\(lot.intitule) · \(lot.typeLu)")
                                .font(.subheadline.weight(.medium))
                        }
                        Text(periode(bail)).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                }
            }
        }
    }

    private func periode(_ bail: Bail) -> String {
        var texte = "Depuis le \(FormatsDuSite.dateCourte(bail.dateEntree))"
        if bail.dateSortiePrevue != nil {
            texte += " · Sortie prévue \(FormatsDuSite.dateCourte(bail.dateSortiePrevue))"
        }
        return texte
    }
}

/// Le regroupement des baux par locataire, comme le site le fait
/// (`locataire_id`, sinon le bail seul).
enum GroupesDeBaux {
    struct Groupe: Hashable {
        let cle: String
        var baux: [Bail]
    }

    static func parLocataire(_ baux: [Bail]) -> [Groupe] {
        var groupes: [Groupe] = []
        for bail in baux {
            if let i = groupes.firstIndex(where: { $0.cle == bail.cleLocataire }) {
                groupes[i].baux.append(bail)
            } else {
                groupes.append(Groupe(cle: bail.cleLocataire, baux: [bail]))
            }
        }
        return groupes
    }
}

/// Un courriel et un téléphone, touchables (`mailto:`, `tel:`).
struct CoordonneesView: View {
    var titre: String?
    let email: String?
    let telephone: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let titre { Text(titre).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text) }
            if let email, !email.isEmpty, let lien = URL(string: "mailto:\(email)") {
                Link(destination: lien) { Label(email, systemImage: "envelope") }
                    .font(.subheadline)
                    .frame(minHeight: Mise.cible, alignment: .leading)
            }
            if let telephone, !telephone.isEmpty {
                let chiffres = telephone.filter { $0.isNumber || $0 == "+" }
                if let lien = URL(string: "tel:\(chiffres)") {
                    Link(destination: lien) { Label(telephone, systemImage: "phone") }
                        .font(.subheadline)
                        .frame(minHeight: Mise.cible, alignment: .leading)
                }
            }
        }
        .tint(palette.primary)
    }
}
