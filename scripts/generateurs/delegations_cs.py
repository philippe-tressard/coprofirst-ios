# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les tables des Délégations et de trois onglets de l'Espace CS (Reporting, Annonces
Hall, Courriels affaires) (#15).

Le contrat d'API ne sert que des CODES (un statut, une décision, une ancienneté, une
teinte de tranche) : leurs libellés et leurs couleurs sont ceux que le site publie
(`tables-clients.json`) :

- le descriptif de la page `delegations` (table `pages`) — ceux des onglets de
  l'Espace CS sont générés avec son cadre (`espace_cs.py`) ;
- l'état d'une délégation (`statutsDelegation`) ;
- la teinte de l'âge d'une affaire (`teinteAge`), les modes du suivi (`modesSuivi`),
  l'état d'une visite (`etatsVisite`), le motif « a évolué » (`motifsEvolution`,
  `motifEvolutionParDefaut`) et la couleur de chaque tranche des répartitions
  (`tranchesRepartition`) : un jeton de la `Palette` (`--serie-*`, `--palier-*`,
  `--color-*`), nommé par son chemin — aucune couleur ici ;
- les formats d'une affiche (`formatsAffiche`) ;
- le verdict de la relève des courriels (`verdictsReleve`) et la pastille de chaque ton
  (`teinteDuTon`).

→ `CoproFirst/Fonctions/Delegations/Genere/` et, pour les onglets du cadre CS,
`CoproFirst/Fonctions/EspaceCS/Genere/`.
"""

from __future__ import annotations

import re

from generateurs._commun import (ATTRIBUTS, FONCTIONS, OPTION, chaine, couples, dictionnaire, ecrire_table,
                                 page_du_site, propriete, sans_pictogramme, teintes)
from generateurs._tables import source
from generateurs.palettes import EXPOSES

SOURCES: list[str] = []
#: Un jeton cité dans la déclaration d'une tranche : `var(--serie-1)`.
JETON_CITE = re.compile(r"var\(--([\w-]+)\)")


def delegations(ctx) -> str:
    page = page_du_site(ctx, "delegations")
    if not page.get("descriptif"):
        raise SystemExit("❌ la page delegations n'a plus de descriptif dans la table « pages »")
    statuts = ctx.table("statutsDelegation", ATTRIBUTS)
    return (
        "    /// Le descriptif de la page : ce qu'une délégation permet.\n"
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
    """Chaque teinte de `tranchesRepartition` → les jetons que son fond peint, dans l'ordre
    (un seul : un aplat ; deux : des hachures)."""
    lignes = []
    for cle, regle in ctx.table("tranchesRepartition", {str: {"background": str}}).items():
        cites = JETON_CITE.findall(regle["background"])
        if not cites:
            raise SystemExit(f"❌ tranchesRepartition.{cle} : aucun jeton dans « {regle['background']} »")
        lignes.append(f"        {chaine(cle)}: [{', '.join(couleur(j) for j in cites)}],\n")
    return "".join(lignes)


def reporting(ctx) -> str:
    modes = ctx.table("modesSuivi", [{"valeur": str, "libelle": str}])
    visites = ctx.table("etatsVisite", {str: {"libelle": str, "teinte": str}})
    return (
        dictionnaire("teintesAge", "La pastille de l'âge d'une affaire, selon son ancienneté servie (`TEINTE_AGE`).",
                     ctx.table("teinteAge", {str: str}))
        + couples("modes", "Les modes du Suivi des affaires, dans l'ordre du site (`MODES_SUIVI`).",
                  [(m["valeur"], m["libelle"]) for m in modes])
        + teintes("etatsVisite", "L'état d'une visite d'entretien, calculé au serveur (`ETATS_VISITE`).",
                  [(c, sans_pictogramme(v["libelle"]), v["teinte"]) for c, v in visites.items()])
        + dictionnaire("motifsEvolution",
                       "Ce que le signal « a évolué » dit d'une affaire, selon le motif servi (`MOTIFS_EVOLUTION`).",
                       ctx.table("motifsEvolution", {str: str}))
        + "    /// Un motif inconnu ou absent (`MOTIF_EVOLUTION_PAR_DEFAUT`).\n"
        f"    static let motifEvolutionParDefaut = {chaine(ctx.table('motifEvolutionParDefaut', str))}\n"
        "    /// La couleur de chaque tranche d'une répartition, selon la teinte que le serveur\n"
        "    /// lui choisit (`tranchesRepartition`) : une couleur, un aplat ; deux, des hachures.\n"
        "    static let tranches: [String: [CouleurDeTranche]] = [\n" + tranches(ctx) + "    ]\n"
    )


def courriels(ctx) -> str:
    verdicts = ctx.table("verdictsReleve", {str: {"libelle": str, "ton": str}})
    badges = ctx.table("teinteDuTon", {str: str})
    manquants = {v["ton"] for v in verdicts.values()} - badges.keys()
    if manquants:
        raise SystemExit(f"❌ teinteDuTon : aucune pastille pour le ton {sorted(manquants)}")
    return teintes("verdicts", "Ce que la relève a fait d'un message (`VERDICTS_RELEVE`), teinté par son ton.",
                   [(c, v["libelle"], badges[v["ton"]]) for c, v in verdicts.items()])


def generer(ctx) -> str:
    formats = ctx.table("formatsAffiche", [OPTION])
    ecrire_table(ctx, FONCTIONS / "Delegations" / "Genere" / "TablesDelegations.swift",
                 source("pages", "statutsDelegation"), "TablesDelegations",
                 "Ce que le site écrit des « Délégations aidant » et que le contrat ne sert pas.", delegations(ctx))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesReporting.swift",
                 source("teinteAge", "modesSuivi", "etatsVisite", "motifsEvolution", "motifEvolutionParDefaut",
                        "tranchesRepartition"), "TablesReporting",
                 "Ce que le site écrit du Reporting de l'Espace CS et que le contrat ne sert pas.", reporting(ctx),
                 swiftui=True)
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesAnnoncesHall.swift",
                 source("formatsAffiche"), "TablesAnnoncesHall",
                 "Ce que le site écrit des Annonces Hall de l'Espace CS et que le contrat ne sert pas.",
                 couples("formats", "Les formats qu'on peut demander pour une affiche (`AH_FORMATS`).",
                         [(f["val"], f["label"]) for f in formats]))
    ecrire_table(ctx, FONCTIONS / "EspaceCS" / "Genere" / "TablesCourriels.swift",
                 source("verdictsReleve", "teinteDuTon"), "TablesCourriels",
                 "Ce que le site écrit des Courriels affaires de l'Espace CS et que le contrat ne sert pas.",
                 courriels(ctx))
    return "délégations, reporting, annonces Hall et courriels affaires"
