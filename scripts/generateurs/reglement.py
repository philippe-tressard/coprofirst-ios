# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas (#71) :

- la classe de la capsule du verdict pour chaque ton SERVI (`verdict_ton`, #2505) —
  `BadgeVerdict.svelte` la choisit ; le serveur dit le ton, le front le peint ;
- le séparateur qui joint l'acte, la rubrique et la page d'un extrait
  (`SEPARATEUR.tiret` de `separateurs.ts` : espace sécable avant, insécable après).

→ `CoproFirst/Fonctions/Residence/Genere/TablesReglement.swift`.
"""

from __future__ import annotations

import re

from generateurs._commun import FONCTIONS, chaine, ecrire_table

SOURCES = [
    "front/src/lib/components/BadgeVerdict.svelte",
    "front/src/lib/separateurs.ts",
]


def _badges(texte: str) -> tuple[dict[str, str], str]:
    """Les tons nommés (`class:badge-x={ton === 'y'}`), et la classe de tout autre ton."""
    tons = {ton: f"badge-{teinte}" for teinte, ton in re.findall(r"class:badge-([\w-]+)=\{ton === '(\w+)'\}", texte)}
    autres = re.findall(r"class:badge-([\w-]+)=\{ton !== ", texte)
    if not tons or len(autres) != 1:
        raise SystemExit("❌ les teintes du verdict sont illisibles dans BadgeVerdict.svelte — l'app doit l'apprendre")
    return tons, f"badge-{autres[0]}"


def _litteral(js: str) -> str:
    """Une chaîne JavaScript en littéral Swift : un `\\u00a0` y reste lisible, `\\u{00A0}`."""
    texte = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), js)
    swift = chaine(texte)
    return "".join(c if c.isascii() or c.isalnum() or c in "—«»" else f"\\u{{{ord(c):04X}}}" for c in swift)


def _tiret(texte: str) -> str:
    m = re.search(r"\btiret: '([^']*)'", texte)
    if not m:
        raise SystemExit("❌ SEPARATEUR.tiret introuvable dans separateurs.ts — l'app doit l'apprendre")
    return _litteral(m.group(1))


def generer(ctx) -> str:
    tons, inconnu = _badges(ctx.lire(SOURCES[0]))
    tiret = _tiret(ctx.lire(SOURCES[1]))
    corps = (
        "    /// La classe de la capsule du verdict, pour chaque ton servi (`BadgeVerdict.svelte`).\n"
        "    static let badgesDuVerdict: [String: String] = [\n"
        + "".join(f"        {chaine(t)}: {chaine(b)},\n" for t, b in tons.items())
        + "    ]\n"
        "    /// Un ton absent ou inconnu : le site le lit incertain.\n"
        f"    static let badgeDuVerdictInconnu = {chaine(inconnu)}\n"
        "    /// Ce qui joint l'acte, la rubrique et la page d'un extrait (`SEPARATEUR.tiret`).\n"
        f"    static let tiret = {tiret}\n"
    )
    ecrire_table(ctx, FONCTIONS / "Residence" / "Genere" / "TablesReglement.swift",
                 "front/src/lib/components/BadgeVerdict.svelte, lib/separateurs.ts", "TablesReglement",
                 "Ce que le site écrit de l'avis sur le règlement et que le contrat ne sert pas.", corps)
    return f"{len(tons)} tons du verdict ; séparateur des repères"
