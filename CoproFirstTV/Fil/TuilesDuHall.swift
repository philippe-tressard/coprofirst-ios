// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import UIKit

/// Une tuile de la grille (#429), à sa place : ce qu'on lit de loin — l'essentiel, les photos
/// en vignettes, le QR code. Le texte entier attend la mise en avant (`MiseEnAvantView`).
struct TuileView: View {
    let tuile: TuileDuHall
    let diffusion: DiffusionDuFil
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch tuile {
            case .urgence(let element): urgence(element)
            case .epingles(let elements): epingles(elements)
            case .sondage(let sondage):
                communaute(
                    "sondage_ouvert", titre: sondage.question, compteur: EcranDeHall.votants(sondage.votants),
                    appel: EcranDeHall.voterDansLApp, lien: sondage.lien)
            case .idee(let idee):
                communaute(
                    "idee", titre: idee.titre, compteur: EcranDeHall.soutiens(idee.soutiens),
                    appel: EcranDeHall.soutenirDansLApp, lien: idee.lien)
            case .annonce(let annonce): AnnonceView(annonce: annonce, diffusion: diffusion)
            case .carte(let element): CarteDuHallView(element: element, diffusion: diffusion)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hall.tuile.\(tuile.id)")
    }

    /// Rouge plein, comme l'urgence du Fil du site.
    private func urgence(_ element: ElementDuHall) -> some View {
        HStack(alignment: .top, spacing: MiseTV.joint) {
            VStack(alignment: .leading, spacing: 8) {
                EnTeteDeTuile(libelle: EcranDeHall.urgent, icone: element.nature.icone)
                Text(element.titre).font(.headline.weight(.bold)).lineLimit(2)
                if let detail = element.detail {
                    Text(TexteDuSite.apercu(detail)).font(.callout).lineLimit(1)
                }
                Spacer(minLength: 0)
                LigneDuLieu(element: element)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 12) {
                CodeQRView(adresse: diffusion.adresse(element.lien), cote: MiseTV.codeQR, titre: element.titre)
                Spacer(minLength: 0)
                VignettesDuHall(source: .element(element.id), nombre: element.photos, diffusion: diffusion)
            }
        }
        .foregroundStyle(palette.surPlein)
        .surfaceDeTuile(palette.dangerPlein)
    }

    /// Fond doré pâle : les épinglés réunis, chacun sur sa ligne avec son QR code — avec son
    /// détail quand la tuile le tient, son titre seul sinon : tout se lit dans la mise en avant.
    private func epingles(_ elements: [ElementDuHall]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EnTeteDeTuile(libelle: EcranDeHall.epingle, icone: "pin")
                .foregroundStyle(palette.jauneTexte)
            // Toute la hauteur qui reste lui est proposée : sinon, partagée avec un espaceur, elle
            // retombait aux titres seuls alors que les détails tenaient.
            ViewThatFits(in: .vertical) {
                lignesEpinglees(elements, details: true)
                lignesEpinglees(elements, details: false)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .foregroundStyle(palette.text)
        .surfaceDeTuile(palette.jauneFond)
    }

    private func lignesEpinglees(_ elements: [ElementDuHall], details: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(elements) { element in
                HStack(spacing: MiseTV.joint) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(element.titre).font(.headline).lineLimit(1)
                        if details, let detail = element.detail {
                            Text(TexteDuSite.apercu(detail)).font(.subheadline).foregroundStyle(palette.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CodeQRView(adresse: diffusion.adresse(element.lien), cote: MiseTV.codeQRPetit, titre: element.titre)
                }
            }
        }
    }

    /// Un sondage, une idée : la teinte de sa rubrique au Fil, son compteur, son QR code.
    private func communaute(
        _ type: String, titre: String, compteur: String, appel: String, lien: String
    ) -> some View {
        let nature = NaturesDuFil.parType[type] ?? .inconnue
        return VStack(alignment: .leading, spacing: 8) {
            EnTeteDeTuile(libelle: nature.libelle, icone: nature.icone)
                .foregroundStyle(palette[keyPath: nature.couleur])
            Text(titre).font(.callout.weight(.semibold)).lineLimit(2).layoutPriority(1)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 16) {
                CodeQRView(adresse: diffusion.adresse(lien), cote: MiseTV.codeQR, titre: titre)
                VStack(alignment: .leading, spacing: 2) {
                    Text(compteur).font(.headline.monospacedDigit())
                    Text(appel).font(.caption).foregroundStyle(palette.textMuted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(palette.text)
        .surfaceDeTuile(palette[keyPath: nature.fond])
    }
}

/// La petite annonce : sa photo en vignette, son prix, son QR code.
private struct AnnonceView: View {
    let annonce: AnnonceALaUne
    let diffusion: DiffusionDuFil
    @Environment(\.palette) private var palette

    var body: some View {
        let nature = NaturesDuFil.parType["annonce"] ?? .inconnue
        HStack(alignment: .top, spacing: MiseTV.joint) {
            VStack(alignment: .leading, spacing: 8) {
                EnTeteDeTuile(libelle: nature.libelle, icone: nature.icone)
                    .foregroundStyle(palette[keyPath: nature.couleur])
                Text(annonce.titre).font(.headline).lineLimit(2)
                if let prix = AnnoncePrix.texte(annonce) { Text(prix).font(.callout.monospacedDigit()) }
                Spacer(minLength: 0)
                VignettesDuHall(source: .annonce(annonce.id), nombre: annonce.photos, diffusion: diffusion)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .center, spacing: 6) {
                Spacer(minLength: 0)
                CodeQRView(adresse: diffusion.adresse(annonce.lien), cote: MiseTV.codeQR, titre: annonce.titre)
                Text(EcranDeHall.repondreDansLApp).font(.caption).foregroundStyle(palette.textMuted).lineLimit(1)
            }
        }
        .foregroundStyle(palette.text)
        .surfaceDeTuile(palette[keyPath: nature.fond])
    }
}

/// Le prix d'une annonce, sur la tuile et dans la mise en avant.
enum AnnoncePrix {
    /// « 180,00 €, à débattre » ; rien pour un don ou une recherche.
    static func texte(_ annonce: AnnonceALaUne) -> String? {
        guard let centimes = annonce.prixCentimes else { return nil }
        let montant = FormatsDuSite.montant(centimes: centimes)
        return annonce.negociable ? "\(montant), \(EcranDeHall.aDebattre)" : montant
    }
}

/// Le libellé d'une tuile, en capitales, précédé du pictogramme de sa rubrique (Lucide, traduit).
struct EnTeteDeTuile: View {
    let libelle: String
    let icone: String

    var body: some View {
        Label(libelle, systemImage: Pictogrammes.symbole(icone))
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .tracking(Mise.approcheLibelle * 2)
    }
}

/// Le délai et le lieu servis d'un élément, sur une ligne : « J-2 · Parking ». Une carte du
/// carrousel porte déjà son délai en tête : le lieu seul.
struct LigneDuLieu: View {
    let element: ElementDuHall
    var avecEcheance = true

    var body: some View {
        let morceaux = [avecEcheance ? element.echeance : nil, element.lieu].compactMap { $0 }
        if !morceaux.isEmpty {
            Text(morceaux.joined(separator: Separateur.point)).font(.caption.weight(.semibold)).lineLimit(1)
        }
    }
}

/// Les photos d'un élément en vignettes : trois au plus, puis « +N » — la carte FERMÉE de
/// l'iPhone (`VignettePieces`) n'en montre qu'une, l'écran de hall, lu de loin, en montre trois
/// (divergence déclarée, `ux-patterns-ios`).
struct VignettesDuHall: View {
    let source: SourcePhoto
    let nombre: Int
    let diffusion: DiffusionDuFil
    @State private var photos: [UIImage] = []
    @Environment(\.palette) private var palette

    var body: some View {
        if nombre > 0 {
            HStack(spacing: 8) {
                ForEach(0..<min(nombre, MiseTV.vignettesMax), id: \.self) { rang in
                    Group {
                        if photos.indices.contains(rang) {
                            Image(uiImage: photos[rang]).resizable().scaledToFill()
                        } else {
                            palette.neutreFond
                        }
                    }
                    .frame(width: MiseTV.vignette, height: MiseTV.vignette)
                    .clipShape(.rect(cornerRadius: MiseTV.rayon / 3, style: .continuous))
                }
                if nombre > MiseTV.vignettesMax {
                    Text("+\(nombre - MiseTV.vignettesMax)")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 12)
                        .frame(height: MiseTV.vignette)
                        .background(.thinMaterial, in: .rect(cornerRadius: MiseTV.rayon / 3, style: .continuous))
                }
            }
            .accessibilityHidden(true)
            .task(id: source) {
                photos = await diffusion.photosDe(source, nombre: nombre).compactMap(UIImage.init(data:))
            }
        }
    }
}

extension View {
    /// Le fond, le dedans et l'arrondi d'une tuile ; ce qui n'y tient pas (un très grand texte)
    /// reste dans la tuile, jamais sur la voisine.
    func surfaceDeTuile(_ fond: Color) -> some View {
        padding(MiseTV.dedans)
            // Un minimum nul : la tuile prend la place que lui donne sa rangée, pas celle de son texte.
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .background(fond)
            .clipShape(.rect(cornerRadius: MiseTV.rayon, style: .continuous))
    }
}
