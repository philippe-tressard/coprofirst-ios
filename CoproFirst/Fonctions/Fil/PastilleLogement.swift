// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le logement de l'utilisateur, comme l'en-tête de l'accueil du site — en haut à
/// gauche du fil, DANS la barre de navigation, en face de la pastille de la résidence.
/// Un toucher ouvre l'onglet Accès. Sans libellé servi (utilisateur sans lot, ou API
/// qui ne le sert pas) : rien.
///
/// ⚠️ Sa LARGEUR est bornée (`largeurTexte`), celle du nom de la résidence aussi
/// (`largeurNomResidence`). Libres, ils faisaient déborder la barre et iOS repliait la
/// pastille de la résidence et la cloche dans un menu « … » (#8, puis mesuré au
/// simulateur : 434 pt pour 402). Bornés, ils se tronquent ; le libellé entier reste à
/// VoiceOver et à l'agrandissement par appui long.
///
/// Aux tailles d'accessibilité, iOS réduit le grand titre et le coince entre les deux
/// côtés de la barre : le logement redescend alors sous le titre (`ligne`), et la barre
/// rend sa place au nom de la résidence.
enum PastilleLogement {
    /// Le partage de la barre, mesuré au simulateur : logement (pictogramme et texte)
    /// à gauche, pastille de la résidence et cloche à droite tiennent ensemble sur
    /// l'iPhone le plus étroit (375 pt), sans quoi iOS replie la droite.
    static let largeurTexte: CGFloat = 72
    /// Le nom de la résidence, en face du logement (150 pt quand il est seul).
    static let largeurNomResidence: CGFloat = 104

    /// Le libellé servi, s'il y en a un.
    static func libelle(_ profil: ProfilResidence?) -> String? {
        guard let logement = profil?.libelleLogement, !logement.isEmpty else { return nil }
        return logement
    }

    /// La largeur du libellé dans la barre : celle du texte, au plus `largeurTexte`.
    ///
    /// ⚠️ MESURÉE et posée en dur (`frame(width:)`), jamais négociée : la barre ne
    /// propose à un élément que son minimum (le libellé tombait à « B… »), et un
    /// `fixedSize` dans un élément de barre relançait la mise en page sans fin pendant
    /// la présentation d'une feuille sous iOS 26.5 (la confirmation de déconnexion ne
    /// s'ouvrait plus, CI de #46).
    static func largeurLibelle(_ texte: String, taille: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(taille))
        let base = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits)
        let police = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        let largeur = (texte as NSString).size(withAttributes: [.font: police]).width.rounded(.up)
        return min(largeur, largeurTexte)
    }

    /// La place laissée au nom de la résidence : moindre quand le logement est en face.
    static func largeurNom(_ profil: ProfilResidence?, dansLaBarre: Bool) -> CGFloat {
        libelle(profil) != nil && dansLaBarre ? largeurNomResidence : 150
    }

    /// Le logement dans la barre (tailles ordinaires).
    struct Barre: ToolbarContent {
        let profil: ProfilResidence?
        let ouvrir: () -> Void

        var body: some ToolbarContent {
            if let logement = PastilleLogement.libelle(profil) {
                ToolbarItem(placement: .topBarLeading) {
                    Bouton(logement: logement, dansLaBarre: true, ouvrir: ouvrir)
                }
            }
        }
    }

    /// Le logement sous le titre (tailles d'accessibilité) : le même bouton, la largeur
    /// de l'écran.
    struct Ligne: View {
        let profil: ProfilResidence?
        let ouvrir: () -> Void

        var body: some View {
            if let logement = PastilleLogement.libelle(profil) {
                Bouton(logement: logement, dansLaBarre: false, ouvrir: ouvrir)
                    .frame(minHeight: Mise.cible, alignment: .leading)
                    .padding(.horizontal, Mise.marge)
            }
        }
    }

    /// Le bouton, dans la barre ou sous le titre : pictogramme et libellé tronqué.
    private struct Bouton: View {
        let logement: String
        /// Dans la barre : une largeur mesurée et bornée ; sous le titre : toute la place.
        let dansLaBarre: Bool
        let ouvrir: () -> Void
        @Environment(\.palette) private var palette
        @Environment(\.dynamicTypeSize) private var taille

        private var largeur: CGFloat? {
            dansLaBarre ? PastilleLogement.largeurLibelle(logement, taille: taille) : nil
        }

        var body: some View {
            Button(action: ouvrir) {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(palette.primary)
                        .accessibilityHidden(true)
                    Text(logement)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: largeur, alignment: .leading)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityShowsLargeContentViewer {
                Label(logement, systemImage: "mappin.and.ellipse")
            }
            .accessibilityLabel(Text("Mon logement : \(logement)"))
            .accessibilityHint("Ouvre Mes lots & accès")
            .accessibilityIdentifier("fil.lot")
        }
    }
}
