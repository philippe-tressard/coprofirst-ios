// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.76.0 (commit 92633e233a414f3d20d189055d71ea62a0b36b41), front/src/lib/flux.ts (NATURES).

/// Ce que le fil montre de chaque type d'élément : libellé, teinte, pictogramme (Lucide).
enum NaturesDuFil {
    static let parType: [String: NatureDuFil] = [
        "ticket_resolu": NatureDuFil(libelle: "Affaire résolue", couleur: \.filRouge, fond: \.filRougeFond, icone: "circle-check"),
        "ticket_ouvert": NatureDuFil(libelle: "Affaire", couleur: \.filRouge, fond: \.filRougeFond, icone: "wrench"),
        "ticket_mis_a_jour": NatureDuFil(libelle: "Affaire mise à jour", couleur: \.filRouge, fond: \.filRougeFond, icone: "refresh-cw"),
        "annonce": NatureDuFil(libelle: "Petite annonce", couleur: \.orange, fond: \.orangeFond, icone: "heart-handshake"),
        "point_conseil": NatureDuFil(libelle: "Point CS / Syndic", couleur: \.filAmbre, fond: \.filAmbreFond, icone: "users"),
        "diagnostic": NatureDuFil(libelle: "Diagnostic", couleur: \.filOlive, fond: \.filOliveFond, icone: "activity"),
        "annuaire": NatureDuFil(libelle: "Annuaire", couleur: \.filVert, fond: \.filVertFond, icone: "users"),
        "prestataire": NatureDuFil(libelle: "Prestataire", couleur: \.filSarcelle, fond: \.filSarcelleFond, icone: "hard-hat"),
        "idee": NatureDuFil(libelle: "Boîte à idées", couleur: \.filCyan, fond: \.filCyanFond, icone: "lightbulb"),
        "publication": NatureDuFil(libelle: "Actualité", couleur: \.primary, fond: \.primaryLight, icone: "newspaper"),
        "document": NatureDuFil(libelle: "Document", couleur: \.filIndigo, fond: \.filIndigoFond, icone: "file-text"),
        "sondage_clos": NatureDuFil(libelle: "Sondage clos", couleur: \.filViolet, fond: \.filVioletFond, icone: "bar-chart-3"),
        "sondage_ouvert": NatureDuFil(libelle: "Sondage", couleur: \.filViolet, fond: \.filVioletFond, icone: "bar-chart-3"),
        "faq": NatureDuFil(libelle: "Question fréquente", couleur: \.filFuchsia, fond: \.filFuchsiaFond, icone: "help-circle"),
        "question_reglement": NatureDuFil(libelle: "Question au règlement", couleur: \.filRose, fond: \.filRoseFond, icone: "book-open"),
    ]
}
