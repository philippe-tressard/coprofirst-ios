// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les mots des aperçus d'une saisie — la vue et les tests les lisent ici.
enum TextesApercus {
    static let quiLaLira = "Qui la lira"
    /// Avant la catégorie : la règle du serveur part de la nature de l'affaire.
    static let selonLaCategorie = "Elle se dit dès la catégorie choisie."
    static let nomAffiche = "Nom affiché"
}

/// « Qui la lira » d'une affaire en saisie (#129) : la pastille et la phrase que le
/// serveur rend pour CE qui est saisi (`POST /lectures/apercu`) — le badge et l'aide de
/// la section Destinataires du site. `saisie` nulle : pas encore de catégorie, rien à
/// demander. Une Section, à poser dans un `Form`.
struct QuiLaLira: View {
    let saisie: SaisieLecture?
    let identifiant: String

    var body: some View {
        Section {
            if let saisie {
                ApercuServi(
                    saisie, demander: { try await $0.lecture(de: $2, dans: $1) },
                    contenu: { LectureDeLaSaisie(lecture: $0, identifiant: identifiant) })
            } else {
                LectureDeLaSaisie(lecture: nil, identifiant: identifiant)
            }
        } header: {
            Text(TextesApercus.quiLaLira)
        }
    }
}

/// La pastille, la phrase entière et l'avertissement servis ; avant la première
/// réponse, une ligne qui dit d'où elle viendra — à la même place.
private struct LectureDeLaSaisie: View {
    let lecture: Lecture?
    let identifiant: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lecture {
                PastilleLecture(lecture: lecture, memeParDefaut: true)
                Text(lecture.phraseEntiere)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if let avertissement = lecture.avertissement?.nulSiVide {
                    Text(avertissement).font(.footnote).foregroundStyle(palette.danger)
                }
            } else {
                Text(TextesApercus.selonLaCategorie).font(.subheadline).foregroundStyle(palette.textMuted)
            }
        }
        .contentTransition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lecture.map { "\($0.enClair()) \($0.exclus)" } ?? TextesApercus.selonLaCategorie)
        .accessibilityIdentifier(identifiant)
    }
}

/// Le lieu d'une sélection en saisie, nommé par le serveur (#130, `POST /perimetres/libelle`)
/// — même le périmètre par défaut — : l'épingle et le libellé du lieu servi
/// (`EtiquetteLieu`). Sa ligne est réservée avant la première réponse. Rien sans code.
struct LieuDeLaSaisie: View {
    let codes: Set<String>
    let identifiant: String
    @Environment(\.palette) private var palette

    var body: some View {
        if !codes.isEmpty {
            ApercuServi(codes.sorted(), demander: { try await $0.lieu(de: $2, dans: $1) }, contenu: etiquette)
        }
    }

    /// La ligne est là avant la première réponse, invisible : rien ne bouge à son arrivée.
    private func etiquette(_ libelle: String?) -> some View {
        let servi = libelle?.nulSiVide
        return EtiquetteLieu(lieu: servi ?? FormatsDuSite.tiret)
            .font(.footnote)
            .foregroundStyle(palette.textMuted)
            .contentTransition(.opacity)
            .opacity(servi == nil ? 0 : 1)
            .accessibilityHidden(servi == nil)
            .accessibilityIdentifier(identifiant)
    }
}

/// « Prénom NOM » d'une personne en saisie, rendu par le serveur (#135,
/// `POST /noms/affiche`) : le prénom et le nom tels que tapés, la casse est la sienne.
/// `connu` : le nom servi avec la personne, et le prénom et le nom qu'il nomme — il ne
/// se redemande pas. Une ligne de `Form`.
struct NomDeLaSaisie: View {
    let saisie: NomSaisi
    var connu: (NomSaisi, String)?
    let identifiant: String

    var body: some View {
        ApercuServi(saisie, connue: connu, demander: { try await $0.nomAffiche($2, dans: $1) }, contenu: ligne)
    }

    private func ligne(_ nom: String?) -> some View {
        LabeledContent(TextesApercus.nomAffiche) {
            Text(nom?.nulSiVide ?? FormatsDuSite.tiret).contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifiant)
    }
}
