// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import QuickLook
import SwiftUI

/// « Règles & Recommandations » : une carte par règle, dans l'ordre du serveur ;
/// un toucher la déplie (texte entier, annexes) — une seule ouverte à la fois.
struct RubriqueRegles: View {
    let contenu: ContenuFiche
    @State private var ouverte: Int?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EnTeteRubrique(titre: TextesResidence.regles)
            if contenu.regles.isEmpty { RubriqueVide(texte: TextesResidence.reglesVide) }
            ForEach(contenu.regles) { regle in
                let annexes = contenu.annexes(deRegle: regle.id)
                let depliable = !(regle.contenu ?? "").isEmpty || !annexes.isEmpty
                let depliee = ouverte == regle.id
                Button {
                    ouverte = depliee ? nil : regle.id
                } label: {
                    CarteAGouttiere(gouttiere: Gouttiere(nature: .regle)) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(regle.titre).font(.headline).foregroundStyle(palette.text)
                            Spacer()
                            if depliable {
                                Image(systemName: "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(palette.textMuted)
                                    .rotationEffect(.degrees(depliee ? 180 : 0))
                            }
                        }
                        if let html = regle.contenu, !html.isEmpty {
                            if depliee {
                                TexteRiche(html: html).tint(palette.primary).foregroundStyle(palette.text)
                            } else {
                                Text(TexteDuSite.apercu(html)).lineLimit(3).foregroundStyle(palette.textMuted)
                            }
                        }
                        if depliee { ListeAnnexes(annexes: annexes) }
                    }
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .disabled(!depliable)
                .accessibilityHint(depliable ? (depliee ? "Replie la règle" : "Déplie la règle") : "")
            }
        }
        .animationEtat(ouverte, reduit: mouvementReduit)
        .sensoryFeedback(.selection, trigger: ouverte)
    }
}

/// Une rubrique de documents (plans, règlement, comptes-rendus d'AG), dans l'ordre
/// du serveur. Un toucher ouvre le document dans l'aperçu du système (QuickLook).
struct RubriqueDocuments: View {
    let titre: String
    let vide: String
    let documents: [DocumentResidence]
    let contenu: ContenuFiche
    let gouttiere: Gouttiere.Nature
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EnTeteRubrique(titre: titre)
            if documents.isEmpty { RubriqueVide(texte: vide) }
            ForEach(documents) { document in
                // La date montrée est celle de l'acte, jamais celle du dépôt ; un plan n'en a pas.
                let date = gouttiere == .plan ? nil : document.date
                CarteAGouttiere(gouttiere: Gouttiere(nature: gouttiere, date: date)) {
                    NavigationLink(value: DestinationResidence.document(document)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(document.titre).font(.headline).foregroundStyle(palette.text)
                                Spacer()
                                Image(systemName: "doc.viewfinder")
                                    .foregroundStyle(palette.primary)
                                    .accessibilityHidden(true)
                            }
                            if let description = document.description {
                                Text(description).font(.subheadline).lineLimit(3).foregroundStyle(palette.textMuted)
                            }
                            badges(document)
                        }
                        .multilineTextAlignment(.leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ouvre le document")
                    ListeAnnexes(annexes: contenu.annexes(deDocument: document.id))
                }
            }
        }
    }

    @ViewBuilder
    private func badges(_ document: DocumentResidence) -> some View {
        switch gouttiere {
        case .plan:
            PastilleTeinte.neutre(contenu.libelleBatiment(document.batimentId))
        case .assemblee:
            // Le périmètre d'un compte-rendu (« 🔹 Bât. A · Parking ») se compose dans le
            // front du site (`BadgePerimetre`) : l'app attend que l'API le serve (coprofirst#2505).
            if let annee = document.annee { PastilleTeinte.neutre(String(annee)) }
        default:
            EmptyView()
        }
    }
}

/// « Diagnostics et Contrôles Réglementaires » : les types applicables, et sous
/// chacun ses rapports — un toucher ouvre le rapport, « Synthèse » la déplie.
struct RubriqueDiagnostics: View {
    let contenu: ContenuFiche
    let installation: Installation
    let service: any ServiceResidence
    @State private var synthese: Int?
    @State private var enCours: Int?
    @State private var apercu: URL?
    @State private var erreur: ErreurService?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    /// Les types non applicables ne se montrent qu'au conseil syndical, sur le site.
    private var applicables: [TypeDiagnostic] { contenu.diagnostics.filter { !$0.nonApplicable } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EnTeteRubrique(titre: TextesResidence.diagnostics)
            if applicables.isEmpty { RubriqueVide(texte: TextesResidence.diagnosticsVide) }
            ForEach(applicables) { type in
                let dernier = type.rapports.compactMap(\.date).max()
                CarteAGouttiere(gouttiere: Gouttiere(nature: .diagnostic, date: dernier)) {
                    Text(type.nom).font(.headline).foregroundStyle(palette.text)
                    Text(type.texteLegislatif).font(.subheadline).foregroundStyle(palette.textMuted)
                    if let frequence = type.frequence, !frequence.isEmpty { PastilleTeinte.neutre(frequence) }
                    ForEach(type.rapports) { rapport in ligne(rapport) }
                }
            }
        }
        .animationEtat(synthese, reduit: mouvementReduit)
        .quickLookPreview($apercu)
        .alert(
            "Le rapport n'a pas pu s'ouvrir.", isPresented: Binding { erreur != nil } set: { if !$0 { erreur = nil } },
            actions: { Button("OK", role: .cancel) {} }, message: { Text(erreur?.phrase ?? "") })
    }

    private func ligne(_ rapport: RapportDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(palette.border)
            Button {
                Task { await ouvrir(rapport) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "doc.text").foregroundStyle(palette.primary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rapport.titre).font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
                        if let date = rapport.date {
                            Text(FormatsDuSite.dateCourte(date))
                                .font(.caption).foregroundStyle(palette.textMuted)
                        }
                    }
                    Spacer()
                    if enCours == rapport.id { ProgressView() }
                }
                .frame(minHeight: Mise.cible)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(enCours != nil)
            .accessibilityHint("Ouvre le rapport")
            if let html = rapport.synthese {
                let ouverte = synthese == rapport.id
                Button {
                    synthese = ouverte ? nil : rapport.id
                } label: {
                    Label(TextesResidence.synthese, systemImage: ouverte ? "chevron.up" : "chevron.down")
                        .labelStyle(TitreAvantIcone())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primary)
                        .frame(minHeight: Mise.cible)
                }
                .buttonStyle(.plain)
                if ouverte {
                    TexteRiche(html: html)
                        .tint(palette.primary)
                        .foregroundStyle(palette.text)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) { palette.primary.frame(width: 3) }
                        .transition(.opacity)
                }
            }
            ListeAnnexes(annexes: contenu.annexes(deRapport: rapport.id))
        }
    }

    private func ouvrir(_ rapport: RapportDiagnostic) async {
        enCours = rapport.id
        defer { enCours = nil }
        do {
            apercu = try await service.rapport(rapport.id, nom: rapport.fichier, dans: installation)
        } catch {
            erreur = ErreurService.depuis(error)
        }
    }
}

/// « 💡 Synthèse ⌄ » : le libellé, puis le chevron — comme le bouton du site.
private struct TitreAvantIcone: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon.font(.caption.weight(.bold))
        }
    }
}
