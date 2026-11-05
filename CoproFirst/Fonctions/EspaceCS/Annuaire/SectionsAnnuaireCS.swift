// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Conseil Syndical » : l'AG et la communauté WhatsApp, puis une carte par membre.
struct SectionConseilCS: View {
    let lecture: EtatAnnuaireCS.Lecture<ConseilCS>
    let installation: Installation
    let ouvrir: (FeuilleAnnuaireCS, _ retirer: Bool) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        SectionAnnuaireCS(titre: TextesAnnuaire.conseil, lecture: lecture, id: "cs.annuaire.conseil") { conseil in
            EnteteFiche(id: "cs.annuaire.conseil.modifier") { ouvrir(.enteteConseil, false) } contenu: {
                Text(TextesAnnuaireCS.ag(conseil.agAnnee, le: conseil.agDate))
                    .font(.subheadline).foregroundStyle(palette.text)
                if let lien = conseil.whatsappUrl?.nulSiVide.flatMap(URL.init(string:)) {
                    Link(destination: lien) {
                        Label(TextesAnnuaire.whatsapp, systemImage: "bubble.left.and.bubble.right")
                    }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.primary)
                }
            }
            if conseil.membres.isEmpty {
                Text(TextesAnnuaire.aucunMembre).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            ForEach(Array(conseil.membres.enumerated()), id: \.offset) { rang, membre in
                FicheAnnuaireCS(
                    personne: membre.enCarte, medaillons: membre.enCarte.medaillonsDuConseil(site: installation.nom),
                    principal: false,
                    installation: installation, id: "cs.annuaire.conseil.\(rang)",
                    gestes: [
                        .init(TextesEspaceCS.modifier, "pencil") { ouvrir(.membreConseil(rang), false) },
                        .init(TextesEspaceCS.supprimer, "trash", destructif: true) {
                            ouvrir(.membreConseil(rang), true)
                        },
                    ]
                ) {
                    if let lieu = membre.batimentNom?.nulSiVide {
                        Text(TextesAnnuaireCS.batiment(lieu)).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                    if membre.userId != nil {
                        Label(TextesAnnuaireCS.inscritLie, systemImage: "link").font(.footnote)
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            BoutonAjout(libelle: TextesAnnuaireCS.nouveauMembreCS, id: "cs.annuaire.conseil.ajouter") {
                ouvrir(.membreConseil(nil), false)
            }
        }
    }
}

/// « Syndic » : le cabinet, son adresse et son espace client, puis ses interlocuteurs
/// dans l'ordre choisi — l'interlocuteur principal mis en avant.
struct SectionSyndicCS: View {
    let lecture: EtatAnnuaireCS.Lecture<SyndicCS>
    let installation: Installation
    let ouvrir: (FeuilleAnnuaireCS, _ retirer: Bool) -> Void
    let deplacer: (_ rang: Int, _ sens: Int) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        SectionAnnuaireCS(titre: TextesAnnuaire.syndic, lecture: lecture, id: "cs.annuaire.syndic") { syndic in
            EnteteFiche(id: "cs.annuaire.syndic.modifier") { ouvrir(.enteteSyndic, false) } contenu: {
                Text(syndic.nomSyndic?.nulSiVide ?? TextesAnnuaireCS.nomSyndicAbsent)
                    .font(.headline).foregroundStyle(palette.text)
                if let adresse = syndic.adresse?.nulSiVide {
                    Text(adresse).font(.subheadline).foregroundStyle(palette.textMuted)
                }
                if let lien = syndic.siteWeb?.nulSiVide.flatMap(URL.init(string:)) {
                    Link(destination: lien) { Label(TextesAnnuaire.espaceClient, systemImage: "globe") }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.primary)
                }
            }
            if syndic.membres.isEmpty {
                Text(TextesAnnuaire.aucunContact).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            ForEach(Array(syndic.membres.enumerated()), id: \.offset) { rang, membre in
                let principal = membre.estPrincipal == true
                FicheAnnuaireCS(
                    personne: membre.enCarte,
                    medaillons: membre.enCarte.medaillonsDuSyndic,
                    principal: principal, installation: installation, id: "cs.annuaire.syndic.\(rang)",
                    gestes: gestes(rang, total: syndic.membres.count)
                ) {
                    if let fonction = membre.fonction?.nulSiVide {
                        Text(fonction).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                    Coordonnees(personne: membre.enCarte)
                }
            }
            BoutonAjout(libelle: TextesAnnuaireCS.nouveauMembreSyndic, id: "cs.annuaire.syndic.ajouter") {
                ouvrir(.membreSyndic(nil), false)
            }
        }
    }

    private func gestes(_ rang: Int, total: Int) -> [GesteFiche] {
        var gestes: [GesteFiche] = [.init(TextesEspaceCS.modifier, "pencil") { ouvrir(.membreSyndic(rang), false) }]
        if rang > 0 { gestes.append(.init(TextesAnnuaireCS.monter, "arrow.up") { deplacer(rang, -1) }) }
        if rang < total - 1 { gestes.append(.init(TextesAnnuaireCS.descendre, "arrow.down") { deplacer(rang, 1) }) }
        gestes.append(.init(TextesEspaceCS.supprimer, "trash", destructif: true) { ouvrir(.membreSyndic(rang), true) })
        return gestes
    }
}

/// Une section de l'annuaire : son titre, puis sa fiche une fois lue.
private struct SectionAnnuaireCS<Valeur: Equatable & Sendable, Contenu: View>: View {
    let titre: String
    let lecture: EtatAnnuaireCS.Lecture<Valeur>
    let id: String
    @ViewBuilder let contenu: (Valeur) -> Contenu
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titre).font(.titre(.title2)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            switch lecture {
            case .chargement:
                Carte { Text(TextesAnnuaireCS.squelette).font(.subheadline) }
                    .redacted(reason: .placeholder)
                    .accessibilityLabel("Chargement")
            case .erreur(let phrase):
                MessageErreur(texte: phrase)
            case .pret(let valeur):
                contenu(valeur)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }
}

/// L'en-tête d'une fiche (l'AG, le cabinet) et son crayon.
private struct EnteteFiche<Contenu: View>: View {
    let id: String
    let modifier: () -> Void
    @ViewBuilder let contenu: () -> Contenu
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) { contenu() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: modifier) { Image(systemName: "pencil") }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(palette.primary)
                .accessibilityLabel(TextesEspaceCS.modifier)
                .accessibilityIdentifier(id)
        }
    }
}

private struct BoutonAjout: View {
    let libelle: String
    let id: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) { Label(libelle, systemImage: "plus") }
            .buttonStyle(.bordered)
            .tint(palette.primary)
            .accessibilityIdentifier(id)
    }
}

/// Un geste du menu d'une fiche.
struct GesteFiche: Identifiable {
    let libelle: String
    let symbole: String
    var destructif = false
    let action: () -> Void
    var id: String { libelle }

    init(_ libelle: String, _ symbole: String, destructif: Bool = false, action: @escaping () -> Void) {
        self.libelle = libelle
        self.symbole = symbole
        self.destructif = destructif
        self.action = action
    }
}

/// Une fiche : la carte de l'Annuaire, et ses gestes dans un menu « … » (ou par un
/// appui long).
private struct FicheAnnuaireCS<Detail: View>: View {
    let personne: Annuaire.Membre
    let medaillons: [Medaille]
    let principal: Bool
    let installation: Installation
    let id: String
    let gestes: [GesteFiche]
    @ViewBuilder let detail: () -> Detail
    @Environment(\.palette) private var palette

    var body: some View {
        CarteContact(personne: personne, medaillons: medaillons, principal: principal, installation: installation) {
            detail()
        }
        .overlay(alignment: .topTrailing) {
            Menu { boutons } label: {
                Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(palette.primary)
                    .frame(minWidth: Mise.cible, minHeight: Mise.cible)
            }
            .accessibilityLabel(TextesAnnuaireCS.gestes(personne.nomComplet))
            .accessibilityIdentifier("\(id).gestes")
        }
        .contextMenu { boutons }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var boutons: some View {
        ForEach(gestes) { geste in
            Button(role: geste.destructif ? .destructive : nil, action: geste.action) {
                Label(geste.libelle, systemImage: geste.symbole)
            }
        }
    }
}

extension MembreConseil {
    /// La fiche telle que l'Annuaire la rend (`CarteContact`).
    var enCarte: Annuaire.Membre {
        Annuaire.Membre(
            id: id ?? 0, genre: genre, prenom: prenom, nom: nom, batimentNom: batimentNom,
            estGestionnaireSite: estGestionnaireSite, estPresident: estPresident, photoUrl: photoUrl)
    }
}

extension MembreSyndic {
    var enCarte: Annuaire.Membre {
        Annuaire.Membre(
            id: id ?? 0, genre: genre, prenom: prenom, nom: nom, photoUrl: photoUrl, fonction: fonction, email: email,
            telephone: telephone, estPrincipal: estPrincipal)
    }
}
