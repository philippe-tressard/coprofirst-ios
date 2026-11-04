// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Contrats » (`OngletContrats.svelte`) : un résumé, les contrats groupés
/// par équipement et rangés par échéance, les archives repliées en bas.
struct OngletContrats: View {
    let donnees: DonneesPrestataires
    let installation: Installation
    let service: any ServicePrestataires
    @State private var archives: [Contrat]?
    @State private var deplie: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        let courants = donnees.contrats
        VStack(alignment: .leading, spacing: 14) {
            if courants.isEmpty && (archives ?? []).isEmpty {
                NoteAcces(titre: TextesPrestataires.aucunContrat, texte: "", pictogramme: "doc.text")
            } else {
                Text(resume(courants)).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                if courants.isEmpty {
                    NoteAcces(
                        titre: TextesPrestataires.aucunContratActif, texte: TextesPrestataires.contratsArchivesRanges)
                }
                ForEach(groupes(courants), id: \.code) { groupe in
                    Intertitre(titre: donnees.equipement(groupe.code))
                    ForEach(groupe.contrats) { carte($0) }
                }
                if let archives, !archives.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 10) { ForEach(archives) { carte($0, archive: true) } }.padding(.top, 8)
                    } label: {
                        Text("\(TextesPrestataires.archives) (\(archives.count))").font(.headline)
                    }
                    .tint(palette.primary)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: deplie)
        .task { archives = try? await service.contrats(installation, archives: true) }
    }

    private func carte(_ contrat: Contrat, archive: Bool = false) -> some View {
        CarteContrat(
            contrat: contrat, prestataire: donnees.prestataires.first { $0.id == contrat.prestataireId },
            archive: archive, installation: installation, service: service,
            deplie: Binding(get: { deplie == contrat.id }, set: { deplie = $0 ? contrat.id : nil }))
    }

    /// Le résumé en tête : actifs, sans échéance. Le site compte aussi les visites
    /// en retard et à venir : c'est une règle de son front, que l'app ne recopie pas
    /// (coprofirst#2507 demande `en_retard`).
    private func resume(_ contrats: [Contrat]) -> String {
        let sans = contrats.filter { $0.prochaineVisite == nil }.count
        var morceaux = [TextesPrestataires.contratsActifs(contrats.count)]
        if sans > 0 { morceaux.append(TextesPrestataires.sansEcheance(sans)) }
        return morceaux.joined(separator: " · ")
    }

    /// `groupesParEquipement` : l'ordre des équipements servis, puis l'alphabet.
    private func groupes(_ contrats: [Contrat]) -> [(code: String, contrats: [Contrat])] {
        var parCode: [String: [Contrat]] = [:]
        for contrat in contrats {
            // L'équipement tel que le contrat le porte : le repli du site sur la
            // spécialité du prestataire (`typeEquipementDuContrat`) n'est pas recopié.
            parCode[contrat.typeEquipement, default: []].append(contrat)
        }
        let rang = { (code: String) in donnees.equipements.first { $0.code == code }?.ordre ?? Int.max }
        return parCode.keys
            .sorted { rang($0) != rang($1) ? rang($0) < rang($1) : donnees.equipement($0) < donnees.equipement($1) }
            .map { ($0, parCode[$0, default: []].sorted(by: LibellesPrestataires.parEcheance)) }
    }
}

/// La carte d'un contrat (`CarteContrat.svelte`).
private struct CarteContrat: View {
    let contrat: Contrat
    let prestataire: Prestataire?
    let archive: Bool
    let installation: Installation
    let service: any ServicePrestataires
    @Binding var deplie: Bool
    @State private var documents: [DocumentContrat]?
    @Environment(\.palette) private var palette

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    deplie.toggle()
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(contrat.libelle).font(.headline).foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textMuted)
                            .rotationEffect(.degrees(deplie ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("contrat.\(contrat.id)")
                FlowCapsules {
                    if let prestataire {
                        PastilleTeinte(libelle: prestataire.nom, badge: "badge-gray", compacte: true)
                    } else {
                        PastilleTeinte(
                            libelle: TextesPrestataires.sansIntervenant, badge: "badge-orange", compacte: true)
                    }
                    if let numero = contrat.numeroContrat, !numero.isEmpty {
                        PastilleTeinte(libelle: "🔖 \(numero)", badge: "badge-gray", compacte: true)
                    }
                    if contrat.prochaineVisite == nil {
                        PastilleTeinte(
                            libelle: TextesPrestataires.sansEcheanceCapsule, badge: "badge-gray", compacte: true)
                    }
                    if let documents, !documents.isEmpty {
                        PastilleTeinte(libelle: "📄 \(documents.count)", badge: "badge-gray", compacte: true)
                    }
                }
                if deplie { detail.transition(.opacity) }
            }
        }
        .task { documents = try? await service.documents(contrat: contrat.id, dans: installation) }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text(TextesPrestataires.leContrat).styleLibelle()
            LigneFiche(libelle: TextesPrestataires.debut, valeur: "📅 \(FormatsDuSite.dateCourte(contrat.dateDebut))")
            if let valeur = contrat.dureeValeur {
                LigneFiche(
                    libelle: TextesPrestataires.dureeInitiale,
                    valeur: "\(FormatsDuSite.nombre(valeur)) \(contrat.dureeUnite ?? "")")
            }
            if contrat.prochaineVisite != nil {
                LigneFiche(
                    libelle: TextesPrestataires.prochaineVisite,
                    valeur: "🗓 \(FormatsDuSite.dateCourte(contrat.prochaineVisite))")
            }
            if let notes = contrat.notes, !notes.isEmpty {
                Text(TextesPrestataires.description).styleLibelle().padding(.top, 4)
                Text(TexteDuSite.riche(notes)).font(.subheadline).tint(palette.primary)
            }
            Text(TextesPrestataires.documents(documents?.count ?? 0)).styleLibelle().padding(.top, 4)
            if let documents, !documents.isEmpty {
                ForEach(documents) { document in
                    NavigationLink {
                        DocumentView(
                            id: document.id, nom: document.fichierNom, titre: document.titre,
                            installation: installation)
                    } label: {
                        Label(document.titre, systemImage: "doc.text").font(.subheadline)
                            .frame(minHeight: Mise.cible, alignment: .leading)
                    }
                    .tint(palette.primary)
                }
            } else {
                Text(TextesPrestataires.aucunDocument).font(.subheadline).foregroundStyle(palette.textMuted)
            }
        }
    }
}
