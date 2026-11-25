#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Aucun nom de personne réelle dans ce dépôt PUBLIC : une liste BLANCHE de noms inventés (#352).

Socle `standards/14` §9 : un nom tiré d'un écran, d'un import ou d'un courriel et collé dans
un test est une donnée personnelle publiée, que l'historique git garde. Liste blanche, jamais
noire : écrire les vrais noms dans le contrôle les republierait. Même forme que le contrôle
du serveur (`api/tests/test_identites_fictives.py` de coprofirst), dont les personnages se
reprennent (« Jean-Baptiste FORT », « Alix DURAND ») ; l'app a aussi les siens (« Camille
Exemple », « Dominique EXEMPLE »).

Tout nom repéré figure dans `FICTIFS` — l'y ajouter, c'est AFFIRMER qu'il est inventé ; un
mot repéré qui n'est pas un nom va dans `PAS_DES_NOMS`. Une entrée qui ne sert plus échoue,
et moins de `PLANCHER` noms repérés rend INCONNU (une forme ou une portée a cassé).

Formes repérées, dans le code et les tests des quatre cibles (`portee`) :
  - une civilité suivie d'un nom (« Mme DUPONT », « Madame Hélène Dupont », « M. de LeRoy ») ;
  - « Prénom NOM » ou « NOM Prénom » en chaîne entière, ou après « « » ; un prénom composé
    suivi d'un nom à casse mixte (« Jean-Hervé ForT ») ;
  - dans les DONNÉES (tests, `Fixtures*`, simulation) : la valeur d'un champ de personne
    (`prenom`, `nom_affiche`, `auteur_nom`…), et celle de `nom` sur une ligne qui porte aussi
    un `prenom` — seul, `nom` nomme aussi un onglet, une résidence, une pièce jointe.

Ce qu'il ne voit pas : un nom isolé hors de ces formes, une raison sociale bâtie sur un
patronyme (« Toitures Dupont »), un nom dans un identifiant, les documents (`*.md`) et ce qui
est public sans être un fichier — messages de commit, tickets, PR.

Sortie : 0 conforme, 1 refus, 2 INCONNU. `--autotest` ; `--inventaire` liste les noms repérés.
"""

from __future__ import annotations

import collections
import pathlib
import re
import sys
import unicodedata

RACINE = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

#: Les noms inventés. En ajouter un, c'est affirmer qu'il ne désigne personne.
#: Des mots ordinaires servent de patronymes inventés (« Elsa Gestion », « Alex Témoin ») :
#: dans ces jeux, ils nomment une personne, ils sont donc ici.
FICTIFS = frozenset("""
    ALEX ALIX BASILE CAMILLE CELESTE CLAUDE DEMO DESIREE DOMINIQUE DURAND ELSA ESSAI EUDES EXEMPLE
    FICHE FICTIF FORT GESTION INVENTE JEAN-BAPTISTE LUCIE MARC MARIE MODELE MORGAN NOUVELLE PAUL
    PLATEFORME SACHA TEMOIN
""".split())
#: Les mots que les formes attrapent sans qu'ils nomment quelqu'un : rôles, lieux, libellés.
PAS_DES_NOMS = frozenset("""
    BAT BATIMENT CONSEIL EDF NOM PARKING PRENOM RESIDENT RESIDENTE SYNDIC SYNDICAL VOISIN
""".split())
#: Noms repérés sur l'arbre du 23/11/2026 : 374 occurrences. Sous ce plancher, une forme ou
#: une portée a cassé, et le contrôle serait vert sur rien.
PLANCHER = 200

_MAJ = "A-ZÀÂÄÇÉÈÊËÎÏÔÖÙÛÜ"
_MIN = "a-zàâäçéèêëîïôöùûü"
_PRENOM = rf"[{_MAJ}][{_MIN}]+(?:-[{_MAJ}][{_MIN}]+)?"
_NOM = rf"[{_MAJ}][{_MAJ}'-]+[{_MAJ}]"
_PRENOM_COMPOSE = rf"[{_MAJ}][{_MIN}]+-[{_MAJ}][{_MIN}]+"
_PERSONNE = (rf"(?:{_PRENOM}\s+{_NOM})|(?:{_NOM}\s+{_PRENOM})"
             rf"|(?:{_PRENOM_COMPOSE}\s+[{_MAJ}][{_MAJ}{_MIN}'-]+)")
CIVILITE = re.compile(
    rf"\b(?:M\.|Mme|Madame|Monsieur)\s+(?:({_PRENOM})\s+)?(?:(?:de|du)\s+|d')?"
    rf"([{_MAJ}][{_MAJ}{_MIN}'-]*[{_MAJ}{_MIN}])")
LITTERAL = re.compile(rf"\"({_PERSONNE})\"")
GUILLEMETS = re.compile(rf"«\s*({_PERSONNE})")
_VALEUR = r"\"?\s*:\s*\"([^\"\\{}\n]+)\""
CHAMP = re.compile(r"\"?\b(?:prenom|nom_affiche|nom_aide_affiche|nom_complet|auteur_nom|porteur_nom|aidant_nom"
                   r"|nomAffiche|auteurNom|porteurNom|aidantNom)" + _VALEUR)
CHAMP_NOM = re.compile(r"\"?\bnom" + _VALEUR)
_MOT = re.compile(rf"[{_MAJ}{_MIN}][{_MAJ}{_MIN}'-]{{2,}}")


def normaliser(mot: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", mot) if unicodedata.category(c) != "Mn").upper()


def donnees(chemin: str) -> bool:
    """Un jeu de données : les tests, les réponses simulées, la simulation."""
    nom = chemin.rsplit("/", 1)[-1]
    return any(portee.sous(chemin, d) for d in portee.TESTS) or nom.startswith("Fixtures") or "Simul" in nom


def noms_dans(texte: str, *, jeu: bool) -> list[str]:
    sources = [(CIVILITE, texte), (LITTERAL, texte), (GUILLEMETS, texte)]
    if jeu:
        avec_prenom = "\n".join(ligne for ligne in texte.splitlines() if "prenom" in ligne)
        sources += [(CHAMP, texte), (CHAMP_NOM, avec_prenom)]
    return [normaliser(mot) for motif, source in sources for trouve in motif.finditer(source)
            for groupe in trouve.groups() if groupe for mot in _MOT.findall(groupe)]


def releve(racine: pathlib.Path) -> tuple[dict[str, set[str]], int]:
    vus: dict[str, set[str]] = collections.defaultdict(set)
    total = 0
    for f in portee.fichiers(racine, portee.CODE + portee.TESTS):
        chemin = f.relative_to(racine).as_posix()
        for nom in noms_dans(f.read_text(encoding="utf-8"), jeu=donnees(chemin)):
            vus[nom].add(chemin)
            total += 1
    return vus, total


def refus(vus: dict[str, set[str]], total: int) -> tuple[int, list[str]]:
    if total < PLANCHER:
        return 2, [f"❓ INCONNU : {total} nom(s) repéré(s), plancher {PLANCHER} — une forme ou une portée a cassé"]
    fautes = [f"❌ {n} — {', '.join(sorted(vus[n]))} : nom non déclaré fictif. Un nom tiré d'un écran ou d'un "
              "courriel se remplace par un nom inventé ; un nom inventé s'ajoute à FICTIFS, un mot qui n'est "
              "pas un nom à PAS_DES_NOMS" for n in sorted(set(vus) - FICTIFS - PAS_DES_NOMS)]
    fautes += [f"❌ {n} : déclaré sans plus servir — le retirer" for n in sorted((FICTIFS | PAS_DES_NOMS) - set(vus))]
    fautes += [f"❌ {n} : à la fois un nom et pas un nom" for n in sorted(FICTIFS & PAS_DES_NOMS)]
    return (1, fautes) if fautes else (0, [f"✅ {total} noms repérés, tous inventés et déclarés ({len(FICTIFS)})"])


def autotest() -> bool:
    cas = [
        (noms_dans('"prenom": "Zorglub", "nom": "ZORGLUB"', jeu=True), ["ZORGLUB", "ZORGLUB"]),
        (noms_dans('"prenom": "Zorglub"', jeu=False), []),                       # une donnée hors jeu
        (noms_dans('Onglet(nom: "Zorglub")', jeu=True), []),                     # `nom` sans prénom
        (noms_dans("« Remplace Mme ZORGLUB »", jeu=False), ["ZORGLUB"]),
        (noms_dans("Madame Hélène Zorglub,", jeu=False), ["HELENE", "ZORGLUB"]),
        (noms_dans('let a = "Hélène ZORGLUB"', jeu=False), ["HELENE", "ZORGLUB"]),
        (noms_dans('let a = "ZORGLUB Hélène"', jeu=False), ["ZORGLUB", "HELENE"]),
        (noms_dans("« Jean-Hervé ZorgluB », signalé", jeu=False), ["JEAN-HERVE", "ZORGLUB"]),
        (noms_dans('nomAffiche: "Zoé Zorglub"', jeu=True), ["ZOE", "ZORGLUB"]),
        (noms_dans('let t = "Les Tilleuls"', jeu=False), []),
    ]
    ok = all(trouve == attendu for trouve, attendu in cas)
    vus = {n: {"T.swift"} for n in FICTIFS | PAS_DES_NOMS}
    ok = ok and refus(vus, PLANCHER)[0] == 0
    ok = ok and refus({**vus, "ZORGLUB": {"T.swift"}}, PLANCHER)[0] == 1            # un nom hors liste
    ok = ok and refus({n: v for n, v in vus.items() if n != "EXEMPLE"}, PLANCHER)[0] == 1  # entrée morte
    ok = ok and refus(vus, PLANCHER - 1)[0] == 2
    ok = ok and donnees("CoproFirstTests/A.swift") and donnees("CoproFirst/M/FixturesM.swift")
    return ok and not donnees("CoproFirst/M/Vue.swift")


def main() -> int:
    if sys.argv[1:] == ["--autotest"]:
        ok = autotest()
        print("✅ autotest des identités fictives" if ok else "❌ autotest des identités fictives en échec")
        return 0 if ok else 1
    vus, total = releve(RACINE)
    if sys.argv[1:] == ["--inventaire"]:
        for nom in sorted(vus):
            print(f"{nom} : {', '.join(sorted(vus[nom]))}")
        return 0
    code, messages = refus(vus, total)
    print("\n".join(messages))
    return code


if __name__ == "__main__":
    sys.exit(main())
