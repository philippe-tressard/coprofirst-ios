# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""L'autotest de `verifier-confidentialite.py` : un jeu conforme, puis chaque rupture,
dans les deux sens. Sorti du juge pour qu'il tienne sous 500 lignes (standards/02 §6) ;
il reçoit le juge (`v`) et n'en recopie rien.
"""

from __future__ import annotations

from typing import Callable


def _jeu(v) -> object:
    fiche = "\n".join([
        "<!-- table:donnees -->", "| Type | Preuve |", "|---|---|",
        "| `NSPrivacyCollectedDataTypeEmailAddress` | `CoproFirst/A.swift` › `postAuthLogin(` |",
        "", "<!-- table:envois -->", "| Envoi | Types |", "|---|---|",
        "| `postAuthLogin` | `EmailAddress` |", "| `postAuthLogout` | — |",
        "| `postEcransAppairage` | — |", "", "<!-- table:portes -->", "| Fichier |", "|---|", "| `CoproFirst/A.swift` |",
        "", "<!-- table:droits -->", "| Droit |", "|---|", "| `aps-environment` |",
        "", "<!-- table:autorisations -->", "| Clé |", "|---|", "| `NSCameraUsageDescription` |",
        "", "<!-- table:modules -->", "| Module |", "|---|", "| `Foundation` |",
        "", "<!-- table:paquets -->", "| Paquet | Révision | Rôle | Sources |", "|---|---|---|---|",
        "| `p-runtime` | `abc123` | embarqué | `Sources/R` |", "| `p-outil` | `def456` | outil | — |", "",
        "<!-- description -->", "Aucune publicité, aucune mesure d'audience.", "<!-- /description -->", ""])
    projet = "\n".join([
        "targets:", "  CoproFirst:", "    sources:", "      - path: CoproFirst", "    info:",
        "      properties:", "        CFBundleDisplayName: X", "        NSCameraUsageDescription: \"La caméra\"",
        "    entitlements:", "      path: X", "      properties:", "        # un commentaire",
        "        aps-environment: development", "    settings:", "      base:", "        A: B",
        "  CoproFirstTV:", "    sources:", "      - path: CoproFirstTV", "    dependencies:", "      - package: X",
        "  CoproFirstWatch:", "    sources:", "      - path: CoproFirstWatch", "      - path: CoproFirst/A.swift", ""])
    code = {"CoproFirst/A.swift": (
        "import Foundation\n/// `UserDefaults` en commentaire seulement.\n"
        "let s = URLSession(configuration: .ephemeral)\nclient.postAuthLogin(x)\nclient.postAuthLogout()\n"
        "let r = UserDefaults.standard\n"),
        "CoproFirstTV/T.swift": "import Foundation\nclient.postEcransAppairage()\n",
        "CoproFirstWatch/M.swift": "import Foundation\nlet m = 1\n"}
    manifeste = {
        "NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [{
            v.TYPE: v.TYPE + "EmailAddress", v.TYPE + "Linked": True, v.TYPE + "Tracking": False,
            v.TYPE + "Purposes": [v.TYPE + "PurposeAppFunctionality"]}],
        "NSPrivacyAccessedAPITypes": [{
            "NSPrivacyAccessedAPIType": v.CATEGORIE + "UserDefaults", "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]}]}
    fichiers = dict(code)
    fichiers[v.MANIFESTE] = "<plist/>"
    vide = {"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [],
            "NSPrivacyAccessedAPITypes": []}
    # La montre compile A.swift : elle déclare ce qu'il appelle et ce qu'il envoie.
    montre = {**vide, "NSPrivacyCollectedDataTypes": [dict(manifeste["NSPrivacyCollectedDataTypes"][0])],
              "NSPrivacyAccessedAPITypes": [dict(manifeste["NSPrivacyAccessedAPITypes"][0])]}
    return v.Etat(
        manifeste=manifeste, fiche=fiche, projet=projet, code=code, lire=fichiers.get,
        resolu={"p-runtime": "abc123", "p-outil": "def456"}, paquets={"p-runtime": {"Sources/R/a.swift": "let a = 1\n"}},
        cibles={"CoproFirstTV": vide, "CoproFirstWatch": montre})


def autotest(v) -> bool:
    def code(e, texte): e.code["CoproFirst/A.swift"] += texte
    def fiche(e, avant, apres): e.fiche = e.fiche.replace(avant, apres)
    def manifeste(e, cle, valeur): e.manifeste[cle] = valeur
    ruptures: list[tuple[str, Callable[[object], object]]] = [
        ("FileTimestamp est appelée", lambda e: code(e, "let d = valeurs.creationDate\n")),
        ("UserDefaults est appelée", lambda e: manifeste(e, "NSPrivacyAccessedAPITypes", [])),
        ("ne l'appelle plus", lambda e: setattr(
            e, "code", {c: t.replace("let r = UserDefaults.standard\n", "") for c, t in e.code.items()})),
        ("raison absente ou hors", lambda e: e.manifeste["NSPrivacyAccessedAPITypes"][0].update(
            NSPrivacyAccessedAPITypeReasons=["DDA9.1"])),
        ("symbole de traçage", lambda e: code(e, "let i = ASIdentifierManager.shared()\n")),
        ("NSPrivacyTracking", lambda e: manifeste(e, "NSPrivacyTracking", True)),
        ("« Sentry »", lambda e: code(e, "@preconcurrency import Sentry\n")),
        ("« UIKit » est déclaré", lambda e: fiche(e, "| `Foundation` |", "| `Foundation` |\n| `UIKit` |")),
        ("porte réseau : « CoproFirst/B.swift »", lambda e: e.code.update({"CoproFirst/B.swift": "let (d, _) = try await s.data(from: u)\n"})),
        ("droit : « com.apple.developer.x »", lambda e: setattr(
            e, "projet", e.projet.replace("        aps-environment", "        com.apple.developer.x: true\n        aps-environment"))),
        ("droit : « aps-environment » est déclaré", lambda e: setattr(
            e, "projet", e.projet.replace("        aps-environment: development\n", ""))),
        ("autorisation : « NSLocationWhenInUseUsageDescription »", lambda e: setattr(
            e, "projet", e.projet.replace("        CFBundleDisplayName: X", "        NSLocationWhenInUseUsageDescription: X"))),
        ("envoi : « postTickets »", lambda e: code(e, "try await client(a)\n    .postTickets(body: b)\n")),
        ("envoi : « postAuthLogout » est déclaré", lambda e: setattr(
            e, "code", {c: t.replace("client.postAuthLogout()\n", "") for c, t in e.code.items()})),
        ("classé « PhoneNumber »", lambda e: fiche(e, "| `postAuthLogout` | — |", "| `postAuthLogout` | `PhoneNumber` |")),
        ("aucun envoi ne le porte", lambda e: fiche(e, "| `postAuthLogin` | `EmailAddress` |", "| `postAuthLogin` | — |")),
        ("type de donnée : « NSPrivacyCollectedDataTypeEmailAddress »", lambda e: fiche(
            e, "| `NSPrivacyCollectedDataTypeEmailAddress` | `CoproFirst/A.swift` › `postAuthLogin(` |\n", "| `x` | y |\n")),
        ("n'a aucune preuve", lambda e: fiche(e, "`CoproFirst/A.swift` › `postAuthLogin(`", "voir le code")),
        ("n'est plus dans CoproFirst/A.swift", lambda e: fiche(e, "› `postAuthLogin(`", "› `postAuthLoginV2(`")),
        ("n'est pas un fichier suivi", lambda e: fiche(e, "`CoproFirst/A.swift` › `postAuthLogin(`", "`CoproFirst/Z.swift` › `postAuthLogin(`")),
        ("PhotosorVideos", lambda e: code(e, "PhotosPicker(selection: $s) {}\n")),
        ("examiné à abc123", lambda e: e.resolu.update({"p-runtime": "999999"})),
        ("paquet : « p-neuf »", lambda e: e.resolu.update({"p-neuf": "1"})),
        ("paquet : « p-outil » est déclaré", lambda e: e.resolu.pop("p-outil")),
        ("par le paquet p-runtime", lambda e: e.paquets["p-runtime"].update({"Sources/R/b.swift": "let t = ProcessInfo.processInfo.systemUptime\n"})),
        ("n'a plus de sources", lambda e: e.paquets.update({"p-runtime": {"Sources/Autre/a.swift": ""}})),
        ("par le client généré", lambda e: setattr(e, "genere", {"Client.swift": "let t = mach_absolute_time()\n"})),
        ("n'est plus embarqué", lambda e: setattr(e, "projet", e.projet.replace("- path: CoproFirst", "- path: Sources"))),
        ("table(s) absente(s)", lambda e: fiche(e, "<!-- table:envois -->", "")),
        # La 1.0 puis #199 : vraie sans le type, la même phrase est refusée dès qu'il est déclaré.
        ("« aucune mesure d'audience » nie NSPrivacyCollectedDataTypeProductInteraction", lambda e: e.manifeste[
            "NSPrivacyCollectedDataTypes"].append({**e.manifeste["NSPrivacyCollectedDataTypes"][0], v.TYPE: v.TYPE + "ProductInteraction"})),
        ("aucun bloc <!-- description -->", lambda e: fiche(e, "<!-- description -->", "")),
        # Le manifeste propre d'une cible (`confidentialite_cibles.py`) : l'Apple TV (#218, lot 5)…
        ("UserDefaults est appelée par le code de CoproFirstTV", lambda e: e.code.update(
            {"CoproFirstTV/T.swift": e.code["CoproFirstTV/T.swift"] + "let r = UserDefaults.standard\n"})),
        ("UserDefaults est appelée par le paquet p-runtime, embarqué dans CoproFirstTV", lambda e: e.paquets[
            "p-runtime"].update({"Sources/R/b.swift": "let r = UserDefaults.standard\n"})),
        ("n'est plus dans une source de la cible CoproFirstTV", lambda e: setattr(
            e, "projet", e.projet.replace("      - path: CoproFirstTV\n", ""))),
        ("CoproFirstTV/PrivacyInfo.xcprivacy est absent", lambda e: e.cibles.update({"CoproFirstTV": None})),
        ("manifeste de CoproFirstTV : NSPrivacyTracking", lambda e: e.cibles["CoproFirstTV"].update(
            NSPrivacyTracking=True)),
        ("que le manifeste de CoproFirstTV ne déclare pas", lambda e: fiche(
            e, "| `postEcransAppairage` | — |", "| `postEcransAppairage` | `EmailAddress` |")),
        ("NameType n'est pas déclaré par l'app", lambda e: e.cibles["CoproFirstTV"].update(
            NSPrivacyCollectedDataTypes=[{**e.manifeste["NSPrivacyCollectedDataTypes"][0], v.TYPE: v.TYPE + "NameType"}])),
        # … et l'Apple Watch (#226), qui compile aussi un fichier partagé de l'app.
        ("manifeste de CoproFirstWatch : NSPrivacyTracking", lambda e: e.cibles["CoproFirstWatch"].update(
            NSPrivacyTracking=True)),
        ("FileTimestamp est appelée par le code de CoproFirstWatch", lambda e: e.code.update(
            {"CoproFirstWatch/M.swift": "let d = valeurs.creationDate\n"})),
        ("UserDefaults est déclarée, mais le code de CoproFirstWatch", lambda e: e.code.update(
            {"CoproFirst/A.swift": e.code["CoproFirst/A.swift"].replace("let r = UserDefaults.standard\n", ""),
             "CoproFirst/B.swift": "let r = UserDefaults.standard\n"})),
        ("PreciseLocation n'est pas déclaré par l'app", lambda e: e.cibles["CoproFirstWatch"][
            "NSPrivacyCollectedDataTypes"].append({**e.manifeste["NSPrivacyCollectedDataTypes"][0], v.TYPE: v.TYPE + "PreciseLocation"})),
        ("CoproFirstWatch/PrivacyInfo.xcprivacy est absent", lambda e: e.cibles.update({"CoproFirstWatch": None})),
        ("n'est plus dans une source de la cible CoproFirstWatch", lambda e: setattr(
            e, "projet", e.projet.replace("      - path: CoproFirstWatch\n", ""))),
    ]
    conforme = v.juger(_jeu(v))
    if conforme:
        print(f"❌ autotest : le jeu conforme est refusé — {conforme}")
        return False
    for attendu, rompre in ruptures:
        etat = _jeu(v)
        rompre(etat)
        fautes = v.juger(etat)
        if not any(attendu in f for f in fautes):
            print(f"❌ autotest : la rupture « {attendu} » n'est pas refusée — {fautes}")
            return False
    print(f"✅ autotest : {len(ruptures)} ruptures refusées, le jeu conforme accepté")
    return True
