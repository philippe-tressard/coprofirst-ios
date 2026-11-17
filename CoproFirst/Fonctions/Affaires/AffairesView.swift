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
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var etat = EtatAffaires()
    @State private var onglet = "liste"
    @State private var nouvelle = false
    /// L'affaire ouverte depuis la liste ou les archives : poussée sur iPhone, à côté de la
    /// liste sur iPad (`ListeEtFiche`, #222). Le Kanban, qui veut toute la largeur, pousse.
    @State private var choisie: AffaireAOuvrir?

    private var droits: DroitsAffaires { DroitsAffaires(profil: parcours.ouverteAJour?.profil) }
    /// Les onglets que la réserve de chacun ouvre à ce compte (`ongletsOuverts` du site).
    private var onglets: [OngletDuSite] { droits.onglets }
    /// La saisie du compte, telle que le serveur la sert (`saisie_affaire_effective`), et
    /// les sections essentielles des référentiels lus à l'arrivée : « Nouvelle affaire »
    /// s'ouvre composée, sans qu'une section change de place sous le pouce (#69).
    private var forme: FormeDeSaisie? {
        FormeDeSaisie(
            servi: parcours.ouverteAJour?.profil?.saisieAffaire, essentielles: etat.referentiels?.essentielles)
    }

    var body: some View {
        let service = parcours.service.menuAffaires
        // L'en-tête au-dessus du contenu, pas en marge de la liste : posé en marge, il
        // couvrait le grand titre des onglets qui défilent (Liste, Archives).
        VStack(spacing: 0) {
            enTete
            if onglet == "kanban" {
                contenu(service).frame(maxHeight: .infinity)
            } else {
                ListeEtFiche(selection: $choisie, memoire: "affaires") {
                    contenu(service).frame(maxHeight: .infinity)
                } fiche: { cible in
                    DetailAffaireView(id: cible.id, installation: installation)
                }
            }
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
            NouvelleAffaireView(
                installation: installation, categories: etat.referentiels?.permises,
                erreurCategories: etat.erreurReferentiels,
                poseLesReservees: etat.referentiels?.poseLesReservees ?? false, service: service, forme: forme
            ) { creee in
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
        // L'affaire d'un lien ou d'une notification (#18, #17) : la porte a choisi cet onglet.
        .onChange(of: parcours.porte.affaireDansLOnglet, initial: true) { ouvrirDemandee() }
        .task {
            await etat.charger(installation, avec: service)
            await parcours.rafraichirProfil()
        }
    }

    @ViewBuilder
    private func contenu(_ service: (any ServiceAffaires)?) -> some View {
        switch onglet {
        case "kanban":
            KanbanAffaires(etat: etat, installation: installation, service: service, ouvrir: ouvrir)
        case "archives":
            ArchivesAffaires(etat: etat, installation: installation, service: service, ouvrir: ouvrir)
        default:
            ListeAffaires(etat: etat, installation: installation, service: service, ouvrir: ouvrir) {
                nouvelle = true
            }
        }
    }

    private func ouvrir(_ affaire: Affaire) { ouvrir(AffaireAOuvrir(id: affaire.id)) }

    private func ouvrir(_ cible: AffaireAOuvrir) {
        if onglet == "kanban" { chemin.append(cible) } else { choisie = cible }
    }

    private func ouvrirDemandee() {
        guard let id = parcours.porte.affaireDansLOnglet else { return }
        parcours.porte.affaireDansLOnglet = nil
        ouvrir(AffaireAOuvrir(id: id))
    }

    /// Le choix de l'onglet, sur la matière de la barre : le contenu défile dessous.
    private var enTete: some View {
        VStack(spacing: 0) {
            BandeauHorsLigne()
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
            // Le libellé nomme aussi le raccourci dans le panneau de ⌘ tenu (#223).
            Label(TextesClavier.nouvelleAffaire, systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(palette.primaryPlein)
        .keyboardShortcut("n")
        .gesteEnLigne()
        .accessibilityIdentifier("affaires.nouvelle")
    }
}

/// Une affaire à ouvrir : son détail (`DetailAffaireView`), poussé ou à côté de la liste.
struct AffaireAOuvrir: Hashable {
    let id: Int
}

/// Le marque-page du pliable garde l'affaire ouverte par son numéro seul (#119).
extension AffaireAOuvrir: SelectionGardable {
    var cleGardee: String { String(id) }

    init?(cleGardee: String) {
        guard let id = Int(cleGardee) else { return nil }
        self.init(id: id)
    }
}

extension AffairesView: EcranDeMenu {
    init(contexte: ContexteDeMenu) {
        self.init(installation: contexte.installation, titre: contexte.page.titre, chemin: contexte.chemin)
    }
}
