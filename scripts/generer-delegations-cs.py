#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables des Délégations et de trois onglets de l'Espace CS (Reporting, Annonces
Hall, Courriels affaires), GÉNÉRÉES depuis les sources de coprofirst (#15).

Le contrat d'API ne sert que des CODES (un statut, une décision, une ancienneté, une
teinte de tranche) : leurs libellés et leurs couleurs vivent dans le front du site.
Rien ne se recopie à la main (garde-fou de `projets.json`) ; ce script les lit :

- le descriptif de la page `delegations` (`pages-roles.ts`) — ceux des onglets de
  l'Espace CS sont générés avec son cadre (`TablesEspaceCS`) ;
- l'état d'une délégation (`parAttribut` de `routes/(app)/delegations/+page.svelte`) ;
- la teinte de l'âge d'une affaire (`TEINTE_AGE`, `TableauAffaires.svelte`), les modes
  du suivi (`MODES`, `VueSuiviAffaires.svelte`), l'état d'une visite (`ETATS_VISITE`,
  `entretien-periodique.ts`), le motif « a évolué » (`reporting.ts`) et la couleur de chaque tranche des
  répartitions (`BarresCroisees.svelte`, jetons de `socle.css` et `palette-sombre.css`) ;
- les formats d'une affiche (`AH_FORMATS`, `OngletAnnoncesHall.svelte`) ;
- le verdict de la relève des courriels (`VERDICTS`, `OngletCourriels.svelte`) et la
  pastille de chaque ton (`JournalVerdicts.svelte`).

Sorties : `CoproFirst/Fonctions/Delegations/Genere/` et, pour les onglets du cadre CS,
`CoproFirst/Fonctions/EspaceCS/Genere/`.

Usage : python3 scripts/generer-delegations-cs.py   ($COPROFIRST_REVISION, $COPROFIRST_RACINE)
"""

from __future__ import annotations

import re

import source_epinglee as src

SCRIPT = "generer-delegations-cs.py"
LIB = "src/lib/"
COMPOSANTS = "src/lib/components/"


def pages_roles() -> dict[str, dict]:
    return {p["id"]: p for p in src.tableau(src.front(LIB + "pages-roles.ts"), "PAGES_ROLES")}


def teintes(nom: str, doc: str, entrees: list[tuple[str, str, str]]) -> str:
    lignes = "".join(
        f"        {src.chaine(c)}: LibelleTeinte({src.chaine(l)}, {src.chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def couples(nom: str, doc: str, entrees: list[tuple[str, str]]) -> str:
    lignes = "".join(f"        ({src.chaine(c)}, {src.chaine(l)}),\n" for c, l in entrees)
    return f"    /// {doc}\n    static let {nom}: [(code: String, libelle: String)] = [\n{lignes}    ]\n"


def delegations() -> str:
    page = pages_roles()["delegations"]
    statuts = src.objet(src.front("src/routes/(app)/delegations/+page.svelte"), r"=\s*parAttribut\(")
    return (
        "/// Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.\n"
        "enum TablesDelegations {\n"
        "    /// Le descriptif de la page (`pages-roles.ts`) : ce qu'une délégation permet.\n"
        f"    static let descriptif = {src.chaine(page['descriptif'])}\n"
        + teintes("statuts", "L'état d'une délégation (`parAttribut` de la page du site).",
                  [(c, v["libelle"], v["badge"]) for c, v in statuts.items()])
        + "}\n"
    )


def couleurs_des_tranches() -> list[tuple[str, list[str]]]:
    """Chaque `[data-teinte='…']` de `BarresCroisees.svelte` → les jetons qu'il peint, dans
    l'ordre (un seul : un aplat ; deux : des hachures)."""
    texte = src.front(COMPOSANTS + "reporting/BarresCroisees.svelte")
    style = texte[texte.index("<style>"):]
    regles = re.findall(r"\[data-teinte='([\w-]+)'\]\s*\{([^}]*)\}", style)
    if not regles:
        raise SystemExit("❌ BarresCroisees.svelte : aucune règle [data-teinte] lue")
    return [(cle, re.findall(r"var\(--([\w-]+)\)", corps)) for cle, corps in regles]


def jeton_fixe(nom: str) -> str:
    """`serie-1` → `Color(clair:sombre:)`, lu dans socle.css (clair) et palette-sombre.css."""
    clair = src.jetons_css(src.front("src/styles/socle.css"))
    sombres = re.findall(rf"--{re.escape(nom)}\s*:\s*([^;]+);",
                         re.sub(r"/\*.*?\*/", "", src.front("src/styles/palette-sombre.css"), flags=re.S))
    if nom not in clair or not sombres or len(set(sombres)) != 1:
        raise SystemExit(f"❌ --{nom} : valeur claire ou sombre introuvable, ou sombre ambiguë")
    return (f"Color(clair: {src.rvba(clair[nom], '--' + nom)}, "
            f"sombre: {src.rvba(sombres[0].strip(), '--' + nom + ' (sombre)')})")


def couleur(nom: str) -> str:
    if nom.startswith("color-"):
        propriete = re.sub(r"-(\w)", lambda m: m.group(1).upper(), nom[len("color-"):])
        return f".palette(\\.{propriete})"
    return f".fixe({jeton_fixe(nom)})"


def reporting() -> str:
    age = src.objet(src.front(COMPOSANTS + "reporting/TableauAffaires.svelte"), r"\bconst TEINTE_AGE\b[^=]*=\s*\{")
    modes = src.tableau(src.front(COMPOSANTS + "reporting/VueSuiviAffaires.svelte"), "MODES")
    visites = src.objet(src.front(LIB + "entretien-periodique.ts"), r"\bconst ETATS_VISITE\b[^=]*=\s*\{")
    texte_reporting = src.front(LIB + "reporting.ts")
    motifs = src.objet(texte_reporting, r"\bconst MOTIFS_EVOLUTION\b[^=]*=\s*\{")
    defaut = re.search(r"function motifEvolution[^{]*\{[^}]*\|\|\s*'([^']+)'", texte_reporting)
    if not defaut:
        raise SystemExit("❌ reporting.ts : le motif par défaut de motifEvolution est introuvable")
    tranches = "".join(
        f"        {src.chaine(cle)}: [{', '.join(couleur(j) for j in jetons)}],\n"
        for cle, jetons in couleurs_des_tranches())
    return (
        "/// Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.\n"
        "enum TablesReporting {\n"
        + "    /// La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).\n"
        "    static let teintesAge: [String: String] = [\n"
        + "".join(f"        {src.chaine(c)}: {src.chaine(b)},\n" for c, b in age.items()) + "    ]\n"
        + couples("modes", "Les modes du Suivi des affaires, dans l'ordre du site (`MODES`).",
                  [(m["valeur"], m["libelle"]) for m in modes])
        + teintes("etatsVisite", "L'état d'une visite d'entretien, calculé au serveur (`ETATS_VISITE`).",
                  [(c, src.sans_pictogramme(v["libelle"]), v["teinte"]) for c, v in visites.items()])
        + "    /// Ce que le signal « a évolué » dit d'une affaire, selon le motif servi (`MOTIFS_EVOLUTION`).\n"
        "    static let motifsEvolution: [String: String] = [\n"
        + "".join(f"        {src.chaine(c)}: {src.chaine(l)},\n" for c, l in motifs.items()) + "    ]\n"
        + f"    /// Un motif inconnu ou absent (`motifEvolution`).\n    static let motifEvolutionParDefaut = {src.chaine(defaut.group(1))}\n"
        + "    /// La couleur de chaque tranche d'une répartition, selon la teinte que le serveur\n"
        "    /// lui choisit (`BarresCroisees.svelte`) : une couleur, un aplat ; deux, des hachures.\n"
        "    static let tranches: [String: [CouleurDeTranche]] = [\n" + tranches + "    ]\n"
        "}\n"
    )


def annonces_hall() -> str:
    formats = src.tableau(src.front(COMPOSANTS + "OngletAnnoncesHall.svelte"), "AH_FORMATS")
    return (
        "/// Ce que le site écrit des Annonces Hall de l'Espace CS et que le contrat ne sert pas.\n"
        "enum TablesAnnoncesHall {\n"
        + couples("formats", "Les formats qu'on peut demander pour une affiche (`AH_FORMATS`).",
                  [(f["val"], f["label"]) for f in formats])
        + "}\n"
    )


def courriels() -> str:
    verdicts = src.objet(src.front(COMPOSANTS + "OngletCourriels.svelte"), r"\bconst VERDICTS\b[^=]*=\s*\{")
    journal = src.front(COMPOSANTS + "JournalVerdicts.svelte")
    badges = {ton: badge for badge, ton in re.findall(r"class:(badge-[a-z]+)=\{e\.ton === '(\w+)'\}", journal)}
    manquants = {v["ton"] for v in verdicts.values()} - badges.keys()
    if manquants:
        raise SystemExit(f"❌ JournalVerdicts.svelte : aucune pastille pour le ton {sorted(manquants)}")
    return (
        "/// Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.\n"
        "enum TablesCourriels {\n"
        + teintes("verdicts", "Ce que la relève a fait d'un message (`VERDICTS`), teinté par son ton.",
                  [(c, v["libelle"], badges[v["ton"]]) for c, v in verdicts.items()])
        + "}\n"
    )


def main() -> None:
    src.ecrire("CoproFirst/Fonctions/Delegations/Genere/TablesDelegations.swift", SCRIPT,
               "front/src/lib/pages-roles.ts, src/routes/(app)/delegations/+page.svelte.", delegations())
    src.ecrire("CoproFirst/Fonctions/EspaceCS/Genere/TablesReporting.swift", SCRIPT,
               "front/src/lib/entretien-periodique.ts, reporting.ts, components/reporting/\n"
               "//   (TableauAffaires, VueSuiviAffaires, BarresCroisees) ; front/src/styles/socle.css et\n"
               "//   palette-sombre.css.", reporting(),
               imports="import SwiftUI\n")
    src.ecrire("CoproFirst/Fonctions/EspaceCS/Genere/TablesAnnoncesHall.swift", SCRIPT,
               "front/src/lib/components/OngletAnnoncesHall.svelte.", annonces_hall())
    src.ecrire("CoproFirst/Fonctions/EspaceCS/Genere/TablesCourriels.swift", SCRIPT,
               "front/src/lib/components/OngletCourriels.svelte, JournalVerdicts.svelte.",
               courriels())


if __name__ == "__main__":
    main()
