// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « À propos » : ce que le pied de page du site dit sur chaque page — la résidence, le
/// « © », la version, puis « À propos de CoproFirst », « Logiciel libre », « Mentions
/// légales » et « Confidentialité ». Les deux derniers sont verrouillés sur le site (LCEN
/// art. 6, RGPD art. 13) : l'app les rend lisibles ici, sans passer par le navigateur.
struct AProposView: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var lu: AProposResidence?
    @State private var erreur: ErreurService?

    /// Le code de CETTE app (AGPLv3 §13 : offrir le source de ce qu'on distribue) — le
    /// dépôt du serveur, lui, est celui du site (`TextesDuPied.depotSource`).
    static let depotApp = "https://github.com/philippe-tressard/coprofirst-ios"

    var body: some View {
        List {
            Section { marque }.listRowBackground(palette.surface)
            Section("Informations légales") {
                NavigationLink {
                    PageLegaleView(titre: TextesDuPied.mentions.libelle, html: lu?.mentionsLegales, logicielLibre: true)
                } label: {
                    Label(TextesDuPied.mentions.libelle, systemImage: "building.columns")
                }
                .accessibilityIdentifier("a-propos.mentions")
                NavigationLink {
                    PageLegaleView(titre: TextesDuPied.confidentialite.libelle, html: lu?.confidentialite)
                } label: {
                    Label(TextesDuPied.confidentialite.libelle, systemImage: "hand.raised")
                }
                .accessibilityIdentifier("a-propos.confidentialite")
            }
            .disabled(lu == nil)
            .listRowBackground(palette.surface)
            Section {
                lienExterne(TextesDuPied.site.libelle, aide: TextesDuPied.site.aide, vers: TextesDuPied.sitePlateforme)
                lienExterne(TextesDuPied.source.libelle, aide: TextesDuPied.source.aide, vers: TextesDuPied.depotSource)
                lienExterne("Code source de l'app", aide: "Le code de cette app iPhone", vers: Self.depotApp)
            } footer: {
                Text("\(TextesDuPied.nomPlateforme) est distribué sous la \(TextesDuPied.licenceNom).")
            }
            .listRowBackground(palette.surface)
            Section("Composants tiers") {
                ForEach(ComposantsTiers.tous) { composant in
                    NavigationLink {
                        LicencesTiercesView(composant: composant)
                    } label: {
                        LabeledContent(composant.nom, value: composant.licences)
                    }
                    .accessibilityIdentifier("apropos.composant.\(composant.nom)")
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle("À propos")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let erreur {
                MessageErreur(texte: erreur.phrase) { Task { await charger() } }.padding(Mise.marge)
            }
        }
        .task { await charger() }
    }

    /// Le logo et le nom, puis la mention : « © 2025–2026 · texte libre · app 0.1.0 ».
    private var marque: some View {
        HStack(spacing: 14) {
            LogoResidence(installation: installation)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(installation.nom).font(.titre(.headline)).foregroundStyle(palette.text)
                Text(mention).font(.footnote.monospacedDigit()).foregroundStyle(palette.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("a-propos.mention")
    }

    private var mention: String {
        let annee = Calendar.current.component(.year, from: .now)
        var morceaux = [AProposResidence.mentionAnnee(debut: lu?.anneeDebut, courante: annee)]
        if let texte = lu?.texte { morceaux.append(texte) }
        let info = Bundle.main.infoDictionary
        if let version = info?["CFBundleShortVersionString"] as? String {
            morceaux.append("app \(version)")
        }
        return morceaux.joined(separator: " · ")
    }

    @ViewBuilder
    private func lienExterne(_ libelle: String, aide: String, vers adresse: String) -> some View {
        if let destination = URL(string: adresse) {
            lien(libelle, aide: aide, vers: destination)
        }
    }

    private func lien(_ libelle: String, aide: String, vers destination: URL) -> some View {
        Link(destination: destination) {
            Label {
                HStack {
                    Text(libelle).foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(palette.textMuted)
                }
            } icon: {
                Image(systemName: "link")
            }
        }
        .accessibilityHint(aide)
    }

    private func charger() async {
        do {
            let reponse = try await parcours.serviceAPropos.aPropos(installation)
            withAnimation(.snappy) {
                lu = reponse
                erreur = nil
            }
        } catch {
            withAnimation(.snappy) { erreur = ErreurService.depuis(error) }
        }
    }
}

/// Un texte légal de la résidence (`PageLegale.svelte`) : le HTML servi, rendu en texte
/// riche. Les mentions légales finissent, comme sur le site, par « Logiciel libre ».
struct PageLegaleView: View {
    let titre: String
    let html: String?
    var logicielLibre = false
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let html, case let texte = TexteRiche(html: html), !texte.vide {
                    texte.font(.body).foregroundStyle(palette.text).tint(palette.primary).textSelection(.enabled)
                } else {
                    Text("La résidence n'a pas encore publié ce texte.")
                        .font(.body).foregroundStyle(palette.textMuted)
                }
                if logicielLibre {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(TextesDuPied.source.libelle).font(.titre(.title3)).foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                        Text(
                            (try? AttributedString(markdown: """
                            Ce site et cette app reposent sur **\(TextesDuPied.nomPlateforme)**, distribué sous la \
                            [\(TextesDuPied.licenceNom)](\(TextesDuPied.licenceURL)) (\(TextesDuPied.licenceSPDX)) : \
                            chacun peut l'utiliser, l'étudier, le modifier et le redistribuer, à condition de \
                            publier ses modifications sous la même licence. Le code est sur \
                            [GitHub](\(TextesDuPied.depotSource)).
                            """)) ?? AttributedString(TextesDuPied.licenceNom)
                        )
                        .font(.body).foregroundStyle(palette.text).tint(palette.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
    }
}
