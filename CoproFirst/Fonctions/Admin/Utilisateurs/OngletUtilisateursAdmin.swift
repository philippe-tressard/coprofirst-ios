// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Utilisateurs » (onglet `utilisateurs`) : tous les comptes — recherche, type, état du
/// compte, compteurs —, et chacun s'ouvre sur sa fiche, qui porte les gestes de l'app.
struct OngletUtilisateursAdmin: OngletDePage {
    let contexte: ContexteOnglet
    @State private var etat = EtatUtilisateursAdmin()
    @State private var ouvert: UtilisateurAdmin?

    init(contexte: ContexteOnglet) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceUtilisateurs {
            contenu(service)
                .task(id: contexte.actualisation) { await etat.charger(service, contexte.installation) }
                .sheet(item: $ouvert, onDismiss: { contexte.avis.feuilleFermee() }, content: { compte in
                    FicheUtilisateurAdmin(id: compte.id, etat: etat, service: service, contexte: contexte)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                })
        } else {
            MessageErreur(texte: TextesAdmin.serviceAbsent)
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceUtilisateursAdmin) -> some View {
        switch etat.phase {
        case .chargement:
            VStack(spacing: 10) { ForEach(0..<4, id: \.self) { _ in LigneUtilisateurAdmin.squelette } }
                .redacted(reason: .placeholder)
                .accessibilityLabel("Chargement")
        case .erreur(let phrase):
            MessageErreur(texte: phrase) { Task { await etat.charger(service, contexte.installation) } }
        case .pret:
            liste
        }
    }

    private var liste: some View {
        let affiches = etat.affiches
        return LazyVStack(alignment: .leading, spacing: 10) {
            FiltresUtilisateursAdmin(etat: etat, affiches: affiches.count)
            if affiches.isEmpty {
                ContentUnavailableView.search(text: etat.recherche).padding(.top, 12)
            }
            ForEach(affiches) { compte in
                Button { ouvert = compte } label: { LigneUtilisateurAdmin(compte: compte) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("admin.utilisateur.\(compte.id)")
            }
            RenvoiAuSite(
                texte: TextesUtilisateursAdmin.surLeSite, onglet: "utilisateurs",
                adresse: contexte.installation.adresse)
        }
        .animation(.snappy(duration: 0.25), value: affiches)
    }
}

/// La recherche, le type (menu, comme la pastille déroulante du site), l'état du compte
/// (pastilles, compte sur la retenue) et le compteur.
private struct FiltresUtilisateursAdmin: View {
    @Bindable var etat: EtatUtilisateursAdmin
    let affiches: Int
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChampRecherche(
                texte: $etat.recherche, indication: TextesUtilisateursAdmin.recherche,
                identifiant: "admin.utilisateurs.recherche")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker(TextesUtilisateursAdmin.type, selection: $etat.statut) {
                            Text(TextesUtilisateursAdmin.tousTypes).tag(String?.none)
                            ForEach(TablesAdmin.ordreStatutsCompte, id: \.self) { statut in
                                Text(RolesUtilisateur.libelleStatut(statut)).tag(Optional(statut))
                            }
                        }
                    } label: {
                        Label(
                            etat.statut.map(Self.abrege) ?? TextesUtilisateursAdmin.tousTypes,
                            systemImage: "line.3.horizontal.decrease")
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(palette.primary)
                    .accessibilityIdentifier("admin.utilisateurs.type")
                    ForEach(EtatUtilisateursAdmin.FiltreCompte.allCases) { filtre in
                        Pastille(
                            libelle: Self.libelle(filtre), retenue: etat.compte == filtre,
                            compte: etat.compte == filtre ? affiches : nil
                        ) { withAnimation(.snappy) { etat.compte = filtre } }
                        .accessibilityIdentifier("admin.utilisateurs.compte.\(filtre.rawValue)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            Text(TextesUtilisateursAdmin.compteur(affiches, etat.comptes.count, etat.membresDuConseil))
                .font(.footnote)
                .foregroundStyle(palette.textMuted)
                .contentTransition(.numericText())
        }
        .padding(.bottom, 4)
    }

    static func abrege(_ statut: String) -> String {
        TablesAdmin.abregesStatutCompte[statut] ?? RolesUtilisateur.libelleStatut(statut)
    }

    static func libelle(_ filtre: EtatUtilisateursAdmin.FiltreCompte) -> String {
        switch filtre {
        case .tous: TextesUtilisateursAdmin.tousComptes
        case .actifs: TextesUtilisateursAdmin.actifs
        case .enAttente: TextesUtilisateursAdmin.enAttente
        }
    }
}

/// Un compte dans la liste : nom, e-mail, type, état, rôles, bâtiment — grisé s'il est
/// inactif, comme sur le site.
struct LigneUtilisateurAdmin: View {
    let compte: UtilisateurAdmin
    @Environment(\.palette) private var palette

    static let squelette = Carte {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prénom Nom du compte").font(.headline)
            Text("adresse@exemple.fr").font(.subheadline)
            Text("Copro. résident · Actif").font(.footnote)
        }
    }

    var body: some View {
        Carte {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(compte.nomAffiche).font(.headline).foregroundStyle(palette.text)
                        if compte.ban.banni() {
                            Image(systemName: compte.ban.interdit ? "nosign" : "hourglass")
                                .font(.footnote)
                                .foregroundStyle(palette.danger)
                                .accessibilityLabel(TextesUtilisateursAdmin.communaute)
                        }
                    }
                    Text(compte.email).font(.subheadline).foregroundStyle(palette.textMuted).lineLimit(1)
                    PastillesCompte(compte: compte)
                    if let nom = compte.nomProprietaire, compte.statut == "locataire" {
                        Text(TextesUtilisateursAdmin.bailleur(nom)).font(.footnote).foregroundStyle(palette.textMuted)
                    }
                    if let averti = compte.purgeAvertieLe {
                        Label(TextesUtilisateursAdmin.purgeAvertie(FormatsDuSite.date(averti)), systemImage: "clock")
                            .font(.footnote)
                            .foregroundStyle(palette.warningTexte)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .opacity(compte.actif ? 1 : 0.6)
        .accessibilityElement(children: .combine)
    }
}

/// Le type, l'état du compte, les rôles et le bâtiment, en pastilles teintées du site.
struct PastillesCompte: View {
    let compte: UtilisateurAdmin

    var body: some View {
        FlowCapsules {
            PastilleTeinte(
                libelle: FiltresUtilisateursAdmin.abrege(compte.statut),
                badge: TablesAdmin.teintesStatutCompte[compte.statut] ?? "badge-gray", compacte: true)
            PastilleTeinte(libelle: etatDuCompte.0, badge: etatDuCompte.1, compacte: true)
            ForEach(compte.roles, id: \.self) { role in
                PastilleTeinte(
                    libelle: RolesUtilisateur.libelleRole(role), badge: TablesAdmin.teintesRole[role] ?? "badge-gray",
                    compacte: true)
            }
            if let batiment = compte.batimentNom {
                PastilleTeinte(libelle: batiment, badge: "badge-gray", compacte: true)
            }
        }
    }

    /// Actif ; sinon, faute d'e-mail vérifié ; sinon, en attente de validation.
    private var etatDuCompte: (String, String) {
        if compte.actif { return (TextesUtilisateursAdmin.actif, "badge-green") }
        if !compte.emailVerifie { return (TextesUtilisateursAdmin.emailNonVerifie, "badge-orange") }
        return (TextesUtilisateursAdmin.enAttente, "badge-gray")
    }
}
