// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'Espace conseil syndical (page `espace-cs` du site, #15) : le CADRE — titre, barre
/// d'onglets dans l'ordre du site, descriptif de l'onglet, défilement et avis — et
/// l'onglet choisi, que `OngletsEspaceCS` inscrit.
///
/// Réservé au conseil et à l'administration : la barre ne l'offre qu'à eux
/// (`PagesOuvertes`), et l'écran le redit s'il est atteint autrement — le serveur, lui,
/// refuse chaque route à qui n'en est pas.
struct EspaceCSView: View {
    let contexte: ContexteDeMenu
    @Environment(Parcours.self) private var parcours
    @Environment(\.palette) private var palette
    @State private var choisi: String?
    @State private var avis: String?
    @State private var actualisation = 0

    init(contexte: ContexteDeMenu) { self.contexte = contexte }

    private var droits: DroitsOnglet {
        DroitsOnglet(profil: parcours.ouverteAJour?.profil ?? contexte.installation.profil)
    }

    private var onglets: [OngletDuSite] { OngletsDuSite.ouverts(page: "espace-cs", droits: droits) }

    var body: some View {
        Group {
            if PagesOuvertes.ouverte("espace-cs", droits: droits), let actif = onglets.first(where: { $0.id == choisi })
                ?? onglets.first
            {
                page(actif)
            } else {
                ContentUnavailableView(
                    contexte.page.titre, systemImage: "lock.shield",
                    description: Text(TextesEspaceCS.reserve))
            }
        }
        .background(palette.bg)
        // Le libellé du menu (« Espace CS »), et non le titre de la page (« Espace Conseil
        // Syndical (CS) ») : un grand titre ne passe pas à la ligne, il se tronquerait.
        // Écart de rendu assumé avec le site (standards/11 §14) ; le descriptif dit le reste.
        .navigationTitle(contexte.page.libelle)
        .titreDeMenu()
        .toolbar { PastilleOuSuisJe(installation: contexte.installation, cloche: true) }
    }

    private func page(_ actif: OngletDuSite) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BarreOnglets(onglets: onglets, actif: Binding { actif.id } set: { choisi = $0 })
                if let descriptif = TablesEspaceCS.descriptifs[actif.id] {
                    Text(TexteDuSite.apercu(descriptif))
                        .font(.subheadline)
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                OngletsEspaceCS.ecran(actif, contexteOnglet)
                    .id(actif.id)
                    .transition(.opacity)
            }
            .padding(.horizontal, Mise.marge)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .animation(.snappy(duration: 0.22), value: actif.id)
        }
        .refreshable { actualisation += 1 }
        .avisEphemere($avis)
    }

    private var contexteOnglet: ContexteOngletCS {
        ContexteOngletCS(
            installation: contexte.installation, service: parcours.service, droits: droits, avis: $avis,
            actualisation: actualisation)
    }
}

extension EspaceCSView: EcranDeMenu {}

/// Les mots du cadre et ce que les onglets partagent.
enum TextesEspaceCS {
    static let reserve = "Cet espace est réservé au conseil syndical."
    static let serviceAbsent = "Cet onglet n'est pas disponible avec cette résidence."
    static let approuver = "Approuver"
    static let rejeter = "Rejeter"
    static let modifier = "Modifier"
    static let supprimer = "Supprimer"
    static let annuler = "Annuler"
}
