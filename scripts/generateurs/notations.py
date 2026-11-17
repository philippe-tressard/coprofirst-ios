# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La notation d'un prestataire, telle que le site l'écrit (`front/src/lib/notations.ts`, #207).

Le serveur sert l'ÉTAT d'un avis (`etat` : `mauvais`, `neutre`, `excellent`) et la
moyenne d'un prestataire (`note_moyenne`) ; le site en tient le libellé, la teinte et
les seuils qui disent l'état d'une moyenne (`etatDeMoyenne`) — cette table est « la
SEULE du front ». L'app la reçoit générée :

- `etats` : l'ordre du site (`ETATS`) ;
- `libelles`, `teintes` : `LIBELLE_ETAT`, `TEINTE_ETAT` (la table `parAttribut`) ;
- `seuilsDeMoyenne` et `etatAuDela` : les `if (moyenne < X) return 'Y'` d'`etatDeMoyenne`,
  dans l'ordre, puis son dernier `return` ;
- `pointsForts`, `pointsFaibles` : les motifs à cocher (`POINTS_FORTS`, `POINTS_FAIBLES`) ;
- `phraseForts`, `phraseFaibles` : le début de chaque morceau de `phraseGeneree`
  (« Points forts : … . ») — sa forme est vérifiée ici, et le générateur échoue si elle
  change : la composition (`AvisSaisi`) devrait alors changer avec elle.

→ `CoproFirst/Fonctions/Prestataires/Genere/TablesNotations.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table, objet

SOURCES = ["front/src/lib/notations.ts"]


def _etats(texte: str) -> list[str]:
    m = re.search(r"export const ETATS = \[([^\]]*)\] as const;", texte)
    etats = re.findall(r"'(\w+)'", m.group(1)) if m else []
    if not etats:
        raise SystemExit("❌ ETATS illisible dans notations.ts — l'app doit l'apprendre")
    return etats


def _seuils(texte: str) -> tuple[list[tuple[str, str]], str]:
    m = re.search(r"export function etatDeMoyenne\(moyenne: number\): Etat \{(.*?)\n\}", texte, re.S)
    corps = m.group(1) if m else ""
    seuils = re.findall(r"if \(moyenne < ([\d.]+)\) return '(\w+)';", corps)
    dernier = re.findall(r"\n\s*return '(\w+)';", corps)
    if not seuils or len(dernier) != 1:
        raise SystemExit("❌ etatDeMoyenne illisible dans notations.ts — l'app doit l'apprendre")
    return seuils, dernier[0]


def _motifs(texte: str, nom: str) -> list[str]:
    m = re.search(rf"export const {nom} = \[([^\]]*)\] as const;", texte)
    motifs = re.findall(r"'([^']+)'", m.group(1)) if m else []
    if not motifs:
        raise SystemExit(f"❌ {nom} illisible dans notations.ts — l'app doit l'apprendre")
    return motifs


def _phrases(texte: str) -> tuple[str, str]:
    """Les deux débuts de `phraseGeneree`, si sa forme est celle que l'app compose."""
    m = re.search(r"export function phraseGeneree\(.*?\n\}", texte, re.S)
    corps = m.group(0) if m else ""
    morceaux = re.findall(r"if \((forts|faibles)\.length\) morceaux\.push\(`([^`$]+)\$\{\1\.join\(', '\)\}\.`\);", corps)
    if [n for n, _ in morceaux] != ["forts", "faibles"] or "return morceaux.join(' ');" not in corps:
        raise SystemExit("❌ phraseGeneree a changé de forme dans notations.ts — AvisSaisi doit la suivre")
    return morceaux[0][1], morceaux[1][1]


def generer(ctx) -> str:
    texte = ctx.lire(SOURCES[0])
    etats = _etats(texte)
    table = objet(texte, r"export const \{ libelle: LIBELLE_ETAT, badge: TEINTE_ETAT \} = parAttribut\(")
    if set(table) != set(etats):
        raise SystemExit(f"❌ LIBELLE_ETAT ne couvre pas ETATS ({sorted(table)} ≠ {sorted(etats)})")
    seuils, au_dela = _seuils(texte)
    forts, faibles = _motifs(texte, "POINTS_FORTS"), _motifs(texte, "POINTS_FAIBLES")
    phrase_forts, phrase_faibles = _phrases(texte)
    corps = (
        "    /// Les états d'un avis, dans l'ordre du site (`ETATS`).\n"
        f"    static let etats = [{', '.join(chaine(e) for e in etats)}]\n"
        "    /// Le libellé de chaque état (`LIBELLE_ETAT`).\n"
        "    static let libelles: [String: String] = [\n"
        + "".join(f"        {chaine(e)}: {chaine(table[e]['libelle'])},\n" for e in etats)
        + "    ]\n"
        "    /// La classe de teinte de chaque état (`TEINTE_ETAT`).\n"
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
        "    /// Le début de chaque morceau de la phrase générée (`phraseGeneree`) : les motifs\n"
        "    /// suivent, joints par « , », puis un point ; les deux morceaux, par une espace.\n"
        f"    static let phraseForts = {chaine(phrase_forts)}\n"
        f"    static let phraseFaibles = {chaine(phrase_faibles)}\n"
    )
    ecrire_table(ctx, FONCTIONS / "Prestataires" / "Genere" / "TablesNotations.swift",
                 "front/src/lib/notations.ts", "TablesNotations",
                 "La notation d'un prestataire, telle que le site l'écrit.", corps)
    return f"{len(etats)} états d'un avis, {len(seuils)} seuils de moyenne, {len(forts) + len(faibles)} motifs"
