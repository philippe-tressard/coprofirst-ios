// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Les textes de la confirmation d'hôte (#82), écrits une fois.
enum ConfirmationHote {
    static let titre = "Vérifiez l'adresse"
    static let annonce = "Votre mot de passe va être envoyé à :"
    static let conseil =
        "Comparez-la lettre à lettre avec celle de votre fiche d'arrivée : une adresse qui lui ressemble "
        + "peut imiter votre résidence."
    static let verification = "Vérification de l'adresse…"
    static let reconnue = "Adresse reconnue comme une installation CoproFirst."
    static let avertissement = "Cette adresse n'est pas reconnue comme une installation CoproFirst."
    static let detailAvertissement =
        "Si vous n'êtes pas certain de l'adresse, ne vous connectez pas : demandez-la au conseil syndical "
        + "ou au gestionnaire de votre résidence."
    static let secondAccord = "Je connais cette adresse et je veux m'y connecter quand même"
    static let confirmer = "Me connecter à cette adresse"
    static let annuler = "Annuler"

    static func nomServi(_ nom: String) -> String { "Ce serveur se présente comme « \(nom) »." }

    /// L'hôte en entier, port compris, tel qu'il recevra le mot de passe — un nom de
    /// domaine international s'y lit sous sa forme encodée (`xn--…`), qui ne se déguise pas.
    static func hote(_ adresse: URL) -> String {
        let hote = adresse.host() ?? adresse.absoluteString
        return adresse.port.map { "\(hote):\($0)" } ?? hote
    }
}

/// L'écran de confirmation, avant le premier mot de passe envoyé à un hôte jamais vu :
/// l'hôte en entier, puis la preuve qu'il sert. La règle vit dans `GardeHote` ; cet
/// écran la montre et lui transmet les deux accords.
struct ConfirmationHoteFeuille: View {
    let installation: Installation
    let confirme: () -> Void
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var fermer
    @State private var secondAccord = false

    private var garde: GardeHote { parcours.garde }
    private var preuve: PreuveHote? { garde.preuve }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                entete
                hote
                etatPreuve
                boutons
            }
            .padding(.horizontal, Mise.marge)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(palette.bg)
        .animation(.snappy, value: preuve)
        .sensoryFeedback(.warning, trigger: preuve) { _, nouvelle in nouvelle.map { !$0.reconnue } ?? false }
        .task(id: installation.adresse) { await garde.verifier() }
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: pictogramme)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(preuve.map { $0.reconnue ? palette.primary : palette.warningTexte } ?? palette.primary)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text(ConfirmationHote.titre)
                .font(.titre(.title2))
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            Text(ConfirmationHote.annonce)
                .font(.body)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pictogramme: String {
        switch preuve {
        case .none: "lock.shield"
        case .some(let preuve): preuve.reconnue ? "checkmark.shield" : "exclamationmark.shield"
        }
    }

    private var hote: some View {
        Carte {
            VStack(alignment: .leading, spacing: 8) {
                HoteSansCesure(hote: ConfirmationHote.hote(installation.adresse), couleur: UIColor(palette.text))
                Text(ConfirmationHote.nomServi(installation.nom))
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ConfirmationHote.conseil)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var etatPreuve: some View {
        switch preuve {
        case .none:
            HStack(spacing: 10) {
                ProgressView().tint(palette.primary)
                Text(ConfirmationHote.verification)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("confirmationHote.verification")
            .transition(.opacity)
        case .some(let preuve) where preuve.reconnue:
            Label(ConfirmationHote.reconnue, systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(palette.successTexte)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("confirmationHote.reconnue")
                .transition(.opacity)
        case .some:
            avertissement.transition(.opacity)
        }
    }

    private var avertissement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(ConfirmationHote.avertissement, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(palette.warningTexte)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("confirmationHote.avertissement")
            Text(ConfirmationHote.detailAvertissement)
                .font(.subheadline)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(isOn: $secondAccord) {
                // Le libellé est long : le toucher, comme l'interrupteur, donne l'accord.
                Text(ConfirmationHote.secondAccord)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(.rect)
                    .onTapGesture { secondAccord.toggle() }
            }
            .tint(palette.warning)
            .accessibilityIdentifier("confirmationHote.secondAccord")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.warningFond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(palette.warningBordure, lineWidth: 1)
        }
    }

    private var boutons: some View {
        VStack(spacing: 10) {
            Button(ConfirmationHote.confirmer) {
                if garde.confirmer(secondAccord: secondAccord) { confirme() }
            }
            .buttonStyle(.plein)
            .disabled(!(preuve.map { $0.reconnue || secondAccord } ?? false))
            .accessibilityIdentifier("confirmationHote.confirmer")
            Button(ConfirmationHote.annuler) {
                garde.renoncer()
                fermer()
            }
            .buttonStyle(.contour)
            .accessibilityIdentifier("confirmationHote.annuler")
        }
        .padding(.top, 4)
    }
}

/// L'hôte, en chasse fixe — un « l » et un « 1 », un « O » et un « 0 » s'y distinguent —,
/// coupé au caractère et JAMAIS par une césure : un trait d'union ajouté par le système
/// (« imita-tion ») se lirait comme un tiret de l'hôte, qui en est un caractère valide.
/// `Text` césure au grand texte ; `UILabel` se règle.
private struct HoteSansCesure: UIViewRepresentable {
    let hote: String
    let couleur: UIColor

    func makeUIView(context: Context) -> UILabel {
        let etiquette = UILabel()
        etiquette.numberOfLines = 0
        etiquette.lineBreakMode = .byCharWrapping
        etiquette.adjustsFontForContentSizeCategory = true
        etiquette.accessibilityIdentifier = "confirmationHote.hote"
        etiquette.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return etiquette
    }

    func updateUIView(_ etiquette: UILabel, context: Context) {
        // La taille du style à la taille par défaut : `UIFontMetrics` l'agrandit, une fois,
        // jusqu'à 34 pt — au-delà, l'hôte ne tiendrait que trois lettres par ligne.
        let defaut = UITraitCollection(preferredContentSizeCategory: .large)
        let base = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .title3, compatibleWith: defaut).pointSize, weight: .semibold)
        let police = UIFontMetrics(forTextStyle: .title3).scaledFont(for: base, maximumPointSize: 34)
        let paragraphe = NSMutableParagraphStyle()
        paragraphe.lineBreakMode = .byCharWrapping
        paragraphe.hyphenationFactor = 0
        etiquette.attributedText = NSAttributedString(
            string: hote, attributes: [.font: police, .foregroundColor: couleur, .paragraphStyle: paragraphe])
        etiquette.accessibilityLabel = hote
    }

    func sizeThatFits(_ proposition: ProposedViewSize, uiView etiquette: UILabel, context: Context) -> CGSize? {
        let largeur = proposition.width ?? UIView.layoutFittingExpandedSize.width
        let taille = etiquette.sizeThatFits(CGSize(width: largeur, height: .greatestFiniteMagnitude))
        return CGSize(width: largeur, height: ceil(taille.height))
    }
}
