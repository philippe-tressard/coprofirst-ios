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
| **Archiver, pas supprimer** | geste de balayage « Archiver » dans la liste ; Archives repliées sous la liste ; « Restaurer » sans confirmation |
| **Droits** : l'écran dit ce que dit le serveur | un bouton n'apparaît que si le droit servi l'autorise |
| **Mouvement** : retour au toucher, rien d'animé sans fin hors attente, mouvement réduit respecté | animations système et ressorts ; `accessibilityReduceMotion` lu, jamais ignoré |
| **Explication** : jamais un survol seul | pas de survol au doigt : `popover` ou texte visible |
| **Charte** : tailles et couleurs par jeton | Dynamic Type (`.font(.body)`…) ; couleurs d'état **générées** depuis `socle.css` |

## Divergences iOS déclarées

*(aucune encore — chacune s'écrit ici avec sa date, sa raison et l'écran web qu'elle
quitte)*
