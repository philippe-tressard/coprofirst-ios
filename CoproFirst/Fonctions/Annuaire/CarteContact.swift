// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Un rôle mis en avant sur une carte (« Président du Conseil Syndical »).
struct Medaille: Hashable {
    let titre: String
    let symbole: String
}

/// La carte d'une personne de l'annuaire (`CarteContact.svelte`) : l'avatar, le nom,
/// les médaillons, puis ce que la section y ajoute (lieu, fonction, coordonnées).
struct CarteContact<Detail: View>: View {
    let personne: Annuaire.Membre
    let medaillons: [Medaille]
    var principal = false
    let installation: Installation
    @ViewBuilder let detail: () -> Detail
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        // L'avatar en haut, à hauteur du nom, comme dans Contacts ; au-dessus du nom aux
        // très grandes tailles, qui sinon se couperait au milieu d'un mot.
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        disposition {
            Avatar(personne: personne, installation: installation)
            VStack(alignment: .leading, spacing: 6) {
                Text(personne.nomComplet).font(.headline).foregroundStyle(palette.text)
                ForEach(medaillons, id: \.self) { medaille in
                    Label(medaille.titre, systemImage: medaille.symbole)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primary)
                }
                detail()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            // Le gestionnaire principal : un liseré de la couleur d'accent, comme sur le site.
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(principal ? palette.accent : palette.border, lineWidth: principal ? 2 : 1)
        }
    }
}

/// La photo de la personne, ou ses initiales.
private struct Avatar: View {
    let personne: Annuaire.Membre
    let installation: Installation
    @Environment(\.palette) private var palette
    /// Plafonné : l'avatar n'a pas à grandir comme le texte qu'il accompagne.
    @ScaledMetric(relativeTo: .headline) private var coteSuivi: CGFloat = 48
    private var cote: CGFloat { min(coteSuivi, 72) }

    var body: some View {
        Group {
            if let photo = personne.photoUrl, !photo.isEmpty {
                PhotoProtegee(chemin: photo, installation: installation)
            } else {
                Text(personne.initiales)
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.primaryLight)
            }
        }
        .frame(width: cote, height: cote)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Le courriel et les numéros d'un contact : chacun s'ouvre d'un toucher.
struct Coordonnees: View {
    let personne: Annuaire.Membre
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let email = personne.email, !email.isEmpty, let lien = URL(string: "mailto:\(email)") {
                action(email, symbole: "envelope", lien: lien, aide: "Écrit un courriel", id: "annuaire.courriel")
            }
            ForEach(personne.telephones, id: \.self) { numero in
                let chiffres = numero.filter { $0.isNumber || $0 == "+" }
                if let lien = URL(string: "tel:\(chiffres)") {
                    action("📞 \(numero)", symbole: nil, lien: lien, aide: "Appelle ce numéro", id: "annuaire.appeler")
                }
            }
        }
    }

    /// `id` : l'identifiant des tests d'interface — le TYPE d'un `Link` exposé à
    /// l'accessibilité varie d'une version d'iOS à l'autre, pas son identifiant.
    private func action(_ texte: String, symbole: String?, lien: URL, aide: String, id: String) -> some View {
        Link(destination: lien) {
            Group {
                if let symbole { Label(texte, systemImage: symbole) } else { Text(texte) }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(palette.primary)
            .frame(minHeight: Mise.cible, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityHint(aide)
        .accessibilityIdentifier(id)
    }
}

extension AnnuaireView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre)
    }
}
