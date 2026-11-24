#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un numéro de téléphone écrit dans ce dépôt PUBLIC se prend dans la tranche fixe réservée
à la fiction, 01 99 00 xx xx (#359).

Les jeux simulés, les tests et les exemples de saisie le disaient (« des numéros de la plage
réservée à la fiction ») ; six numéros en sortaient — des mobiles en 06 99 00, des fixes en
01 00 00, un exemple en 01 23 45 —, et la tranche 06 99 est attribuée à un opérateur : un
numéro qui en sort peut être celui d'un abonné, qu'un test d'appel ou une capture publierait.
Seule la tranche fixe est permise : c'est la seule que le dépôt nomme, et la seule vérifiée.

Repéré, dans le code et les tests des quatre cibles (`portee`) : un numéro français écrit
par paires séparées d'une espace ou d'un point (« 01 99 00 12 34 », « +33 1 99 00 00 00 »).
Ce qu'il ne voit pas : un numéro écrit d'un bloc (« 0199001234 ») ou découpé autrement, et ce
qui est public sans être un fichier — messages de commit, tickets, PR.

Sortie : 0 conforme, 1 refus, 2 INCONNU (moins de `PLANCHER` numéros repérés : une forme ou
une portée a cassé). `--autotest` prouve qu'il refuse et laisse passer.
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

#: Un numéro français par paires : national (0X) ou international (+33 X).
NUMERO = re.compile(r"(?<![\d+])(?:0[1-9]|\+33 ?[1-9])(?:[ .]\d{2}){4}(?!\d)")
#: La tranche fixe réservée aux œuvres de fiction.
FICTIF = re.compile(r"^(?:01|\+33 ?1)[ .]99[ .]00[ .]")
#: En deçà, la forme ou la portée a cassé : INCONNU, jamais conforme.
PLANCHER = 5


def numeros(texte: str) -> list[tuple[int, str]]:
    return [(texte.count("\n", 0, m.start()) + 1, m.group()) for m in NUMERO.finditer(texte)]


def juger(racine: pathlib.Path) -> tuple[int, list[str]]:
    vus, refus = 0, []
    for f in portee.fichiers(racine, portee.CODE + portee.TESTS):
        chemin = f.relative_to(racine).as_posix()
        for ligne, numero in numeros(f.read_text(encoding="utf-8")):
            vus += 1
            if not FICTIF.match(numero):
                refus.append(f"{chemin}:{ligne} : « {numero} » hors de la tranche fictive")
    return vus, refus


def autotest() -> bool:
    cas = {
        '"01 99 00 12 34"': [],
        '"+33 1 99 00 00 00"': [],
        '"01.99.00.00.05"': [],
        '"06 99 00 12 34"': ["06 99 00 12 34"],
        '"01 00 00 00 01, 06 00 00 00 02"': ["01 00 00 00 01", "06 00 00 00 02"],
        '"ex. 01 23 45 67 89"': ["01 23 45 67 89"],
        'Text("+33 6 00 00 00 00")': ["+33 6 00 00 00 00"],
        '"/uploads/tickets/0123456789abcdef_Devis.pdf"': [],
        "let n = 2026_11_24": [],
    }
    ok = all([n for n in (x for _, x in numeros(texte)) if not FICTIF.match(n)] == attendu
             for texte, attendu in cas.items())
    with tempfile.TemporaryDirectory() as d:
        racine = pathlib.Path(d)
        (racine / "CoproFirstTests").mkdir()
        (racine / "CoproFirstTests" / "T.swift").write_text('let t = "06 99 00 00 02"\n', encoding="utf-8")
        vus, refus = juger(racine)
        ok = ok and vus == 1 and len(refus) == 1
    return ok


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        if autotest():
            print("✅ autotest des numéros fictifs")
            return 0
        print("❌ autotest des numéros fictifs en échec")
        return 1
    vus, refus = juger(RACINE)
    if vus < PLANCHER:
        print(f"❓ {vus} numéros repérés (moins de {PLANCHER}) : numéros fictifs INCONNUS")
        return 2
    for ligne in refus:
        print(f"❌ {ligne} → 01 99 00 xx xx")
    if refus:
        return 1
    print(f"✅ numéros dans la tranche fictive 01 99 00 ({vus} repérés)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
