// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Badges & télécommandes » (onglet `badges`, `BadgesCopropriete.svelte`) : qui
/// détient quoi. La recherche en tête (code, porteur, lot), le type dessous, puis le
/// parc, rangé par porteur — la question qu'on pose à cette liste est « que détient
/// cette personne ».
///
/// Consultation seule dans l'app : enregistrer, corriger, exporter et retirer un accès
/// se font sur le site (la note de `Parite/PARITE.md` le dit).
struct OngletBadgesCS: OngletDePage {
    let contexte: ContexteOnglet
    @State private var parc: [AccesDuParc]?
    /// L'arbre servi, pour dire ce qu'un accès ouvre ; sans lui, rien plutôt qu'un code.
    @State private var perimetres: [Perimetre] = []
    @State private var erreur: String?
    @State private var recherche = ""
    @State private var type: TypeAcces?
    @Environment(\.palette) private var palette

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceBadges {
            contenu(service)
                .task(id: contexte.actualisation) { await charger(service) }
        } else {
            MessageErreur(texte: TextesEspaceCS.serviceAbsent)
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceBadgesCS) -> some View {
        if let parc {
            liste(parc)
        } else if let erreur {
            VStack(alignment: .leading, spacing: 8) {
                Text(TextesBadgesCS.erreurTitre).font(.headline).foregroundStyle(palette.text)
                MessageErreur(texte: erreur) { Task { await charger(service) } }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    CarteAccesDuParc(acces: TextesBadgesCS.exempleSquelette, perimetres: [])
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityLabel("Chargement")
        }
    }

    @ViewBuilder
    private func liste(_ parc: [AccesDuParc]) -> some View {
        if parc.isEmpty {
            ContentUnavailableView(
                TextesBadgesCS.videTitre, systemImage: "key.slash", description: Text(TextesBadgesCS.videMessage))
        } else {
            let filtres = filtrer(parc)
            VStack(alignment: .leading, spacing: 12) {
                ChampRecherche(
                    texte: $recherche, indication: TextesBadgesCS.recherche, identifiant: "cs.badges.recherche")
                FiltreTypes(type: $type)
                if filtres.isEmpty {
                    Text(TextesBadgesCS.aucunResultat).font(.subheadline).foregroundStyle(palette.textMuted)
                }
                LazyVStack(spacing: 10) {
                    ForEach(filtres) { CarteAccesDuParc(acces: $0, perimetres: perimetres) }
                }
                Text(TextesBadgesCS.compte(filtres.count, sur: parc.count))
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
                    .accessibilityIdentifier("cs.badges.compte")
            }
            .animation(.snappy(duration: 0.2), value: filtres.map(\.id))
        }
    }

    private func filtrer(_ parc: [AccesDuParc]) -> [AccesDuParc] {
        parc.filter { acces in
            (type == nil || acces.type == type)
                && Recherche.contientTousLesMots([acces.code, acces.porteurNom, acces.lotLibelle], recherche)
        }
        .sorted(by: AccesDuParc.parPorteur)
    }

    private func charger(_ service: any ServiceBadgesCS) async {
        do {
            async let lus = service.parc(contexte.installation)
            async let arbre = try? service.perimetres(contexte.installation)
            (parc, perimetres) = try await (lus, arbre ?? perimetres)
            erreur = nil
        } catch {
            if parc == nil { erreur = ErreurService.phrase(error, sinon: TextesBadgesCS.erreurTitre) }
        }
    }
}

/// Le filtre « Type » : Tous, puis les familles du site (`TYPES_ACCES`, généré).
private struct FiltreTypes: View {
    @Binding var type: TypeAcces?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TextesBadgesCS.type).styleLibelle()
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Pastille(libelle: TextesBadgesCS.tous, retenue: type == nil) { type = nil }
                    ForEach(TypeAcces.allCases) { option in
                        Pastille(libelle: option.libelle, retenue: type == option) {
                            withAnimation(.snappy(duration: 0.2)) { type = type == option ? nil : option }
                        }
                        .accessibilityIdentifier("cs.badges.type.\(option.rawValue)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .sensoryFeedback(.selection, trigger: type)
        }
    }
}

/// Un accès du parc : son code, son type et son état, puis qui le porte, pour quel lot,
/// et ce qu'il ouvre.
private struct CarteAccesDuParc: View {
    let acces: AccesDuParc
    let perimetres: [Perimetre]
    @Environment(\.palette) private var palette

    var body: some View {
        let ouvre = Perimetre.libelles(acces.perimetreCible, parmi: perimetres)
        Carte {
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) { entete }
                    VStack(alignment: .leading, spacing: 4) { entete }
                }
                if !acces.porteurNom.isEmpty {
                    Label(acces.porteurNom, systemImage: "person").font(.subheadline).foregroundStyle(palette.text)
                }
                if let lot = acces.lotLibelle {
                    Label(lot, systemImage: "house").font(.subheadline).foregroundStyle(palette.textMuted)
                }
                if !ouvre.isEmpty {
                    Label(ouvre.joined(separator: ", "), systemImage: "door.left.hand.open")
                        .font(.subheadline).foregroundStyle(palette.textMuted)
                }
                if acces.chezLocataire {
                    Text(TextesBadgesCS.chezLocataire).font(.footnote).foregroundStyle(palette.textMuted)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityIdentifier("cs.badge.\(acces.id)")
    }

    @ViewBuilder
    private var entete: some View {
        Text(acces.code).font(.headline.monospaced()).foregroundStyle(palette.text)
        Text(acces.type.libelle).font(.subheadline).foregroundStyle(palette.textMuted)
        Spacer(minLength: 0)
        let statut = LibellesAcces.statutAcces(acces.statut)
        PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
    }
}

/// Les mots de l'onglet, repris du site (`BadgesCopropriete.svelte`).
enum TextesBadgesCS {
    static let recherche = "4521, Dupont, appartement 12…"
    static let type = "Type"
    static let tous = "Tous"
    static let erreurTitre = "Impossible d’afficher les badges"
    static let videTitre = "Aucun badge enregistré"
    static let videMessage =
        "Les badges apparaissent ici une fois l’import Excel résolu, ou déclarés par leurs porteurs."
    static let aucunResultat = "Aucun badge ne correspond à cette recherche."
    static let chezLocataire = "Confié au locataire"

    static func compte(_ n: Int, sur total: Int) -> String {
        let badges = "\(FormatsDuSite.nombre(n)) badge\(n > 1 ? "s" : "")"
        return n == total ? badges : "\(badges) sur \(FormatsDuSite.nombre(total))"
    }

    static let exempleSquelette = AccesDuParc(
        type: .vigik, numero: 0, code: "0000", porteurNom: "Prénom Nom", porteurRang: 0, porteurId: nil,
        lotLibelle: "Lot 00 — appartement",
        perimetreCible: [], statut: "actif", chezLocataire: false)
}
