# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La notation d'un prestataire, telle que le site l'écrit (#207).

Le serveur sert l'ÉTAT d'un avis (`etat` : `mauvais`, `neutre`, `excellent`) et la
moyenne d'un prestataire (`note_moyenne`) ; le site en tient le libellé, la teinte et
les seuils qui disent l'état d'une moyenne (`etatDeMoyenne`) — cette table est « la
SEULE du front ». Depuis v3.106.0, elle se lit dans `tables-clients.json` (`notations`,
coprofirst#2775) — plus par motif dans `front/src/lib/notations.ts` :

- `etats` : l'ordre du site (`ETATS`) ;
- `libelles`, `teintes` : `PAR_ETAT` ;
- `seuilsDeMoyenne` et `etatAuDela` : `SEUILS_DE_MOYENNE`, dans l'ordre, puis `ETAT_AU_DELA`.

Depuis v3.109.0, la saisie guidée d'un avis se lit aussi dans `tables-clients.json`
(`commentaireAvis`, coprofirst#2816) :

- `pointsForts`, `pointsFaibles` : les motifs à cocher (`POINTS_FORTS`, `POINTS_FAIBLES`) ;
- la forme de la phrase générée et du commentaire (`FORME_COMMENTAIRE`) : le début de
  chaque groupe (`phraseForts`, `phraseFaibles`), et les quatre séparateurs que
  `AvisSaisi` compose et décompose — aucun ne s'écrit dans l'app.

REPLI DATÉ (17/11/2026, #268) : sous v3.109.0, la release ne publie pas cette table ; les
motifs et la forme se lisent alors dans `notations.ts`, dont la forme est vérifiée — le
générateur échoue si elle change. À retirer quand le plancher atteint v3.109.0.

→ `CoproFirst/Fonctions/Prestataires/Genere/TablesNotations.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table

#: Lu seulement sous v3.109.0 (le repli daté ci-dessus).
SOURCES = ["front/src/lib/notations.ts"]
#: La forme du commentaire (`FORME_COMMENTAIRE`), clé publiée → constante générée.
FORME = {"prefixeForts": "phraseForts", "prefixeFaibles": "phraseFaibles", "entreMotifs": "entreMotifs",
         "finDeGroupe": "finDeGroupe", "entreGroupes": "entreGroupes", "avantLibre": "avantLibre"}


def _notations(ctx) -> tuple[list[str], dict, list[tuple[int | float, str]], str]:
    """La table publiée, vérifiée : une forme inattendue arrête la génération."""
    t = ctx.table("notations")
    etats, par_etat = t.get("etats"), t.get("parEtat")
    seuils, au_dela = t.get("seuilsDeMoyenne"), t.get("etatAuDela")
    lisible = (isinstance(etats, list) and etats and isinstance(par_etat, dict)
               and set(par_etat) == set(etats)
               and all(isinstance(v, dict) and {"libelle", "badge"} <= set(v) for v in par_etat.values())
               and isinstance(seuils, list) and seuils
               and all(isinstance(x, dict) and isinstance(x.get("borne"), (int, float))
                       and x.get("etat") in etats for x in seuils)
               and au_dela in etats)
    if not lisible:
        raise SystemExit(f"❌ notations : forme inattendue ({t!r}) — l'app doit l'apprendre")
    return etats, par_etat, [(x["borne"], x["etat"]) for x in seuils], au_dela


def _motifs(texte: str, nom: str) -> list[str]:
    m = re.search(rf"export const {nom} = \[([^\]]*)\] as const;", texte)
    motifs = re.findall(r"'([^']+)'", m.group(1)) if m else []
    if not motifs:
        raise SystemExit(f"❌ {nom} illisible dans notations.ts — l'app doit l'apprendre")
    return motifs


def _forme_lue(texte: str) -> dict[str, str]:
    """REPLI DATÉ (sous v3.109.0) : la forme écrite en dur dans `phraseGeneree` et
    `commentaireComplet`, si c'est bien celle-là — sinon la génération s'arrête."""
    m = re.search(r"export function phraseGeneree\(.*?\n\}", texte, re.S)
    corps = m.group(0) if m else ""
    morceaux = re.findall(r"if \((forts|faibles)\.length\) morceaux\.push\(`([^`$]+)\$\{\1\.join\(', '\)\}\.`\);", corps)
    complet = re.search(r"export function commentaireComplet\(.*?\n\}", texte, re.S)
    if ([n for n, _ in morceaux] != ["forts", "faibles"] or "return morceaux.join(' ');" not in corps
            or not complet or ".join('\\n');" not in complet.group(0)):
        raise SystemExit("❌ phraseGeneree a changé de forme dans notations.ts — AvisSaisi doit la suivre")
    return {"prefixeForts": morceaux[0][1], "prefixeFaibles": morceaux[1][1], "entreMotifs": ", ",
            "finDeGroupe": ".", "entreGroupes": " ", "avantLibre": "\n"}


def _des_motifs(liste) -> bool:
    return isinstance(liste, list) and bool(liste) and all(isinstance(m, str) and m for m in liste)


def _commentaire(ctx) -> tuple[list[str], list[str], dict[str, str], str]:
    """Les motifs à cocher, la forme du commentaire, et d'où ils viennent."""
    if not ctx.publie("commentaireAvis"):  # REPLI DATÉ (17/11/2026) : sous v3.109.0
        texte = ctx.lire(SOURCES[0])
        return (_motifs(texte, "POINTS_FORTS"), _motifs(texte, "POINTS_FAIBLES"), _forme_lue(texte),
                SOURCES[0])
    t = ctx.table("commentaireAvis")
    forts, faibles, forme = t.get("pointsForts"), t.get("pointsFaibles"), t.get("forme")
    if not (_des_motifs(forts) and _des_motifs(faibles) and isinstance(forme, dict) and set(forme) == set(FORME)
            and all(isinstance(v, str) and v for v in forme.values())):
        raise SystemExit(f"❌ commentaireAvis : forme inattendue ({t!r}) — l'app doit l'apprendre")
    return forts, faibles, forme, ctx.provenance_tables("commentaireAvis")


def generer(ctx) -> str:
    etats, table, seuils, au_dela = _notations(ctx)
    forts, faibles, forme, provenance = _commentaire(ctx)
    corps = (
        "    /// Les états d'un avis, dans l'ordre du site (`ETATS`).\n"
        f"    static let etats = [{', '.join(chaine(e) for e in etats)}]\n"
        "    /// Le libellé de chaque état (`PAR_ETAT`).\n"
        "    static let libelles: [String: String] = [\n"
        + "".join(f"        {chaine(e)}: {chaine(table[e]['libelle'])},\n" for e in etats)
        + "    ]\n"
        "    /// La classe de teinte de chaque état (`PAR_ETAT`).\n"
        "    static let teintes: [String: String] = [\n"
        + "".join(f"        {chaine(e)}: {chaine(table[e]['badge'])},\n" for e in etats)
        + "    ]\n"
        "    /// L'état d'une moyenne (`etatDeMoyenne`) : sous la borne, l'état — dans l'ordre.\n"
        "    static let seuilsDeMoyenne: [(borne: Double, etat: String)] = [\n"
        + "".join(f"        ({borne}, {chaine(etat)}),\n" for borne, etat in seuils)
        + "    ]\n"
        "    /// Au-delà de la dernière borne.\n"
        f"    static let etatAuDela = {chaine(au_dela)}\n"
        "    /// Les motifs à cocher, par nature (`POINTS_FORTS`, `POINTS_FAIBLES`).\n"
        f"    static let pointsForts = [{', '.join(chaine(m) for m in forts)}]\n"
        f"    static let pointsFaibles = [{', '.join(chaine(m) for m in faibles)}]\n"
        "    /// La forme de la phrase générée et du commentaire (`FORME_COMMENTAIRE`) : le début\n"
        "    /// de chaque groupe, puis ses motifs joints par `entreMotifs`, puis `finDeGroupe` ;\n"
        "    /// les groupes, joints par `entreGroupes` ; le texte libre suit après `avantLibre`.\n"
        + "".join(f"    static let {nom} = {chaine(forme[cle])}\n" for cle, nom in FORME.items())
    )
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesNotations.swift",
                 f"{ctx.provenance_tables('notations')}, {provenance}", "TablesNotations",
                 "La notation d'un prestataire, telle que le site l'écrit.", corps)
    return f"{len(etats)} états d'un avis, {len(seuils)} seuils de moyenne, {len(forts) + len(faibles)} motifs"
