// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un composant tiers embarqué dans l'app : son nom, sa licence, et les textes qui
/// doivent accompagner chaque copie — l'avis de ses auteurs, puis la licence entière.
struct ComposantTiers: Identifiable, Sendable {
    enum Texte: Sendable {
        /// Un texte écrit dans le code (généré depuis coprofirst).
        case ecrit(String)
        /// Un fichier `.txt` copié dans l'app, par son nom sans extension.
        case embarque(String)
    }

    let nom: String
    let licences: String
    let role: String
    let textes: [Texte]

    var id: String { nom }

    /// Les textes, dans l'ordre. Un fichier absent de l'app n'est pas remplacé par un
    /// texte de secours : `ComposantsTiersTests` refuse qu'il en manque un.
    func lus(dans paquet: Bundle = .main) -> [String] {
        textes.compactMap { texte in
            switch texte {
            case .ecrit(let ecrit): ecrit
            case .embarque(let fichier):
                paquet.url(forResource: fichier, withExtension: "txt")
                    .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            }
        }
    }
}

/// Ce que l'app embarque d'autrui (`DEPENDANCES.md`, « Embarquées dans l'application ») :
/// `scripts/verifier-dependances.py` refuse un paquet embarqué qui n'est pas nommé ici,
/// un avis de `Ressources/AvisTiers/` que rien n'affiche, une licence sans son texte.
enum ComposantsTiers {
    /// Le texte de la licence : `LICENSES/Apache-2.0.txt`, copié tel quel (`project.yml`).
    static let apache = "Apache-2.0"

    static let tous: [ComposantTiers] = [
        ComposantTiers(
            nom: LicencesDesPictogrammes.composant, licences: "ISC, MIT",
            role: "Les pictogrammes du fil d'activité.",
            textes: [.ecrit(LicencesDesPictogrammes.isc), .ecrit(LicencesDesPictogrammes.mit)]),
        paquet("swift-openapi-runtime", role: "Les types du client de l'API de CoproFirst.", avis: true),
        paquet("swift-openapi-urlsession", role: "Le transport des requêtes vers la résidence.", avis: true),
        paquet("swift-http-types", role: "Les requêtes et les réponses HTTP.", avis: true),
        // Sans fichier NOTICE dans son dépôt : la licence seule.
        paquet("swift-collections", role: "La file d'attente du transport.", avis: false),
    ]

    private static func paquet(_ nom: String, role: String, avis: Bool) -> ComposantTiers {
        ComposantTiers(
            nom: nom, licences: apache, role: role,
            textes: (avis ? [.embarque("NOTICE-\(nom)")] : []) + [.embarque(apache)])
    }
}

/// Un composant tiers et ses textes entiers : l'avis doit accompagner chaque copie.
struct LicencesTiercesView: View {
    @Environment(\.palette) private var palette
    let composant: ComposantTiers

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Mise.marge) {
                Text(composant.role)
                    .font(.body).foregroundStyle(palette.text)
                ForEach(Array(composant.lus().enumerated()), id: \.offset) { _, texte in
                    Text(texte)
                        .font(.footnote.monospaced())
                        .foregroundStyle(palette.textMuted)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Mise.marge)
        }
        .background(palette.bg)
        .navigationTitle(composant.nom)
        .navigationBarTitleDisplayMode(.inline)
    }
}
