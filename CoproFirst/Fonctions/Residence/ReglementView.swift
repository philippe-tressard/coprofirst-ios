// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes de l'onglet Règlement (`OngletReglement.svelte` et ses cartes).
enum TextesReglement {
    static let avertissementCS =
        "Les réponses sont un **avis indicatif**, rédigé par l'assistant d'après le texte de travail joint ici : "
        + "il ne se substitue pas aux actes authentiques, qui seuls font foi. Relisez-le — et vérifiez les extraits "
        + "signalés ⚠️ — avant de le relayer."
    static let avertissement =
        "Les réponses sont un **avis indicatif** : seuls les actes authentiques font foi. En cas de doute, "
        + "interrogez un juriste ou le syndic."
    static let texte = "Texte du règlement"
    static let texteDansLaFiche = "Le règlement de copropriété est disponible sur le site, dans la Fiche."
    static let voirDansLaFiche = "Voir le règlement dans la Fiche"
    static let votreQuestion = "Votre question"
    static let exemple = "Ex. : Un copropriétaire peut-il installer une climatisation sur son balcon ?"
    static let poser = "Poser la question"
    static let lecture = "Lecture du règlement…"
    static let patience = "L'assistant lit tout le règlement avant de répondre : comptez jusqu'à deux minutes."
    static let indisponibleCS =
        "L'assistant n'est pas activé pour cet usage : Admin › Assistant IA › « Question au règlement de copropriété »."
    static let indisponible = "L'assistant ne répond pas pour le moment : réessayez plus tard."
    static let sansTexte = "Le texte du règlement n'est pas encore à la disposition de l'assistant."
    static let questionsPosees = "Questions posées"
    static let vosQuestions = "Vos questions"
    static let aucune = "Aucune question posée"
    static let aucuneDetail = "Les réponses de l'assistant s'afficheront ici."
    static let aucuneDetailPrive = "Vous seul et le conseil syndical les lisez."
    /// La limite du champ, celle du site (`maxlength`).
    static let longueurMaximale = 2000
}

/// L'onglet « Règlement » : poser une question sur le règlement de copropriété ;
/// l'assistant répond en juriste, avec les extraits qui fondent sa réponse.
struct ReglementView: View {
    let installation: Installation
    let service: any ServiceResidence
    /// `$isCS` du site (conseil syndical ou administration) : il choisit les textes.
    let cs: Bool
    var ouvrirFiche: () -> Void = {}
    @Environment(\.palette) private var palette
    @State private var nouvelles: [QuestionReglement] = []

    var body: some View {
        let service = service
        let installation = installation
        Chargement(
            charger: { try await service.reglement(installation) },
            contenu: { lu, recharger in
                ScrollView {
                    // Une question posée ici passe en tête ; le serveur la rendra au prochain chargement.
                    let anciennes = lu.1.filter { q in !nouvelles.contains { $0.id == q.id } }
                    contenu(etat: lu.0, questions: nouvelles + anciennes)
                        .padding(.horizontal, Mise.marge)
                        .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { recharger() }
            },
            squelette: {
                let etat = EtatReglement(disponible: true, texteDisponible: true)
                contenu(etat: etat, questions: [ServiceSimule.question])
                    .padding(Mise.marge)
            }
        )
    }

    private func contenu(etat: EtatReglement, questions: [QuestionReglement]) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            Text(.init(cs ? TextesReglement.avertissementCS : TextesReglement.avertissement))
                .font(.subheadline)
                .foregroundStyle(palette.text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.infoFond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.infoBordure)
                }
            VStack(alignment: .leading, spacing: 8) {
                EnTeteRubrique(titre: TextesReglement.texte)
                Text(TextesReglement.texteDansLaFiche).font(.subheadline).foregroundStyle(palette.textMuted)
                Button(TextesReglement.voirDansLaFiche, action: ouvrirFiche)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primary)
                    .frame(minHeight: Mise.cible)
            }
            FormulaireQuestion(etat: etat, cs: cs, installation: installation, service: service) { posee in
                nouvelles.insert(posee, at: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                EnTeteRubrique(titre: cs ? TextesReglement.questionsPosees : TextesReglement.vosQuestions)
                if questions.isEmpty {
                    ContentUnavailableView {
                        Label(TextesReglement.aucune, systemImage: "text.bubble")
                    } description: {
                        Text(TextesReglement.aucuneDetail + (cs ? "" : " " + TextesReglement.aucuneDetailPrive))
                    }
                }
                ForEach(questions) { question in
                    NavigationLink(value: DestinationResidence.question(question)) {
                        CarteQuestion(question: question)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// « Votre question » : le champ, et le bouton qui la pose — désactivé tant que
/// l'assistant ne peut pas répondre, comme sur le site.
private struct FormulaireQuestion: View {
    let etat: EtatReglement
    let cs: Bool
    let installation: Installation
    let service: any ServiceResidence
    let posee: (QuestionReglement) -> Void
    @Environment(\.palette) private var palette
    @State private var question = ""
    @State private var enCours = false
    @State private var erreur: ErreurService?
    @FocusState private var focus: Bool

    private var empechement: String? {
        if !etat.disponible { return cs ? TextesReglement.indisponibleCS : TextesReglement.indisponible }
        if !etat.texteDisponible { return TextesReglement.sansTexte }
        return nil
    }

    private var vide: Bool { question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EnTeteRubrique(titre: TextesReglement.votreQuestion)
            TextField(TextesReglement.exemple, text: $question, axis: .vertical)
                .lineLimit(3...8)
                .focused($focus)
                .padding(12)
                .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                        .strokeBorder(focus ? palette.primary : palette.borderChamp, lineWidth: focus ? 2 : 1)
                }
                .disabled(enCours || empechement != nil)
                .onChange(of: question) { _, texte in
                    if texte.count > TextesReglement.longueurMaximale {
                        question = String(texte.prefix(TextesReglement.longueurMaximale))
                    }
                }
                .accessibilityLabel(TextesReglement.votreQuestion)
                .accessibilityIdentifier("reglement.question")
            if let empechement {
                Text(empechement).font(.footnote).foregroundStyle(palette.textMuted)
            }
            if let erreur { MessageErreur(texte: erreur.phrase) }
            Button {
                Task { await poser() }
            } label: {
                HStack(spacing: 8) {
                    if enCours { ProgressView().tint(palette.surPlein) }
                    Text(enCours ? TextesReglement.lecture : TextesReglement.poser)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plein)
            .disabled(vide || enCours || empechement != nil)
            .accessibilityIdentifier("reglement.poser")
            if enCours {
                Text(TextesReglement.patience).font(.footnote).foregroundStyle(palette.textMuted)
            }
        }
        .sensoryFeedback(.success, trigger: enCours) { avant, apres in avant && !apres && erreur == nil }
    }

    private func poser() async {
        focus = false
        enCours = true
        erreur = nil
        defer { enCours = false }
        do {
            let reponse = try await service.poser(question, dans: installation)
            question = ""
            posee(reponse)
        } catch {
            self.erreur = ErreurService.depuis(error)
        }
    }
}

/// Une question dans la liste : la date, la question, l'aperçu de la réponse, le
/// verdict et les extraits vérifiés. Un toucher ouvre l'avis entier.
private struct CarteQuestion: View {
    let question: QuestionReglement
    @Environment(\.palette) private var palette

    var body: some View {
        CarteAGouttiere(gouttiere: Gouttiere(nature: .reglement, date: question.poseeLe)) {
            HStack(alignment: .firstTextBaseline) {
                Text(question.question).font(.headline).foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textMuted)
            }
            Text(TexteDuSite.apercu(question.reponseSansRenvois)).font(.subheadline).lineLimit(3)
                .foregroundStyle(palette.textMuted)
            PiedQuestion(question: question)
        }
        .multilineTextAlignment(.leading)
        .contentShape(.rect)
    }
}

/// Le pied d'un avis : verdict, extraits vérifiés, texte remplacé, FAQ, auteur.
struct PiedQuestion: View {
    let question: QuestionReglement
    @Environment(\.palette) private var palette

    var body: some View {
        // Les capsules passent à la ligne quand le texte grandit.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { capsules }
            VStack(alignment: .leading, spacing: 6) { capsules }
        }
        .font(.caption)
    }

    @ViewBuilder
    private var capsules: some View {
        // Le ton du verdict est servi (`verdict_ton`, #2505) ; sa teinte, celle de `BadgeVerdict`.
        PastilleTeinte(libelle: question.verdictLibelle, badge: question.badgeDuVerdict, compacte: true)
        if !question.extraits.isEmpty {
            let n = question.extraits.count
            Text("\(question.verifies)/\(n) extrait\(n > 1 ? "s" : "") vérifié\(question.verifies > 1 ? "s" : "")")
                .foregroundStyle(question.verifies < n ? palette.warningTexte : palette.textMuted)
        }
        if !question.texteEnVigueur { Text("Texte remplacé depuis").foregroundStyle(palette.warningTexte) }
        if question.dansLaFAQ { Text("📚 Dans la FAQ").foregroundStyle(palette.textMuted) }
        if let auteur = question.auteur { Text(auteur).foregroundStyle(palette.textMuted) }
    }
}
