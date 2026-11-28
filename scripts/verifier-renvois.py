#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Un renvoi écrit dans la documentation désigne ce qui existe encore (#368, suite de #349, #358, #361).

La montée du plancher (#313) n'a touché ni le README ni les skills : `VersionContrat.moderation`,
`PrestatairesServis`, « #18 … en attente » sont restés vrais au texte et faux au code. Ce juge lit
le README, `CLAUDE.md`, `.claude/skills/**/*.md` et `Parite/PARITE.md`, et refuse :

  1. un identifiant entre accents graves — `Type`, `Type.membre`, `fonction(` — que le code ne
     porte plus (le client généré compris, lu dans `openapi.json`), et un `Fichier.ext` qu'aucun
     fichier suivi ne porte ; un composant du site (`*.svelte`) et le projet généré
     (`*.xcodeproj`) sont hors de sa vue ; un renvoi qui nomme exprès autre chose (un exemple
     interdit, un module tiers) se déclare dans `EXCEPTIONS`, qui échoue quand il ne sert plus ;
  2. un renvoi « README, « Titre » » dont aucun titre du README ne porte ce texte ;
  3. (`--distant`) un « #N » qu'une phrase dit « en attente », « à arrêter » ou « attend … »,
     alors que le ticket est CLOS ;
  4. (`--distant`) dans `PARITE.md`, un « non porté » ou un « reste au site » dont la raison est un
     ticket du serveur clos (piste de #361).

Les deux derniers lisent GitHub (`gh`) : sans réseau, INCONNU, jamais vert —
`scripts/controles-distants.sh` les joue sous sa borne. Sortie : 0, 1 refus, 2 INCONNU.
`--autotest` prouve chaque refus dans les deux sens.
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
DEPOT = "philippe-tressard/coprofirst-ios"
#: (document, identifiant) → raison. Un renvoi déclaré qui ne sert plus échoue.
EXCEPTIONS = {
    (".claude/skills/ux-patterns-ios/SKILL.md", "ARBITRAGES.md"): "le registre des arbitrages de coprofirst, pas de ce dépôt",
    (".claude/skills/ux-patterns-ios/SKILL.md", "FormulaireTicket"): "un composant du site (coprofirst), son modèle",
    (".claude/skills/ux-patterns-ios/SKILL.md", "SectionDestinataires.svelte"): "un composant du site (coprofirst)",
    (".claude/skills/ux-patterns-ios/SKILL.md", "ExtraitRecherche"): "un composant du site (coprofirst)",
    (".claude/skills/ux-patterns-ios/SKILL.md", "BadgePerimetre"): "un composant du site (coprofirst)",
    (".claude/skills/ux-patterns-ios/SKILL.md", "FormulaireNotation"): "un composant du site (coprofirst)",
    (".claude/skills/ux-patterns-ios/SKILL.md", "SUPPRESSION"): "une constante du site (coprofirst)",
    (".claude/skills/swiftui-patterns/SKILL.md", "FileResponse"): "le type de réponse du serveur (FastAPI, coprofirst)",
    (".claude/skills/publication-app-store/confidentialite.md", "DequeModule"): "un module de swift-collections, paquet tiers",
    (".claude/skills/swiftui-patterns/SKILL.md", "Color.red"): "l'exemple de ce que verifier-depot.sh refuse",
    ("CLAUDE.md", "multi-coproprietes.md"): "une spécification de coprofirst (specs/), pas de ce dépôt",
    ("CLAUDE.md", "verrou_poste.py"): "l'outil du poste, ~/.claude/bin (claude-config)",
    (".claude/skills/publication-app-store/confidentialite.md", "contenu.json"): "le fichier servi par coprofirst.fr",
    (".claude/skills/publication-app-store/SKILL.md", "SORTIES"): "la liste des versions sorties du contrat en circulation, dans coprofirst (api/app/contrat/circulation.py)",
}
#: Un fichier nommé par son extension : jugé à son nom, ou hors de vue (le site, le projet généré).
FICHIER = re.compile(r"[\w+-]+\.(swift|md|py|sh|json|yml|yaml|plist|xcprivacy|svelte|xcodeproj|ts|txt|toml|env)")
HORS_DE_VUE = ("svelte", "xcodeproj", "ts")
CODE = (".swift", ".py", ".sh", ".yml", ".yaml", ".toml", ".env", ".xcprivacy", ".plist", ".entitlements")
IDENT = re.compile(r"([A-Z][A-Za-z0-9]+)(?:\.([a-z][A-Za-z0-9]*))?(?:\()?|()([a-z][A-Za-z0-9]+)\(")
TICK = re.compile(r"`([^`\n]+)`")
RENVOI_README = re.compile(r"README, « ([^»]+?) »")
ATTENTE = re.compile(r"(en attente|à arrêter|attend (?:sa|la|le|les|l'))[^.\n]{0,60}?\(?((?:[\w-]+)?#\d+)")
PARITE_NON = re.compile(r"(non porté|reste au site|site seulement)[^|\n]{0,80}?\(?((?:coprofirst)#\d+)")


def documents(racine: pathlib.Path) -> dict[str, str]:
    noms = ["README.md", "CLAUDE.md", "Parite/PARITE.md", *sorted(
        p.relative_to(racine).as_posix() for p in (racine / ".claude" / "skills").rglob("*.md"))]
    return {n: (racine / n).read_text(encoding="utf-8") for n in noms if (racine / n).is_file()}


def corpus(racine: pathlib.Path) -> tuple[set[str], str, dict[str, str]]:
    sortie = subprocess.run(["git", "ls-files"], cwd=racine, capture_output=True, text=True)
    suivis = sortie.stdout.split() if sortie.returncode == 0 else []
    textes = {f: (racine / f).read_text(encoding="utf-8", errors="replace") for f in suivis
              if f.endswith(CODE) and (racine / f).is_file()}
    # Les mots du CODE, commentaires ôtés : un type disparu survit dans les commentaires qui le
    # racontent (`PrestatairesServis`, #368).
    sans_commentaires = [re.sub(r"(^|\s)(//|#).*$", "", ligne) for t in textes.values() for ligne in t.splitlines()]
    mots = {m for ligne in sans_commentaires for m in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", ligne)}
    mots |= {pathlib.PurePath(f).name for f in suivis} | {pathlib.PurePath(f).stem for f in suivis}
    contrat = racine / "Paquets" / "ClientAPI" / "Sources" / "ClientAPI" / "openapi.json"
    if contrat.is_file():   # le client GÉNÉRÉ : `post_tickets_ticket_id_messages` → `postTicketsTicketIdMessages`
        for op in re.findall(r'"operationId":\s*"([^"]+)"', contrat.read_text(encoding="utf-8")):
            tete, *reste = op.split("_")
            mots.add(tete + "".join(m[:1].upper() + m[1:] for m in reste))
    return mots, " ".join(mots), textes


def existe(nom: str, mots: set[str], tous: str) -> bool:
    return nom in mots or nom in tous   # `UserID` vit dans `NSPrivacyCollectedDataTypeUserID`


def refus_locaux(docs: dict[str, str], mots: set[str], tous: str, textes: dict[str, str]) -> list[str]:
    fautes, servies = [], set()
    titres = [l.lstrip("#").strip() for l in docs.get("README.md", "").splitlines() if l.startswith("#")]
    for nom, texte in docs.items():
        for numero, ligne in enumerate(texte.splitlines(), 1):
            for brut in TICK.findall(ligne):
                jeton = brut.strip()
                if (nom, jeton) in EXCEPTIONS:
                    servies.add((nom, jeton))
                    continue
                fichier = FICHIER.fullmatch(jeton)
                if fichier:
                    if fichier.group(1) not in HORS_DE_VUE and jeton not in mots:
                        fautes.append(f"{nom}:{numero} : `{jeton}` — aucun fichier suivi de ce nom")
                    continue
                m = IDENT.fullmatch(jeton)
                if not m:
                    continue
                type_, membre = m.group(1) or "", m.group(2) or m.group(4) or ""
                if type_ and not existe(type_, mots, tous) and jeton not in mots:
                    fautes.append(f"{nom}:{numero} : `{jeton}` — `{type_}` n'existe plus dans le code")
                elif type_ and membre and f"{type_}.{membre}" not in tous and not any(
                        type_ in t and re.search(rf"\b(?:let|var|case|func)\s+{membre}\b", t) for t in textes.values()):
                    fautes.append(f"{nom}:{numero} : `{jeton}` — `{type_}` n'a plus de membre `{membre}`")
                elif not type_ and membre not in mots and not re.search(
                        rf"\b(?:func|def)\s+{membre}\b", " ".join(textes.values())):
                    fautes.append(f"{nom}:{numero} : `{jeton}` — aucune fonction `{membre}` dans le code")
            for titre in RENVOI_README.findall(ligne):
                if not any(titre in t for t in titres):
                    fautes.append(f"{nom}:{numero} : « README, « {titre} » » — aucun titre du README ne le porte")
    fautes += [f"exception {n} `{j}` sans emploi — la retirer" for n, j in sorted(set(EXCEPTIONS) - servies)
               if n in docs]
    return fautes


def depot_de(renvoi: str) -> tuple[str, str]:
    prefixe, numero = renvoi.split("#")
    return (f"philippe-tressard/{prefixe}" if prefixe else DEPOT), numero


def refus_distants(docs: dict[str, str], etat) -> tuple[list[str], list[str]]:
    """`etat(depot, numero)` → "OPEN" | "CLOSED" | None (illisible). Rend (refus, inconnus)."""
    fautes, inconnus = [], []
    for nom, texte in docs.items():
        for numero, ligne in enumerate(texte.splitlines(), 1):
            trouves = [(m.group(1), m.group(2)) for m in ATTENTE.finditer(ligne)]
            if nom == "Parite/PARITE.md":
                trouves += [(m.group(1), m.group(2)) for m in PARITE_NON.finditer(ligne)]
            for motif, renvoi in trouves:
                lu = etat(*depot_de(renvoi))
                if lu is None:
                    inconnus.append(f"{nom}:{numero} : {renvoi} illisible")
                elif lu == "CLOSED":
                    fautes.append(f"{nom}:{numero} : « {motif} » cite {renvoi}, CLOS — dire ce qui est vrai")
    return fautes, inconnus


def etat_gh(depot: str, numero: str, cache: dict = {}) -> str | None:  # noqa: B006 (cache voulu)
    cle = (depot, numero)
    if cle not in cache:
        sortie = subprocess.run(["gh", "issue", "view", numero, "-R", depot, "--json", "state"],
                                capture_output=True, text=True, timeout=30)
        cache[cle] = json.loads(sortie.stdout).get("state") if sortie.returncode == 0 else None
    return cache[cle]


def autotest() -> bool:
    mots = {"VersionContrat", "plancher", "Liste", "ouvrir", "Fichier.swift", "Fichier"}
    tous = " ".join(mots) + " NSPrivacyCollectedDataTypeUserID"
    textes = {"a.swift": "enum VersionContrat { static let plancher = 1 }\nfunc ouvrir() {}"}
    def refuse(ligne: str, docs_sup: dict | None = None) -> bool:
        docs = {"README.md": "# Construire\n", "Parite/PARITE.md": ligne, **(docs_sup or {})}
        return bool(refus_locaux(docs, mots, tous, textes))
    ok = refuse("voir `PrestatairesServis`") and refuse("la porte `VersionContrat.moderation`")
    ok &= refuse("appeler `fermer(`") and refuse("voir README, « Outillage »")
    ok &= not refuse("voir `VersionContrat.plancher`, `ouvrir(`, `UserID`, `Fichier.swift`, README, « Construire »")
    ok &= not refuse("une `chaîne` et `deux mots`, `Nav.svelte`, `CoproFirst.xcodeproj`")
    ok &= refuse("voir `Disparu.swift`")
    ok &= refuse("", {".claude/skills/ux-patterns-ios/SKILL.md": "rien"})        # exception sans emploi
    etats = {(DEPOT, "18"): "CLOSED", (DEPOT, "263"): "OPEN", ("philippe-tressard/coprofirst", "2506"): "CLOSED"}
    lire = lambda d, n: etats.get((d, n))  # noqa: E731
    f, i = refus_distants({"README.md": "liste des domaines en attente de décision (#18)."}, lire)
    ok &= len(f) == 1 and not i
    f, i = refus_distants({"README.md": "coupée et attend sa soumission (#263)."}, lire)
    ok &= not f and not i
    f, i = refus_distants({"Parite/PARITE.md": "| faq | — | non porté (coprofirst#2506) |"}, lire)
    ok &= len(f) == 1
    f, i = refus_distants({"README.md": "en attente (#999)"}, lire)
    return ok and not f and len(i) == 1


def main() -> int:
    args = sys.argv[1:]
    if args == ["--autotest"]:
        ok = autotest()
        print("✅ autotest des renvois de la documentation" if ok else "❌ autotest des renvois en échec")
        return 0 if ok else 1
    docs = documents(RACINE)
    if not docs:
        print("❓ INCONNU : aucun document lu")
        return 2
    if args == ["--distant"]:
        try:
            fautes, inconnus = refus_distants(docs, etat_gh)
        except (OSError, subprocess.SubprocessError, ValueError) as erreur:
            print(f"❓ INCONNU : GitHub illisible ({erreur})")
            return 2
        for ligne in fautes:
            print(f"❌ {ligne}")
        for ligne in inconnus:
            print(f"❓ {ligne}")
        if fautes:
            return 1
        if inconnus:
            return 2
        print("✅ renvois aux tickets à jour")
        return 0
    mots, tous, textes = corpus(RACINE)
    if not mots:
        print("❓ INCONNU : git ne rend aucun fichier de code")
        return 2
    fautes = refus_locaux(docs, mots, tous, textes)
    for ligne in fautes:
        print(f"❌ {ligne}")
    if fautes:
        return 1
    print(f"✅ renvois de la documentation : {len(docs)} documents, identifiants et titres existants")
    return 0


if __name__ == "__main__":
    sys.exit(main())
