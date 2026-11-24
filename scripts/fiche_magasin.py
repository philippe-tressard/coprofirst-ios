# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La fiche de l'App Store ne promet que ce que l'app fait (#343).

Deux promesses avaient survécu au code :

- « avec photos et documents » : l'app les MONTRE, elle ne les joint pas — elle le dit
  elle-même, « Les photos et les documents s'ajoutent depuis le site. » Ce que l'app dit
  s'ajouter au site ne se nomme, dans la description, qu'au fil d'un verbe de lecture
  (« consultez ses photos »). Même règle que la fiche Play (coprofirst-android#318,
  `scripts/test_fiche_play.py`) ;
- la notification générique et l'avis urgent, décrits dans la description et les notes de
  revue alors que l'app tient le relais éteint (`RelaisPush.courant`, #283). Éteint : les
  deux textes disent qu'aucune notification ne part, et ne décrivent ni offre ni charge ;
  allumé : ils ne le disent plus.

Appelé par `verifier-confidentialite.py`, qui lit déjà la fiche. Un texte illisible, ou
des libellés que le contrôle ne retrouve plus : une faute (INCONNU), jamais un vert.
`--autotest` prouve chaque refus, et qu'une fiche juste passe.
"""

from __future__ import annotations

import re
import sys

NOTES = ".claude/skills/publication-app-store/notes-revue.md"
RELAIS = "CoproFirst/Fonctions/Notifications/Push/RelaisPush.swift"
DESCRIPTION = re.compile(r"<!-- description -->(.*?)<!-- /description -->", re.S)

#: « Les photos et les documents s'ajoutent depuis le site. » → {photos, documents}
AJOUT_AU_SITE = re.compile(r"\b(?:Les?|La|L')\s*(\w+)(?: et (?:les?|la|l')\s*(\w+))? s'ajoutent?\b[^\"\n]*\bsite\b")
LECTURE = re.compile(r"\b(consultez|voyez|retrouvez|lisez|regardez|ouvrez)\b", re.I)
ATTENDUS = {"photos", "documents"}  # ce que l'app dit aujourd'hui ; plus lu = le contrôle ne voit plus rien

ALLUME = re.compile(r"static let courant = RelaisPush\(allume: (true|false)\b")
#: Ce qu'un texte dit d'un relais ALLUMÉ (offre, charge, niveau urgent)…
OFFRE = {
    "description": re.compile(r"nouvelle notification\.|mode Concentration|signalé comme urgent", re.I),
    "notes de revue": re.compile(r"requested after the user|notification carries|use the time-sensitive level", re.I),
}
#: … et ce qu'il dit d'un relais ÉTEINT.
AUCUNE = {
    "description": re.compile(r"n'en envoie aucune", re.I),
    "notes de revue": re.compile(r"sends no push notification", re.I),
}


def ajouts_au_site(code: dict[str, str]) -> set[str]:
    """Les noms que l'app dit s'ajouter au site (photos, documents…)."""
    return {n.lower() for texte in code.values() for m in AJOUT_AU_SITE.finditer(texte) for n in m.groups() if n}


def promesses(description: str, noms: set[str]) -> list[str]:
    """Les propositions de la description qui nomment l'un d'eux sans verbe de lecture."""
    return [p.strip() for p in re.split(r"[,;:.\n•]", description)
            if any(re.search(rf"\b{n}\b", p, re.I) for n in noms) and not LECTURE.search(p)]


def juger(fiche: str, code: dict[str, str], lire) -> list[str]:
    bloc = DESCRIPTION.search(fiche)
    notes, relais = lire(NOTES), lire(RELAIS)
    if bloc is None or notes is None or relais is None:
        return [f"fiche du magasin : INCONNU — description, {NOTES} ou {RELAIS} illisible (#343)"]
    fautes = []
    noms = ajouts_au_site(code)
    if not ATTENDUS <= noms:
        fautes.append(
            f"fiche du magasin : INCONNU — l'app ne dit plus « {' et '.join(sorted(ATTENDUS))} s'ajoutent depuis le"
            f" site » (lu : {sorted(noms) or 'rien'}) ; revoir ce contrôle avec le geste qui les joint (#343)")
    fautes += [f"description : « {p} » promet de joindre ce que l'app laisse au site (#343)"
               for p in promesses(bloc.group(1), noms)]
    etat = ALLUME.search(relais)
    if etat is None:
        return fautes + [f"fiche du magasin : INCONNU — `RelaisPush.courant` illisible dans {RELAIS} (#343)"]
    allume = etat.group(1) == "true"
    textes = {"description": bloc.group(1), "notes de revue": notes}
    for quoi, texte in textes.items():
        if not allume and (m := OFFRE[quoi].search(texte)):
            fautes.append(f"{quoi} : « {m.group(0)} » décrit une notification poussée, le relais est éteint (#343)")
        if not allume and not AUCUNE[quoi].search(texte):
            fautes.append(f"{quoi} : ne dit pas qu'aucune notification ne part (« {AUCUNE[quoi].pattern} »), le relais est éteint (#343)")
        if allume and (m := AUCUNE[quoi].search(texte)):
            fautes.append(f"{quoi} : « {m.group(0)} », alors que le relais est allumé (#318)")
    return fautes


def autotest() -> bool:
    code = {"CoproFirst/A.swift": 'let p = "Les photos et les documents s\'ajoutent depuis le site."\n'}
    eteint = "    static let courant = RelaisPush(allume: false, depuis: .plancher)\n"
    juste = ("<!-- description -->\n• Affaires : signalez une panne et suivez-la ; consultez ses photos et ses documents.\n"
             "Les notifications se lisent sous la cloche : cette version n'en envoie aucune.\n<!-- /description -->")
    notes = "- Notifications: this version sends no push notification.\n"

    def fautes(fiche=juste, code=code, notes=notes, relais=eteint):
        fichiers = {NOTES: notes, RELAIS: relais}
        return juger(fiche, code, fichiers.get)

    ruptures = {
        "promet de joindre": dict(fiche=juste.replace("; consultez ses photos et ses documents", ", avec photos et documents")),
        "ne dit plus": dict(code={"CoproFirst/A.swift": "let p = 1\n"}),
        "décrit une notification poussée": dict(fiche=juste.replace("n'en envoie aucune.", "n'en envoie aucune. Le message est toujours « Vous avez une nouvelle notification. »")),
        "notes de revue : « requested after the user": dict(notes=notes + "- Notifications: requested after the user taps the bell.\n"),
        "notes de revue : ne dit pas": dict(notes="- Camera: QR code only.\n"),
        "alors que le relais est allumé": dict(relais=eteint.replace("false", "true")),
        "`RelaisPush.courant` illisible": dict(relais="struct RelaisPush {}\n"),
        "illisible": dict(notes=None),
    }
    ok = fautes() == []
    for attendu, changement in ruptures.items():
        ok &= any(attendu in f for f in fautes(**changement))
    return ok and promesses("avec photos et documents", ATTENDUS) == ["avec photos et documents"]


if __name__ == "__main__":
    if sys.argv[1:] != ["--autotest"]:
        print("usage : appelé par verifier-confidentialite.py ; seul, `--autotest`")
        sys.exit(2)
    reussi = autotest()
    print("✅ autotest de la fiche du magasin" if reussi else "❌ autotest de la fiche du magasin en échec")
    sys.exit(0 if reussi else 1)
