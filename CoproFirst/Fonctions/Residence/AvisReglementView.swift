// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes de l'avis à renvois (`AvisReglement.svelte`, `ExtraitsReglement.svelte`).
enum TextesAvis {
    static let fondements = "Ce qui fonde l'avis"
    static let reglement = "Le règlement de copropriété"
    static let assemblees = "Les assemblées générales"
    static let reserves = "Réserves"
    static let nonRetrouveCourt = "⚠️ Non retrouvé"
    static let retrouve = "Retrouvé dans le texte"
    static let allerAuxExtraits = "Ouvre la section et montre l'extrait"

    /// « Renvoi sans extrait — à vérifier : R3. » (`renvois_sans_extrait`, servi).
    static func sansExtrait(_ renvois: [String]) -> String {
        let pluriel = renvois.count > 1 ? "s" : ""
        return "Renvoi sans extrait\(pluriel)\(TablesReglement.tiret)à vérifier\u{00A0}: "
            + renvois.joined(separator: ", ") + "."
    }

    /// Un extrait que le code n'a pas retrouvé le dit en clair, avec la référence donnée.
    static func nonRetrouve(_ extrait: ExtraitReglement) -> String {
        let reference = extrait.reference.flatMap { $0.isEmpty ? nil : " (référence donnée : \($0))" } ?? ""
        return "⚠️ Non retrouvé mot pour mot dans le texte\(TablesReglement.tiret)à vérifier\(reference)"
    }
}

/// L'avis d'une question au règlement, quand ses extraits portent leurs RENVOIS
/// (contrat 1.14.0, `AvisReglement.svelte`) : la synthèse, puis « Ce qui fonde
/// l'avis » — une ligne par renvoi, toujours visible, qui ouvre sa section et amène
/// à l'extrait —, puis trois sections pliées, une seule ouverte à la fois.
struct AvisARenvois: View {
    let question: QuestionReglement
    /// Le défilement de l'écran qui porte l'avis : un fondement y amène son extrait.
    let defilement: ScrollViewProxy
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var ouverte: SectionAvis?
    /// Le renvoi de l'extrait qu'un fondement vient de montrer : il se signale un instant.
    @State private var cible: String?
    @AccessibilityFocusState private var focus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TexteRiche(html: question.reponse).tint(palette.primary).foregroundStyle(palette.text)
            if !question.fondements.isEmpty { fondements }
            VStack(spacing: 0) {
                if question.selonReglement != nil || !question.extraitsReglement.isEmpty {
                    section(.reglement, html: question.selonReglement, extraits: question.extraitsReglement)
                }
                if question.selonAG != nil || !question.extraitsAG.isEmpty {
                    section(.assemblees, html: question.selonAG, extraits: question.extraitsAG)
                }
                if question.reserves != nil { section(.reserves, html: question.reserves, extraits: []) }
            }
        }
        .sensoryFeedback(.selection, trigger: ouverte)
    }

    private var fondements: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TextesAvis.fondements).font(.headline).foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)
                .accessibilityIdentifier("avis.fondements")
            ForEach(question.fondements, id: \.self) { extrait in
                Button {
                    aller(a: extrait)
                } label: {
                    LigneFondement(extrait: extrait)
                }
                .buttonStyle(.fondement)
                .accessibilityHint(TextesAvis.allerAuxExtraits)
                .accessibilityIdentifier("avis.fondement.\(extrait.renvoi ?? "")")
            }
            if !question.renvoisSansExtrait.isEmpty {
                Text(TextesAvis.sansExtrait(question.renvoisSansExtrait))
                    .font(.footnote).foregroundStyle(palette.warningTexte)
                    .padding(.top, 4)
            }
        }
    }

    private func section(_ quoi: SectionAvis, html: String?, extraits: [ExtraitReglement]) -> some View {
        SectionPliee(
            titre: quoi.titre, compte: quoi == .reserves ? nil : extraits.count, ouverte: ouverte == quoi,
            identifiant: "avis.section.\(quoi)",
            basculer: { withAnimation(animation) { ouverte = ouverte == quoi ? nil : quoi } },
            contenu: {
                if let html, !html.isEmpty {
                    TexteRiche(html: html).tint(palette.primary).foregroundStyle(palette.text)
                }
                ExtraitsReglementView(extraits: extraits, cible: cible, focus: $focus)
            })
    }

    private var animation: Animation? { mouvementReduit ? nil : .snappy(duration: 0.25) }

    /// Ouvre la section de l'extrait, le fait venir en haut de l'écran et le signale,
    /// comme le site (`revelerCible` : 2,5 s, dont la fin s'efface).
    private func aller(a extrait: ExtraitReglement) {
        guard let renvoi = extrait.renvoi else { return }
        withAnimation(animation) { ouverte = extrait.source == "ag" ? .assemblees : .reglement }
        cible = renvoi
        Task { @MainActor in
            // La section dépliée doit être posée avant qu'on y défile.
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(mouvementReduit ? nil : .smooth(duration: 0.35)) {
                defilement.scrollTo(ExtraitsReglementView.ancre(renvoi), anchor: .top)
            }
            focus = renvoi
            try? await Task.sleep(for: .milliseconds(1_750))
            guard cible == renvoi else { return }
            withAnimation(.easeOut(duration: 0.75)) { cible = nil }
        }
    }
}

/// Les trois sections pliées de l'avis, dans l'ordre du site.
enum SectionAvis: String, Hashable, CustomStringConvertible {
    case reglement, assemblees, reserves

    var titre: String {
        switch self {
        case .reglement: TextesAvis.reglement
        case .assemblees: TextesAvis.assemblees
        case .reserves: TextesAvis.reserves
        }
    }

    var description: String { rawValue }
}

/// Une ligne de « Ce qui fonde l'avis » : le renvoi, où se trouve l'extrait, et ce
/// que le code en a vérifié. Aux tailles d'accessibilité, le lieu passe dessous.
private struct LigneFondement: View {
    let extrait: ExtraitReglement
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
        disposition {
            Text(extrait.renvoi ?? "")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(palette.primary)
                .frame(minWidth: taille.isAccessibilitySize ? nil : 36, alignment: .leading)
            Text(extrait.origine ?? "").font(.subheadline).foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if extrait.verifie {
                Text("✓").font(.subheadline.weight(.semibold)).foregroundStyle(palette.successTexte)
                    .accessibilityLabel(TextesAvis.retrouve)
            } else {
                Text(TextesAvis.nonRetrouveCourt).font(.footnote).foregroundStyle(palette.warningTexte)
            }
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }
}

/// Un fondement se touche : la ligne entière, 44 points au doigt, et un fond qui
/// répond à l'appui.
private struct StyleFondement: ButtonStyle {
    @Environment(\.palette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: Mise.cible)
            .background(
                configuration.isPressed ? palette.bg : .clear,
                in: .rect(cornerRadius: Mise.rayon, style: .continuous)
            )
            .contentShape(.rect)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == StyleFondement {
    fileprivate static var fondement: StyleFondement { StyleFondement() }
}

/// Une section pliée de l'avis (`SectionRepliee` en série) : un bandeau — titre,
/// compte, chevron — qui ouvre ce qu'il cache ; l'appelant décide qui est ouverte.
private struct SectionPliee<Contenu: View>: View {
    let titre: String
    let compte: Int?
    let ouverte: Bool
    let identifiant: String
    let basculer: () -> Void
    @ViewBuilder let contenu: Contenu
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            palette.border.frame(height: 1)
            Button(action: basculer) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(titre).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                    if let compte, compte > 0 {
                        Text(FormatsDuSite.nombre(compte))
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(palette.textMuted)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(palette.neutreFond, in: .capsule)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(palette.textMuted)
                        .rotationEffect(.degrees(ouverte ? 180 : 0))
                }
                .multilineTextAlignment(.leading)
                .frame(minHeight: Mise.cible)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(ouverte ? "déplié" : "replié")
            .accessibilityHint(ouverte ? "Replie la section" : "Déplie la section")
            .accessibilityIdentifier(identifiant)
            if ouverte {
                VStack(alignment: .leading, spacing: 14) { contenu }
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .transition(mouvementReduit ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }
        }
    }
}

/// Les extraits d'un avis, avec ce que le CODE en a vérifié (`ExtraitsReglement`) :
/// un extrait retrouvé montre son repère, un extrait non retrouvé le dit en clair.
/// Dans un avis à renvois, chaque extrait porte son renvoi et une ancre où mène son
/// fondement ; sans `titre`, la liste se lit sous le bandeau qui la plie.
struct ExtraitsReglementView: View {
    var titre: String?
    let extraits: [ExtraitReglement]
    var cible: String?
    var focus: AccessibilityFocusState<String?>.Binding?
    @Environment(\.palette) private var palette

    static func ancre(_ renvoi: String) -> String { "extrait-\(renvoi)" }

    var body: some View {
        if !extraits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if let titre {
                    Text(titre).font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                }
                ForEach(extraits, id: \.self) { extrait in
                    let vise = extrait.renvoi != nil && extrait.renvoi == cible
                    extraitVue(extrait)
                        .padding(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                                .strokeBorder(palette.primary, lineWidth: 3)
                                .opacity(vise ? 1 : 0)
                        }
                        .padding(-8)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(extrait.renvoi.map { "avis.extrait.\($0)" } ?? "avis.extrait")
                        .modifier(AncreExtrait(renvoi: extrait.renvoi, focus: focus))
                }
            }
        }
    }

    private func extraitVue(_ extrait: ExtraitReglement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let renvoi = extrait.renvoi {
                Text(renvoi).font(.footnote.weight(.semibold)).foregroundStyle(palette.primary)
            }
            Text("« \(extrait.citation) »")
                .font(.body.italic())
                .foregroundStyle(palette.text)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { palette.border.frame(width: 3) }
            if extrait.verifie {
                Text("✓ \(extrait.origine ?? "")").font(.footnote).foregroundStyle(palette.successTexte)
            } else {
                Text(TextesAvis.nonRetrouve(extrait)).font(.footnote).foregroundStyle(palette.warningTexte)
            }
            if let apport = extrait.apport, !apport.isEmpty {
                Text(apport).font(.footnote).foregroundStyle(palette.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// L'ancre d'un extrait à renvoi, où son fondement fait défiler — et où VoiceOver le suit.
private struct AncreExtrait: ViewModifier {
    let renvoi: String?
    let focus: AccessibilityFocusState<String?>.Binding?

    func body(content: Content) -> some View {
        if let renvoi, let focus {
            content.id(ExtraitsReglementView.ancre(renvoi)).accessibilityFocused(focus, equals: renvoi)
        } else if let renvoi {
            content.id(ExtraitsReglementView.ancre(renvoi))
        } else {
            content
        }
    }
}
