#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le serveur SERT ne se recalcule plus dans l'app (#83, `standards/09` §8).

Le 10/11/2026, l'app rangeait encore les cartes du Kanban par une table générée depuis
le front (`colonneParStatut`), déduisait des rôles qui peut glisser une carte, archiver
ou supprimer une annonce, et lisait les états clos dans une liste figée — alors que le
contrat 1.14.0 sert `colonne_kanban`, `peut_*`, `categorie_libelle`, `perimetre_libelle`
et `GET /tickets/referentiels`. Chaque copie divergeait au premier arbitrage du serveur.

Ce contrôle refuse le RETOUR de chaque table ou prédicat retiré, dans le code de l'app
(`CoproFirst/**/*.swift`) comme dans les générateurs (`scripts/generateurs/*.py`), qui
pourraient le réécrire. Chaque motif nomme ce qu'on lit à la place.

Une dispense se déclare avec sa raison ; une dispense qui ne couvre plus rien échoue.

Usage :
  python3 scripts/verifier-regles-servies.py            juge le dépôt
  python3 scripts/verifier-regles-servies.py --autotest prouve qu'il refuse et accepte

Sortie : 0 conforme, 1 retour d'une règle retirée, 2 INCONNU (rien à juger).
"""

from __future__ import annotations

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]

#: (motif, ce qu'on lit à la place). Un motif vise la COPIE, jamais le champ servi :
#: `lu.colonnesKanban` (le type généré du contrat) reste permis.
RETIREES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bTablesAffaires\.(colonneParStatut|statutParColonne|colonnesKanban|statutsClos|categorieParCode)\b"),
     "la colonne et la clôture servies (`colonne_kanban`, `close`, `GET /tickets/referentiels`)"),
    (re.compile(r"\bstatic let (colonneParStatut|statutParColonne|colonnesKanban|statutsClos)\b"),
     "les référentiels servis (`ReferentielsAffaires`), jamais une table écrite ou générée"),
    (re.compile(r"\b(COLONNE_PAR_STATUT_TICKET|STATUTS_TICKET_CLOS)\b"),
     "les référentiels servis : le générateur ne lit plus ces tables du front"),
    (re.compile(r"\bpeutRepondre\(moi:"),
     "`peut_repondre` de l'affaire (`DroitsServisAffaire`)"),
    (re.compile(r"\bvar estConseil: Bool \{ roles\b|\.contains\(\"(conseil_syndical|admin)\"\)"),
     "un `peut_*` servi ; à défaut, la règle GÉNÉRÉE du site (`DroitsOnglet.cs`)"),
]

#: chemin → raison. Une dispense dit pourquoi le motif n'y est pas une règle recopiée.
DISPENSES: dict[str, str] = {
    "CoproFirst/Fonctions/Admin/Utilisateurs/EtatUtilisateursAdmin.swift":
        "compte les membres du conseil parmi les comptes listés — une donnée affichée, pas un droit du lecteur",
}


def fichiers(racine: pathlib.Path) -> list[pathlib.Path]:
    return sorted([*(racine / "CoproFirst").rglob("*.swift"), *(racine / "scripts" / "generateurs").glob("*.py")])


def juger(racine: pathlib.Path) -> tuple[list[str], int]:
    """Rend les refus et le nombre de fichiers jugés."""
    refus: list[str] = []
    dispenses_utiles: set[str] = set()
    jugés = fichiers(racine)
    for f in jugés:
        chemin = f.relative_to(racine).as_posix()
        for n, ligne in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            for motif, remede in RETIREES:
                if not motif.search(ligne):
                    continue
                if chemin in DISPENSES:
                    dispenses_utiles.add(chemin)
                    continue
                refus.append(f"{chemin}:{n} : règle retirée qui revient ({motif.search(ligne).group(0)}) — lire {remede}")
    for chemin in sorted(set(DISPENSES) - dispenses_utiles):
        refus.append(f"{chemin} : dispensé sans plus rien couvrir — retirer la dispense")
    return refus, len(jugés)


def autotest() -> int:
    """Dans les deux sens : un contrôle qui ne refuse rien ne prouve rien."""
    fautifs = [
        "    var colonne: String? { TablesAffaires.colonneParStatut[statut] }",
        "    static let statutsClos: Set<String> = [\"résolu\"]",
        '    par_statut = table_simple(texte, "COLONNE_PAR_STATUT_TICKET")',
        "        if DroitsAffaire.peutRepondre(moi: profil) {",
        '    var estConseil: Bool { roles.contains("conseil_syndical") || estAdmin }',
        '        return roles.contains("admin")',
    ]
    sains = [
        "            colonnes: lu.colonnesKanban.map { ColonneKanban(id: $0.code) },",
        "            colonne: ticket.colonneKanban, peutDeplacer: ticket.peutDeplacerAuKanban ?? false,",
        "    private var estConseil: Bool { DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs }",
    ]
    echecs = [f for f in fautifs if not any(m.search(f) for m, _ in RETIREES)]
    echecs += [s for s in sains if any(m.search(s) for m, _ in RETIREES)]
    for e in echecs:
        print(f"❌ autotest : mal jugé — {e.strip()}")
    if not echecs:
        print(f"✅ autotest : {len(fautifs)} retours refusés, {len(sains)} lectures servies acceptées")
    return 1 if echecs else 0


def main() -> int:
    if "--autotest" in sys.argv[1:]:
        return autotest()
    refus, jugés = juger(RACINE)
    if jugés == 0:
        print("❓ INCONNU : aucun fichier à juger (CoproFirst/**/*.swift, scripts/generateurs/*.py)")
        return 2
    for r in refus:
        print(f"❌ {r}")
    if refus:
        return 1
    print(f"✅ {jugés} fichiers : aucune règle servie recalculée (#83)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
