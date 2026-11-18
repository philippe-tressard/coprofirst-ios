// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Écrans du hall » (onglet `ecrans`, `OngletEcrans.svelte`, #295) : appairer un écran avec
/// le code qu'il affiche, voir quand il a lu les annonces pour la dernière fois, le retirer.
/// L'écran lui-même est l'app Apple TV (#218).
///
/// La forme est celle du site : l'action primaire en tête, la liste et ses trois états, le
/// retrait confirmé en rouge. La création s'ouvre en feuille (`ux-patterns-ios`).
struct OngletEcransCS: OngletDePage {
    let contexte: ContexteOnglet
    @State private var feuille = false
    @State private var aRetirer: EcranDuHall?
    @State private var erreur: ErreurService?
    /// Augmente à chaque appairage confirmé : la liste se relit quand l'écran a eu le temps
    /// de venir chercher son accès.
    @State private var appairages = 0
    @State private var retraits = 0

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceEcrans {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    feuille = true
                } label: {
                    Label(TextesEcransCS.appairer, systemImage: "plus")
                }
                .buttonStyle(.plein)
                .gesteEnLigne()
                .accessibilityIdentifier("ecrans.appairer")
                liste(service)
            }
            .sheet(
                isPresented: $feuille, onDismiss: { contexte.avis.feuilleFermee() },
                content: {
                    FeuilleAppairage(service: service, installation: contexte.installation) { appaire in
                        contexte.avis.direApresFermeture(TextesEcransCS.appaire(appaire.nom))
                        appairages += 1
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                })
        } else {
            MessageErreur(texte: TextesEspaceCS.serviceAbsent)
        }
    }

    private func liste(_ service: any ServiceEcransCS) -> some View {
        let installation = contexte.installation
        return Chargement(
            charger: { try await service.ecrans(dans: installation) },
            contenu: { ecrans, recharger in
                VStack(alignment: .leading, spacing: 10) {
                    if let erreur { MessageErreur(texte: erreur.phrase) }
                    if ecrans.isEmpty {
                        ContentUnavailableView(
                            TextesEcransCS.videTitre, systemImage: "tv",
                            description: Text(TextesEcransCS.videMessage))
                        .accessibilityIdentifier("ecrans.vide")
                    }
                    ForEach(ecrans) { ecran in
                        CarteEcran(ecran: ecran) { aRetirer = ecran }
                    }
                }
                .animation(.snappy, value: ecrans)
                .task(id: appairages) {
                    guard appairages > 0 else { return }
                    try? await Task.sleep(for: TextesEcransCS.relectureApresAppairage)
                    if !Task.isCancelled { recharger() }
                }
                .confirmationDialog(
                    TextesEcransCS.retirerTitre,
                    isPresented: Binding(get: { aRetirer != nil }, set: { if !$0 { aRetirer = nil } }),
                    titleVisibility: .visible, presenting: aRetirer
                ) { ecran in
                    Button(TextesEcransCS.retirer, role: .destructive) {
                        Task { await retirer(ecran, service, recharger) }
                    }
                    .accessibilityIdentifier("ecrans.retirer.confirmer")
                } message: { ecran in
                    Text(TextesEcransCS.retirerMessage(ecran))
                }
            },
            squelette: { SqueletteEcrans() }
        )
        .id(contexte.actualisation)
        .sensoryFeedback(.success, trigger: retraits)
    }

    private func retirer(_ ecran: EcranDuHall, _ service: any ServiceEcransCS, _ recharger: () -> Void) async {
        aRetirer = nil
        erreur = nil
        do {
            try await service.retirerEcran(ecran.id, dans: contexte.installation)
            contexte.avis.dire(TextesEcransCS.retire)
            retraits += 1
            recharger()
        } catch {
            withAnimation(.snappy) { self.erreur = ErreurService.depuis(error) }
        }
    }
}

/// Un écran : son nom, son lieu, « Échu » s'il l'est, sa dernière lecture — et « Retirer ».
private struct CarteEcran: View {
    let ecran: EcranDuHall
    let retirer: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        Carte {
            let disposition =
                taille.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            disposition {
                VStack(alignment: .leading, spacing: 6) {
                    Text("📺 \(ecran.nom)")
                        .font(.headline)
                        .foregroundStyle(palette.text)
                    if ecran.lieu != nil || ecran.echu {
                        FlowEtiquettes {
                            EtiquetteLieu(lieu: ecran.lieu)
                                .font(.subheadline)
                                .foregroundStyle(palette.textMuted)
                            if ecran.echu {
                                PastilleTeinte(libelle: TextesEcransCS.echu, badge: "badge-gray", compacte: true)
                                    .accessibilityIdentifier("ecran.\(ecran.id).echu")
                            }
                        }
                    }
                    Text(TextesEcransCS.lecture(ecran))
                        .font(.footnote)
                        .foregroundStyle(palette.textMuted)
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(TextesEcransCS.retirer, role: .destructive, action: retirer)
                    .buttonStyle(.bordered)
                    .tint(palette.danger)
                    .frame(minHeight: Mise.cible)
                    .gesteEnLigne()
                    .accessibilityLabel(TextesEcransCS.retirerLibelle(ecran))
                    .accessibilityIdentifier("ecran.\(ecran.id).retirer")
            }
        }
        .accessibilityIdentifier("ecran.\(ecran.id)")
    }
}

private struct SqueletteEcrans: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { _ in
                Carte {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📺 Hall du bâtiment").font(.headline)
                        Text("Dernière lecture : 18 nov. 2026, 08:42").font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
