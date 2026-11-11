// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Les textes du Carnet d'entretien, comme le site les écrit (`CarnetEntretien.svelte`).
enum TextesCarnet {
    static let aide =
        "Ce que la copropriété a fait entretenir, réparer et contrôler. Il est constitué automatiquement "
        + "à partir des contrats, des entretiens terminés et des affaires résolues du bâti, rangées sous "
        + "l'équipement que le conseil syndical désigne — rien n'y est saisi à la main. Une question ou une "
        + "nuisance n'y figure pas."
    static let sansEquipement = "Sans équipement rattaché"
    static let vide = "Aucun contrat, aucune intervention terminée ni aucun ticket résolu pour ce périmètre."
    static let perimetre = "Périmètre"
    static let tous = "Toute la résidence"
    /// Le bilan de l'exercice (conseil syndical) reste sur le site pour l'instant.
    static let bilanSurLeSite = "Le bilan de l'exercice, réservé au conseil syndical, se consulte sur le site."

    /// « 2 visites attendues » : le compte en gras, le reste de la phrase ensuite.
    static func visitesAttendues(_ n: Int) -> String {
        n > 1 ? "\(n) visites attendues" : "1 visite attendue"
    }

    static let echeanceDepassee = "dont l'échéance est dépassée :"

    /// Où mène une entrée (`ORIGINES`) : « Ouvrir l'affaire : … ».
    static func nature(_ origine: String) -> Gouttiere.Nature {
        switch origine {
        case "contrat": .contrat
        case "intervention": .intervention
        default: .affaire
        }
    }
}

/// L'onglet « Carnet d'entretien » : ce qui a été entretenu, réparé et contrôlé,
/// rangé par équipement ; les visites en retard en tête. Réservé aux propriétaires
/// et au conseil syndical (l'onglet ne s'ouvre qu'à eux).
struct CarnetView: View {
    let installation: Installation
    let service: any ServiceResidence
    let droits: DroitsOnglet
    @Environment(\.palette) private var palette
    @State private var perimetre: String?
    @State private var perimetres: [Perimetre] = []

    var body: some View {
        let service = service
        let installation = installation
        let perimetre = perimetre
        Chargement(
            charger: { try await service.carnet(perimetre: perimetre, dans: installation) },
            contenu: { carnet, recharger in
                ScrollView {
                    contenu(carnet).padding(.horizontal, Mise.marge).padding(.vertical, 16)
                }
                .refreshable { recharger() }
            },
            squelette: {
                ScrollView {
                    contenu(ContenuCarnet(entrees: Apercu.carnet, libellesEquipements: [:])).padding(Mise.marge)
                }
            }
        )
        // Le filtre est servi par le serveur (`?perimetre=`) : changer de périmètre recharge.
        .id(perimetre)
        .task { perimetres = (try? await service.perimetres(installation)) ?? [] }
    }

    private func contenu(_ carnet: ContenuCarnet) -> some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            Text(TextesCarnet.aide).font(.subheadline).foregroundStyle(palette.textMuted)
            if !perimetres.isEmpty { filtre(compte: carnet.entrees.count) }
            if droits.cs {
                Label(TextesCarnet.bilanSurLeSite, systemImage: "chart.bar")
                    .font(.footnote)
                    .foregroundStyle(palette.textMuted)
            }
            if !carnet.enAlerte.isEmpty { EncartAlerte(entrees: carnet.enAlerte) }
            if carnet.entrees.isEmpty { RubriqueVide(texte: TextesCarnet.vide) }
            ForEach(carnet.groupes, id: \.titre) { groupe in
                VStack(alignment: .leading, spacing: 10) {
                    EnTeteRubrique(titre: groupe.titre, compte: groupe.entrees.count)
                    ForEach(groupe.entrees) { CarteEntree(entree: $0, installation: installation) }
                }
            }
        }
    }

    private func filtre(compte: Int) -> some View {
        Menu {
            Picker(TextesCarnet.perimetre, selection: $perimetre) {
                Text(TextesCarnet.tous).tag(String?.none)
                ForEach(perimetres) { Text($0.libelle).tag(Optional($0.code)) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(perimetres.first { $0.code == perimetre }?.libelle ?? TextesCarnet.tous)
                Text(FormatsDuSite.nombre(compte)).monospacedDigit().fontWeight(.bold)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .frame(minHeight: Mise.cible)
            .foregroundStyle(palette.text)
            .background(palette.surface, in: .capsule)
            .overlay { Capsule().strokeBorder(palette.border, lineWidth: 1) }
        }
        .accessibilityLabel(TextesCarnet.perimetre)
        .accessibilityValue(perimetres.first { $0.code == perimetre }?.libelle ?? TextesCarnet.tous)
        .sensoryFeedback(.selection, trigger: perimetre)
    }
}

/// L'alerte en TÊTE : ce que le carnet apprend et que rien d'autre ne dit.
private struct EncartAlerte: View {
    let entrees: [EntreeCarnet]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⚠️ **\(TextesCarnet.visitesAttendues(entrees.count))** \(TextesCarnet.echeanceDepassee)")
            ForEach(entrees) { entree in
                Text("• \(entree.libelle)" + (entree.alerte.map { " — \($0)" } ?? ""))
                    .font(.subheadline)
            }
        }
        .foregroundStyle(palette.warningTexte)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(palette.warningFond, in: .rect(cornerRadius: Mise.rayon, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Mise.rayon, style: .continuous).strokeBorder(palette.warningBordure)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Une entrée du carnet : la date et l'origine en gouttière, le libellé, l'extrait
/// du texte (HTML, par la porte `TexteDuSite`), le détail, l'alerte et le numéro.
private struct CarteEntree: View {
    let entree: EntreeCarnet
    let installation: Installation
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var ouvrir

    /// Une affaire s'ouvre dans l'app ; un contrat ou une intervention, sur le site
    /// (Prestataires n'est pas encore porté).
    private var affaire: Int? {
        guard entree.origine == "affaire", let lien = entree.lien, lien.hasPrefix("/tickets/") else { return nil }
        return Int(lien.dropFirst("/tickets/".count).prefix { $0.isNumber })
    }

    var body: some View {
        CarteAGouttiere(gouttiere: Gouttiere(nature: TextesCarnet.nature(entree.origine), date: entree.jour)) {
            Text(entree.libelle).font(.headline).foregroundStyle(palette.text)
            if let extrait = entree.extrait, !extrait.isEmpty {
                Text(TexteDuSite.apercu(extrait)).font(.subheadline).lineLimit(3).foregroundStyle(palette.textMuted)
            }
            if let detail = entree.detail, !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(palette.textMuted)
            }
            HStack(spacing: 8) {
                if let alerte = entree.alerte, !alerte.isEmpty {
                    // Le badge orange du site (`badge-orange`).
                    PastilleTeinte(libelle: "⚠️ \(alerte)", badge: "badge-orange", compacte: true)
                }
                if let numero = entree.numero { PastilleTeinte.neutre("#\(numero)") }
            }
            lien
        }
    }

    @ViewBuilder
    private var lien: some View {
        if let affaire {
            NavigationLink(value: DestinationResidence.affaire(affaire)) {
                Label("Voir l'affaire", systemImage: "arrow.right").labelStyle(.titleAndIcon)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.primary)
            .frame(minHeight: Mise.cible)
        } else if let chemin = entree.lien, let adresse = URL(string: chemin, relativeTo: installation.adresse) {
            Button {
                ouvrir(adresse.absoluteURL)
            } label: {
                Label("Ouvrir sur le site", systemImage: "safari")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.primary)
            .frame(minHeight: Mise.cible)
        }
    }
}
