// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import QuickLook
import SwiftUI

/// Les pièces jointes d'un élément OUVERT — affaire, suite de l'Historique, message,
/// résumé d'une carte du fil, annonce — écrites une fois (`PiecesJointes.svelte` du site,
/// format « grand ») : les photos en mosaïque (`MosaiquePhotos`), puis les documents en
/// lignes (`LigneDocument`). Un toucher ouvre Coup d'œil : on y feuillette toutes les
/// photos de l'élément, ou on lit le document — zoom, partage et impression du système.
///
/// Une seule section « Pièces jointes », photos et documents ensemble, comme le site l'a
/// tranché le 20/09/2026 (`SectionsPiecesJointes.svelte`). Sur une carte FERMÉE, c'est
/// `VignettePieces` qui signale les pièces, sans les ouvrir.
struct PiecesJointesView: View {
    /// `grand` : l'élément lui-même (intitulé, mosaïque haute) ; `compact` : une pièce d'un
    /// fil — suite, message — sous son texte, sans intitulé.
    enum Format {
        case grand
        case compact

        var hauteurMosaique: CGFloat { self == .grand ? Mise.mosaique : Mise.mosaiqueCompacte }
    }

    let pieces: PiecesJointes
    let installation: Installation
    var format: Format = .grand
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var apercu: URL?
    @State private var apercus: [URL] = []
    @State private var enCours: String?
    @State private var echec: String?

    var body: some View {
        if !pieces.vide {
            VStack(alignment: .leading, spacing: 10) {
                if format == .grand {
                    Text("Pièces jointes · \(pieces.photos.count + pieces.documents.count)")
                        .styleLibelle()
                        .accessibilityAddTraits(.isHeader)
                }
                if !pieces.photos.isEmpty {
                    MosaiquePhotos(
                        chemins: pieces.photos, installation: installation, hauteur: format.hauteurMosaique,
                        enCours: enCours
                    ) { rang in
                        ouvrir(pieces.photos, depuis: rang)
                    }
                }
                if !pieces.documents.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(pieces.documents.enumerated()), id: \.element) { rang, chemin in
                            if rang > 0 { Divider().overlay(palette.border) }
                            LigneDocument(chemin: chemin, enCours: enCours == chemin) {
                                ouvrir([chemin], depuis: 0)
                            }
                            .accessibilityIdentifier("pieces.document.\(rang)")
                        }
                    }
                }
                if let echec {
                    Label(echec, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(palette.danger)
                }
            }
            .quickLookPreview($apercu, in: apercus)
            .sensoryFeedback(.impact(weight: .light), trigger: apercu) { _, nouveau in nouveau != nil }
        }
    }

    /// Lire les fichiers (une fois), puis ouvrir Coup d'œil sur celui touché. Un seul à la fois.
    private func ouvrir(_ chemins: [String], depuis rang: Int) {
        guard enCours == nil, chemins.indices.contains(rang) else { return }
        enCours = chemins[rang]
        echec = nil
        let service = parcours.service
        let installation = installation
        Task {
            defer { enCours = nil }
            do {
                let urls = try await PiecesLocales.partagees.fichiers(chemins, dans: installation, service: service)
                guard urls.indices.contains(rang) else { return }
                apercus = urls
                apercu = urls[rang]
            } catch {
                echec = ErreurService.phrase(error, sinon: "La pièce jointe n'a pas pu s'ouvrir.")
            }
        }
    }
}

/// Un document joint : son type d'abord — on cherche « le PDF » (`PastilleFichier` du
/// site) —, son nom sans extension, et l'ouverture.
struct LigneDocument: View {
    let chemin: String
    let enCours: Bool
    let ouvrir: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: ouvrir) {
            HStack(spacing: 12) {
                Text(Fichiers.typeAffiche(chemin))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(palette.infoFond, in: .rect(cornerRadius: Mise.rayon / 3, style: .continuous))
                Text(Fichiers.nomSansExtension(chemin))
                    .font(.subheadline)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Spacer(minLength: 8)
                if enCours {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Mise.cible)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Fichiers.typeAffiche(chemin)), \(Fichiers.nomSansExtension(chemin))")
        .accessibilityHint("Ouvre le document.")
    }
}
