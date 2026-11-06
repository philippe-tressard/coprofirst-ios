# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables des Délégations et de trois onglets de l'Espace CS (Reporting, Annonces
Hall, Courriels affaires) (#15).

Le contrat d'API ne sert que des CODES (un statut, une décision, une ancienneté, une
teinte de tranche) : leurs libellés et leurs couleurs vivent dans le front du site :

- le descriptif de la page `delegations` (`pages-roles.ts`) — ceux des onglets de
  l'Espace CS sont générés avec son cadre (`espace_cs.py`) ;
- l'état d'une délégation (`parAttribut` de `routes/(app)/delegations/+page.svelte`) ;
- la teinte de l'âge d'une affaire (`TEINTE_AGE`, `TableauAffaires.svelte`), les modes
  du suivi (`MODES`, `VueSuiviAffaires.svelte`), l'état d'une visite (`ETATS_VISITE`,
  `entretien-periodique.ts`), le motif « a évolué » (`reporting.ts`) et la couleur de
  chaque tranche des répartitions (`BarresCroisees.svelte`) : un jeton de la `Palette`
  (`--serie-*`, `--palier-*`, `--color-*`), nommé par son chemin — aucune couleur ici ;
- les formats d'une affiche (`AH_FORMATS`, `OngletAnnoncesHall.svelte`) ;
- le verdict de la relève des courriels (`VERDICTS`, `OngletCourriels.svelte`) et la
  pastille de chaque ton (`JournalVerdicts.svelte`).

→ `CoproFirst/Fonctions/Delegations/Genere/` et, pour les onglets du cadre CS,
`CoproFirst/Fonctions/EspaceCS/Genere/`.
"""

from __future__ import annotations

import re

import lecture_ts
from generateurs._commun import FONCTIONS, chaine, ecrire_table, objet, propriete, sans_pictogramme
from generateurs.palettes import EXPOSES

LIB = "front/src/lib/"
COMPOSANTS = "front/src/lib/components/"
PAGE_DELEGATIONS = "front/src/routes/(app)/delegations/+page.svelte"
SOURCES = [
    LIB + "pages-roles.ts",
    PAGE_DELEGATIONS,
    COMPOSANTS + "reporting/TableauAffaires.svelte",
    COMPOSANTS + "reporting/VueSuiviAffaires.svelte",
    COMPOSANTS + "reporting/BarresCroisees.svelte",
    LIB + "entretien-periodique.ts",
    LIB + "reporting.ts",
    COMPOSANTS + "OngletAnnoncesHall.svelte",
    COMPOSANTS + "OngletCourriels.svelte",
    COMPOSANTS + "JournalVerdicts.svelte",
]


def teintes(nom: str, doc: str, entrees: list[tuple[str, str, str]]) -> str:
    lignes = "".join(f"        {chaine(c)}: LibelleTeinte({chaine(l)}, {chaine(b)}),\n" for c, l, b in entrees)
    return f"    /// {doc}\n    static let {nom}: [String: LibelleTeinte] = [\n{lignes}    ]\n"


def couples(nom: str, doc: str, entrees: list[tuple[str, str]]) -> str:
    lignes = "".join(f"        ({chaine(c)}, {chaine(l)}),\n" for c, l in entrees)
    return f"    /// {doc}\n    static let {nom}: [(code: String, libelle: String)] = [\n{lignes}    ]\n"


def dictionnaire(nom: str, doc: str, entrees: dict) -> str:
    lignes = "".join(f"        {chaine(c)}: {chaine(v)},\n" for c, v in entrees.items())
    return f"    /// {doc}\n    static let {nom}: [String: String] = [\n{lignes}    ]\n"


def delegations(ctx) -> str:
    page = next(p for p in lecture_ts.table(ctx.lire(LIB + "pages-roles.ts"), "PAGES_ROLES")
                if p["id"] == "delegations")
    statuts = objet(ctx.lire(PAGE_DELEGATIONS), r"=\s*parAttribut\(")
    return (
        "    /// Le descriptif de la page (`pages-roles.ts`) : ce qu'une délégation permet.\n"
        f"    static let descriptif = {chaine(page['descriptif'])}\n"
        + teintes("statuts", "L'état d'une délégation (`parAttribut` de la page du site).",
                  [(c, v["libelle"], v["badge"]) for c, v in statuts.items()])
    )


def couleur(jeton: str) -> str:
    """Un jeton du site → la couleur de la `Palette` qui le porte (chemin, jamais valeur)."""
    if not jeton.startswith(EXPOSES):
        raise SystemExit(f"❌ BarresCroisees.svelte : --{jeton} n'est pas un jeton de la Palette ({EXPOSES})")
    return f".palette(\\.{propriete(jeton)})"


def tranches(ctx) -> str:
    """Chaque `[data-teinte='…']` de `BarresCroisees.svelte` → les jetons qu'il peint, dans
    l'ordre (un seul : un aplat ; deux : des hachures)."""
    texte = ctx.lire(COMPOSANTS + "reporting/BarresCroisees.svelte")
    regles = re.findall(r"\[data-teinte='([\w-]+)'\]\s*\{([^}]*)\}", texte[texte.index("<style>"):])
    if not regles:
        raise SystemExit("❌ BarresCroisees.svelte : aucune règle [data-teinte] lue")
    lignes = []
    for cle, corps in regles:
        couleurs = ", ".join(couleur(j) for j in re.findall(r"var\(--([\w-]+)\)", corps))
        lignes.append(f"        {chaine(cle)}: [{couleurs}],\n")
    return "".join(lignes)


def reporting(ctx) -> str:
    age = objet(ctx.lire(COMPOSANTS + "reporting/TableauAffaires.svelte"), r"\bconst TEINTE_AGE\b[^=]*=\s*\{")
    modes = lecture_ts.table(ctx.lire(COMPOSANTS + "reporting/VueSuiviAffaires.svelte"), "MODES")
    visites = objet(ctx.lire(LIB + "entretien-periodique.ts"), r"\bconst ETATS_VISITE\b[^=]*=\s*\{")
    texte = ctx.lire(LIB + "reporting.ts")
    motifs = objet(texte, r"\bconst MOTIFS_EVOLUTION\b[^=]*=\s*\{")
    defaut = re.search(r"function motifEvolution[^{]*\{[^}]*\|\|\s*'([^']+)'", texte)
    if not defaut:
        raise SystemExit("❌ reporting.ts : le motif par défaut de motifEvolution est introuvable")
    return (
        dictionnaire("teintesAge", "La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).",
                     age)
        + couples("modes", "Les modes du Suivi des affaires, dans l'ordre du site (`MODES`).",
                  [(m["valeur"], m["libelle"]) for m in modes])
        + teintes("etatsVisite", "L'état d'une visite d'entretien, calculé au serveur (`ETATS_VISITE`).",
                  [(c, sans_pictogramme(v["libelle"]), v["teinte"]) for c, v in visites.items()])
        + dictionnaire("motifsEvolution",
                       "Ce que le signal « a évolué » dit d'une affaire, selon le motif servi (`MOTIFS_EVOLUTION`).",
                       motifs)
        + "    /// Un motif inconnu ou absent (`motifEvolution`).\n"
        f"    static let motifEvolutionParDefaut = {chaine(defaut.group(1))}\n"
        "    /// La couleur de chaque tranche d'une répartition, selon la teinte que le serveur\n"
        "    /// lui choisit (`BarresCroisees.svelte`) : une couleur, un aplat ; deux, des hachures.\n"
        "    static let tranches: [String: [CouleurDeTranche]] = [\n" + tranches(ctx) + "    ]\n"
    )


def courriels(ctx) -> str:
    verdicts = objet(ctx.lire(COMPOSANTS + "OngletCourriels.svelte"), r"\bconst VERDICTS\b[^=]*=\s*\{")
    journal = ctx.lire(COMPOSANTS + "JournalVerdicts.svelte")
    badges = {ton: badge for badge, ton in re.findall(r"class:(badge-[a-z]+)=\{e\.ton === '(\w+)'\}", journal)}
    manquants = {v["ton"] for v in verdicts.values()} - badges.keys()
    if manquants:
        raise SystemExit(f"❌ JournalVerdicts.svelte : aucune pastille pour le ton {sorted(manquants)}")
    return teintes("verdicts", "Ce que la relève a fait d'un message (`VERDICTS`), teinté par son ton.",
                   [(c, v["libelle"], badges[v["ton"]]) for c, v in verdicts.items()])


def generer(ctx) -> str:
    formats = lecture_ts.table(ctx.lire(COMPOSANTS + "OngletAnnoncesHall.svelte"), "AH_FORMATS")
    ecrire_table(ctx, FONCTIONS / "Delegations" / "Genere" / "TablesDelegations.swift",
                 "front/src/lib/pages-roles.ts, src/routes/(app)/delegations/+page.svelte", "TablesDelegations",
                 "Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.", delegations(ctx))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesReporting.swift",
                 "front/src/lib/entretien-periodique.ts, reporting.ts, components/reporting/ (TableauAffaires, "
                 "VueSuiviAffaires, BarresCroisees)", "TablesReporting",
                 "Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.", reporting(ctx),
                 swiftui=True)
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesAnnoncesHall.swift",
                 "front/src/lib/components/OngletAnnoncesHall.svelte", "TablesAnnoncesHall",
                 "Ce que le site écrit des Annonces Hall de l'Espace CS et que le contrat ne sert pas.",
                 couples("formats", "Les formats qu'on peut demander pour une affiche (`AH_FORMATS`).",
                         [(f["val"], f["label"]) for f in formats]))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesCourriels.swift",
                 "front/src/lib/components/OngletCourriels.svelte, JournalVerdicts.svelte", "TablesCourriels",
                 "Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.",
                 courriels(ctx))
    return "délégations, reporting, annonces Hall et courriels affaires"
