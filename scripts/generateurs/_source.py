# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""La SOURCE de toute génération : une version PUBLIÉE de coprofirst, et elle seule.

Une règle pour tous les générateurs (#34, #20) : coprofirst se lit à une version
taguée `vX.Y.Z` qui a sa release — jamais l'arbre de travail d'un clone, jamais une
branche. La version et son commit sont nommés dans l'en-tête « GÉNÉRÉ » de chaque
fichier. Ce module est le SEUL à toucher coprofirst et coprofirst-site :
`verifier-depot.sh` refuse qu'un autre script de génération le fasse.

- les fichiers lus : l'archive du tag servie par GitHub, dont l'en-tête pax porte le
  commit ; seuls les fichiers DÉCLARÉS (`SOURCES` des modules) en sont extraits — un
  module qui lit un fichier non déclaré échoue, la concordance ne le manque donc pas ;
- les pièces jointes de la release : `openapi.json` (le contrat publié) et
  `tables-clients.json` (les tables que le site publie pour ses clients, depuis
  v3.88.0 — `tables_clients`, #128) : une table du site ne se cherche plus par motif
  dans ses sources ;
- un fichier de coprofirst-site (le contenu de la vitrine, #51), lu à un COMMIT
  nommé par le générateur qui le lit (`fichier_du_site`) : un commit est immuable,
  comme une étiquette — jamais une branche ;
- pour la concordance seule, le contrat que SERT une installation connue
  (`contrat_servi`, `version_contrat` de GET /config, #83) : il mesure le plancher, il
  ne génère rien.

Aucun clone, aucun chemin du poste : le runner de la CI lit exactement comme lui.
Toute lecture impossible lève `SourceIllisible`, que la concordance rend INCONNU.
"""

from __future__ import annotations

import io
import json
import os
import pathlib
import re
import tarfile
import urllib.error
import urllib.request

DEPOT = os.environ.get("COPROFIRST_DEPOT", "philippe-tressard/coprofirst")
DEPOT_SITE = os.environ.get("COPROFIRST_SITE_DEPOT", "philippe-tressard/coprofirst-site")
VERSION = re.compile(r"^v\d+\.\d+\.\d+$")
CONTRAT = re.compile(r"^\d+\.\d+\.\d+$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
TABLES_CLIENTS = "tables-clients.json"
# Le format de `tables-clients.json` que les générateurs savent lire : un autre est refusé.
FORMAT_TABLES = 1


class SourceIllisible(Exception):
    """La version, son archive ou une pièce jointe n'a pas pu être lue : INCONNU."""


def _lire(url: str) -> bytes:
    entetes = {"User-Agent": "coprofirst-ios-generateurs"}
    jeton = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if url.startswith("https://api.github.com/"):
        entetes["Accept"] = "application/vnd.github+json"
        # Le jeton ne part que vers l'API de GitHub (limite de requêtes), jamais ailleurs.
        if jeton:
            entetes["Authorization"] = f"Bearer {jeton}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=entetes), timeout=120) as reponse:
            return reponse.read()
    except (urllib.error.URLError, TimeoutError, OSError) as erreur:
        raise SourceIllisible(f"{url} : {erreur}") from erreur


def _release(chemin: str) -> dict:
    try:
        release = json.loads(_lire(f"https://api.github.com/repos/{DEPOT}/releases/{chemin}"))
    except json.JSONDecodeError as erreur:
        raise SourceIllisible(f"release {chemin} : réponse illisible") from erreur
    if release.get("draft") or not VERSION.match(str(release.get("tag_name", ""))):
        raise SourceIllisible(f"release {chemin} : brouillon ou étiquette hors de vX.Y.Z")
    return release


def derniere_version() -> str:
    """L'étiquette de la dernière release publiée de coprofirst."""
    return _release("latest")["tag_name"]


def versions_publiees() -> list[str]:
    """Les étiquettes des cent dernières releases publiées, de la plus récente à la plus ancienne."""
    try:
        releases = json.loads(_lire(f"https://api.github.com/repos/{DEPOT}/releases?per_page=100"))
    except json.JSONDecodeError as erreur:
        raise SourceIllisible("liste des releases : réponse illisible") from erreur
    if not isinstance(releases, list):
        raise SourceIllisible("liste des releases : réponse illisible")
    return [r["tag_name"] for r in releases
            if isinstance(r, dict) and not r.get("draft") and VERSION.match(str(r.get("tag_name", "")))]


def _version_contrat(valeur, origine: str) -> str:
    if not isinstance(valeur, str) or not CONTRAT.match(valeur):
        raise SourceIllisible(f"{origine} : version du contrat illisible ({valeur!r})")
    return valeur


def contrat_servi(hote: str) -> str:
    """`version_contrat` de GET https://<hôte>/api/config : le contrat qu'une installation SERT."""
    try:
        config = json.loads(_lire(f"https://{hote}/api/config"))
    except json.JSONDecodeError as erreur:
        raise SourceIllisible(f"{hote} : GET /api/config illisible") from erreur
    return _version_contrat(config.get("version_contrat") if isinstance(config, dict) else None, hote)


class Version:
    """Une version publiée : sa release vérifiée, son archive, ses pièces jointes."""

    def __init__(self, etiquette: str) -> None:
        if not VERSION.match(etiquette):
            raise SourceIllisible(f"« {etiquette} » n'est pas une version publiée (vX.Y.Z)")
        self.etiquette = etiquette
        self._pieces = {p["name"]: p["browser_download_url"] for p in _release(f"tags/{etiquette}").get("assets", [])}

    def extraire(self, chemins: list[str], dossier: pathlib.Path) -> str:
        """Extrait `chemins` (relatifs à la racine de coprofirst) dans `dossier` ; rend le commit."""
        archive = _lire(f"https://codeload.github.com/{DEPOT}/tar.gz/refs/tags/{self.etiquette}")
        voulus = set(chemins)
        try:
            with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
                commit = str(tar.pax_headers.get("comment", ""))
                if not COMMIT.match(commit):
                    raise SourceIllisible(f"{self.etiquette} : l'archive ne nomme pas son commit")
                for membre in tar:
                    relatif = membre.name.split("/", 1)[-1]
                    if relatif in voulus and membre.isfile():
                        membre.name = relatif
                        tar.extract(membre, dossier, filter="data")
                        voulus.discard(relatif)
        except (tarfile.TarError, EOFError) as erreur:
            raise SourceIllisible(f"{self.etiquette} : archive illisible ({erreur})") from erreur
        if voulus:
            raise SourceIllisible(f"{self.etiquette} : absent du tag — {', '.join(sorted(voulus))}")
        return commit

    def piece_jointe(self, nom: str) -> bytes:
        if nom not in self._pieces:
            raise SourceIllisible(f"{self.etiquette} : la release ne joint pas {nom}")
        return _lire(self._pieces[nom])

    def tables_clients(self) -> dict[str, dict]:
        """Les tables publiées (`tables-clients.json`) : `{nom: {source, valeur}}`.

        Une version qui ne joint pas le fichier (avant v3.88.0), un autre format, une
        entrée sans `valeur` : illisible — jamais une table supposée."""
        origine = f"{self.etiquette} : {TABLES_CLIENTS}"
        try:
            document = json.loads(self.piece_jointe(TABLES_CLIENTS))
        except ValueError as erreur:
            raise SourceIllisible(f"{origine} illisible ({erreur})") from erreur
        if not isinstance(document, dict) or document.get("format") != FORMAT_TABLES:
            lu = document.get("format") if isinstance(document, dict) else None
            raise SourceIllisible(f"{origine} n'est pas au format {FORMAT_TABLES} (lu : {lu!r})")
        tables = document.get("tables")
        if not isinstance(tables, dict) or not tables:
            raise SourceIllisible(f"{origine} ne porte aucune table")
        sans_valeur = sorted(nom for nom, entree in tables.items()
                             if not isinstance(entree, dict) or "valeur" not in entree or "source" not in entree)
        if sans_valeur:
            raise SourceIllisible(f"{origine} : entrée(s) sans `source` ou `valeur` — {', '.join(sans_valeur)}")
        return tables

    def contrat(self) -> str:
        """La version du contrat publié (`info.version` de la pièce jointe `openapi.json`)."""
        try:
            version = json.loads(self.piece_jointe("openapi.json"))["info"]["version"]
        except (ValueError, KeyError, TypeError) as erreur:
            raise SourceIllisible(f"{self.etiquette} : openapi.json illisible") from erreur
        return _version_contrat(version, self.etiquette)


def fichier_du_site(commit: str, chemin: str) -> bytes:
    """Un fichier de coprofirst-site (`site/contenu.json`) au commit `commit` (40 hexa)."""
    if not COMMIT.match(commit):
        raise SourceIllisible(f"coprofirst-site : « {commit} » n'est pas un commit (40 caractères hexadécimaux)")
    return _lire(f"https://raw.githubusercontent.com/{DEPOT_SITE}/{commit}/{chemin}")
