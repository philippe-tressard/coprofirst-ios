---
name: ux-patterns-ios
description: "Traduire en iOS les patterns d'interface de CoproFirst (cadre une entité / quatre rendus, sections et pliage, archiver plutôt que supprimer, droits affichés = droits servis, mouvement, charte) — à charger avant tout parcours, écran d'entité, libellé ou message de l'app."
---

<!--
SPDX-FileCopyrightText: 2026 Philippe TRESSARD
SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
-->

# Patterns d'interface — leur traduction iOS

> Squelette posé à l'amorce (01/11/2026). **La source est la skill `ux-patterns` de
> coprofirst** (`.claude/skills/ux-patterns/SKILL.md` et `ARBITRAGES.md`, lus en
> lecture seule — `standards/08` §9 bis). Cette skill ne recopie ni ses règles ni ses
> arbitrages : elle dit **comment chacun se rend en SwiftUI**. Un arbitrage de
> coprofirst s'applique ici sans se rediscuter ; une divergence propre à iOS se
> déclare ci-dessous, avec sa raison (`standards/11` §14).

## Avant d'écrire un écran

1. Lire, dans la skill de coprofirst, la section de la notion **et** les entrées
   d'`ARBITRAGES.md` qui la touchent.
2. Regarder l'écran web correspondant (la démo : `demo.coprofirst.fr`) : même
   ordre, mêmes mots, mêmes gestes.
3. Vérifier ce que le serveur permet (le contrat généré) : l'écran ne propose
   ni plus ni moins que les droits servis.

## Correspondances posées

| Pattern de coprofirst | Rendu iOS |
|---|---|
| **Une entité, quatre rendus** (Affichage, Création, Édition, Évolution) | Affichage : écran poussé dans la `NavigationStack` ; Création et Édition : feuille (`.sheet`) à `Form` ; Évolution : entrée de l'Historique, ajoutée par « Ajouter une suite » |
| **Ordre des sections** | lu dans `front/src/lib/entites/types.ts` de coprofirst (`SECTIONS_ORDRE`) — à **générer**, comme les couleurs, jamais recopié |
| **Pliage** : obligatoire → déplié, facultatif → plié ; une valeur autre que le défaut rouvre | `DisclosureGroup` dont l'état initial se **calcule** de la même règle |
| **Saisie Essentielle ou Complète** (coprofirst#2595) : en Essentielle, ce qui n'est pas essentiel pour la catégorie se range dans « Plus de détails », en fin de formulaire ; une section éteinte n'y entre pas | le mode se **lit** (`saisie_affaire_effective`), les sections aussi (`sections_essentielles`) : `FormeDeSaisie` range, ne décide rien (#69) |
| **Archiver, pas supprimer** | geste de balayage « Archiver » dans la liste ; Archives repliées sous la liste ; « Restaurer » sans confirmation |
| **Droits** : l'écran dit ce que dit le serveur | un bouton n'apparaît que si le droit servi l'autorise |
| **Mouvement** : retour au toucher, rien d'animé sans fin hors attente, mouvement réduit respecté | animations système et ressorts ; `accessibilityReduceMotion` lu, jamais ignoré |
| **Explication** : jamais un survol seul | pas de survol au doigt : `popover` ou texte visible |
| **Charte** : tailles et couleurs par jeton | Dynamic Type (`.font(.body)`…) ; couleurs d'état **générées** depuis `socle.css` |

## Patterns propres à iOS

Ce que le site n'a pas, et qui se règle ici une fois.

| Pattern | Règle | Où |
|---|---|---|
| **Permission du système** (notifications, et toute alerte d'autorisation à venir) | jamais au lancement ni au premier écran : une **offre** dans l'écran où l'usage se voit (les notifications : en tête de la cloche), qui dit ce que la personne y gagne et ce qui ne part pas ; l'alerte d'iOS ne s'ouvre qu'après « Activer » ; « Plus tard » tait l'offre quelques jours ; un refus ne se redemande pas — seuls les Réglages d'iOS le rendent. Aucun réglage « sur mon téléphone » dans le Profil (spec push de coprofirst, §10 décision 4) | `OffrePush` (#17) |

## Divergences iOS déclarées

Chacune s'écrit ici avec sa date, sa raison et l'écran web qu'elle quitte.

| Date | Écran web quitté | Divergence iOS | Raison |
|---|---|---|---|
| 10/11/2026 | La rangée d'icônes d'une affaire (`ActionsTicket.svelte`) | Rendue en **barre d'outils du bas** (`BandeauAffaire`), la barre d'onglets masquée sur la fiche ; 💬 Répondre n'est offert **ni au conseil syndical ni à l'administration**, même si `peut_repondre` le permet — eux suivent l'affaire par 🔄 « Ajouter une suite » | Décision de l'utilisateur ; le bas de l'écran est l'endroit du pouce, et le matériau du système y laisse défiler le texte (`apple-design` §12) |
| 10/11/2026 | 🔗 « Copier le lien » (`BoutonLien`) | Un toucher copie, comme le site ; l'appui long offre aussi « Partager… » | Le geste natif du partage, en second geste choisi — la copie reste à un toucher |
| 10/11/2026 | ✏️ « Modifier » d'une affaire (`FormulaireTicket` en édition) | Modifie l'**affaire** (#91) : catégorie, titre, description, lieu, urgence — les champs de la Création (`ChampsAffaire`), et seuls les champs changés partent. Une description mise en forme (gras, liste, lien) se montre sans se modifier ; plusieurs lieux aussi. Titre de feuille « Modifier » ; corriger une **suite** de l'Historique attend que le serveur en serve le droit (coprofirst#2646) | Rien ne se réenregistre en perdant ce que l'app ne sait pas écrire ; un droit non servi ne s'affiche pas |
| 10/11/2026 | La Suite d'une actualité (`etatsDeLaSuite`) | Commentaire seul : le suivi d'actualité (`SUIVI_ACTUALITE_OPTIONS`) reste au site | Ses états ne sont pas encore générés |
| 10/11/2026 | Le fil des messages d'une affaire (`FilMessagesTicket.svelte`) | Intitulé « Messages » sous l'Historique (le site n'en met pas) ; la bulle dit « Vous » pour le compte (`est_auteur` servi, contrat 1.26.0, #138) et se range de son côté ; le nom servi (`auteur_nom`) sinon, la qualité servie (`auteur_qualite`) d'une installation antérieure (`FilMessagesAffaire`) | Deux fils sur un même écran : l'intitulé les distingue ; « Vous » dit la bulle du compte sans répéter son nom |
| 10/11/2026 | « Supprimer les lues », dans l'en-tête de la page des notifications à côté de « Tout marquer lu » (`notifications/+page.svelte`) | En **tête de la liste**, sous le titre — « Tout marquer lu » reste dans la barre ; même libellé, même confirmation (`SUPPRESSION`), même phrase ensuite ; absent sans notification lue. « Modifier » → sélection → « Supprimer (n) », que le site n'a pas, reste pour un choix à la main | La barre du haut est pleine (« Tout marquer lu », « Modifier », « OK ») ; un geste définitif ne se pose pas à côté d'eux, et en tête de liste il grandit avec le texte au lieu d'une barre plafonnée (#53) |
