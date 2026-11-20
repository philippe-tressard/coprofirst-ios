#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un GESTE refusé dit la phrase du serveur (#41, #262) : chaque écriture du client
généré (`post…`, `put…`, `patch…`, `delete…`) lit sa réponse non documentée par
`refus(…)` — `ServiceAPI.refus` → `ErreurService.depuisRefus`, qui rend le `detail` tel
quel. Une installation suspendue (403) ou en mode limité (409) explique elle-même quoi
faire ; une écriture lue comme une lecture (`depuisLecture`) le remplacerait par
« Cet élément n'est plus disponible ».

Les exceptions sont NOMMÉES, chacune avec sa raison (`EXCEPTIONS`), et le contrôle échoue
si l'une cesse de servir (l'appel a disparu, ou lit désormais le refus).

    python3 scripts/verifier-refus.py             # le dépôt
    python3 scripts/verifier-refus.py --autotest  # le contrôle refuse bien le cas fautif
"""

from __future__ import annotations

import pathlib
import re
import sys
import tempfile

RACINE = pathlib.Path(__file__).resolve().parent.parent
#: Un appel d'écriture du client généré : `.postAdminComptes…(`, `.deleteIdees…(`.
ECRITURE = re.compile(r"\.((?:post|put|patch|delete)[A-Z]\w*)\(")
#: La lecture du refus : la porte commune, ou l'échec d'écriture qui y mène (Communauté).
LIT_LE_REFUS = re.compile(r"\brefus\(|\.echec\)")

#: Les écritures qui ne montrent pas la phrase d'un refus — et pourquoi (11/2026, #262).
EXCEPTIONS: dict[str, str] = {
    "postAuthLogin": "la connexion : un refus y dit des identifiants refusés (`ErreurService.depuis(statut:)`)",
    "postAuthLogout": "la déconnexion : un refus n'empêche pas de quitter, rien ne se dit",
    "postAuthRefresh": "le renouvellement : un refus est une session expirée (`Renouvellement`)",
    "postTelemetryCollect": "la mesure d'audience : un échec ne se dit ni ne se rejoue (`MesureAudience`)",
    "postLecturesApercu": "un calcul servi en POST, une LECTURE (`depuisLecture`) — ouvert en suspension",
    "postPerimetresLibelle": "un calcul servi en POST, une LECTURE (`depuisLecture`) — ouvert en suspension",
    "postNomsAffiche": "l'aperçu d'une saisie servi en POST, une LECTURE (`depuisLecture`)",
}


def fonctions(texte: str):
    """Chaque `func` et son corps : de sa ligne à l'accolade fermante de même retrait."""
    lignes = texte.split("\n")
    for debut, ligne in enumerate(lignes):
        m = re.match(r"^(\s*)(?:[\w@]+\s+)*func\s", ligne)
        if not m:
            continue
        fin = next((i for i in range(debut + 1, len(lignes)) if lignes[i] == m.group(1) + "}"), len(lignes))
        yield debut + 1, "\n".join(lignes[debut:fin + 1])


def ecarts(racine: pathlib.Path, exceptions: dict[str, str]) -> list[str]:
    trouves: list[str] = []
    servies: set[str] = set()
    fichiers = sorted((racine / "CoproFirst").rglob("*.swift"))
    if not fichiers:
        return ["aucun fichier Swift sous CoproFirst/ : rien n'a été mesuré (INCONNU)"]
    for fichier in fichiers:
        relatif = fichier.relative_to(racine)
        for ligne, corps in fonctions(fichier.read_text(encoding="utf-8")):
            appels = set(ECRITURE.findall(corps))
            if not appels:
                continue
            lit = bool(LIT_LE_REFUS.search(corps))
            for appel in sorted(appels):
                if appel in exceptions:
                    servies.add(appel)
                    if lit:
                        trouves.append(f"{relatif}:{ligne} : {appel} lit désormais le refus — retirer son exception")
                elif not lit:
                    trouves.append(f"{relatif}:{ligne} : {appel} ne lit pas le refus du serveur — "
                                   "`throw await Self.refus(statut, reponse)`")
    for appel in sorted(set(exceptions) - servies):
        trouves.append(f"exception {appel} : plus aucun appel — la retirer de EXCEPTIONS")
    return trouves


def autotest() -> int:
    fautif = """extension ServiceAPI {
    func geste() async throws {
        let sortie = try await client.postAdminChose(body: .json(corps))
        switch sortie {
        case .undocumented(let statut, _): throw ErreurService.depuisLecture(statut)
        }
    }
}
"""
    propre = fautif.replace("throw ErreurService.depuisLecture(statut)", "throw await Self.refus(statut, reponse)")
    with tempfile.TemporaryDirectory() as dossier:
        racine = pathlib.Path(dossier)
        (racine / "CoproFirst").mkdir()
        source = racine / "CoproFirst" / "Geste.swift"
        source.write_text(fautif, encoding="utf-8")
        if not any("postAdminChose ne lit pas" in e for e in ecarts(racine, {})):
            print("❌ autotest : une écriture lue comme une lecture passe")
            return 1
        source.write_text(propre, encoding="utf-8")
        if ecarts(racine, {}):
            print("❌ autotest : une écriture qui lit le refus est refusée")
            return 1
        if not any("lit désormais le refus" in e for e in ecarts(racine, {"postAdminChose": "x"})):
            print("❌ autotest : une exception qui ne sert plus passe")
            return 1
        if not any("plus aucun appel" in e for e in ecarts(racine, {"postAilleurs": "x"})):
            print("❌ autotest : une exception sans appel passe")
            return 1
    print("✅ verifier-refus.py : autotest")
    return 0


def main() -> int:
    if "--autotest" in sys.argv:
        return autotest()
    trouves = ecarts(RACINE, EXCEPTIONS)
    if trouves:
        print("❌ un geste refusé doit dire la phrase du serveur (#41, #262) :")
        print("\n".join(f"   {e}" for e in trouves))
        return 1
    print(f"✅ chaque écriture lit le refus du serveur ({len(EXCEPTIONS)} exceptions déclarées)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
