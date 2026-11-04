// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// L'onglet « Fiche » : la résidence, ses règles, ses plans, son règlement, ses
/// comptes-rendus d'AG et ses diagnostics — dans l'ordre du site. En lecture : la
/// fiche, les documents et les rapports se déposent et se corrigent sur le site.
struct FicheView: View {
    let installation: Installation
    let service: any ServiceResidence
    @Environment(Parcours.self) private var parcours

    var body: some View {
        let service = service
        let installation = installation
        Chargement(
            charger: { try await service.fiche(installation) },
            contenu: { contenu, recharger in
                ScrollView {
                    sections(contenu)
                        .padding(.horizontal, Mise.marge)
                        .padding(.vertical, 16)
                }
                .refreshable { recharger() }
            },
            squelette: {
                ScrollView {
                    sections(ServiceSimule.contenuFiche).padding(Mise.marge)
                }
            }
        )
    }

    private func sections(_ contenu: ContenuFiche) -> some View {
        let profil = parcours.ouverteAJour?.profil
        let locataire = DroitsResidence.locataire(profil)
        return LazyVStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                BanniereResidence(fiche: contenu.fiche, installation: installation)
                CarteFiche(contenu: contenu)
            }
            RubriqueRegles(contenu: contenu)
            RubriqueDocuments(
                titre: TextesResidence.plans, vide: TextesResidence.plansVide, documents: contenu.plans,
                contenu: contenu, gouttiere: .plan)
            RubriqueDocuments(
                titre: TextesResidence.reglement, vide: TextesResidence.reglementVide, documents: contenu.reglements,
                contenu: contenu, gouttiere: .reglement)
            // Les comptes-rendus d'AG et les diagnostics ne s'affichent pas au locataire.
            if !locataire {
                RubriqueDocuments(
                    titre: TextesResidence.comptesRendus, vide: TextesResidence.comptesRendusVide,
                    documents: contenu.comptesRendus, contenu: contenu, gouttiere: .assemblee)
                RubriqueDiagnostics(contenu: contenu, installation: installation, service: service)
            }
        }
    }
}

/// La photo de la résidence, au format du site (16/5), et son nom en légende.
private struct BanniereResidence: View {
    let fiche: FicheResidence
    let installation: Installation
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16 / 5, contentMode: .fit)
                .overlay {
                    if let photo = fiche.photo {
                        PhotoProtegee(chemin: photo, installation: installation)
                    } else {
                        ZStack {
                            palette.neutreFond
                            Label(TextesResidence.aucunePhoto, systemImage: "building.2")
                                .font(.subheadline)
                                .foregroundStyle(palette.textMuted)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: Mise.rayon, style: .continuous))
                .accessibilityLabel("La résidence")
            Text(fiche.nom)
                .font(.subheadline)
                .italic()
                .foregroundStyle(palette.textMuted)
        }
    }
}

/// L'identité de la résidence : ce qu'elle EST (immatriculation, lots), puis ce
/// qu'elle a CONTRACTÉ (assurance, syndic), puis sa composition par bâtiment.
private struct CarteFiche: View {
    let contenu: ContenuFiche
    @Environment(\.palette) private var palette

    private var fiche: FicheResidence { contenu.fiche }

    var body: some View {
        Carte {
            VStack(alignment: .leading, spacing: 14) {
                if !fiche.adresse.isEmpty {
                    Champ(libelle: TextesResidence.adresse) { Text(fiche.adresse) }
                }
                let colonnes = [GridItem(.adaptive(minimum: 140), alignment: .topLeading)]
                LazyVGrid(columns: colonnes, alignment: .leading, spacing: 12) {
                    if let immatriculation = fiche.immatriculation {
                        Champ(libelle: TextesResidence.immatriculation) {
                            Text(immatriculation).fontWeight(.bold).foregroundStyle(palette.primary)
                        }
                    }
                    if let lots = fiche.lotsPrincipaux {
                        Champ(libelle: TextesResidence.lotsPrincipaux) { Text(lots, format: .number) }
                    }
                    if let lots = fiche.lotsTotal {
                        Champ(libelle: TextesResidence.lotsTotal) { Text(lots, format: .number) }
                    }
                }
                if fiche.assurance != nil || fiche.syndic != nil {
                    Divider().overlay(palette.border)
                    contrats
                }
                if !contenu.batiments.isEmpty {
                    Divider().overlay(palette.border)
                    CompositionBatiments(contenu: contenu)
                }
            }
        }
    }

    @ViewBuilder
    private var contrats: some View {
        if let assurance = fiche.assurance {
            Champ(libelle: TextesResidence.assurance) {
                Text(assurance + TextesResidence.echeance(fiche.assuranceEcheance, reconduit: fiche.assuranceReconduit))
            }
        }
        if let syndic = fiche.syndic {
            // Le lien mène à l'annuaire, qui porte les PERSONNES : la fiche ne les recopie pas.
            Champ(libelle: TextesResidence.syndic) {
                NavigationLink(value: DestinationResidence.syndic) {
                    let cabinet = Text(syndic).foregroundStyle(palette.primary).underline()
                    let mandat = Text(TextesResidence.mandat(fiche.syndicEcheance, echu: fiche.syndicEchu))
                        .foregroundStyle(fiche.syndicEchu ? palette.danger : palette.text)
                        .fontWeight(fiche.syndicEchu ? .semibold : .regular)
                    Text("\(cabinet)\(mandat)").multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Ouvre l'annuaire du syndic")
            }
        }
    }
}

/// Un champ de la fiche : son libellé en capitales, sa valeur dessous.
private struct Champ<Valeur: View>: View {
    let libelle: String
    @ViewBuilder let valeur: () -> Valeur
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(libelle).styleLibelle()
            valeur()
                .font(.body.weight(.medium))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// La composition par bâtiment : un tableau, ou une liste aux très grandes tailles.
private struct CompositionBatiments: View {
    let contenu: ContenuFiche
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var taille

    private static let colonnes = ["Parkings", "Caves", "Appartements", "Loc. commerciaux"]

    private var lignes: [(nom: String, valeurs: [Int])] {
        var lignes = contenu.batiments.map {
            ("Bât. \($0.numero)", [$0.parkings, $0.caves, $0.appartements, $0.locauxCommerciaux])
        }
        if contenu.fiche.parkingsCommuns > 0 { lignes.append(("Communs", [contenu.fiche.parkingsCommuns, 0, 0, 0])) }
        return lignes
    }

    private var totaux: [Int] {
        (0..<Self.colonnes.count).map { i in lignes.reduce(0) { $0 + $1.valeurs[i] } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TextesResidence.composition).styleLibelle()
            if taille.isAccessibilitySize {
                ForEach(lignes + [("Total", totaux)], id: \.nom) { ligne in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ligne.nom).font(.headline)
                        ForEach(Self.colonnes.indices, id: \.self) { i in
                            Text("\(Self.colonnes[i]) : \(valeur(ligne.valeurs[i]))").font(.subheadline)
                        }
                    }
                }
            } else {
                Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        Text("Bâtiment").gridColumnAlignment(.leading)
                        // Un mot seul ne se coupe pas (« Apparte-ments ») ; « Loc. commerciaux » passe à la ligne.
                        ForEach(Self.colonnes, id: \.self) { colonne in
                            Text(colonne).fixedSize(horizontal: !colonne.contains(" "), vertical: false)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.trailing)
                    ForEach(lignes, id: \.nom) { ligne in
                        GridRow {
                            Text(ligne.nom).fontWeight(.medium)
                            ForEach(ligne.valeurs.indices, id: \.self) { Text(valeur(ligne.valeurs[$0])) }
                        }
                    }
                    Divider().overlay(palette.border).gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        Text("Total").fontWeight(.semibold)
                        ForEach(totaux.indices, id: \.self) { Text(valeur(totaux[$0])).fontWeight(.semibold) }
                    }
                }
                .font(.subheadline)
                .monospacedDigit()
            }
        }
    }

    /// « — » pour zéro, comme le tableau du site.
    private func valeur(_ nombre: Int) -> String { nombre > 0 ? nombre.formatted() : "—" }
}
