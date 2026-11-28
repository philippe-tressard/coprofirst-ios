// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// La tuile mise en avant (#429) : au hall, personne n'a la télécommande, l'écran agrandit
/// lui-même une tuile et montre tout — le texte entier, les photos en mosaïque (la règle de
/// `DispositionMosaique`), un QR code plus gros. Ni Coup d'œil ni geste : il ne fait que montrer.
struct MiseEnAvantView: View {
    let tuile: TuileDuHall
    let diffusion: DiffusionDuFil
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch tuile {
            case .urgence(let element), .carte(let element): pourElement(element)
            case .epingles(let elements): epingles(elements)
            case .sondage(let sondage):
                communaute(
                    "sondage_ouvert", titre: sondage.question, compteur: EcranDeHall.votants(sondage.votants),
                    lien: sondage.lien)
            case .idee(let idee):
                communaute("idee", titre: idee.titre, compteur: EcranDeHall.soutiens(idee.soutiens), lien: idee.lien)
            case .annonce(let annonce): pourAnnonce(annonce)
            }
        }
        .padding(MiseTV.dedans * 2)
        .frame(width: MiseTV.miseEnAvantLargeur, height: MiseTV.miseEnAvantHauteur, alignment: .topLeading)
        .background(fond, in: .rect(cornerRadius: MiseTV.rayon * 1.5, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hall.miseEnAvant")
        .accessibilityValue(tuile.id)
    }

    private var fond: Color {
        switch tuile {
        case .urgence: palette.dangerPlein
        case .epingles: palette.jauneFond
        case .carte: palette.surface
        case .sondage: palette[keyPath: (NaturesDuFil.parType["sondage_ouvert"] ?? .inconnue).fond]
        case .idee: palette[keyPath: (NaturesDuFil.parType["idee"] ?? .inconnue).fond]
        case .annonce: palette[keyPath: (NaturesDuFil.parType["annonce"] ?? .inconnue).fond]
        }
    }

    /// Un élément du Fil : tout son texte et ses photos à gauche, son QR code à droite.
    private func pourElement(_ element: ElementDuHall) -> some View {
        let urgent = element.registre == .urgent
        return HStack(alignment: .top, spacing: MiseTV.joint * 2) {
            VStack(alignment: .leading, spacing: 18) {
                EnTeteDeTuile(
                    libelle: urgent ? EcranDeHall.urgent : element.nature.libelle, icone: element.nature.icone)
                    .foregroundStyle(urgent ? palette.surPlein : palette[keyPath: element.nature.couleur])
                Text(element.titre).font(.titre(.title2)).lineLimit(3).minimumScaleFactor(0.7)
                LigneDuLieu(element: element)
                if let detail = element.detail {
                    TexteRiche(html: detail).font(.body).tint(urgent ? palette.surPlein : palette.primary)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
                MosaiqueDuHall(source: .element(element.id), nombre: element.photos, diffusion: diffusion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            codeAgrandi(element.lien, titre: element.titre)
        }
        .foregroundStyle(urgent ? palette.surPlein : palette.text)
    }

    private func epingles(_ elements: [ElementDuHall]) -> some View {
        VStack(alignment: .leading, spacing: MiseTV.joint) {
            EnTeteDeTuile(libelle: EcranDeHall.epingle, icone: "pin").foregroundStyle(palette.jauneTexte)
            ForEach(elements) { element in
                HStack(alignment: .top, spacing: MiseTV.joint * 2) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(element.titre).font(.titre(.title3)).lineLimit(2)
                        LigneDuLieu(element: element).foregroundStyle(palette.textMuted)
                        if let detail = element.detail {
                            TexteRiche(html: detail).font(.callout).tint(palette.primary).minimumScaleFactor(0.6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CodeQRView(
                        adresse: diffusion.adresse(element.lien), cote: MiseTV.codeQR * 1.4, titre: element.titre)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.text)
    }

    private func communaute(_ type: String, titre: String, compteur: String, lien: String) -> some View {
        let nature = NaturesDuFil.parType[type] ?? .inconnue
        return HStack(alignment: .top, spacing: MiseTV.joint * 2) {
            VStack(alignment: .leading, spacing: 18) {
                EnTeteDeTuile(libelle: nature.libelle, icone: nature.icone)
                    .foregroundStyle(palette[keyPath: nature.couleur])
                Text(titre).font(.titre(.title2)).lineLimit(4).minimumScaleFactor(0.7)
                Text(compteur).font(.title3.weight(.semibold).monospacedDigit())
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            codeAgrandi(lien, titre: titre)
        }
        .foregroundStyle(palette.text)
    }

    private func pourAnnonce(_ annonce: AnnonceALaUne) -> some View {
        let nature = NaturesDuFil.parType["annonce"] ?? .inconnue
        return HStack(alignment: .top, spacing: MiseTV.joint * 2) {
            VStack(alignment: .leading, spacing: 18) {
                EnTeteDeTuile(libelle: nature.libelle, icone: nature.icone)
                    .foregroundStyle(palette[keyPath: nature.couleur])
                Text(annonce.titre).font(.titre(.title2)).lineLimit(3).minimumScaleFactor(0.7)
                if let prix = AnnoncePrix.texte(annonce) {
                    Text(prix).font(.title3.weight(.semibold).monospacedDigit())
                }
                Spacer(minLength: 0)
                MosaiqueDuHall(source: .annonce(annonce.id), nombre: annonce.photos, diffusion: diffusion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            codeAgrandi(annonce.lien, titre: annonce.titre)
        }
        .foregroundStyle(palette.text)
    }

    /// Le QR code agrandi, et ce qu'il ouvre.
    private func codeAgrandi(_ lien: String, titre: String) -> some View {
        VStack(spacing: 14) {
            CodeQRView(adresse: diffusion.adresse(lien), cote: MiseTV.codeQRAgrandi, titre: titre)
            Text(EcranDeHall.ouvrirDansLApp)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(width: MiseTV.codeQRAgrandi)
        }
    }
}

/// Les photos d'un élément en mosaïque : une grande et deux petites, « +N » (`DispositionMosaique`),
/// lues avec le jeton de l'écran.
private struct MosaiqueDuHall: View {
    let source: SourcePhoto
    let nombre: Int
    let diffusion: DiffusionDuFil
    @State private var photos: [UIImage] = []
    @Environment(\.palette) private var palette

    var body: some View {
        if nombre > 0 {
            DispositionMosaique(nombre: nombre, hauteur: MiseTV.mosaique) { rang, reste in
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if photos.indices.contains(rang) {
                            Image(uiImage: photos[rang]).resizable().scaledToFill()
                        } else {
                            palette.neutreFond
                        }
                    }
                    .clipped()
                    .overlay {
                        if reste > 0 {
                            Rectangle().fill(.thinMaterial)
                            Text("+\(reste)").font(.title2.weight(.semibold).monospacedDigit())
                        }
                    }
            }
            .accessibilityHidden(true)
            .task(id: source) {
                photos = await diffusion.photosDe(source, nombre: nombre).compactMap(UIImage.init(data:))
            }
        }
    }
}
