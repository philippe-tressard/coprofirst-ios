// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Écran 4 — proposé une fois, après la première connexion à une résidence. Une fois
/// la session gardée, il dit ce qui la protège VRAIMENT : Face ID, ou le seul
/// verrouillage de l'appareil quand la biométrie manque (#84).
struct FaceIDFeuille: View {
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    /// `nil` : la question ; sinon, ce que l'activation a rendu.
    @State private var issue: Issue?
    @State private var enCours = false

    private enum Issue: Equatable {
        case gardee(ProtectionSession)
        case echec
    }

    var body: some View {
        ScrollView {
            Group {
                if let issue {
                    resultat(issue)
                } else {
                    question
                }
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.bg)
        .sensoryFeedback(trigger: issue) { _, nouvelle in
            switch nouvelle {
            case .gardee(.biometrie): .success
            case .gardee, .echec: .warning
            case nil: nil
            }
        }
    }

    private var question: some View {
        VStack(spacing: 18) {
            pictogramme("faceid", teinte: palette.primary)
            titre("Ouvrir avec Face ID ?")
            texte(
                "La prochaine fois, un regard suffira pour retrouver le fil de \(installation.nom), "
                    + "sans ressaisir votre mot de passe.")
            VStack(spacing: 10) {
                Button("Activer") { Task { await activer() } }
                    .buttonStyle(.plein)
                    .disabled(enCours)
                    .accessibilityIdentifier("faceid.activer")
                Button("Plus tard") { parcours.proposerFaceID = false }
                    .buttonStyle(.contour)
                    .disabled(enCours)
                    .accessibilityIdentifier("faceid.plusTard")
            }
            .padding(.top, 6)
        }
        .transition(transition)
    }

    /// Ce qui garde la session, dit sans détour : une protection moindre que Face ID
    /// s'annonce comme telle, avec ce qui la renforcerait.
    private func resultat(_ issue: Issue) -> some View {
        let dit = Self.dire(issue, nom: installation.nom)
        return VStack(spacing: 18) {
            pictogramme(dit.symbole, teinte: dit.rassurant ? palette.primary : palette.textMuted)
                .symbolEffect(.bounce, value: mouvementReduit ? nil : issue)
            titre(dit.titre)
                .accessibilityIdentifier("faceid.protection")
            texte(dit.texte)
            Button("Continuer") { parcours.proposerFaceID = false }
                .buttonStyle(.plein)
                .padding(.top, 6)
                .accessibilityIdentifier("faceid.continuer")
        }
        .transition(transition)
    }

    private func activer() async {
        enCours = true
        let protection = await parcours.service.activerFaceID(installation)
        enCours = false
        withAnimation(mouvementReduit ? .easeOut(duration: 0.2) : .snappy(duration: 0.3)) {
            issue = protection.map(Issue.gardee) ?? .echec
        }
    }

    /// Un fondu, et sans mouvement réduit un léger grossissement — jamais depuis rien.
    private var transition: AnyTransition {
        mouvementReduit ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func pictogramme(_ symbole: String, teinte: Color) -> some View {
        Image(systemName: symbole)
            .font(.system(size: 56, weight: .regular))
            .foregroundStyle(teinte)
            .accessibilityHidden(true)
            .padding(.top, 8)
    }

    private func titre(_ texte: String) -> some View {
        Text(texte)
            .font(.titre(.title2))
            .foregroundStyle(palette.text)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private func texte(_ texte: String) -> some View {
        Text(texte)
            .font(.body)
            .foregroundStyle(palette.textMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension FaceIDFeuille {
    /// Ce que l'écran dit d'une activation : pictogramme, titre, explication — et si la
    /// protection est celle que promettait la question.
    struct Dit: Equatable {
        let symbole: String
        let titre: String
        let texte: String
        let rassurant: Bool
    }

    private static func dire(_ issue: Issue, nom: String) -> Dit {
        switch issue {
        case .gardee(let protection): dire(protection, nom: nom)
        case .echec:
            Dit(
                symbole: "xmark.shield", titre: "Session non gardée",
                texte: "Cet appareil n'a pas pu garder votre session : vous rouvrirez \(nom) avec votre mot de passe.",
                rassurant: false)
        }
    }

    static func dire(_ protection: ProtectionSession, nom: String) -> Dit {
        switch protection {
        case .biometrie(let biometrie):
            Dit(
                symbole: "checkmark.shield.fill", titre: "Protégée par \(biometrie)",
                texte: "Votre session à \(nom) est gardée sur cet appareil ; \(biometrie) seul la rouvre.",
                rassurant: true)
        case .codeAppareil:
            Dit(
                symbole: "lock.shield", titre: "Protégée par le verrouillage de l'appareil",
                texte: "Face ID n'est pas configuré : quiconque connaît le code de cet appareil rouvre votre "
                    + "session. Configurez Face ID dans Réglages pour la protéger davantage.",
                rassurant: false)
        case .aucune:
            Dit(
                symbole: "exclamationmark.shield", titre: "Gardée sans protection",
                texte: "Cet appareil n'a ni code ni Face ID : quiconque le tient rouvre votre session. "
                    + "Ajoutez un code dans Réglages pour la protéger.",
                rassurant: false)
        }
    }
}
