// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet Kanban : les affaires suivies, non archivées, par état — une colonne par
/// étape du workflow, qui défilent de côté et s'alignent. Les colonnes, la colonne de
/// chaque carte et l'état qu'une colonne pose sont SERVIS (`GET /tickets/referentiels`,
/// `colonne_kanban`, #83) : l'app ne range rien elle-même.
///
/// Une carte se déplace si le serveur le permet à CE lecteur (`peut_deplacer_au_kanban`,
/// le conseil seul) : glisser-déposer, ou « Déplacer vers… » dans le menu de la carte —
/// le geste d'iOS que VoiceOver atteint aussi. Un déplacement est une Suite d'état sans
/// texte, qui n'avertit personne.
struct KanbanAffaires: View {
    @Bindable var etat: EtatAffaires
    let installation: Installation
    let service: (any ServiceAffaires)?
    let ouvrir: (Affaire) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var visible: String?
    @State private var cible: String?
    @State private var aClore: Cloture?
    @State private var deplacees = 0

    /// Une clôture qui pourrait absorber des affaires liées : on demande d'abord.
    private struct Cloture: Identifiable {
        let affaire: Affaire
        let statut: ReferentielsAffaires.Statut
        let candidates: Int
        var id: Int { affaire.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let erreur = erreurAffichee {
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
        .onChange(of: etat.referentiels?.colonnes.first?.id, initial: true) { _, premiere in
            if visible == nil { visible = premiere }
        }
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

    /// L'échec de la liste, ou celui des référentiels tant qu'aucun n'est lu : sans
    /// colonnes servies, il n'y a pas de tableau à montrer.
    private var erreurAffichee: ErreurAffaires? {
        if case .erreur(let erreur) = etat.phase { return erreur }
        return etat.referentiels == nil ? etat.erreurReferentiels : nil
    }

    /// Les colonnes servies ; deux colonnes muettes tant qu'elles ne sont pas lues.
    private var colonnesServies: [ColonneKanban] {
        etat.referentiels?.colonnes
            ?? (0..<2).map { ColonneKanban(id: "attente.\($0)", libelle: " ", libelleCourt: " ") }
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
                    ForEach(etat.referentiels?.colonnes ?? []) { colonne in
                        Button {
                            withAnimation(mouvementReduit ? nil : .smooth) { visible = colonne.id }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(palette[keyPath: colonne.teinte]).frame(width: 8, height: 8)
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
                ForEach(colonnesServies) { colonne in
                    ColonneDuKanban(
                        colonne: colonne,
                        cartes: etat.phase == .chargement || etat.referentiels == nil ? nil : etat.cartes(de: colonne),
                        cible: cible == colonne.id, ouvrir: ouvrir,
                        emoji: { etat.referentiels?.categorie($0.categorie)?.emoji },
                        destinations: { affaire in destinations(de: affaire) },
                        deplacer: { affaire, vers in demander(affaire, vers: vers) }
                    )
                    .containerRelativeFrame(.horizontal) { largeur, _ in largeur * 0.86 }
                    .dropDestination(for: String.self) { ids, _ in
                        guard let id = ids.first.flatMap(Int.init),
                            let affaire = etat.affaires.first(where: { $0.id == id }), affaire.peutDeplacer
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

    /// Les colonnes où la carte peut aller : celles où un état servi mène, sauf la sienne.
    private func destinations(de affaire: Affaire) -> [ColonneKanban] {
        guard let referentiels = etat.referentiels else { return [] }
        return referentiels.colonnes.filter {
            $0.id != affaire.colonne && referentiels.statut(pourColonne: $0.id) != nil
        }
    }

    /// Clore demande d'abord si des affaires liées pourraient y être fusionnées
    /// (`demanderFusion` du site) : l'app ne fusionne pas, elle le dit. « Clore », c'est
    /// l'état servi comme clos (`clos` des référentiels), jamais une liste écrite ici.
    private func demander(_ affaire: Affaire, vers colonne: ColonneKanban) {
        guard affaire.peutDeplacer, let statut = etat.referentiels?.statut(pourColonne: colonne.id),
            statut.code != affaire.statut
        else { return }
        Task {
            if statut.clos, !affaire.close, let service,
                let candidates = try? await service.candidatesALaFusion(affaire, dans: installation), candidates > 0
            {
                aClore = Cloture(affaire: affaire, statut: statut, candidates: candidates)
                return
            }
            await deplacer(affaire, vers: statut)
        }
    }

    private func deplacer(_ affaire: Affaire, vers statut: ReferentielsAffaires.Statut) async {
        await etat.deplacer(affaire, vers: statut, dans: installation, avec: service)
        if etat.avis == nil {
            deplacees += 1
            if let colonne = statut.colonne {
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
    let ouvrir: (Affaire) -> Void
    /// Le pictogramme servi de la catégorie d'une carte.
    let emoji: (Affaire) -> String?
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
            .overlay(alignment: .top) { palette[keyPath: colonne.teinte].frame(height: 3) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let cartes {
                        ForEach(cartes) { affaire in carte(affaire) }
                        if cartes.isEmpty {
                            Text(TablesAffaires.colonneVide)
                                .font(.footnote)
                                .foregroundStyle(palette.textMuted)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                    } else {
                        ForEach(0..<2, id: \.self) { _ in
                            CarteKanban(affaire: ServiceSimule.affaires[4], emoji: nil).redacted(reason: .placeholder)
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
            CarteKanban(affaire: affaire, emoji: emoji(affaire))
        }
        .buttonStyle(StyleCarte())
        .contextMenu {
            if affaire.peutDeplacer {
                Menu {
                    ForEach(destinations(affaire)) { vers in
                        Button(vers.libelle) { deplacer(affaire, vers) }
                    }
                } label: {
                    Label("Déplacer vers…", systemImage: "arrow.left.arrow.right")
                }
            }
        }
        .modifier(Saisissable(actif: affaire.peutDeplacer, id: affaire.id))
        .accessibilityActions {
            if affaire.peutDeplacer {
                ForEach(destinations(affaire)) { vers in
                    Button("Déplacer vers \(vers.libelle)") { deplacer(affaire, vers) }
                }
            }
        }
        .accessibilityIdentifier("kanban.carte.\(affaire.numero)")
    }
}

/// Une carte qui se saisit pour glisser — si le serveur le permet ; ailleurs, rien ne bouge.
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
