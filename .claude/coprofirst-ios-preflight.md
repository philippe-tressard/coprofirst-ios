<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->
── PRÉ-FLIGHT CoproFirst-iOS — avant CETTE action → charger CECI ──────────
  • un écran SwiftUI, un état, une navigation  → skill swiftui-patterns
  • un parcours, un libellé, un message         → skill ux-patterns-ios (+ standards/11)
  • un appel à l'API                            → le client GÉNÉRÉ (Paquets/ClientAPI) ;
    une route absente = un ticket dans coprofirst, jamais une requête écrite à la main
  • une dépendance, une image, une police       → DEPENDANCES.md, REUSE.toml (standards/14 §6)
  • une notification, un SDK, une collecte      → standards/14 §1 et §3 bis
  • un envoi, un module, un droit, un paquet NEUF → le manifeste (PrivacyInfo.xcprivacy) ET la
    fiche (skill publication-app-store, confidentialite.md) : verifier-confidentialite.py les tient
  • signature, TestFlight, fiche du magasin     → skill publication-app-store
  • project.yml modifié                         → bash scripts/generer-projet.sh
────────────────────────────────────────────────────────────────────────────
