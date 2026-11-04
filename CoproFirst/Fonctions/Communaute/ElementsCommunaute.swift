// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les éléments archivés, repliés sous la liste : « 📁 Archives (n) ».
struct SectionArchives<Element: Identifiable, Ligne: View>: View {
    let elements: [Element]
    @ViewBuilder let ligne: (Element) -> Ligne
    @State private var ouverte = false
    @Environment(\.palette) private var palette

    var body: some View {
        if !elements.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $ouverte.animation(.snappy)) {
                    ForEach(elements) { ligne($0) }
                } label: {
                    Text("📁 Archives (\(elements.count))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textMuted)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
}

/// L'état d'une liste quand il n'y a rien à montrer : le chargement, l'erreur (avec
/// « Réessayer »), le vide — ou « plus rien en cours » quand tout est archivé.
struct EtatListeCommunaute: View {
    let phase: ListeChargee<Int>.Phase
    let vide: Bool
    let toutArchive: Bool
    let textes: TextesListe
    let reessayer: () -> Void

    var body: some View {
        switch phase {
        case .chargement:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, minHeight: 160)
        case .erreur(let erreur):
            MessageErreur(texte: "\(textes.erreur). \(erreur.phrase)", reessayer: reessayer).padding(Mise.marge)
        case .pret where vide:
            ContentUnavailableView(textes.vide, systemImage: textes.symbole, description: Text(textes.videDetail))
        case .pret where toutArchive:
            ContentUnavailableView(
                textes.enCours, systemImage: "archivebox", description: Text(textes.enCoursDetail))
        case .pret:
            EmptyView()
        }
    }
}

/// Les phrases d'une liste, celles du site.
struct TextesListe {
    let vide: String
    let videDetail: String
    let erreur: String
    let enCours: String
    let enCoursDetail: String
    let symbole: String
}

extension ListeChargee.Phase {
    /// La phase sans son type d'élément, pour `EtatListeCommunaute`.
    var neutre: ListeChargee<Int>.Phase {
        switch self {
        case .chargement: .chargement
        case .pret: .pret
        case .erreur(let erreur): .erreur(erreur)
        }
    }
}

/// Le texte saisi dans l'app devient le HTML que le site attend d'un éditeur riche :
/// échappé, un paragraphe par bloc, un saut de ligne par retour. Jamais de balise
/// venue de la saisie.
enum HTMLDeSaisie {
    static func depuis(_ texte: String) -> String {
        let echappe = texte.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return
            echappe
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "<p>" + $0.replacingOccurrences(of: "\n", with: "<br>") + "</p>" }
            .joined()
    }
}

/// « Signaler au conseil syndical » : un motif obligatoire, puis l'envoi.
struct SignalementCommunaute: ViewModifier {
    @Binding var cible: CibleCommunaute?
    let envoyer: (CibleCommunaute, String) -> Void
    @State private var motif = ""

    func body(content: Content) -> some View {
        content.alert(
            "Signaler au conseil syndical", isPresented: Binding(get: { cible != nil }, set: { if !$0 { cible = nil } })
        ) {
            TextField("Pourquoi signalez-vous ce contenu ?", text: $motif, axis: .vertical)
            Button("Annuler", role: .cancel) { motif = "" }
            Button("Signaler") {
                if let cible { envoyer(cible, motif.trimmingCharacters(in: .whitespacesAndNewlines)) }
                motif = ""
            }
            .disabled(motif.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Le motif sera transmis au conseil syndical, avec le contenu concerné.")
        }
    }
}

/// La phrase d'un geste, un instant en bas de l'écran ; elle s'efface seule.
struct BandeauCommunaute: View {
    @Binding var bandeau: PhraseDuGeste?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    var body: some View {
        ZStack {
            if let bandeau {
                let symbole = bandeau.reussi ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                Label(bandeau.texte, systemImage: symbole)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bandeau.reussi ? palette.text : palette.danger)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: .capsule)
                    .overlay { Capsule().strokeBorder(palette.border, lineWidth: 1) }
                    .padding(.horizontal, Mise.marge)
                    .padding(.bottom, 8)
                    .transition(
                        mouvementReduit ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                    .task(id: bandeau.id) {
                        AccessibilityNotification.Announcement(bandeau.texte).post()
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.snappy) { self.bandeau = nil }
                    }
            }
        }
        .animation(.snappy(duration: 0.3), value: bandeau)
        .sensoryFeedback(trigger: bandeau) { _, nouveau in
            guard let nouveau else { return nil }
            return nouveau.reussi ? .success : .error
        }
    }
}
