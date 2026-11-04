// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes de l'Annuaire, comme le site les écrit (`pages.ts`, `annuaire/+page.svelte`).
enum TextesAnnuaire {
    static let titre = "Annuaire"
    static let descriptif =
        "Coordonnées des membres du Conseil Syndical et du Syndic. En cas d'urgence, contactez le syndic "
        + "directement par téléphone. Sinon, faites une demande depuis la plateforme."
    static let conseil = "Conseil Syndical"
    static let syndic = "Syndic"
    static let whatsapp = "Groupe WhatsApp copropriété"
    static let espaceClient = "Espace client"
    static let aucunMembre = "Aucun membre CS enregistré."
    static let aucunContact = "Aucun contact syndic enregistré."
    static let sansBatiment = "Sans bâtiment"
    static let president = "Président du Conseil Syndical"
    static let principal = "Gestionnaire principal"

    static func gestionnaire(_ site: String) -> String { "Gestionnaire \(site)" }

    /// « Voté en AG 2026 - 12 juin 2026 ».
    static func voteEnAG(_ annee: Int, le date: Date?) -> String {
        "Voté en AG \(String(annee))" + (date.map { " - \($0.formatted(date: .long, time: .omitted))" } ?? "")
    }
}

/// L'annuaire : les membres du conseil syndical, puis le syndic et ses contacts —
/// un toucher appelle ou écrit. Ouvert depuis la Fiche, il se place sur le syndic.
struct AnnuaireView: View {
    let installation: Installation
    let titre: String
    var ancre: Ancre?
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.palette) private var palette

    enum Ancre: Hashable { case syndic }

    var body: some View {
        Group {
            if let service = parcours.service.annuaire {
                let installation = installation
                Chargement(
                    charger: { try await service.annuaire(installation) },
                    contenu: { annuaire, recharger in
                        ScrollViewReader { lecteur in
                            ScrollView {
                                contenu(annuaire).padding(.horizontal, Mise.marge).padding(.vertical, 16)
                            }
                            .refreshable { recharger() }
                            .task {
                                guard ancre == .syndic else { return }
                                lecteur.scrollTo(Ancre.syndic, anchor: .top)
                            }
                        }
                    },
                    squelette: { ScrollView { contenu(ServiceSimule.annuaire).padding(Mise.marge) } }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bg)
        .navigationTitle(titre)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !reseau.enLigne { BandeauHorsLigne() }
        }
    }

    private func contenu(_ annuaire: Annuaire) -> some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            Text(TextesAnnuaire.descriptif).font(.subheadline).foregroundStyle(palette.textMuted)
            SectionConseil(annuaire: annuaire, site: installation.nom, installation: installation)
            SectionSyndic(syndic: annuaire.syndic, installation: installation).id(Ancre.syndic)
        }
    }
}

/// « Conseil Syndical » : l'AG qui l'a élu, le groupe WhatsApp, puis les membres,
/// par bâtiment quand la résidence en a plusieurs.
private struct SectionConseil: View {
    let annuaire: Annuaire
    let site: String
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EnTeteAnnuaire(titre: TextesAnnuaire.conseil)
            if let annee = annuaire.cs.agAnnee {
                Text(TextesAnnuaire.voteEnAG(annee, le: Dates.jour(annuaire.cs.agDate)))
                    .font(.subheadline).foregroundStyle(palette.textMuted)
            }
            if let lien = annuaire.whatsappUrl.flatMap(URL.init(string:)) {
                LienExterne(titre: TextesAnnuaire.whatsapp, symbole: "bubble.left.and.bubble.right.fill", adresse: lien)
            }
            let groupes = annuaire.groupesCS
            if annuaire.cs.membres.isEmpty {
                RubriqueVide(texte: TextesAnnuaire.aucunMembre)
            } else if groupes.count > 1 {
                ForEach(groupes, id: \.batiment) { groupe in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            groupe.batiment.map { "Bâtiment \($0)" } ?? TextesAnnuaire.sansBatiment,
                            systemImage: "building.2"
                        )
                        .styleLibelle()
                        // Le bâtiment titre déjà le groupe : la carte ne le répète pas.
                        ForEach(groupe.membres) { membre($0, lieu: nil) }
                    }
                }
            } else {
                ForEach(annuaire.cs.membres) { membre($0, lieu: $0.batimentNom.map { "Bât. \($0)" }) }
            }
        }
    }

    private func membre(_ personne: Annuaire.Membre, lieu: String?) -> some View {
        var medaillons: [Medaille] = []
        if personne.estGestionnaireSite == true {
            medaillons.append(Medaille(titre: TextesAnnuaire.gestionnaire(site), symbole: "building.2"))
        }
        if personne.estPresident == true {
            medaillons.append(Medaille(titre: TextesAnnuaire.president, symbole: "shield.lefthalf.filled"))
        }
        return CarteContact(personne: personne, medaillons: medaillons, installation: installation) {
            if let lieu { Text(lieu).font(.subheadline).foregroundStyle(palette.textMuted) }
        }
    }
}

/// « Syndic » : le cabinet, son espace client, puis ses contacts — téléphone et
/// courriel d'un toucher. Le gestionnaire principal est mis en avant.
private struct SectionSyndic: View {
    let syndic: Annuaire.Syndic
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EnTeteAnnuaire(titre: TextesAnnuaire.syndic)
            if let nom = syndic.nomSyndic, !nom.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nom).font(.headline).foregroundStyle(palette.text)
                    if let adresse = syndic.adresse, !adresse.isEmpty {
                        Text(adresse).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let lien = syndic.siteWeb.flatMap(URL.init(string:)) {
                LienExterne(titre: TextesAnnuaire.espaceClient, symbole: "globe", adresse: lien)
            }
            if syndic.membres.isEmpty { RubriqueVide(texte: TextesAnnuaire.aucunContact) }
            ForEach(syndic.membres) { personne in
                let principal = personne.estPrincipal == true
                CarteContact(
                    personne: personne,
                    medaillons: principal ? [Medaille(titre: TextesAnnuaire.principal, symbole: "star.fill")] : [],
                    principal: principal, installation: installation
                ) {
                    if let fonction = personne.fonction, !fonction.isEmpty {
                        Text(fonction).font(.subheadline).foregroundStyle(palette.textMuted)
                    }
                    Coordonnees(personne: personne)
                }
            }
        }
    }
}

/// L'en-tête d'une section de l'annuaire, en serif de la charte.
private struct EnTeteAnnuaire: View {
    let titre: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(titre).font(.titre(.title2)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
    }
}

/// Un lien qui quitte l'app (groupe WhatsApp, espace client du syndic).
private struct LienExterne: View {
    let titre: String
    let symbole: String
    let adresse: URL
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Link(destination: adresse) {
            HStack {
                // Aux très grandes tailles, le pictogramme laisse sa place au texte.
                Group {
                    if taille.isAccessibilitySize { Text(titre) } else { Label(titre, systemImage: symbole) }
                }
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold))
            }
            .foregroundStyle(palette.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: Mise.cible)
            .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.border)
            }
        }
        .accessibilityHint("Ouvre un lien hors de l'app")
    }
}
