# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Les onglets du site, leurs réserves et qui les ouvre — pour `OngletsDuSite.swift` (#29).

Appelé par generer-charte.py. Tout se LIT dans coprofirst, rien ne se recopie :

- les onglets de chaque page, leur réserve et `ouvertOperateur`, et les pages
  `reserveeAdmin` : `PAGES` (`pages.ts`) et `PAGES_ROLES` (`pages-roles.ts`) ;
- qui porte chaque droit de `DroitsOnglet` : les rôles des dérivées `isAdmin`,
  `isOperateur`, `isProprioOuCS` (`stores/auth.ts`, par `aRole`) et les statuts de
  `estLocataire`, `estGestionnaire` (`roles.ts`, par `statutDe`).

La règle qui les combine (`reserveAdmise`, `ongletsOuverts` de
`#lib/onglets-ouverts.ts`) est du code : elle vit, écrite une fois, dans
`CoproFirst/Navigation/OngletsOuverts.swift`. Une réserve que l'app ne connaît
pas fait échouer la génération — jamais un onglet ouvert par défaut.
"""

from __future__ import annotations

import pathlib
import re

import lecture_ts

RESERVES = ("proprioOuCS", "nonLocataire", "operateur", "nonGestionnaire")


def _bloc(texte: str, debut: str) -> str:
    """Le texte d'une déclaration, de `debut` jusqu'au premier `;` hors chaîne."""
    i = texte.index(debut)
    return texte[i : texte.index(";", i)]


def _roles(auth: str, derivee: str) -> list[str]:
    """Les rôles qu'une dérivée de `stores/auth.ts` passe à `aRole`."""
    bloc = _bloc(auth, f"export const {derivee} = derived(")
    m = re.search(r"aRole\(\$u,([^)]*)\)", bloc)
    if not m:
        raise SystemExit(f"❌ {derivee} : appel à aRole introuvable dans stores/auth.ts")
    return re.findall(r"'([^']+)'", m.group(1))


def _statuts(roles_ts: str, fonction: str) -> list[str]:
    """Les statuts qu'une fonction de `roles.ts` compare par `statutDe(p) === '…'`."""
    bloc = _bloc(roles_ts, f"export const {fonction} = ")
    statuts = re.findall(r"statutDe\(p\) === '([^']+)'", bloc)
    if not statuts:
        raise SystemExit(f"❌ {fonction} : comparaison de statut introuvable dans roles.ts")
    return statuts


def _constante(lib: pathlib.Path, nom: str) -> str:
    """Le texte d'une constante de libellé (`TITRE_ARCHIVES`), pictogramme retiré."""
    for fichier in sorted(lib.glob("*.ts")):
        m = re.search(rf"export const {nom} = [`'](.*?)[`'];", fichier.read_text(encoding="utf-8"))
        if m:
            return re.sub(r"^\$\{[A-Z_]+\}\s*", "", m.group(1))
    raise SystemExit(f"❌ constante de libellé {nom} introuvable dans front/src/lib")


def _libelle(lib: pathlib.Path, label) -> str:
    if isinstance(label, lecture_ts.Identifiant):
        label = _constante(lib, label)
    return re.sub(r"^[^\w«(]+", "", label or "").strip().replace('"', '\\"')


def _ensemble(valeurs: list[str]) -> str:
    return "[" + ", ".join(f'"{v}"' for v in valeurs) + "]"


def swift(front: pathlib.Path, pages: list[dict]) -> tuple[str, int]:
    """Le corps Swift (sans en-tête) et le nombre d'onglets."""
    lib = front / "src" / "lib"
    auth = (lib / "stores" / "auth.ts").read_text(encoding="utf-8")
    roles_ts = (lib / "roles.ts").read_text(encoding="utf-8")
    lignes, reservees, n = [], [], 0
    for page in pages:
        if page.get("reserveeAdmin"):
            reservees.append(page["id"])
        onglets = page.get("onglets") or []
        if not onglets:
            continue
        lignes.append(f'        "{page["id"]}": [\n')
        for o in onglets:
            reserve = o.get("reserve")
            if reserve is not None and reserve not in RESERVES:
                raise SystemExit(f"❌ réserve inconnue « {reserve} » ({page['id']}/{o['id']}) — l'app doit l'apprendre")
            r = f".{reserve}" if reserve else "nil"
            lignes.append(
                f'            OngletDuSite(id: "{o["id"]}", libelle: "{_libelle(lib, o.get("label"))}", '
                f"reserve: {r}, ouvertOperateur: {'true' if o.get('ouvertOperateur') else 'false'}),\n"
            )
            n += 1
        lignes.append("        ],\n")
    corps = "\n/// Les onglets de chaque page du site, dans leur ordre, avec leur réserve (#29).\n"
    corps += "/// La règle qui en décide l'ouverture : `OngletsDuSite.ouverts` (Navigation/OngletsOuverts.swift).\n"
    corps += "enum OngletsDuSite {\n"
    corps += "    static let parPage: [String: [OngletDuSite]] = [\n" + "".join(lignes) + "    ]\n\n"
    corps += "    /// Les pages de l'administration : un non-administrateur n'y ouvre que les onglets\n"
    corps += "    /// `ouvertOperateur`, s'il est opérateur.\n"
    corps += f"    static let pagesReserveesAdmin: Set<String> = {_ensemble(reservees)}\n\n"
    corps += "    /// Qui porte chaque droit : rôles (`aRole` de `stores/auth.ts`), statuts (`roles.ts`).\n"
    corps += f"    static let rolesAdministrateur: Set<String> = {_ensemble(_roles(auth, 'isAdmin'))}\n"
    corps += f"    static let rolesOperateur: Set<String> = {_ensemble(_roles(auth, 'isOperateur'))}\n"
    corps += f"    static let rolesProprioOuCS: Set<String> = {_ensemble(_roles(auth, 'isProprioOuCS'))}\n"
    corps += f"    static let statutsLocataire: Set<String> = {_ensemble(_statuts(roles_ts, 'estLocataire'))}\n"
    corps += f"    static let statutsGestionnaire: Set<String> = {_ensemble(_statuts(roles_ts, 'estGestionnaire'))}\n"
    corps += "}\n"
    return corps, n
