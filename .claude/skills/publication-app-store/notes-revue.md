<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Notes de revue pour Apple (App Store Connect › App Review Information)

Texte à coller par Philippe dans App Store Connect, à chaque soumission, **après
relecture** : chaque ligne se vérifie contre le code de la version soumise. Il est en
anglais parce que l'équipe de revue d'Apple lit l'anglais ; le reste du dossier est en
français.

Ce fichier ne contient **aucun mot de passe** : celui de la démo est publié sur
<https://coprofirst.fr/demo.html> (`ContenuVitrine.pageIdentifiantsDemo`), et Philippe le
recopie dans les champs « Sign-In Information » d'App Store Connect, pas ici.

## Ce que chaque ligne affirme, et où le vérifier

| Affirmation | Preuve dans le dépôt |
|---|---|
| La démo se joint depuis l'accueil, sans compte personnel | `Entree/Demo/DemoView.swift` : un personnage ouvre la connexion pré-remplie sur `demo.coprofirst.fr` |
| La caméra ne lit que le QR code de la fiche d'arrivée | `NSCameraUsageDescription` de `project.yml`, `Entree/Decouverte/ScannerQRView.swift` |
| Face ID ne sert qu'à rouvrir la session | `NSFaceIDUsageDescription`, `Session/Biometrie.swift` |
| Les notifications se demandent après un geste, jamais au lancement | `Fonctions/Notifications/Push/` (`OffrePush`) |
| Aucune donnée personnelle dans une notification | skill `publication-app-store`, liste d'avant soumission ; charge composée par le relais (coprofirst#2494) |
| Contenu d'utilisateurs : signalement au conseil syndical | `Commun/Composants/SignalementAuConseil.swift` ; arbitrage du 12/11/2026 (#167) : pas de blocage d'un auteur |
| Suppression du compte : une demande lancée depuis le Profil, traitée par l'administration de la résidence | `Fonctions/Profil/SuppressionCompte/` (#166) ; route `/auth/demande-suppression` du contrat 1.27.0 ; la démo accepte la demande sans jamais effacer son compte — **lu dans le code serveur v3.89.0, pas rejoué sur la démo : à jouer avant de soumettre** |
| Ni suivi, ni publicité, ni achat intégré | `PrivacyInfo.xcprivacy` (`NSPrivacyTracking` faux), `scripts/verifier-confidentialite.py` |
| Code source ouvert, lien dans l'app | Plus › À propos › « Code source de l'app » (AGPL §13) |

## Texte à coller

```text
CoproFirst is the companion app of CoproFirst, an open-source platform that a
residential co-ownership (French "copropriété") installs on its own server. Each
residence has its own address; there is no central directory of residences, so the
app opens one of three ways: typing the residence's address, scanning the QR code
printed on the welcome sheet, or the built-in demo.

HOW TO REVIEW
1. On the welcome screen, tap the demo entry and pick any of the personas.
2. The sign-in screen opens on the demo residence (demo.coprofirst.fr) with the
   persona's e-mail pre-filled. Enter the password given in the Sign-In Information
   section (it is also published at https://coprofirst.fr/demo.html).
3. The demo residence contains fictitious data only.

ACCOUNTS
Accounts are opened by each residence's administrators, who check that the person
lives there; the app itself only links to the residence's web sign-up form.
Account deletion: in the app, More > Profile > "Supprimer mon compte" (below "Vos droits
(RGPD)"). The user reads what will be erased, confirms with their password and may give
a reason; the request is sent to the residence's administrators, who process it within
the delay shown on screen (30 days at most). The user can withdraw the request until it is
processed. The demo accounts accept the request but are never erased, so you can try the
whole flow with them.

USER-GENERATED CONTENT
Residents can post requests, community announcements, comments and replies, visible
only to the members of their own residence (a closed community of verified
residents). Any content can be reported to the residence's elected council
("conseil syndical") from the content itself, with a mandatory reason; the council
moderates it.

PERMISSIONS
- Camera: only to scan the QR code of the residence's welcome sheet.
- Face ID: only to reopen the session without typing the password again.
- Notifications: requested after the user taps the bell, never at launch. A
  notification carries only an opaque identifier; the content is fetched from the
  residence once the app is open. Urgent notices (water leak, stuck lift) use the
  time-sensitive level.

PRIVACY
No tracking, no advertising, no third-party analytics, no in-app purchase. Data is
sent only to the residence the user chose, never to the developer.

SOURCE CODE
The app is free software (AGPL-3.0 with an additional permission for App Store
distribution). Its source is linked from More > About.
```
