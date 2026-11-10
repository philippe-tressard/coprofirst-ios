<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Parité avec le site — et feuille de route

L'app ne recopie pas le site : elle en porte les écrans **un par un**, et cette
table dit, pour **chaque onglet de chaque page** du site, où il en est (#10).

| État | Sens |
|---|---|
| `fait` | l'écran natif existe et le registre des menus l'ouvre |
| `prévu` | un ticket le porte — colonne « Ticket », obligatoire |
| `site seulement` | l'app ne le portera pas ; elle renvoie au site, et le dit |

**Jugée en CI** (`scripts/verifier-parite.py`, lancé par `verifier-depot.sh`) :
un onglet du site absent d'ici, une ligne qui n'existe plus sur le site, un état
inconnu, un « prévu » sans ticket — et une page dite `fait` que
`CoproFirst/Navigation/RegistreDesMenus.swift` n'ouvre pas — font échouer la CI.
La liste des onglets du site est **générée** : [ONGLETS-DU-SITE.md](ONGLETS-DU-SITE.md)
(`scripts/generer.py`). Quand le site ajoute un onglet, la régénération
le fait apparaître, et la CI exige qu'on le classe ici.

**Une session = une section.** Chaque lot ne touche que la sienne : il passe ses
lignes de `prévu` à `fait` dans la PR qui livre l'écran, et ajoute une ligne au
registre des menus. Ni les lignes ni les sections ne se déplacent — deux sessions
parallèles ne se gênent pas.

## Feuille de route

1. **#10 — le contrôle de parité** : cette table, le registre des menus, un
   dossier par fonctionnalité, les composants communs (skill `swiftui-patterns`).
2. **Écrans des résidents, en quatre sessions parallèles** : #11, #12, #13, #14.
3. **#15** — Espace conseil syndical et Délégations.
4. **#16** — Administration, en partie.
5. Bloqués côté serveur : **#17** notifications push (coprofirst#2458),
   **#18** liens universels (coprofirst#2459).
6. **#20** — concordance quotidienne des fichiers générés avec coprofirst
   (charte, pages, onglets, contrat d'API) : un écart ouvre un ticket.

## La table

### Livré

Le fil, écran d'accueil de la résidence ouverte.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `tableau-de-bord` | — | fait | #75 | Le fil (`Fonctions/Fil`) — parcours v2, #4 à #8 ; l'échéance d'une affaire datée sous son classement (délai servi, dates), #75 |

### #11 — Mes affaires

Session parallèle (écrans des résidents). Dossier : `Fonctions/Affaires`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `mes-demandes` | `liste` | fait | #11 | Recherche au serveur, Suivi, nature, « ce qui me concerne », archiver (conseil) ; « Nouvelle affaire » sans pièces jointes (site) |
| `mes-demandes` | `kanban` | fait | #11 | Fermé aux locataires ; le conseil déplace (glisser, ou « Déplacer vers… ») ; la fusion à la clôture reste au site |
| `mes-demandes` | `archives` | fait | #11 | Trois ans, par année, chacune repliable |

### #12 — Ma résidence et Annuaire

Session parallèle. Dossiers : `Fonctions/Residence`, `Fonctions/Annuaire`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `residence` | `fiche` | fait | #12 | En lecture : la fiche, les documents et les rapports se déposent et se corrigent sur le site |
| `residence` | `carnet` | fait | #12 | Le bilan de l'exercice (conseil syndical) et le filtre par année restent sur le site, et l'app le dit |
| `residence` | `reglement` | fait | #12 | Poser une question et lire les avis ; publier dans la FAQ et supprimer restent sur le site |
| `annuaire` | — | fait | #12 |  |

### #13 — Mes lots & accès et Prestataires

Session parallèle. Dossiers : `Fonctions/Acces`, `Fonctions/Prestataires`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `mon-lot` | `lots` | fait | #13 | `Fonctions/Acces` — locataire, bailleur, autres ; le tableau des charges renvoie au site (calculé dans son front) |
| `mon-lot` | `badges` | fait | #13 | Détenus, signaler perdu, nouvel accès, déclarer ; accès confiés (locataire), vue par locataire (bailleur) |
| `mon-lot` | `telecommandes` | fait | #13 | Comme les badges |
| `mon-lot` | `location` | fait | #13 | En lecture (baux actifs, archives, inventaire) ; créer, terminer, l'inventaire : sur le site, et l'app le dit |
| `prestataires` | `prestataires` | fait | #13 | `Fonctions/Prestataires`, en lecture : recherche, filtres, fiches, avis ; les gestes du conseil : sur le site |
| `prestataires` | `contrats` | fait | #13 | En lecture : résumé, échéances, documents |
| `prestataires` | `consommations` | fait | #13 | En lecture : compteurs, relevés par année, photos |

### #14 — Communauté, FAQ, Profil et Notifications

Session parallèle. Dossiers : `Fonctions/Communaute`, `Fonctions/FAQ`, `Fonctions/Profil`, `Fonctions/Notifications`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `communaute` | `sondages` | fait | #14, #38 | Liste ; fiche comme celle du site (`SondageView`) : réponse à préciser, commentaire, charte, résultats et réponses libres, fil des commentaires (commenter, retirer, signaler) ; créer, modifier, stopper : site (conseil syndical) |
| `communaute` | `idees` | fait | #14 | Liste, filtre, vote, réponses, signalement, proposer ; corriger, statut, supprimer : site |
| `communaute` | `annonces` | fait | #14 | Filtres, tri, détail, contact, statut (auteur), réponses, déposer sans photo ; corriger, photos : site |
| `communaute` | `avis` | fait | #14 | Liste, filtre, donner, corriger, archiver, restaurer ; répondre, retenir, exporter : site |
| `faq` | — | fait | #14 | Lecture ; rédaction et réorganisation : site. Le masquage des catégories selon le statut ne vit que dans le front : non porté (coprofirst#2506) |
| `profil` | — | fait | #14 | Sous « Plus » ; photo, étages, démarche nouvel arrivant, décor des fêtes : site |
| `notifications` | — | fait | #14 | La cloche de chaque écran |

### #15 — Espace conseil syndical et Délégations

Après les écrans des résidents. Dossiers : `Fonctions/EspaceCS`, `Fonctions/Delegations`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `espace-cs` | `validations` | fait | #15 | Approuver (« Nouvel Arrivant ») ou rejeter un compte, accepter (codes remis) ou rejeter une demande d'accès ; l'annonce de la validation est celle du serveur, avec son ton (#55) |
| `espace-cs` | `badges` | fait | #15 | Consultation : recherche, type, porteur (rangé par le rang servi, #55), lot, accès, état ; enregistrer, corriger, exporter et retirer un accès restent au site |
| `espace-cs` | `reporting` | fait | #15 | Suivi des affaires et des entretiens périodiques (chiffres, répartitions croisées, affaires) ; Renouvellements, le relevé servi (#56) ; relance du syndic, points CS / Syndic, résumés, fusion, PDF et Prestataires restent au site |
| `espace-cs` | `annonces-hall` | fait | #15 | Créer (titre, message, périmètre, format, Diffusion CS / syndic / copie), archives : renvoyer, archiver, restaurer, supprimer — les gestes que le serveur ouvre (#56) ; photos, assistant, aperçu, reprise du fil, WhatsApp et PDF restent au site |
| `espace-cs` | `annuaire` | fait | #15 | Conseil (AG, WhatsApp, président) et syndic (cabinet, interlocuteur principal, ordre), fiches à ajouter, corriger, retirer ; le rapprochement par le nom, servi à la frappe (#55) ; les consignes de la fiche arrivant restent au site |
| `espace-cs` | `courriels` | fait | #15 | Le journal de la relève : verdict, motif, affaire rejointe |
| `delegations` | — | fait | #15 | Liste, Accepter (l'aidant), Révoquer, Nouvelle délégation (conseil) ; lecture seule (coprofirst#1534) ; gestes servis (`peut_accepter`, `peut_revoquer`) et réponses typées (#56) |

### #16 — Administration, en partie

Après l'Espace CS. Quatre onglets dans l'app ; le reste du Paramétrage est « site seulement » (arbitrage du 03/11/2026), et l'app le signale : la pastille « Sur le site » liste les onglets que le compte ouvre, chacun avec son lien. Dossier : `Fonctions/Admin`, cadre commun `Commun/Onglets/`.

| Page | Onglet | État | Ticket | Note |
|---|---|---|---|---|
| `admin` | `a_traiter` | fait | #16 | La file des comptes et des commandes, la même que l'Espace CS ; les demandes de profil (approuver, rejeter avec motif) |
| `admin` | `utilisateurs` | fait | #16, #89 | Recherche, type, compte ; la fiche : communauté (bannissement servi), rôles (les gestes que le serveur sert, contrat ≥ 1.18.0), auto-match, suppression. Modifier et l'accueil d'un arrivant restent au site, comme les rôles d'une installation antérieure |
| `admin` | `audit_lots` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `telemetry` | fait | #16 | Quatre vues, filtre gestionnaire, nombres clés, graphe, pages, utilisateurs actifs ; les six autres sections restent au site |
| `admin` | `imports` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `copropriete` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `perimetres` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `equipements` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `lots` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `fonctionnement` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `legal` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `services` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `smtp` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `whatsapp` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `ia` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `pages` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `connexion` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `emails` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `installation` | site seulement | #16 | Paramétrage : l'app renvoie au site |
| `admin` | `maintenance` | fait | #16 | Santé des tâches (opérateur), dernier export (administration) ; lancer, vérifier, exporter restent au site |
| `admin` | `installations` | site seulement | #16 | Paramétrage : l'app renvoie au site |
