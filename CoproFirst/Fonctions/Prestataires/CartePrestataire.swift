// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// La carte d'un prestataire (`CartePrestataire.svelte`) : repliée, toute la carte
/// l'ouvre ; dépliée, son détail et les avis du conseil syndical.
struct CartePrestataire: View {
    let prestataire: Prestataire
    let donnees: DonneesPrestataires
    let installation: Installation
    let service: any ServicePrestataires
    /// Au-delà de sept fiches, les contacts ne s'affichent que dépliés.
    let compact: Bool
    @Binding var deplie: Bool
    @Environment(\.palette) private var palette

    var body: some View {
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
                capsules(contrats: contrats)
                if !compact || deplie { apercuContacts }
                if deplie {
                    detail(contrats: contrats)
                    RecapitulatifAvis(prestataire: prestataire, installation: installation, service: service)
                }
            }
        }
    }

    private func capsules(contrats: [Contrat]) -> some View {
        FlowCapsules {
            PastilleTeinte(libelle: LibellesPrestataires.type(prestataire.type), badge: "badge-gray", compacte: true)
            PastilleTeinte(libelle: donnees.equipement(prestataire.specialite), badge: "badge-blue", compacte: true)
            if !contrats.isEmpty {
                PastilleTeinte(
                    libelle: TextesPrestataires.sousContrat(contrats.count), badge: "badge-green", compacte: true)
            }
            // La moyenne SERVIE, dite par l'état du site (`etatDeMoyenne`, généré) : « Excellent · 4,33/5 ».
            if let moyenne = prestataire.noteMoyenne {
                PastilleTeinte(
                    libelle: TextesAvisPrestataire.moyenne(moyenne),
                    badge: EtatAvis.teinte(EtatAvis.deMoyenne(moyenne)), compacte: true)
                .accessibilityLabel(TextesAvisPrestataire.moyenneEnClair(moyenne, nombre: prestataire.nbNotations))
            }
        }
    }

    /// L'aperçu des contacts : les contacts nommés, sinon les numéros — un lien d'appel
    /// par numéro SERVI (`Prestataire.telephones`) —, puis le courriel.
    @ViewBuilder private var apercuContacts: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !prestataire.contacts.isEmpty {
                ForEach(Array(prestataire.contacts.enumerated()), id: \.offset) { _, contact in
                    let nom = contact.nomAffiche ?? ""
                    let fonction = contact.fonction.map { " (\($0))" } ?? ""
                    let qui = nom.isEmpty ? "" : "\(Separateur.tiret)\(nom)\(fonction)"
                    lien(
                        "📞 \(contact.telephone ?? FormatsDuSite.tiret)\(qui)",
                        tel: contact.telephone)
                }
            } else {
                ForEach(prestataire.telephones, id: \.self) { lien("📞 \($0)", tel: $0) }
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
}
