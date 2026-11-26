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
| Cette version n'envoie aucune notification poussée et n'en demande pas l'autorisation : la cloche se lit dans l'app (#343) | `Fonctions/Notifications/Push/RelaisPush.swift` › `static let courant = RelaisPush(allume: false, depuis: .plancher)` ; `NotificationsPush.swift` › `offreDue` exige `relais.sert(…)`. Le jour où #318 rallume le relais, la ligne de la 1.1 revient (étiquette `v1.1.0`) : offre après un geste, charge sans donnée personnelle, niveau *time-sensitive* des avis urgents |
| Les droits `aps-environment` et *time-sensitive* restent dans l'app, inutilisés tant que le relais est éteint | `project.yml` (droits) ; la fiche de confidentialité l'assume (`confidentialite.md` §1) |
| Contenu d'utilisateurs : signalement au conseil syndical — une affaire, une suite, une annonce, une idée, une réponse, un commentaire | `Commun/Composants/SignalementAuConseil.swift` ; affaire et suites (#286) : `BandeauAffaire.swift`, `GestesHistorique.swift` |
| Réponse de l'assistant (IA) : signalable depuis l'avis | `Fonctions/Residence/QuestionReglementView.swift` (#286, décision du 17/11/2026 « 2a ») |
| Blocage d'un auteur : « Masquer ce que publie… », pour soi seul, défait dans le Profil | `Commun/Composants/MasquageAuteur.swift`, `Fonctions/Profil/PersonnesMasquees.swift` (#286, décision du 17/11/2026, qui remplace l'arbitrage du 12/11 de #167) ; au plancher depuis v3.121.2 (#313) : toute résidence qui s'ouvre les sert |
| Suppression du compte : une demande lancée depuis le Profil, traitée par l'administration de la résidence | `Fonctions/Profil/SuppressionCompte/` (#166) ; route `/auth/demande-suppression` du contrat 1.27.0 ; la démo accepte la demande sans jamais effacer son compte — **lu dans le code serveur v3.89.0, pas rejoué sur la démo : à jouer avant de soumettre** |
| Ni suivi, ni publicité, ni achat intégré | `PrivacyInfo.xcprivacy` (`NSPrivacyTracking` faux), `scripts/verifier-confidentialite.py` |
| Les écrans vus, comptés par la résidence, refusables au Profil (depuis la 1.1) | #199 ; `ProfilView.swift` (« Refuser la collecte de statistiques de navigation ») ; `ProductInteraction` du manifeste |
| Sur iPad, Profil et À propos sont dans la barre latérale, pas sous « Plus » | `BarreLateraleUITests` (#221) |
| Code source ouvert, lien dans l'app | Plus › À propos › « Code source de l'app » (AGPL §13) |
| Apple Watch (depuis la 1.2) : la cloche de la dernière résidence ouverte, en lecture seule ; un jeton de montre (cloche seule, 30 jours, révocable) remis par l'iPhone, retiré à la déconnexion | `CoproFirst/Fonctions/Notifications/Montre/` (`LiaisonMontre.active`, allumée le 26/11/2026) ; `CoproFirstWatch/` ; route `/montres` (coprofirst#2771) |
| Apple TV (depuis la 1.2) : l'écran du hall, sans compte, appairé par un code de huit lettres (dix minutes) saisi dans Espace CS › « Écrans du hall » › « Appairer un écran » ; lecture seule des annonces de hall | `CoproFirstTV/` ; `CoproFirst/Fonctions/EspaceCS/Ecrans/TextesEcransCS.swift` ; décision du 20/11/2026 dans #320 (compte de démo du conseil) — **l'accès de `user-cs` à l'onglet et des annonces de hall en cours sur la démo : à constater avant de soumettre** |

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
Account deletion: in the app, More > Profile (on iPad: Profile in the sidebar) > "Supprimer mon compte" (below "Vos droits
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
moderates it. This covers requests and their follow-ups, announcements, ideas,
replies and comments.
Blocking: on an announcement, a reply or a follow-up, "Masquer ce que publie…" (hide
what this person posts) hides everything that resident posts, for the user only; the
other resident is not notified and nothing is deleted. The list, with "Ne plus
masquer" (unhide), is in More > Profile > "Personnes masquées".

AI-GENERATED CONTENT
Residence > Rules ("Règlement") lets a resident ask a question about the co-ownership
rules; the answer is written by an AI model, labelled as an indicative opinion, with
the model named. Each answer has "Signaler la réponse de l'assistant" (report the
assistant's answer) right below that label, with a mandatory reason, sent to the
council.

PERMISSIONS
- Camera: only to scan the QR code of the residence's welcome sheet.
- Face ID: only to reopen the session without typing the password again.
- Notifications: this version sends no push notification and never asks for the
  notification permission; notices are read in the app, under the bell. The push and
  time-sensitive entitlements are present but unused until the residence's relay is
  switched on in a later version.

PRIVACY
No tracking, no advertising, no third-party analytics, no in-app purchase. Data is
sent only to the residence the user chose, never to the developer. Like its website,
the residence counts the screens viewed for its own visit statistics (declared as
Usage Data > Product Interaction, Analytics); the user can opt out in Profile >
"Vos droits (RGPD)" > "Refuser la collecte de statistiques de navigation".

APPLE WATCH
The Apple Watch app is read-only: it shows the notices (the bell) of the last
residence opened on the paired iPhone. To try it, sign in to the demo on the iPhone and
open the residence: the iPhone gives the watch a token that can only read the notices
(30 days, revocable), and the watch lists them, unread first. Nothing can be changed
from the watch. Signing out on the iPhone revokes the watch's access.

APPLE TV
The Apple TV app is the hall screen of a residence: it shows the residence's current
hall announcements, read-only, with no account on the TV. To try it:
1. Open the app on the Apple TV and choose "Essayer la démo" (or type a residence's
   address, then "Continuer"): it shows an eight-letter pairing code, valid ten minutes.
2. On the iPhone, sign in to the demo with the "Conseil syndical" persona (user-cs),
   then More > Espace CS > "Écrans du hall" > "Appairer un écran"; type the code, a
   name and the announcements to show.
3. The TV then shows the hall announcements, or "Aucune annonce en ce moment" when there
   are none. "Retirer" on the iPhone unpairs it; on the TV, a click of the remote offers
   "Désappairer".
The TV's "À propos" (on the pairing screen, or a click of the remote while announcements
play) shows the app's source code address, its licence and the third-party components.

SOURCE CODE
The app is free software (AGPL-3.0 with an additional permission for App Store
distribution). Its source is linked from More > About (on iPad: About in the sidebar).
```
