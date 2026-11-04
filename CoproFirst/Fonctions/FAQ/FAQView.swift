// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes de l'écran, écrits une fois — ceux du site (`faq/+page.svelte`).
enum TextesFAQ {
    static let vide = "Aucune question pour l'instant"
    static let pasTrouve = "Vous ne trouvez pas la réponse ?"
    static let pasTrouveTexte =
        "Créez une affaire via la rubrique Affaires et le conseil syndical vous répondra dans les meilleurs délais."
    static let nouvelleAffaire = "Créer une affaire"
    static let manuel = "Le Manuel utilisateur vous guide pas à pas."
    static let ouvrirManuel = "Ouvrir le Manuel utilisateur"
    static let copierLien = "Copier le lien"
    /// Divergence déclarée : la rédaction (conseil syndical) reste au site.
    static let redactionAuSite = "Rédiger, masquer ou réorganiser les questions se fait sur le site."
    static let ouvrirSite = "Ouvrir la FAQ sur le site"
}

/// La FAQ de la résidence : une section par catégorie, une question dépliée à la
/// fois, la réponse en texte riche. Lecture seule ; le conseil syndical rédige sur
/// le site, et l'écran le dit.
struct FAQView: View {
    let installation: Installation
    var titre = "FAQ"
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let service = parcours.serviceFAQ
        let installation = installation
        Chargement(
            charger: { CategorieFAQ.regrouper(try await service.questionsFAQ(installation)) },
            contenu: { categories, recharger in
                ListeFAQ(categories: categories, installation: installation, recharger: recharger)
            },
            squelette: { ListeFAQ(categories: Self.squelette, installation: installation, recharger: {}) }
        )
        .background(palette.bg)
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(tailleTexte.isAccessibilitySize ? .inline : .large)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }

    private static let squelette = [
        CategorieFAQ(
            nom: "Une catégorie",
            questions: (1...4).map {
                QuestionFAQ(id: $0, categorie: "", question: "Une question fréquente de la résidence", reponse: "")
            }),
    ]
}

private struct ListeFAQ: View {
    let categories: [CategorieFAQ]
    let installation: Installation
    let recharger: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var ouverte: Int?

    var body: some View {
        List {
            if categories.isEmpty {
                ContentUnavailableView(TextesFAQ.vide, systemImage: "questionmark.bubble")
                    .listRowBackground(Color.clear)
            }
            ForEach(categories) { categorie in
                Section {
                    ForEach(categorie.questions) { question in
                        LigneQuestion(question: question, installation: installation, ouverte: $ouverte)
                            .listRowBackground(palette.surface)
                    }
                } header: {
                    Text(categorie.nom).styleLibelle()
                }
            }
            sectionAide
        }
        .scrollContentBackground(.hidden)
        .refreshable { recharger() }
        .sensoryFeedback(.selection, trigger: ouverte)
    }

    /// L'encart du bas de la page du site, puis la rédaction réservée au site.
    private var sectionAide: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(TextesFAQ.pasTrouve).font(.headline).foregroundStyle(palette.text)
                Text(TextesFAQ.pasTrouveTexte).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            .padding(.vertical, 4)
            .listRowBackground(palette.surface)
            if let affaires = ongletAffaires {
                Button {
                    parcours.onglet = affaires
                } label: {
                    Label(TextesFAQ.nouvelleAffaire, systemImage: "exclamationmark.bubble")
                }
                .listRowBackground(palette.surface)
            }
            Link(destination: installation.adresse.appending(path: "manuel-utilisateur.html")) {
                Label(TextesFAQ.ouvrirManuel, systemImage: "book")
            }
            .listRowBackground(palette.surface)
        } footer: {
            if estConseil {
                VStack(alignment: .leading, spacing: 6) {
                    Text(TextesFAQ.redactionAuSite)
                    Link(TextesFAQ.ouvrirSite, destination: installation.adresse.appending(path: "faq"))
                        .fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(.top, 6)
            }
        }
    }

    /// L'onglet des affaires, s'il est dans la barre (au-delà de quatre, il vit sous « Plus »).
    private var ongletAffaires: String? {
        installation.pages.prefix(4).first { $0.id == "mes-demandes" }?.id
    }

    /// Le conseil syndical et l'administration rédigent la FAQ (`require_cs_or_admin`).
    private var estConseil: Bool {
        let roles = parcours.ouverteAJour?.profil?.roles ?? []
        return roles.contains("conseil_syndical") || roles.contains("admin")
    }
}

/// Une question, dépliable ; une seule ouverte à la fois, comme sur le site.
private struct LigneQuestion: View {
    let question: QuestionFAQ
    let installation: Installation
    @Binding var ouverte: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        DisclosureGroup(isExpanded: deplie) {
            Text(TexteDuSite.riche(question.reponse))
                .font(.body)
                .foregroundStyle(palette.text)
                .tint(palette.primary)
                .textSelection(.enabled)
                .padding(.vertical, 6)
        } label: {
            Text(question.question)
                .font(.body.weight(.medium))
                .foregroundStyle(palette.text)
                .padding(.vertical, 4)
        }
        .tint(palette.textMuted)
        .contextMenu {
            Button {
                UIPasteboard.general.url = lien
            } label: {
                Label(TextesFAQ.copierLien, systemImage: "link")
            }
            ShareLink(item: lien)
        }
        .accessibilityIdentifier("faq.\(question.id)")
    }

    /// Le lien du site vers cette question (`#faq-<id>`).
    private var lien: URL {
        var composants = URLComponents(url: installation.adresse.appending(path: "faq"), resolvingAgainstBaseURL: false)
        composants?.fragment = "faq-\(question.id)"
        return composants?.url ?? installation.adresse
    }

    private var deplie: Binding<Bool> {
        Binding(
            get: { ouverte == question.id },
            set: { valeur in withAnimation(.snappy) { ouverte = valeur ? question.id : nil } })
    }
}

extension FAQView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre)
    }
}
