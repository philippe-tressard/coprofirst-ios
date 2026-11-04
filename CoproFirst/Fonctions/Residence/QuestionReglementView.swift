// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'avis entier sur une question au règlement (la carte dépliée du site) : la
/// mention, la réponse, puis ses sections — d'après le règlement, ses extraits,
/// d'après les AG, leurs extraits, la synthèse et les réserves.
struct QuestionReglementView: View {
    let question: QuestionReglement
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(question.question).font(.titre(.title2)).foregroundStyle(palette.text)
                PiedQuestion(question: question)
                Text(mention).font(.footnote).italic().foregroundStyle(palette.textMuted)
                riche(question.reponse)
                section("D'après le règlement", question.selonReglement)
                Extraits(titre: "Extraits du règlement", extraits: question.extraitsReglement)
                section("D'après les assemblées générales", question.selonAG)
                Extraits(titre: "Extraits des décisions d'AG", extraits: question.extraitsAG)
                section("Synthèse", question.synthese)
                section("Réserves", question.reserves)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.bg)
        .navigationTitle("Avis sur le règlement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }

    /// « Posée le … Avis indicatif… Rédigé par …, d'après …. » (`CarteQuestionReglement`).
    private var mention: String {
        let posee = question.poseeLe.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
        var texte = "Posée le \(posee). Avis indicatif, qui ne se substitue pas aux actes authentiques."
        switch (question.modele, question.provenance) {
        case let (modele?, provenance?): texte += " Rédigé par \(modele), d'après \(provenance)."
        case let (modele?, nil): texte += " Rédigé par \(modele)."
        case let (nil, provenance?): texte += " Rédigé d'après \(provenance)."
        case (nil, nil): break
        }
        return texte
    }

    private func riche(_ html: String) -> some View {
        Text(TexteDuSite.riche(html)).tint(palette.primary).foregroundStyle(palette.text)
    }

    @ViewBuilder
    private func section(_ titre: String, _ html: String?) -> some View {
        if let html, !html.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(titre).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                riche(html)
            }
        }
    }
}

/// Les extraits d'un avis, avec ce que le CODE en a vérifié (`ExtraitsReglement`) :
/// un extrait retrouvé montre son repère, un extrait non retrouvé le dit en clair.
private struct Extraits: View {
    let titre: String
    let extraits: [ExtraitReglement]
    @Environment(\.palette) private var palette

    var body: some View {
        if !extraits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(titre).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                ForEach(extraits, id: \.self) { extrait in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("« \(extrait.citation) »")
                            .font(.body.italic())
                            .foregroundStyle(palette.text)
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) { palette.border.frame(width: 3) }
                        if extrait.verifie {
                            Text("✓ \(extrait.origine ?? "")").font(.footnote).foregroundStyle(palette.successTexte)
                        } else {
                            Text(nonRetrouve(extrait)).font(.footnote).foregroundStyle(palette.warningTexte)
                        }
                        if let apport = extrait.apport, !apport.isEmpty {
                            Text(apport).font(.footnote).foregroundStyle(palette.textMuted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func nonRetrouve(_ extrait: ExtraitReglement) -> String {
        "⚠️ Non retrouvé mot pour mot dans le texte — à vérifier"
            + (extrait.reference.map { " (référence donnée : \($0))" } ?? "")
    }
}
