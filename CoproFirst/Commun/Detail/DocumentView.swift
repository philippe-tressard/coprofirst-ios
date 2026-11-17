// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import QuickLook
import SwiftUI

/// Un document du fil : son fichier, téléchargé avec la session et montré par
/// l'aperçu du système (QuickLook) — partage et impression compris.
struct DocumentView: View {
    let id: Int
    let nom: String?
    let titre: String
    let installation: Installation
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    /// À côté d'une liste, la fiche n'a pas de barre à elle : le titre passe en tête du
    /// contenu, comme le numéro d'une affaire (#223) — sur iPhone, il reste en barre seule.
    @Environment(\.dansLaColonneDeFiche) private var dansLaColonne

    var body: some View {
        VStack(spacing: 0) {
            if dansLaColonne {
                Text(titre)
                    .font(.headline)
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("document.titre")
                Divider()
            }
            apercu
        }
        .background(palette.bg)
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var apercu: some View {
        let service = parcours.service
        let installation = installation
        return Chargement(
            charger: { [id, nom] in try await service.document(id, nom: nom, dans: installation) },
            contenu: { fichier, _ in
                ApercuQuickLook(fichier: fichier).ignoresSafeArea(edges: .bottom)
            },
            squelette: {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill").font(.system(size: 56))
                    Text(titre).font(.headline)
                    Text("Le document se télécharge.").font(.subheadline)
                }
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
    }
}

private struct ApercuQuickLook: UIViewControllerRepresentable {
    let fichier: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controleur = QLPreviewController()
        controleur.dataSource = context.coordinator
        return controleur
    }

    func updateUIViewController(_ controleur: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Source { Source(fichier: fichier) }

    final class Source: NSObject, QLPreviewControllerDataSource {
        let fichier: URL

        init(fichier: URL) {
            self.fichier = fichier
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            fichier as NSURL
        }
    }
}

/// Un document à ouvrir : la fiche d'une liste (`LienDeFiche`), poussée ou à côté (#222).
struct DocumentAOuvrir: Hashable {
    let id: Int
    let nom: String?
    let titre: String
}

extension DocumentView {
    init(_ document: DocumentAOuvrir, installation: Installation) {
        self.init(id: document.id, nom: document.nom, titre: document.titre, installation: installation)
    }
}
