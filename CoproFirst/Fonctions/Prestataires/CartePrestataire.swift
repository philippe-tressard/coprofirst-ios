// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La carte d'un prestataire (`CartePrestataire.svelte`) : repliée, toute la carte
/// l'ouvre ; dépliée, son détail et les avis du conseil syndical.
struct CartePrestataire: View {
    let prestataire: Prestataire
    let donnees: DonneesPrestataires
    /// Au-delà de sept fiches, les contacts ne s'affichent que dépliés.
    let compact: Bool
    @Binding var deplie: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        let avis = donnees.avis(de: prestataire)
        let contrats = donnees.contrats(de: prestataire)
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    deplie.toggle()
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(prestataire.nom)
                            .font(.headline)
                            .foregroundStyle(palette.text)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.textMuted)
                            .rotationEffect(.degrees(deplie ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(deplie ? "Replie la fiche" : "Déplie la fiche")
                .accessibilityIdentifier("prestataire.\(prestataire.id)")
                capsules(avis: avis, contrats: contrats)
                if !compact || deplie { apercuContacts }
                if deplie {
                    detail(contrats: contrats)
                    if !avis.isEmpty { AvisDuConseil(avis: avis) }
                }
            }
        }
    }

    private func capsules(avis: [AvisPrestataire], contrats: [Contrat]) -> some View {
        FlowCapsules {
            PastilleTeinte(libelle: LibellesPrestataires.type(prestataire.type), badge: "badge-gray", compacte: true)
            PastilleTeinte(libelle: donnees.equipement(prestataire.specialite), badge: "badge-blue", compacte: true)
            if !contrats.isEmpty {
                PastilleTeinte(
                    libelle: TextesPrestataires.sousContrat(contrats.count), badge: "badge-green", compacte: true)
            }
        }
    }

    /// L'aperçu des contacts : les contacts nommés, sinon les numéros, puis le courriel.
    @ViewBuilder private var apercuContacts: some View {
        let telephones = Self.telephones(prestataire.telephone)
        VStack(alignment: .leading, spacing: 2) {
            if !prestataire.contacts.isEmpty {
                ForEach(Array(prestataire.contacts.enumerated()), id: \.offset) { _, contact in
                    let lu = FormatsDuSite.nom(contact.prenom, contact.nom)
                    let nom = lu == FormatsDuSite.tiret ? "" : lu
                    let fonction = contact.fonction.map { " (\($0))" } ?? ""
                    lien(
                        "📞 \(contact.telephone ?? FormatsDuSite.tiret)\(nom.isEmpty ? "" : " — \(nom)\(fonction)")",
                        tel: contact.telephone)
                }
            } else {
                ForEach(telephones, id: \.self) { lien("📞 \($0)", tel: $0) }
            }
            if let email = prestataire.email, !email.isEmpty, let url = URL(string: "mailto:\(email)") {
                Link("✉️ \(email)", destination: url).font(.subheadline).frame(minHeight: Mise.cible)
            }
        }
        .tint(palette.primary)
    }

    @ViewBuilder
    private func lien(_ texte: String, tel: String?) -> some View {
        if let tel, let url = URL(string: "tel:\(tel.filter { $0.isNumber || $0 == "+" })") {
            Link(texte, destination: url).font(.subheadline).frame(minHeight: Mise.cible, alignment: .leading)
        } else {
            Text(texte).font(.subheadline).foregroundStyle(palette.textMuted)
        }
    }

    private func detail(contrats: [Contrat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if let adresse = prestataire.adresse, !adresse.isEmpty {
                LigneFiche(libelle: TextesPrestataires.adresse, valeur: "📮 \(adresse)")
            }
            LigneFiche(libelle: TextesPrestataires.contrats, valeur: FormatsDuSite.nombre(contrats.count))
            if let description = prestataire.description, !description.isEmpty {
                Text(TexteDuSite.riche(description)).font(.subheadline).tint(palette.primary)
            }
        }
        .transition(.opacity)
    }

    /// `telephonesDe` : découpés sur la virgule, sans doublon.
    static func telephones(_ champ: String?) -> [String] {
        var vus: [String] = []
        for brut in (champ ?? "").split(separator: ",") {
            let numero = brut.trimmingCharacters(in: .whitespaces)
            if !numero.isEmpty, !vus.contains(numero) { vus.append(numero) }
        }
        return vus
    }
}

/// Les avis du conseil syndical (`NotationsPrestataire.svelte`), du plus récent au plus ancien.
private struct AvisDuConseil: View {
    let avis: [AvisPrestataire]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TextesPrestataires.avisDuConseil(avis.count)).styleLibelle()
            ForEach(avis) { un in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(un.note)/5")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.text)
                            .accessibilityLabel("\(un.note) sur 5")
                        Text(un.auteurNom ?? FormatsDuSite.tiret).font(.subheadline.weight(.medium))
                        Text(FormatsDuSite.date(un.creeLe)).font(.caption).foregroundStyle(palette.textMuted)
                    }
                    if let commentaire = un.commentaire, !commentaire.isEmpty {
                        Text(commentaire).font(.subheadline).foregroundStyle(palette.text)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 4)
    }
}
