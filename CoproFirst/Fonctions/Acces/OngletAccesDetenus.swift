// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les onglets « Mes badges d’accès (Vigik) » et « Télécommandes de parking »
/// (`OngletAcces.svelte`) : ce que l'on détient, et le geste « Signaler perdu » ;
/// au locataire, ce que son bailleur lui a confié ; au bailleur, ce qu'il a confié.
struct OngletAccesDetenus: View {
    let type: TypeAcces
    let installation: Installation
    let service: any ServiceAcces
    let etat: EtatAcces
    /// Change après une déclaration : la liste se relit.
    let version: Int

    var body: some View {
        let service = service
        let installation = installation
        let droits = etat.droits
        Chargement(
            charger: {
                try await DonneesAcces.lire(installation, service: service, droits: droits)
            },
            contenu: { donnees, recharger in
                ContenuAcces(
                    type: type, donnees: donnees, etat: etat, installation: installation, service: service,
                    recharger: recharger)
            },
            squelette: { SqueletteAcces() }
        )
        .id("\(type.rawValue)-\(version)")
    }
}

/// Ce que l'onglet lit : les deux familles (la vue par locataire les réunit), et,
/// selon le rôle, ce qui a été reçu d'un bailleur.
struct DonneesAcces: Sendable {
    var vigiks: [AccesDetenu]
    var telecommandes: [AccesDetenu]
    var recus: [AccesDetenu]

    func detenus(_ type: TypeAcces) -> [AccesDetenu] { type == .vigik ? vigiks : telecommandes }

    static func lire(
        _ installation: Installation, service: any ServiceAcces, droits: DroitsAcces
    ) async throws -> DonneesAcces {
        async let vigiks = service.mesAcces(.vigik, dans: installation)
        async let telecommandes = service.mesAcces(.telecommande, dans: installation)
        let recus = droits.locataire ? ((try? await service.accesRecus(installation)) ?? []) : []
        return DonneesAcces(vigiks: try await vigiks, telecommandes: try await telecommandes, recus: recus)
    }
}

private struct ContenuAcces: View {
    let type: TypeAcces
    @State var donnees: DonneesAcces
    let etat: EtatAcces
    let installation: Installation
    let service: any ServiceAcces
    let recharger: () -> Void
    @State private var aSignaler: AccesDetenu?
    @State private var erreur: String?

    init(
        type: TypeAcces, donnees: DonneesAcces, etat: EtatAcces, installation: Installation,
        service: any ServiceAcces, recharger: @escaping () -> Void
    ) {
        self.type = type
        _donnees = State(initialValue: donnees)
        self.etat = etat
        self.installation = installation
        self.service = service
        self.recharger = recharger
    }

    var body: some View {
        let detenus = donnees.detenus(type)
        VStack(alignment: .leading, spacing: 12) {
            if let erreur { MessageErreur(texte: erreur) }
            // Un locataire sans objet ne voit pas la section ; tous les autres la voient.
            if !detenus.isEmpty || !etat.droits.locataire {
                Intertitre(titre: type == .vigik ? TextesAcces.badgesVigik : TextesAcces.telecommandes)
                if detenus.isEmpty {
                    NoteAcces(
                        texte: type == .vigik ? TextesAcces.aucunBadge : TextesAcces.aucuneTelecommande,
                        pictogramme: type == .vigik ? "tag" : "antenna.radiowaves.left.and.right")
                } else {
                    Carte {
                        VStack(spacing: 0) {
                            ForEach(Array(detenus.enumerated()), id: \.element.id) { rang, acces in
                                if rang > 0 { Divider().padding(.vertical, 8) }
                                LigneAcces(acces: acces) { aSignaler = acces }
                            }
                        }
                    }
                }
            }
            if etat.droits.locataire { AccesConfies(recus: donnees.recus) }
            if etat.droits.bailleur, !etat.baux.isEmpty {
                VueParLocataire(
                    baux: etat.baux, objets: donnees.vigiks + donnees.telecommandes, installation: installation,
                    service: service, etat: etat, recharger: recharger)
            }
        }
        .confirmationDialog(
            TextesAcces.signalerPerduQuestion,
            isPresented: Binding(get: { aSignaler != nil }, set: { if !$0 { aSignaler = nil } }),
            titleVisibility: .visible,
            presenting: aSignaler
        ) { acces in
            Button(TextesAcces.signalerPerdu, role: .destructive) { Task { await signaler(acces) } }
                .accessibilityIdentifier("acces.perdu.confirmer")
            Button(TextesAcces.annuler, role: .cancel) { aSignaler = nil }
        }
    }

    private func signaler(_ acces: AccesDetenu) async {
        aSignaler = nil
        do {
            try await service.signalerPerdu(acces, dans: installation)
            // Comme le site : le statut passe à « perdu » sans relire la liste.
            let marque = { (liste: [AccesDetenu]) in
                liste.map { lu in
                    var marque = lu
                    if lu.id == acces.id { marque.statut = "perdu" }
                    return marque
                }
            }
            withAnimation(.snappy(duration: 0.25)) {
                if type == .vigik {
                    donnees.vigiks = marque(donnees.vigiks)
                } else {
                    donnees.telecommandes = marque(donnees.telecommandes)
                }
            }
            erreur = nil
            etat.annoncer(TextesAcces.signalementEnregistre)
        } catch {
            erreur = RefusDuServeur.phrase(error)
        }
    }
}

/// Une ligne : le code en chasse fixe, son statut, et « Signaler perdu » s'il est actif.
private struct LigneAcces: View {
    let acces: AccesDetenu
    let signaler: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    var body: some View {
        let statut = LibellesAcces.statutAcces(acces.statut)
        let disposition =
            taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        disposition {
            Text(acces.code)
                .font(.body.monospaced())
                .foregroundStyle(palette.text)
                .textSelection(.enabled)
            PastilleTeinte(libelle: statut.libelle, badge: statut.badge)
            if !taille.isAccessibilitySize { Spacer(minLength: 0) }
            if acces.statut == "actif" {
                Button(TextesAcces.signalerPerdu, action: signaler)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.danger)
                    .frame(minHeight: Mise.cible)
                    .accessibilityIdentifier("acces.perdu.\(acces.id)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// « Accès confiés par votre bailleur » (`AccesConnexes.svelte`) — sous les deux onglets.
private struct AccesConfies: View {
    let recus: [AccesDetenu]
    @Environment(\.palette) private var palette

    var body: some View {
        Intertitre(titre: TextesAcces.accesConfies)
        if recus.isEmpty {
            NoteAcces(texte: TextesAcces.aucunAccesConfie)
        } else {
            Text(TextesAcces.accesConfiesIntro).font(.subheadline).foregroundStyle(palette.textMuted)
            Carte {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recus) { acces in
                        let statut = LibellesAcces.statutAcces(acces.statut)
                        HStack(spacing: 10) {
                            Text(acces.code).font(.body.monospaced())
                            Text(LibellesAcces.typeAcces(acces.type))
                                .font(.subheadline)
                                .foregroundStyle(palette.textMuted)
                            Spacer(minLength: 0)
                            PastilleTeinte(libelle: statut.libelle, badge: statut.badge, compacte: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

/// Le squelette : trois lignes grisées aux identifiants propres.
struct SqueletteAcces: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Intertitre(titre: TextesAcces.badgesVigik)
            Carte {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            Text("XXXXXXXX").font(.body.monospaced())
                            Text("Actif")
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
