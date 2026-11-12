# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables des Délégations et de trois onglets de l'Espace CS (Reporting, Annonces
Hall, Courriels affaires) (#15).

Le contrat d'API ne sert que des CODES (un statut, une décision, une ancienneté, une
teinte de tranche) : leurs libellés et leurs couleurs vivent dans le front du site, qui
les publie dans `tables-clients.json` de chaque release (#128) :

- le descriptif de la page `delegations` (`pages`, qui porte `PAGES_ROLES`) — ceux des
  onglets de l'Espace CS sont générés avec son cadre (`espace_cs.py`) ;
- l'état d'une délégation (`statutsDelegation`) ;
- la teinte de l'âge d'une affaire (`teinteAge`), les modes du suivi (`modesSuivi`),
  l'état d'une visite (`etatsVisite`), le motif « a évolué » (`motifsEvolution`,
  `motifEvolutionParDefaut`) et la couleur de chaque tranche des répartitions
  (`tranchesRepartition`, les règles `[data-teinte]` de `BarresCroisees.svelte`) : un
  jeton de la `Palette` (`--serie-*`, `--palier-*`, `--color-*`), nommé par son
  chemin — aucune couleur ici ;
- les formats d'une affiche (`formatsAffiche`) ;
- le verdict de la relève des courriels (`verdictsReleve`) et la pastille de chaque ton
  (`teinteDuTon`).

→ `CoproFirst/Fonctions/Delegations/Genere/` et, pour les onglets du cadre CS,
`CoproFirst/Fonctions/EspaceCS/Genere/`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table, propriete, sans_pictogramme
from generateurs.palettes import EXPOSES

SOURCES: list[str] = []  # lu dans tables-clients.json de la release (#128), pas dans les sources



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
    page = next(p for p in ctx.table("pages") if p["id"] == "delegations")
    statuts = ctx.table("statutsDelegation")
    return (
        "    /// Le descriptif de la page (`pages-roles.ts`) : ce qu'une délégation permet.\n"
        f"    static let descriptif = {chaine(page['descriptif'])}\n"
        + teintes("statuts", "L'état d'une délégation (`STATUTS_DELEGATION`).",
                  [(c, v["libelle"], v["badge"]) for c, v in statuts.items()])
    )


def couleur(jeton: str) -> str:
    """Un jeton du site → la couleur de la `Palette` qui le porte (chemin, jamais valeur)."""
    if not jeton.startswith(EXPOSES):
        raise SystemExit(f"❌ tranchesRepartition : --{jeton} n'est pas un jeton de la Palette ({EXPOSES})")
    return f".palette(\\.{propriete(jeton)})"


def tranches(ctx) -> str:
    """Chaque `[data-teinte='…']` de `BarresCroisees.svelte` (`tranchesRepartition`) → les
    jetons qu'il peint, dans l'ordre (un seul : un aplat ; deux : des hachures)."""
    regles = ctx.table("tranchesRepartition")
    if not regles:
        raise SystemExit("❌ tranchesRepartition : aucune règle [data-teinte] publiée")
    lignes = []
    for cle, declarations in regles.items():
        corps = " ".join(declarations.values())
        couleurs = ", ".join(couleur(j) for j in re.findall(r"var\(--([\w-]+)\)", corps))
        lignes.append(f"        {chaine(cle)}: [{couleurs}],\n")
    return "".join(lignes)


def reporting(ctx) -> str:
    age = ctx.table("teinteAge")
    modes = ctx.table("modesSuivi")
    visites = ctx.table("etatsVisite")
    motifs = ctx.table("motifsEvolution")
    defaut = ctx.table("motifEvolutionParDefaut")
    return (
        dictionnaire("teintesAge", "La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).",
                     age)
        + couples("modes", "Les modes du Suivi des affaires, dans l'ordre du site (`MODES_SUIVI`).",
                  [(m["valeur"], m["libelle"]) for m in modes])
        + teintes("etatsVisite", "L'état d'une visite d'entretien, calculé au serveur (`ETATS_VISITE`).",
                  [(c, sans_pictogramme(v["libelle"]), v["teinte"]) for c, v in visites.items()])
        + dictionnaire("motifsEvolution",
                       "Ce que le signal « a évolué » dit d'une affaire, selon le motif servi (`MOTIFS_EVOLUTION`).",
                       motifs)
        + "    /// Un motif inconnu ou absent (`motifEvolution`).\n"
        f"    static let motifEvolutionParDefaut = {chaine(defaut)}\n"
        "    /// La couleur de chaque tranche d'une répartition, selon la teinte que le serveur\n"
        "    /// lui choisit (`BarresCroisees.svelte`) : une couleur, un aplat ; deux, des hachures.\n"
        "    static let tranches: [String: [CouleurDeTranche]] = [\n" + tranches(ctx) + "    ]\n"
    )


def courriels(ctx) -> str:
    verdicts = ctx.table("verdictsReleve")
    badges = ctx.table("teinteDuTon")
    manquants = {v["ton"] for v in verdicts.values()} - badges.keys()
    if manquants:
        raise SystemExit(f"❌ teinteDuTon : aucune pastille pour le ton {sorted(manquants)}")
    return teintes("verdicts", "Ce que la relève a fait d'un message (`VERDICTS_RELEVE`), teinté par son ton.",
                   [(c, v["libelle"], badges[v["ton"]]) for c, v in verdicts.items()])


def generer(ctx) -> str:
    formats = ctx.table("formatsAffiche")
    ecrire_table(ctx, FONCTIONS / "Delegations" / "Genere" / "TablesDelegations.swift",
                 ctx.provenance_tables("pages", "statutsDelegation"), "TablesDelegations",
                 "Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.", delegations(ctx))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesReporting.swift",
                 ctx.provenance_tables("teinteAge", "modesSuivi", "etatsVisite", "motifsEvolution", "motifEvolutionParDefaut",
                        "tranchesRepartition"), "TablesReporting",
                 "Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.", reporting(ctx),
                 swiftui=True)
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesAnnoncesHall.swift",
                 ctx.provenance_tables("formatsAffiche"), "TablesAnnoncesHall",
                 "Ce que le site écrit des Annonces Hall de l'Espace CS et que le contrat ne sert pas.",
                 couples("formats", "Les formats qu'on peut demander pour une affiche (`AH_FORMATS`).",
                         [(f["val"], f["label"]) for f in formats]))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesCourriels.swift",
                 ctx.provenance_tables("verdictsReleve", "teinteDuTon"), "TablesCourriels",
                 "Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.",
                 courriels(ctx))
    return "délégations, reporting, annonces Hall et courriels affaires"
