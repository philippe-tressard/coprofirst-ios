// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet Kanban : les affaires suivies, non archivées, par état — une colonne par
/// étape du workflow (`KANBAN_COLS`), qui défilent de côté et s'alignent.
///
/// Le conseil seul déplace une carte (`isCS` du site) : glisser-déposer, ou « Déplacer
/// vers… » dans le menu de la carte — le geste d'iOS que VoiceOver atteint aussi.
/// Un déplacement est une Suite d'état sans texte, qui n'avertit personne.
struct KanbanAffaires: View {
    @Bindable var etat: EtatAffaires
    let installation: Installation
    let droits: DroitsAffaires
    let service: (any ServiceAffaires)?
    let ouvrir: (Affaire) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var visible: String? = TablesDuSite.colonnesKanban.first?.id
    @State private var cible: String?
    @State private var aClore: Cloture?
    @State private var deplacees = 0

    /// Une clôture qui pourrait absorber des affaires liées : on demande d'abord.
    private struct Cloture: Identifiable {
        let affaire: Affaire
        let statut: String
        let candidates: Int
        var id: Int { affaire.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .erreur(let erreur) = etat.phase {
                ContentUnavailableView {
                    Label("Impossible d'afficher le Kanban", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(erreur.phrase)
                } actions: {
                    Button("Réessayer") { Task { await etat.charger(installation, avec: service) } }
                        .buttonStyle(.plein)
                        .fixedSize()
                }
            } else {
                sauts
                colonnes
            }
        }
        .sensoryFeedback(.success, trigger: deplacees)
        .confirmationDialog(
            "Clore cette affaire ?", isPresented: Binding(get: { aClore != nil }, set: { if !$0 { aClore = nil } }),
            titleVisibility: .visible, presenting: aClore
        ) { cloture in
            Button("Clore sans fusionner") { Task { await deplacer(cloture.affaire, vers: cloture.statut) } }
            Button("Annuler", role: .cancel) {}
        } message: { cloture in
            Text(
                "\(cloture.candidates) affaire(s) liée(s) pourraient y être fusionnées. "
                    + "La fusion se fait depuis le site.")
        }
    }

    /// Le compte, puis une pastille par colonne : un toucher y mène.
    private var sauts: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etat.phase == .pret ? "\(etat.suiviesAuKanban) affaire(s) suivie(s)" : " ")
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .padding(.horizontal, Mise.marge)
                .accessibilityIdentifier("kanban.compte")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TablesDuSite.colonnesKanban) { colonne in
                        Button {
                            withAnimation(mouvementReduit ? nil : .smooth) { visible = colonne.id }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(colonne.teinte).frame(width: 8, height: 8)
                                Text(colonne.libelleCourt)
                                Text(etat.cartes(de: colonne).count, format: .number)
                                    .monospacedDigit()
                                    .foregroundStyle(palette.textMuted)
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(palette.text)
                            .padding(.horizontal, 12)
                            .frame(minHeight: Mise.cible)
                            .background(
                                visible == colonne.id ? palette.primaryLight : palette.surface, in: .capsule
                            )
                            .overlay { Capsule().strokeBorder(palette.border, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(colonne.libelle), \(etat.cartes(de: colonne).count) affaires")
                        .accessibilityAddTraits(visible == colonne.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Mise.marge)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
        // Une rangée de navigation, pas du contenu : bornée, elle laisse la place aux colonnes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var colonnes: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(TablesDuSite.colonnesKanban) { colonne in
                    ColonneDuKanban(
                        colonne: colonne, cartes: etat.phase == .chargement ? nil : etat.cartes(de: colonne),
                        cible: cible == colonne.id, peutDeplacer: droits.moderateur, ouvrir: ouvrir,
                        destinations: { affaire in destinations(de: affaire) },
                        deplacer: { affaire, vers in demander(affaire, vers: vers) }
                    )
                    .containerRelativeFrame(.horizontal) { largeur, _ in largeur * 0.86 }
                    .dropDestination(for: String.self) { ids, _ in
                        guard droits.moderateur, let id = ids.first.flatMap(Int.init),
                            let affaire = etat.affaires.first(where: { $0.id == id })
                        else { return false }
                        demander(affaire, vers: colonne)
                        return true
                    } isTargeted: { dessus in
                        withAnimation(.snappy(duration: 0.2)) {
                            if dessus { cible = colonne.id } else if cible == colonne.id { cible = nil }
                        }
                    }
                    .id(colonne.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visible)
        .contentMargins(.horizontal, Mise.marge, for: .scrollContent)
        .scrollIndicators(.hidden)
        .refreshable { await etat.charger(installation, avec: service) }
    }

    /// Les colonnes où la carte peut aller : toutes, sauf la sienne.
    private func destinations(de affaire: Affaire) -> [ColonneKanban] {
        TablesDuSite.colonnesKanban.filter { $0.id != affaire.colonne }
    }

    /// Clore demande d'abord si des affaires liées pourraient y être fusionnées
    /// (`demanderFusion` du site) : l'app ne fusionne pas, elle le dit.
    private func demander(_ affaire: Affaire, vers colonne: ColonneKanban) {
        guard let statut = TablesDuSite.statutParColonne[colonne.id], statut != affaire.statut else { return }
        Task {
            if TablesDuSite.statutsClos.contains(statut), !affaire.close, let service,
                let candidates = try? await service.candidatesALaFusion(affaire, dans: installation), candidates > 0
            {
                aClore = Cloture(affaire: affaire, statut: statut, candidates: candidates)
                return
            }
            await deplacer(affaire, vers: statut)
        }
    }

    private func deplacer(_ affaire: Affaire, vers statut: String) async {
        await etat.deplacer(affaire, vers: statut, dans: installation, avec: service)
        if etat.avis == nil {
            deplacees += 1
            if let colonne = TablesDuSite.colonneParStatut[statut] {
                withAnimation(mouvementReduit ? nil : .smooth) { visible = colonne }
            }
        }
    }
}

/// Une colonne : son en-tête teinté, son compte, ses cartes — ou « Aucune affaire ».
private struct ColonneDuKanban: View {
    let colonne: ColonneKanban
    /// `nil` pendant le chargement : le squelette, jamais « Aucune affaire ».
    let cartes: [Affaire]?
    let cible: Bool
    let peutDeplacer: Bool
    let ouvrir: (Affaire) -> Void
    let destinations: (Affaire) -> [ColonneKanban]
    let deplacer: (Affaire, ColonneKanban) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(colonne.libelle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                if let cartes {
                    Text(cartes.count, format: .number)
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(alignment: .top) { colonne.teinte.frame(height: 3) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let cartes {
                        ForEach(cartes) { affaire in carte(affaire) }
                        if cartes.isEmpty {
                            Text(TablesDuSite.colonneVide)
                                .font(.footnote)
                                .foregroundStyle(palette.textMuted)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                    } else {
                        ForEach(0..<2, id: \.self) { _ in
                            CarteKanban(affaire: ServiceSimule.affaires[4]).redacted(reason: .placeholder)
                        }
                        .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(cible ? palette.primaryLight : palette.surface.opacity(0.55))
        .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(cible ? palette.primary : palette.border, lineWidth: cible ? 2 : 1)
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(colonne.libelle)
        .accessibilityIdentifier("kanban.colonne.\(colonne.id)")
    }

    private func carte(_ affaire: Affaire) -> some View {
        Button {
            ouvrir(affaire)
        } label: {
            CarteKanban(affaire: affaire)
        }
        .buttonStyle(StyleCarte())
        .contextMenu {
            if peutDeplacer {
                Menu {
                    ForEach(destinations(affaire)) { vers in
                        Button(vers.libelle) { deplacer(affaire, vers) }
                    }
                } label: {
                    Label("Déplacer vers…", systemImage: "arrow.left.arrow.right")
                }
            }
        }
        .modifier(Saisissable(actif: peutDeplacer, id: affaire.id))
        .accessibilityActions {
            if peutDeplacer {
                ForEach(destinations(affaire)) { vers in
                    Button("Déplacer vers \(vers.libelle)") { deplacer(affaire, vers) }
                }
            }
        }
        .accessibilityIdentifier("kanban.carte.\(affaire.numero)")
    }
}

/// Une carte qui se saisit pour glisser — au conseil seul ; ailleurs, rien ne bouge.
private struct Saisissable: ViewModifier {
    let actif: Bool
    let id: Int

    func body(content: Content) -> some View {
        if actif {
            content.draggable(String(id))
        } else {
            content
        }
    }
}
