// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Comptes & accès » (onglet `validations`) : la FILE DE TRAVAIL du conseil — deux
/// compteurs, les comptes à valider, puis les demandes de badges et de télécommandes.
/// Chaque ligne s'approuve ou se rejette ; l'approbation d'un compte demande s'il
/// s'agit d'un nouvel arrivant (feuille), celle d'une commande les codes remis.
struct OngletComptesCS: OngletEspaceCS {
    let contexte: ContexteOngletCS
    @State private var etat = EtatComptesCS()
    @State private var aValider: CompteEnAttente?
    @State private var aRejeter: CompteEnAttente?
    @State private var aAccepter: CommandeEnAttente?
    @State private var aRefuser: CommandeEnAttente?
    @State private var codes = ""
    @State private var echec: String?
    @Environment(\.palette) private var palette

    init(contexte: ContexteOngletCS) { self.contexte = contexte }

    var body: some View {
        if let service = contexte.serviceComptes {
            contenu(service)
                .task(id: contexte.actualisation) { await etat.charger(service, contexte.installation) }
        } else {
            MessageErreur(texte: TextesEspaceCS.serviceAbsent)
        }
    }

    @ViewBuilder
    private func contenu(_ service: any ServiceComptesCS) -> some View {
        switch etat.phase {
        case .chargement:
            VStack(spacing: 12) { ForEach(0..<3, id: \.self) { _ in LigneFileSquelette() } }
                .redacted(reason: .placeholder)
                .accessibilityLabel("Chargement")
        case .erreur(let phrase):
            MessageErreur(texte: phrase) { Task { await etat.charger(service, contexte.installation) } }
        case .pret:
            file(service)
        }
    }

    private func file(_ service: any ServiceComptesCS) -> some View {
        gestesSurCommandes(gestesSurComptes(listes, service), service)
    }

    private var listes: some View {
        VStack(alignment: .leading, spacing: 24) {
            CompteursFile(comptes: etat.comptes.count, commandes: etat.commandes.count)
            if let echec {
                MessageErreur(texte: echec).transition(.opacity)
            }
            Section {
                if etat.comptes.isEmpty {
                    Vide(texte: TextesComptesCS.aucunCompte)
                }
                ForEach(etat.comptes) { compte in
                    CarteCompte(
                        compte: compte, enCours: etat.enCours == compte.id,
                        approuver: { aValider = compte }, rejeter: { aRejeter = compte })
                }
            } header: {
                TitreFile(texte: TextesComptesCS.titreComptes)
            }
            Section {
                if etat.commandes.isEmpty {
                    Vide(texte: TextesComptesCS.aucuneCommande)
                }
                ForEach(etat.commandes) { commande in
                    CarteCommande(
                        commande: commande, enCours: etat.enCours == commande.id,
                        approuver: {
                            codes = ""
                            aAccepter = commande
                        },
                        rejeter: { aRefuser = commande })
                }
            } header: {
                TitreFile(texte: TextesComptesCS.titreCommandes)
            }
        }
        .animation(.snappy(duration: 0.25), value: etat.comptes)
        .animation(.snappy(duration: 0.25), value: etat.commandes)
    }
}

/// Les gestes : approuver un compte (feuille « Nouvel Arrivant »), le rejeter ;
/// accepter une commande (codes remis), la rejeter.
extension OngletComptesCS {
    fileprivate func gestesSurComptes(_ contenu: some View, _ service: any ServiceComptesCS) -> some View {
        contenu
            .sheet(item: $aValider, onDismiss: { contexte.avis.feuilleFermee() }, content: { compte in
                ValidationCompteFeuille(compte: compte) { accueil in
                    try await etat.valider(compte, accueil: accueil, service, contexte.installation)
                } fait: {
                    contexte.avis.direApresFermeture($0)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            })
            .confirmationDialog(
                aRejeter.map { TextesComptesCS.rejeterCompte(FormatsDuSite.nom($0.prenom, $0.nom)) } ?? "",
                isPresented: presente($aRejeter), titleVisibility: .visible, presenting: aRejeter
            ) { compte in
                Button(TextesEspaceCS.rejeter, role: .destructive) {
                    geste { try await etat.rejeter(compte, service, contexte.installation) }
                }
            }
    }

    fileprivate func gestesSurCommandes(_ contenu: some View, _ service: any ServiceComptesCS) -> some View {
        contenu
            .confirmationDialog(
                aRefuser.map { TextesComptesCS.rejeterCommande($0.demandeurNom) } ?? "",
                isPresented: presente($aRefuser), titleVisibility: .visible, presenting: aRefuser
            ) { commande in
                Button(TextesEspaceCS.rejeter, role: .destructive) {
                    geste { try await etat.traiter(commande, accepter: nil, service, contexte.installation) }
                }
            }
            .alert(
                TextesComptesCS.accepterCommande, isPresented: presente($aAccepter), presenting: aAccepter
            ) { commande in
                TextField(TextesComptesCS.codesIndication, text: $codes)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("cs.commande.codes")
                Button(TextesEspaceCS.annuler, role: .cancel) {}
                Button(TextesComptesCS.accepter) {
                    let saisis = EtatComptesCS.codes(codes)
                    geste { try await etat.traiter(commande, accepter: saisis, service, contexte.installation) }
                }
            } message: { _ in
                Text(TextesComptesCS.accepterMessage + "\n" + TextesComptesCS.codesLibelle)
            }
    }

    /// Un geste : son annonce en cas de succès, la phrase du serveur sinon.
    private func geste(_ faire: @escaping () async throws -> String) {
        Task {
            do {
                let annonce = try await faire()
                withAnimation(.snappy) { echec = nil }
                contexte.avis.dire(annonce)
            } catch {
                withAnimation(.snappy) { echec = ErreurService.depuis(error).phrase }
            }
        }
    }

    private func presente<T>(_ element: Binding<T?>) -> Binding<Bool> {
        Binding {
            element.wrappedValue != nil
        } set: {
            if !$0 { element.wrappedValue = nil }
        }
    }
}

/// Les deux compteurs du haut : en alerte quand la file n'est pas vide.
private struct CompteursFile: View {
    let comptes: Int
    let commandes: Int
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        let disposition =
            taille.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        disposition {
            CompteurFile(valeur: comptes, libelle: TextesComptesCS.comptesAValider, id: "cs.compteur.comptes")
            CompteurFile(valeur: commandes, libelle: TextesComptesCS.demandesDAcces, id: "cs.compteur.commandes")
        }
    }
}

private struct CompteurFile: View {
    let valeur: Int
    let libelle: String
    let id: String
    @Environment(\.palette) private var palette

    var body: some View {
        let alerte = valeur > 0
        VStack(alignment: .leading, spacing: 4) {
            Text(FormatsDuSite.nombre(valeur))
                .font(.titre(.largeTitle))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(valeur)))
                .foregroundStyle(alerte ? palette.warningTexte : palette.text)
            Text(libelle).font(.subheadline).foregroundStyle(palette.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            alerte ? palette.warningFond : palette.surface, in: .rect(cornerRadius: Mise.rayon, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous)
                .strokeBorder(alerte ? palette.warningBordure : palette.border, lineWidth: 1)
        }
        .animation(.snappy, value: valeur)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}

private struct TitreFile: View {
    let texte: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte)
            .font(.titre(.title3))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct Vide: View {
    let texte: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(texte).font(.subheadline).foregroundStyle(palette.textMuted)
    }
}

private struct LigneFileSquelette: View {
    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prénom Nom du demandeur").font(.headline)
                Text("Statut — Bâtiment").font(.subheadline)
                Text("01/01/2026").font(.footnote)
            }
        }
    }
}
