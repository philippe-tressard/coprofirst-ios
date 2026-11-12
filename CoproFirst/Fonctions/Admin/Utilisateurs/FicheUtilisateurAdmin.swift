// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La fiche d'un compte : ce que le serveur en sert, puis les gestes que l'app porte —
/// chacun offert aux seuls rôles que sa route accepte : la communauté et la suppression
/// à l'administration (`require_admin`), l'auto-match au conseil et à l'administration
/// (`require_cs_or_admin`), pour un compte actif sans lot, comme le site ; les rôles,
/// tels que le serveur les sert (`gestes_roles`, #89).
struct FicheUtilisateurAdmin: View {
    let id: Int
    let etat: EtatUtilisateursAdmin
    let service: any ServiceUtilisateursAdmin
    let contexte: ContexteOnglet
    @State private var aSupprimer = false
    @State private var roleAConfirmer: GesteDeRole?
    @State private var echec: String?
    @Environment(\.dismiss) private var fermer
    @Environment(\.palette) private var palette
    @Environment(Parcours.self) private var parcours

    var body: some View {
        NavigationStack {
            Group {
                if let compte = etat.compte(id) {
                    fiche(compte)
                } else {
                    ContentUnavailableView(TextesUtilisateursAdmin.aucunResultat, systemImage: "person.slash")
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextesUtilisateursAdmin.fermer) { fermer() }
                        .accessibilityIdentifier("admin.fiche.fermer")
                }
            }
        }
    }

    private func fiche(_ compte: UtilisateurAdmin) -> some View {
        let nom = compte.nomAffiche
        return Form {
            if let echec {
                Section { MessageErreur(texte: echec).listRowInsets(EdgeInsets()) }
            }
            identite(compte)
            Section(TextesUtilisateursAdmin.etiquettes) {
                ForEach(TextesUtilisateursAdmin.etiquettesCompte, id: \.cle) { etiquette in
                    let valeur = compte.etiquettes[etiquette.cle] ?? "manque"
                    LabeledContent(etiquette.libelle) {
                        Text(etiquette.texte(valeur))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(valeur == "manque" ? palette.danger : palette.textMuted)
                    }
                }
            }
            gestes(compte, nom)
            Section {
                RenvoiAuSite(
                    texte: TextesUtilisateursAdmin.surLeSite, onglet: "utilisateurs",
                    adresse: contexte.installation.adresse)
            }
        }
        .disabled(etat.enCours == compte.id)
        .navigationTitle(nom)
        .confirmationDialog(
            TextesUtilisateursAdmin.confirmerSuppression(nom, compte.email), isPresented: $aSupprimer,
            titleVisibility: .visible
        ) {
            Button(TextesUtilisateursAdmin.supprimer, role: .destructive) {
                geste { PhraseAvis(texte: try await etat.supprimer(compte, service, contexte.installation)) }
            }
        }
        .confirmationDialog(
            roleAConfirmer.map { TextesUtilisateursAdmin.confirmerRole($0, nom) } ?? "",
            isPresented: Binding { roleAConfirmer != nil } set: { if !$0 { roleAConfirmer = nil } },
            titleVisibility: .visible, presenting: roleAConfirmer
        ) { offert in
            Button(TextesUtilisateursAdmin.confirmer, role: offert.geste == .retirer ? .destructive : nil) {
                geste {
                    let annonce = try await etat.changerRole(compte, offert, service, contexte.installation)
                    // Un rôle qu'on se retire à soi-même vaut aussitôt : le profil se relit.
                    await parcours.rafraichirProfil()
                    return PhraseAvis(texte: annonce)
                }
            }
        } message: { _ in
            Text(TextesUtilisateursAdmin.notifie)
        }
    }

    private func identite(_ compte: UtilisateurAdmin) -> some View {
        Section(TextesUtilisateursAdmin.identite) {
            PastillesCompte(compte: compte).padding(.vertical, 4)
            ligne(TextesUtilisateursAdmin.email, compte.email)
            ligne(TextesUtilisateursAdmin.statut, RolesUtilisateur.libelleStatut(compte.statut))
            ligne(TextesUtilisateursAdmin.batiment, compte.batimentNom ?? "—")
            if let bailleur = compte.nomProprietaire, compte.statut == "locataire" {
                Text(TextesUtilisateursAdmin.bailleur(bailleur)).foregroundStyle(palette.textMuted)
            }
            ligne(TextesUtilisateursAdmin.inscription, FormatsDuSite.date(compte.creeLe))
            ligne(TextesUtilisateursAdmin.derniereConnexion, FormatsDuSite.dateHeure(compte.derniereConnexion))
            if let averti = compte.purgeAvertieLe {
                VStack(alignment: .leading, spacing: 4) {
                    Label(TextesUtilisateursAdmin.purgeAvertie(FormatsDuSite.date(averti)), systemImage: "clock")
                        .foregroundStyle(palette.warningTexte)
                    Text(TextesUtilisateursAdmin.purgeAide).font(.footnote).foregroundStyle(palette.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private func gestes(_ compte: UtilisateurAdmin, _ nom: String) -> some View {
        let droits = contexte.droits
        Section(TextesUtilisateursAdmin.communaute) {
            ligne(TextesUtilisateursAdmin.communaute, etatCommunaute(compte.ban))
            if droits.administrateur {
                let banni = compte.ban.banni
                Button {
                    geste {
                        PhraseAvis(texte: try await etat.basculerCommunaute(compte, service, contexte.installation))
                    }
                } label: {
                    Label(
                        banni ? TextesUtilisateursAdmin.autoriser : TextesUtilisateursAdmin.interdire,
                        systemImage: banni ? "checkmark.circle" : "lock")
                }
                .tint(banni ? palette.successTexte : palette.warningTexte)
                .accessibilityIdentifier("admin.fiche.communaute")
            }
        }
        if !compte.gestesRoles.isEmpty {
            GestesRolesCompte(gestes: compte.gestesRoles) { roleAConfirmer = $0 }
        }
        if (droits.cs || droits.administrateur) && compte.actif && !compte.aDesLots {
            Section {
                Button {
                    geste { try await etat.relancerRapprochement(compte, service, contexte.installation) }
                } label: {
                    Label(TextesUtilisateursAdmin.rapprochement, systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("admin.fiche.rapprochement")
            }
        }
        if droits.administrateur {
            Section {
                Button(role: .destructive) { aSupprimer = true } label: {
                    Label(TextesUtilisateursAdmin.supprimer, systemImage: "trash")
                }
                .accessibilityIdentifier("admin.fiche.supprimer")
            }
        }
    }

    private func etatCommunaute(_ ban: BanCommunaute) -> String {
        if ban.interdit { return TextesUtilisateursAdmin.banniPourDeBon }
        if ban.banni, let fin = ban.jusquAu { return TextesUtilisateursAdmin.banniJusquAu(FormatsDuSite.date(fin)) }
        return TextesUtilisateursAdmin.autorisee
    }

    private func ligne(_ libelle: String, _ valeur: String) -> some View {
        LabeledContent(libelle) {
            Text(valeur).multilineTextAlignment(.trailing).foregroundStyle(palette.textMuted).textSelection(.enabled)
        }
    }

    /// Un geste : réussi, la fiche se ferme et son annonce suit la fermeture (dite avant,
    /// elle passerait derrière la feuille, #43) ; refusé, la phrase du serveur reste ici.
    private func geste(_ faire: @escaping () async throws -> PhraseAvis) {
        Task {
            do {
                contexte.avis.direApresFermeture(try await faire())
                fermer()
            } catch {
                withAnimation(.snappy) { echec = ErreurService.depuis(error).phrase }
            }
        }
    }
}
