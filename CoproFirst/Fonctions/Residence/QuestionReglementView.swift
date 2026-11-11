// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'avis entier sur une question au règlement (la carte dépliée du site) : la
/// mention, puis l'avis. Un avis à renvois se lit en synthèse, fondements et sections
/// pliées (`AvisARenvois`) ; un avis d'avant, section après section — d'après le
/// règlement, ses extraits, d'après les AG, leurs extraits, la synthèse et les réserves.
struct QuestionReglementView: View {
    let question: QuestionReglement
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollViewReader { defilement in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.question).font(.titre(.title2)).foregroundStyle(palette.text)
                    PiedQuestion(question: question)
                    Text(mention).font(.footnote).italic().foregroundStyle(palette.textMuted)
                    if question.avecRenvois {
                        AvisARenvois(question: question, defilement: defilement)
                    } else {
                        avisDAvant
                    }
                }
                .padding(.horizontal, Mise.marge)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(palette.bg)
        .navigationTitle("Avis sur le règlement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { PastilleOuSuisJe(installation: installation, cloche: true) }
    }

    /// « Posée le … Avis indicatif… Rédigé par …, d'après …. » (`CarteQuestionReglement`).
    private var mention: String {
        let posee = FormatsDuSite.dateHeure(question.poseeLe)
        var texte = "Posée le \(posee). Avis indicatif, qui ne se substitue pas aux actes authentiques."
        switch (question.modele, question.provenance) {
        case let (modele?, provenance?): texte += " Rédigé par \(modele), d'après \(provenance)."
        case let (modele?, nil): texte += " Rédigé par \(modele)."
        case let (nil, provenance?): texte += " Rédigé d'après \(provenance)."
        case (nil, nil): break
        }
        return texte
    }

    /// Un avis d'avant les renvois se rend comme il l'a toujours été (`CarteQuestionReglement`).
    @ViewBuilder
    private var avisDAvant: some View {
        riche(question.reponse)
        section("D'après le règlement", question.selonReglement)
        ExtraitsReglementView(titre: "Extraits du règlement", extraits: question.extraitsReglement)
        section("D'après les assemblées générales", question.selonAG)
        ExtraitsReglementView(titre: "Extraits des décisions d'AG", extraits: question.extraitsAG)
        section("Synthèse", question.synthese)
        section("Réserves", question.reserves)
    }

    private func riche(_ html: String) -> some View {
        TexteRiche(html: html).tint(palette.primary).foregroundStyle(palette.text)
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
