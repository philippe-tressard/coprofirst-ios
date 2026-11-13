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
| **Saisie Essentielle ou Complète** (coprofirst#2595) : en Essentielle, ce qui n'est pas essentiel pour la catégorie se range dans « Plus de détails », en fin de formulaire ; une section éteinte n'y entre pas | le mode se **lit** (`saisie_affaire_effective`), les sections aussi (`sections_essentielles`) : `FormeDeSaisie` range, ne décide rien (#69) ; la Création et l'Édition la composent par le même initialiseur, et l'Édition l'ouvre composée (#110) |
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
| **Aperçu d'une saisie** (#129, #130, #135) | ce que la résidence fera de ce qu'on saisit se DEMANDE, jamais ne se compose : « Qui la lira » en section sous les champs de la Création (pastille même par défaut, phrase entière, avertissement), le lieu choisi sous le sélecteur (épingle, même pour le défaut), « Nom affiché » sous le prénom et le nom. Toujours SOUS ce qu'on touche, la place réservée : rien ne bouge sous le doigt quand la réponse arrive ; la valeur change en fondu court, rien ne s'anime pendant l'attente (ni roue, ni grisé) ; VoiceOver lit la valeur courante ; sans réseau, la dernière réponse reste et la saisie n'est jamais bloquée | `Commun/Apercu/` |
| **Consultation hors ligne** (#101) | sans réseau, Face ID passé, la dernière lecture s'ouvre ; l'état se lit en haut (`BandeauHorsLigne` : « Hors ligne — à jour au 10/11/2026 à 14:32 », puis « Consultation seule »), jamais par une alerte ; chaque geste reste à sa place, grisé, sa raison lue par VoiceOver (`.gesteEnLigne()`) — rien ne disparaît, rien ne bouge ; le réseau revenu, la session reprend sans redemander Face ID et tout se relit ; une lecture de plus de 7 jours est effacée et l'écran de retour le dit. Les droits affichés datent peut-être : on n'offre pas un geste que le serveur pourrait refuser | `Session/LectureGardee/`, `Commun/Composants/` |

## Divergences iOS déclarées

Chacune s'écrit ici avec sa date, sa raison et l'écran web qu'elle quitte.

| Date | Écran web quitté | Divergence iOS | Raison |
|---|---|---|---|
| 10/11/2026 | La rangée d'icônes d'une affaire (`ActionsTicket.svelte`) | Rendue en **barre d'outils du bas** (`BandeauAffaire`), la barre d'onglets masquée sur la fiche ; 💬 Répondre n'est offert **ni au conseil syndical ni à l'administration**, même si `peut_repondre` le permet — eux suivent l'affaire par 🔄 « Ajouter une suite » | Décision de l'utilisateur ; le bas de l'écran est l'endroit du pouce, et le matériau du système y laisse défiler le texte (`apple-design` §12) |
| 10/11/2026 | 🔗 « Copier le lien » (`BoutonLien`) | Un toucher copie, comme le site ; l'appui long offre aussi « Partager… » | Le geste natif du partage, en second geste choisi — la copie reste à un toucher |
| 10/11/2026 | ✏️ « Modifier » d'une affaire (`FormulaireTicket` en édition) | Modifie l'**affaire** (#91) : catégorie, titre, description, lieu, urgence — les champs de la Création (`ChampsAffaire`), et seuls les champs changés partent. Une description mise en forme (gras, liste, lien) se montre sans se modifier ; plusieurs lieux aussi. Titre de feuille « Modifier » ; corriger une **suite** se fait sur son entrée de l'Historique (ligne du 12/11/2026) | Rien ne se réenregistre en perdant ce que l'app ne sait pas écrire ; un droit non servi ne s'affiche pas |
| 11/11/2026 | ✏️ « Modifier » d'une affaire engagée (`FormulaireTicket`, crayon `peut_corriger`) | Le crayon suit `peut_corriger`, comme le site (#127) ; sans `peut_modifier` (l'affaire n'est plus ouverte), la feuille montre le contenu (catégorie, titre, description, lieu) **grisé**, sous une phrase qui le dit — l'urgence reste réglable. Le site laisse saisir et refuse à l'envoi | La feuille de l'app ne porte que le contenu et l'urgence : un refus au bout d'une saisie perdue n'apprend rien, le droit servi se dit avant |
| 11/11/2026 | « Intervenant » de la fiche d'une affaire (`intervenantAffiche`) | Le prestataire et le rythme SERVI (`frequence_libelle`, celui du contrat d'abord, #125), sans « sous contrat n° … » | Le cadre du contrat se compose dans le front du site ; l'app attend qu'il soit servi |
| 10/11/2026 | La Suite d'une actualité (`etatsDeLaSuite`) | Commentaire seul : le suivi d'actualité (`SUIVI_ACTUALITE_OPTIONS`) reste au site | Ses états ne sont pas encore générés |
| 12/11/2026 | ✏️ et 🗑️ d'une entrée de l'Historique (`RubriqueHistorique.svelte`, `SuiteAffaire.svelte` en correction) | Un bouton « ⋯ » à droite de l'entrée ouvre le menu du système — « Modifier la suite », « Supprimer cette entrée » — au lieu de deux icônes côte à côte ; les mêmes gestes sont des actions d'accessibilité de l'entrée. Chacun selon le droit servi avec l'entrée (`peut_modifier`, `peut_supprimer`, contrat 1.19.0, typés au plancher) : absents, aucun. La correction rouvre la feuille de la Suite (#91) : le Suivi et le texte seuls, et seul ce qui a changé part — pièces jointes, lieu, équipement, dates, intervenant et destinataires de l'entrée se corrigent sur le site ; un texte mis en forme se montre sans se modifier. La suppression se confirme, avec les mots du site | Deux cibles de 44 pt ne tiennent pas dans l'en-tête d'une entrée au très grand texte, et l'irréversible ne se pose pas à un doigt du crayon ; la feuille ne réécrit que ce qu'elle montre |
| 10/11/2026 | Le fil des messages d'une affaire (`FilMessagesTicket.svelte`) | Intitulé « Messages » sous l'Historique (le site n'en met pas) ; la bulle dit « Vous » pour le compte (`est_auteur` servi, contrat 1.26.0, #138) et se range de son côté ; le nom servi (`auteur_nom`) sinon, la qualité servie (`auteur_qualite`) d'une installation antérieure (`FilMessagesAffaire`) | Deux fils sur un même écran : l'intitulé les distingue ; « Vous » dit la bulle du compte sans répéter son nom |
| 11/11/2026 | La pastille de lecture d'une carte (`PastilleLecture.svelte`), qui ouvre sa bulle au toucher ; le badge 🔹 du lieu (`BadgePerimetre`) | Sur une carte, la pastille ne s'ouvre pas : le toucher ouvre le contenu, et la phrase entière se lit sur le détail d'une affaire (« Qui la lit », `LectureDetaillee`) ; VoiceOver lit la phrase de la bulle sur la carte. Le lieu servi garde l'épingle de l'app (`EtiquetteLieu`, déjà sur les affaires) au lieu du 🔹 ; « Périmètre précisé : 🔹 … » d'une Suite s'affiche tel que servi (#129, #130) | Une carte est un seul bouton (une cible dans une cible se rate au doigt) ; l'épingle était le rendu du lieu dans l'app avant #130 : un même objet garde un rendu |
| 11/11/2026 | Les pièces jointes dépliées (`PiecesJointes.svelte`, format « grand » : galerie qui défile, chaque photo entière ; visionneuse du site) | Une **mosaïque** à la Messages (`MosaiquePhotos` : 1, 2, ou une grande et deux petites avec « +N »), tuiles recadrées, hauteur fixe ; la photo entière et les documents s'ouvrent dans **Coup d'œil**, qui feuillette toutes les photos de l'élément. Même composant dans l'affaire, l'Historique, les messages, le résumé du fil et l'annonce ; la carte fermée garde la vignette du site (`VignettePieces`) | Proposition retenue par l'utilisateur parmi cinq ; Coup d'œil apporte zoom, partage et impression du système |
| 12/11/2026 | « Qui la lira » d'une affaire en saisie : badge et aide de la section Destinataires (`SectionDestinataires.svelte`) ; le sélecteur de périmètre (`PerimetrePicker.svelte`), qui ne nomme pas la sélection ; le Profil, qui ne montre pas le nom affiché | « Qui la lira » est une section à part, sous les champs de la Création (`QuiLaLira`) ; sous le lieu d'une affaire et sous le périmètre d'une affiche de hall, le lieu retenu en clair (`LieuDeLaSaisie`, même par défaut) ; sous le prénom et le nom (Profil, fiche de l'annuaire du conseil), « Nom affiché » (`NomDeLaSaisie`). Tous trois DEMANDÉS au serveur (#129, #130, #135) | La feuille ne pose pas de Destinataires : la pastille n'a pas de section où se ranger. Le lieu d'une affaire se choisit sur une page poussée qui ne montre que le nom du nœud (« Toit ») ; le nom servi dit avant l'envoi ce que les autres liront — rien n'est composé dans l'app |
| 10/11/2026 | « Supprimer les lues », dans l'en-tête de la page des notifications à côté de « Tout marquer lu » (`notifications/+page.svelte`) | En **tête de la liste**, sous le titre — « Tout marquer lu » reste dans la barre ; même libellé, même confirmation (`SUPPRESSION`), même phrase ensuite ; absent sans notification lue. « Modifier » → sélection → « Supprimer (n) », que le site n'a pas, reste pour un choix à la main | La barre du haut est pleine (« Tout marquer lu », « Modifier », « OK ») ; un geste définitif ne se pose pas à côté d'eux, et en tête de liste il grandit avec le texte au lieu d'une barre plafonnée (#53) |
| 13/11/2026 | Les prestataires d'une affaire en saisie (`FormulaireTicket`, section Intervenant : ↑ ↓ ✕ et « Ajouter un prestataire », coprofirst#2704) | Dans « Modifier », une ligne par prestataire avec son × (et le balayage pour retirer) ; l'ordre se change par « Monter » / « Descendre » au menu contextuel d'une ligne et en actions d'accessibilité, au lieu de deux flèches par ligne ; « Ajouter un prestataire » ouvre le menu du système. La **Suite** (🔄) n'en pose pas : elle n'a pas de section Intervenant dans l'app (#181) | Deux flèches et un × par ligne serraient trois cibles dans une rangée de `Form` ; le menu contextuel est le geste natif d'une action secondaire, l'ajout et le retrait restent à un toucher |
