// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Le menu « Mes affaires » (`mes-demandes`) : Liste · Kanban · Archives, et
/// « Nouvelle affaire ». Un onglet du site est un segment de cet écran (#10).
struct AffairesView: View {
    let installation: Installation
    var titre = "Mes affaires"
    /// La pile de l'onglet : une carte y pousse le détail de son affaire.
    @Binding var chemin: NavigationPath
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours
    @Environment(Reseau.self) private var reseau
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var etat = EtatAffaires()
    @State private var onglet = "liste"
    @State private var nouvelle = false
    /// Les sections essentielles de chaque catégorie, lues d'avance : « Nouvelle affaire »
    /// s'ouvre composée, sans qu'une section change de place sous le pouce (#69).
    @State private var essentielles: SectionsEssentielles?

    private var droits: DroitsAffaires { DroitsAffaires(profil: parcours.ouverteAJour?.profil) }
    /// Les onglets que la réserve de chacun ouvre à ce compte (`ongletsOuverts` du site).
    private var onglets: [OngletDuSite] { droits.onglets }
    /// La saisie du compte, telle que le serveur la sert (`saisie_affaire_effective`).
    private var forme: FormeDeSaisie? {
        ModeSaisie(servi: parcours.ouverteAJour?.profil?.saisieAffaire).map {
            FormeDeSaisie(mode: $0, essentielles: essentielles)
        }
    }

    var body: some View {
        let service = parcours.service.menuAffaires
        // L'en-tête au-dessus du contenu, pas en marge de la liste : posé en marge, il
        // couvrait le grand titre des onglets qui défilent (Liste, Archives).
        VStack(spacing: 0) {
            enTete
            contenu(service).frame(maxHeight: .infinity)
        }
        .background(palette.bg)
        .navigationTitle(titre)
        // Aux tailles d'accessibilité, un grand titre fixe prendrait la moitié de l'écran.
        .titreDeMenu()
        .navigationDestination(for: AffaireAOuvrir.self) { cible in
            DetailAffaireView(id: cible.id, installation: installation)
        }
        .toolbar {
            PastilleOuSuisJe(installation: installation, cloche: true)
            ToolbarItem(placement: .topBarLeading) { boutonNouvelle }
        }
        .sheet(isPresented: $nouvelle) {
            NouvelleAffaireView(installation: installation, droits: droits, service: service, forme: forme) { creee in
                etat.ajouter(creee)
                onglet = "liste"
            }
        }
        .alert(
            "Le geste n'a pas abouti",
            isPresented: Binding(get: { etat.avis != nil }, set: { if !$0 { etat.avis = nil } }),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(etat.avis ?? "") }
        )
        .onChange(of: onglets) { _, ouverts in
            if !ouverts.contains(where: { $0.id == onglet }) { onglet = "liste" }
        }
        .task {
            await etat.charger(installation, avec: service)
            await parcours.rafraichirProfil()
        }
        .task(id: nouvelle) {
            // Lues à l'arrivée ; relues à l'ouverture de la feuille si la première lecture a échoué.
            guard essentielles == nil, let service else { return }
            essentielles = try? await service.sectionsEssentielles(installation)
        }
    }

    @ViewBuilder
    private func contenu(_ service: (any ServiceAffaires)?) -> some View {
        switch onglet {
        case "kanban":
            KanbanAffaires(etat: etat, installation: installation, droits: droits, service: service, ouvrir: ouvrir)
        case "archives":
            ArchivesAffaires(etat: etat, installation: installation, service: service, ouvrir: ouvrir)
        default:
            ListeAffaires(
                etat: etat, installation: installation, droits: droits, service: service, ouvrir: ouvrir
            ) {
                nouvelle = true
            }
        }
    }

    private func ouvrir(_ affaire: Affaire) { chemin.append(AffaireAOuvrir(id: affaire.id)) }

    /// Le choix de l'onglet, sur la matière de la barre : le contenu défile dessous.
    private var enTete: some View {
        VStack(spacing: 0) {
            if !reseau.enLigne { BandeauHorsLigne() }
            if onglets.count > 1 {
                Picker("Onglet", selection: $onglet.animation(mouvementReduit ? nil : .snappy)) {
                    ForEach(onglets) { onglet in
                        Text(onglet.libelle).tag(onglet.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Mise.marge)
                .padding(.vertical, 8)
                .accessibilityIdentifier("affaires.onglets")
            }
        }
        .sensoryFeedback(.selection, trigger: onglet)
    }

    private var boutonNouvelle: some View {
        Button {
            nouvelle = true
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(palette.primaryPlein)
        .accessibilityLabel("Nouvelle affaire")
        .accessibilityIdentifier("affaires.nouvelle")
    }
}

/// Une affaire à ouvrir dans la pile de l'onglet : son détail (`DetailAffaireView`).
struct AffaireAOuvrir: Hashable {
    let id: Int
}

extension AffairesView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre, chemin: contexte.chemin)
    }
}
