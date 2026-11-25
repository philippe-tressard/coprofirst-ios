#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# verifier-depot.sh — les garde-fous du dépôt qui ne demandent pas Xcode.
# Lancé par la CI, par le hook pre-commit et à la main ; sortie non nulle = refus.
#
#   1. aucun fichier versionné de plus de 500 lignes (standards/02 §6)
#   2. ni BOM ni CRLF (standards/10)
#   3. bit d'exécution sur les scripts, et sur eux seuls (standards/08 §3)
#   4. syntaxe de chaque script bash et Python (standards/05 §6)
#   5. LICENSE = permission App Store + texte de l'AGPL, assemblés par
#      `--ecrire-licence` : les deux textes vivent dans LICENSES/, LICENSE n'en est
#      que la réunion, et ce contrôle refuse qu'il en diverge.
#   6. aucune automatisation ne soumet à Apple : rien ne part en revue sans le
#      « oui » écrit de Philippe pour la version (skill publication-app-store).
#   7. aucune couleur écrite à la main dans l'app : elles se génèrent depuis
#      coprofirst dans la `Palette` (scripts/generer.py) ; seuls les fichiers de
#      chaque palette en portent, et une dispense qui ne couvre plus aucune couleur
#      échoue. Un fichier de `Fonctions/<Menu>/Genere/` porte l'en-tête
#      « GÉNÉRÉ » en 1re ligne — et aucune couleur (#34) ;
#   8. aucun moteur web pour le texte du site : ni WebKit, ni conversion HTML de
#      NSAttributedString — le HTML passe par TexteDuSite, seul (#22) ;
#   9. aucun chemin de .claude/worktrees/ suivi : les worktrees des sessions
#      parallèles sont des dépôts, pas des fichiers du projet ;
#  10. la table de parité avec le site (Parite/PARITE.md) classe chaque onglet,
#      et le registre des menus dit vrai (scripts/verifier-parite.py, #10) ;
#  11. un générateur ne lit coprofirst qu'à une version PUBLIÉE, et coprofirst-site
#      qu'à un commit épinglé (#51), par scripts/generateurs/_source.py seul : ni
#      clone, ni arbre de travail, ni branche (#34, #20) ; une table du site se lit
#      dans la pièce jointe tables-clients.json, par son nom et à la forme attendue,
#      jamais par motif dans une source du front — autotest de scripts/concordance.py
#      (#128) ; le logo, lui, se compare et se recopie à l'étiquette du plancher
#      (scripts/plancher.sh, #133 ; jugé par scripts/controles-distants.sh) ;
#  12. chaque réponse de l'API simulée a la forme du schéma du serveur
#      (scripts/verifier-fixtures.py, bogue des badges du 05/11/2026) ;
#  13. les tests au simulateur : relance bornée et déclarée (#50), un passage qui ne
#      joue rien rendu INCONNU (#96), un seul passage à la fois sur le poste et
#      l'arrêt par le pid (#108) — autotests de scripts/bilan_tests_ui.py et
#      scripts/tests-simulateur.sh ; le simulateur choisi sans hasard — autotest de
#      scripts/destination_simulateur.py (#112) ;
#  14. les tickets de la concordance : un vert ferme, un rouge ou un INCONNU jamais —
#      autotest de scripts/tickets_concordance.py (#67).
#  15. la simulation ne part pas en production : `ServiceSimule`, ses jeux de
#      données et `-api-simulee` sous `#if DEBUG` seulement (scripts/verifier-simule.py,
#      autotest d'abord, #84) ;
#  16. ce que le serveur SERT ne se recalcule pas : aucune table ni aucun prédicat
#      retiré ne revient (scripts/verifier-regles-servies.py, #83) ; un geste refusé dit
#      la phrase du serveur, exceptions nommées (scripts/verifier-refus.py, #262) ;
#  17. dans les tests d'interface, toute attente passe par le point d'attente
#      commun (CoproFirstUITests/Attente.swift) et son plafond : ni prédicat (#123),
#      ni existence, ni délai écrits sur place, et une sonde ne s'affirme pas (#147) ;
#  18. la confidentialité déclarée est celle du code : manifeste embarqué, fiche de
#      l'App Store et code concordent sur ce qui se mesure — API à raison requise,
#      envois, modules, droits, paquets (scripts/verifier-confidentialite.py, #19) ;
#  19. DEPENDANCES.md dit ce que Package.resolved épingle : chaque paquet embarqué de
#      la fiche y est listé embarqué, et chaque version écrite est l'épinglée
#      (scripts/verifier-dependances.py, #143) ;
#  20. l'aperçu servi d'une saisie passe par UNE porte, `ApercuServi` (#129, #130,
#      #135) : ni ses trois routes, ni son service, ni son délai ailleurs ;
#  21. ce que lit coprofirst ou demande reuse : écart au plancher, logo (et sa
#      référence, le plancher), REUSE, chacun sous une borne qui coupe son groupe de
#      processus — autotest de scripts/borne.py (#293) —
#      (scripts/controles-distants.sh) — et ce script est la seule étape du job
#      « Dépôt » de la CI (scripts/verifier-ci.py, #241), qui tient aussi chaque job
#      macOS plafonné et exigé par l'agrégat (#288). INCONNU (sortie 2) ≠ vert.
#
# Il juge les fichiers que git connaît (index compris) : un fichier ignoré n'est
# pas livré, il n'a pas à passer.
set -uo pipefail
cd "$(dirname "$0")/.."

PERMISSION=LICENSES/LicenseRef-CoproFirst-AppStore.txt
AGPL=LICENSES/AGPL-3.0-or-later.txt

assembler_licence() {
  cat "$PERMISSION"
  printf '\n%s\n\n' "================================================================================"
  cat "$AGPL"
}

if [ "${1:-}" = "--ecrire-licence" ]; then
  assembler_licence > LICENSE
  echo "✅ LICENSE réassemblé depuis LICENSES/"
  exit 0
fi

ECHECS=0
echec() { echo "❌ $*"; ECHECS=$((ECHECS + 1)); }
# Les règles par motif (couleurs, lecture de coprofirst, portes de la session et des aperçus,
# attentes des tests) : motifs, refus et autotests dans scripts/regles-depot.sh.
# shellcheck source=scripts/regles-depot.sh
. scripts/regles-depot.sh || { echo "❓ INCONNU : scripts/regles-depot.sh illisible"; exit 2; }

FICHIERS=$(git ls-files --cached)
[ -n "$FICHIERS" ] || { echo "❓ INCONNU : git ne connaît aucun fichier (rien d'indexé ?)"; exit 2; }
# Le code Swift de l'app, ses quatre cibles : la liste des dossiers est UNE, dans
# scripts/portee.py, que SwiftLint et chaque juge lisent aussi (#341) — une cible neuve n'y
# échappe pas par son dossier : non déclarée, portee.py la refuse.
CODE_APP=$(python3 -I scripts/portee.py --motif code) || { echo "❓ INCONNU : scripts/portee.py illisible"; exit 2; }
PORTEE=$(python3 -I scripts/portee.py) || { echo "$PORTEE"; echec "portée des contrôles : une cible hors de SwiftLint ou d'un juge (#341)"; }

# Les seuls fichiers dispensés de la limite de longueur — produits par un outil,
# jamais écrits à la main. Toute autre exception se discute, elle ne s'ajoute pas.
DISPENSES_LONGUEUR='^(LICENSE|LICENSES/.*|Paquets/ClientAPI/Sources/ClientAPI/openapi\.json|.*Package\.resolved)$'

while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Un binaire n'a ni lignes ni fins de ligne.
  grep -Iq . "$f" 2>/dev/null || continue
  if ! [[ "$f" =~ $DISPENSES_LONGUEUR ]]; then
    n=$(wc -l < "$f" | tr -d ' ')
    [ "$n" -le 500 ] || echec "$f : $n lignes (> 500) — découper (standards/02 §6)"
  fi
  [ "$(head -c 3 "$f" | od -An -tx1 | tr -d " \n")" != "efbbbf" ] || echec "$f : BOM UTF-8"
  ! grep -q $'\r' "$f" || echec "$f : fins de ligne CRLF"
done <<< "$FICHIERS"

# `git ls-files --stage` : « <mode> <objet> <étape>\t<chemin> ».
while IFS=$'\t' read -r meta f; do
  mode=${meta%% *}
  if [[ "$f" == *.sh || "$f" == .githooks/* ]]; then
    [ "$mode" = "100755" ] || echec "$f : mode $mode, attendu 100755 (git update-index --chmod=+x)"
    bash -n "$f" 2>/dev/null || echec "$f : syntaxe bash invalide"
  elif [[ "$f" == *.py ]]; then
    # Un script Python lancé directement porte son shebang et son bit d'exécution.
    if head -1 "$f" | grep -q '^#!'; then
      [ "$mode" = "100755" ] || echec "$f : shebang sans bit d'exécution (git update-index --chmod=+x)"
    fi
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$f" 2>/dev/null \
      || echec "$f : syntaxe Python invalide"
  elif [ "$mode" = "100755" ]; then
    echec "$f : exécutable sans être un script (git update-index --chmod=-x)"
  fi
done < <(git ls-files --stage)

autotest_couleurs || echec "verifier-depot.sh : autotest des couleurs en échec"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_couleur "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done < <(grep -E "$CODE_APP" <<< "$FICHIERS")

autotest_lecture || echec "verifier-depot.sh : autotest de la lecture de coprofirst en échec"
# Les autotests des scripts : leur liste se DÉRIVE (standards/04 §11), jamais tenue à la main
# — tout script de scripts/ qui porte `--autotest` est lancé ici, avant chaque juge. Exceptions
# déclarées : ce script, et deux morceaux sourcés que joue l'autotest de tests-simulateur.sh.
# Ce que prouvent les autotests nommés à l'en-tête y est dit ; s'y ajoutent l'app montre
# livrée dépendante de l'iPhone (verifier-montre-dependante.sh, #226 ; la construction
# Release se juge en CI), la PR de documentation seule, qu'un .swift relance (#204), et le
# contrôle avant soumission, qui refuse un rouge comme un INCONNU (avant_soumission.py, #205).
SOURCES_AUTOTEST="scripts/verifier-depot.sh scripts/autotest-tests-simulateur.sh scripts/verrou-simulateur.sh"
for f in $SOURCES_AUTOTEST; do grep -q -e '--autotest' "$f" || echec "$f : exception sans --autotest, à retirer"; done
while IFS= read -r f; do
  case " $SOURCES_AUTOTEST " in *" $f "*) continue ;; esac
  case $f in *.py) python3 -I "$f" --autotest ;; *) bash "$f" --autotest ;; esac >/dev/null 2>&1 \
    || echec "${f#scripts/} : autotest en échec"
done < <(grep -l -e '--autotest' scripts/*.py scripts/*.sh)
python3 -I scripts/generer.py --sources >/dev/null || echec "generer.py : un générateur déclare un fichier dont la release publie les constantes (#237), ou l'autotest du refus échoue"
grep -qx "$SOURCE_UNIQUE" <<< "$FICHIERS" || echec "$SOURCE_UNIQUE absent : la règle de provenance n'a plus de source"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_lecture "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done < <(grep -E "$GENERATION" <<< "$FICHIERS")

bash scripts/plancher.sh > /dev/null || echec "scripts/plancher.sh : plancher illisible (INCONNU)"

# Les réponses de l'API simulée contre le schéma du serveur : l'autotest d'abord, puis
# le juge. INCONNU (sortie 2) est un échec, jamais un succès.
FIXTURES=$(python3 -I scripts/verifier-fixtures.py) || { echo "$FIXTURES"; echec "API simulée hors du schéma du serveur"; }

# Ce que le serveur SERT ne se recalcule plus (#83) : une table ou un prédicat retiré
# qui revient échoue. L'autotest d'abord ; INCONNU (sortie 2) est un échec.
SERVIES=$(python3 -I scripts/verifier-regles-servies.py) || { echo "$SERVIES"; echec "une règle servie est recalculée dans l'app"; }
REFUS=$(python3 -I scripts/verifier-refus.py) || { echo "$REFUS"; echec "une écriture tait la phrase du serveur (#262)"; }

# Le texte riche du site passe par UNE porte, sans WebKit (#22) : WKWebView exécute
# et charge, NSAttributedString(.html) passe par WebKit et charge des ressources
# distantes. Ni l'un ni l'autre dans l'app.
MOTEUR_WEB='import WebKit|WKWebView|\.documentType|DocumentType\.html|NSAttributedString\(data:'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Le code seul : un commentaire qui explique l'interdit a le droit de le nommer.
  trouve=$(grep -nE "$MOTEUR_WEB" "$f" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || echec "$f : moteur web pour du HTML (${trouve%%:*}) — passer par TexteDuSite"
done < <(grep -E "$CODE_APP" <<< "$FICHIERS")

autotest_porte_session || echec "verifier-depot.sh : autotest des portes de la session en échec"

autotest_porte_apercu || echec "verifier-depot.sh : autotest de la porte des aperçus en échec"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_porte_session "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
  motif=$(refus_porte_apercu "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
done < <(grep -E "$CODE_APP" <<< "$FICHIERS")

# Les gestes qui envoient une version en revue chez Apple : soumission à l'App
# Store, distribution aux testeurs externes de TestFlight. Ils n'ont pas de place
# dans une automatisation — la soumission est manuelle, après validation du rendu.
GESTES_REVUE='submit_for_review|distribute_external|upload_to_app_store|deliver|submit-for-review|reviewSubmissions'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if grep -nEi "$GESTES_REVUE" "$f" >/dev/null; then
    echec "$f : geste de soumission à Apple automatisé ($(grep -oEi "$GESTES_REVUE" "$f" | head -1)) — interdit, skill publication-app-store"
  fi
done < <(grep -E '^(fastlane/|\.github/workflows/)' <<< "$FICHIERS")

# Un worktree de session ajouté par erreur arrive comme lien de sous-module ou
# comme fichiers : les deux se voient dans l'index.
if grep -qE '^\.claude/worktrees(/|$)' <<< "$FICHIERS"; then
  echec ".claude/worktrees/ est suivi — git rm -r --cached .claude/worktrees (exclu par .gitignore)"
fi

# La parité : son autotest d'abord (un contrôle qui ne refuse rien ne prouve rien),
# puis la table elle-même. INCONNU (sortie 2) est un échec, jamais un succès.
PARITE=$(python3 -I scripts/verifier-parite.py) || { echo "$PARITE"; echec "parité avec le site (Parite/PARITE.md)"; }

autotest_attente || echec "verifier-depot.sh : autotest des attentes par prédicat en échec"
grep -qx "$POINT_ATTENTE" <<< "$FICHIERS" || echec "$POINT_ATTENTE absent : les attentes n'ont plus de point commun"
ATTENTES=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  motif=$(refus_attente "$f" "$f")
  [ -z "$motif" ] || echec "$f : $motif"
  [ "$f" = "$POINT_ATTENTE" ] || ! grep -qE '\.(attendre\("|apparait\(\)|disparait\(\))' "$f" || ATTENTES=$((ATTENTES + 1))
done < <(grep -E '^CoproFirstUITests/.*\.swift$' <<< "$FICHIERS")
# Un point commun que personne n'emploie ne remplace rien.
[ "$ATTENTES" -gt 0 ] || echec "aucun test n'attend par $POINT_ATTENTE : le point commun n'est pas employé"

# La mise en page se décide sur la classe de taille, jamais sur l'appareil (#222) : un
# iPhone pliable déplié est un iPhone en classe régulière (#119). Le dossier doit exister,
# sinon le contrôle ne contrôle rien (standards/04).
if [ -d CoproFirst/Commun/MiseEnPage ]; then
  IDIOME=$(grep -rn 'userInterfaceIdiom' CoproFirst/Commun/MiseEnPage || true)
  [ -z "$IDIOME" ] || { echo "$IDIOME"; echec "Commun/MiseEnPage lit l'appareil : horizontalSizeClass, jamais userInterfaceIdiom"; }
else
  echec "CoproFirst/Commun/MiseEnPage absent : le contrôle de l'idiome ne contrôle rien"
fi

# Tirer pour actualiser passe par `.actualisable`, qui pose aussi ⌘R à l'iPad (#223) ; le
# point commun doit s'employer, sinon le contrôle ne contrôle rien (standards/04).
P_ACT=CoproFirst/Commun/Composants/Actualisable.swift
grep -rq '\.actualisable' CoproFirst --include='*.swift' || echec "$P_ACT jamais employé : le contrôle ne contrôle rien"
NUS=$(grep -rn '\.refreshable' CoproFirst --include='*.swift' | grep -v "^$P_ACT:" || true)
[ -z "$NUS" ] || { echo "$NUS"; echec "\.refreshable nu : .actualisable, qui pose aussi ⌘R (#223)"; }
# De même, une recherche passe par ChampRecherche ou .barreDeRecherche, qui posent ⌘F (#223).
P_RECH=CoproFirst/Commun/Composants/ChampRecherche.swift
NUS=$(grep -rnE '\.searchable\(|\.submitLabel\(\.search\)' CoproFirst --include='*.swift' | grep -v "^$P_RECH:" || true)
[ -z "$NUS" ] || { echo "$NUS"; echec "recherche nue : ChampRecherche ou .barreDeRecherche, qui posent ⌘F (#223)"; }

# Un toucher passe par le point commun (#217) : plafond décroissant des tap() directs.
TOUCHERS=$(bash scripts/verifier-touchers.sh) || { echo "$TOUCHERS"; echec "touchers hors du point commun (#217)"; }

# La simulation reste aux builds Debug (#84) : l'autotest prouve que le juge refuse
# un symbole hors de `#if DEBUG`, puis le juge lit l'app. INCONNU (2) est un échec.
SIMULE=$(python3 -I scripts/verifier-simule.py) || { echo "$SIMULE"; echec "simulation hors de #if DEBUG"; }

# Un Label identifié est lu en un élément (#183) : sous iOS 26, son identifiant se
# résout en son image, et la requête du test tourne jusqu'au délai.
IDENTIFIANTS=$(python3 -I scripts/verifier-identifiants.py) || { echo "$IDENTIFIANTS"; echec "Label identifié lu en plusieurs éléments"; }
# Les séparateurs du site se lisent dans la table générée (#188) : aucun ne finit une ligne.
SEPARATEURS=$(python3 -I scripts/verifier-separateurs.py) || { echo "$SEPARATEURS"; echec "séparateur sécable ou recopié"; }
# Formats, mesures, lectures et recopies par leur point commun, exceptions comptées (#345 à #348).
ECRITURES=$(python3 -I scripts/verifier-ecritures-vues.py) || { echo "$ECRITURES"; echec "format, mesure, lecture ou recopie écrits à la main"; }

# Un hôte fictif se prend dans un nom réservé (#214, standards/03 §8 quater) : exemple.fr
# est un vrai domaine tiers, qui recevrait requêtes et cookies d'un test égaré.
HOTES=$(python3 -I scripts/verifier-hotes.py) || { echo "$HOTES"; echec "hôte fictif hors des noms réservés"; }
# Une personne nommée dans le code ou un test est inventée et déclarée (#352, standards/14 §9).
IDENTITES=$(python3 -I scripts/verifier-identites.py) || { echo "$IDENTITES"; echec "nom de personne hors de la liste blanche"; }
# Un jeton se garde dans UN JetonMasque, l'en-tête Authorization s'écrit à UN endroit (#342).
JETONS=$(python3 -I scripts/verifier-jetons.py) || { echo "$JETONS"; echec "jeton en clair, ou en-tête écrit hors de JetonAppareil"; }
# Un numéro de téléphone se prend dans une racine réservée aux fictions par l'ARCEP (#359, #375).
NUMEROS=$(python3 -I scripts/verifier-numeros.py) || { echo "$NUMEROS"; echec "numéro de téléphone hors des racines fictives"; }

# Confidentialité déclarée = confidentialité réelle (#19) : l'autotest d'abord, puis le
# manifeste, la fiche et le code. Ce que le juge ne mesure pas, il le dit INCONNU à chaque
# passage — la ligne s'affiche, elle ne compte pas pour conforme.
CONFIDENTIALITE=$(python3 -I scripts/verifier-confidentialite.py) || { echo "$CONFIDENTIALITE"; echec "confidentialité déclarée ≠ code"; }
grep '^❓' <<< "$CONFIDENTIALITE" || true

# L'inventaire des dépendances tenu à Package.resolved (#143) : l'autotest d'abord.
DEPENDANCES=$(python3 -I scripts/verifier-dependances.py) || { echo "$DEPENDANCES"; echec "DEPENDANCES.md ≠ Package.resolved, ou un composant tiers sans ses textes"; }

# Le job « Dépôt » de la CI n'a qu'une étape, ce script (#241) : poste, hook et CI jouent
# la même chose, réseau et REUSE compris. Sans réseau ni reuse : INCONNU, jamais vert.
JOBS_CI=$(python3 -I scripts/verifier-ci.py) || { echo "$JOBS_CI"; echec "CI : job « Dépôt » à plus d'une étape, job macOS hors de l'agrégat, ou classe de l'iPad seul hors de l'échantillon iPad"; }
DISTANTS=$(bash scripts/controles-distants.sh)
DISTANTS_CODE=$?
[ "$DISTANTS_CODE" -eq 0 ] || echo "$DISTANTS"
[ "$DISTANTS_CODE" -eq 2 ] || [ "$DISTANTS_CODE" -eq 0 ] || echec "contrôles distants (plancher, logo, REUSE)"

if ! cmp -s LICENSE <(assembler_licence); then
  echec "LICENSE diverge de LICENSES/ — bash scripts/verifier-depot.sh --ecrire-licence"
fi

if [ "$ECHECS" -gt 0 ]; then
  echo "── $ECHECS échec(s)"
  exit 1
fi
[ "$DISTANTS_CODE" -eq 0 ] || { echo "❓ INCONNU : le reste est conforme, les contrôles distants n'ont pas joué"; exit 2; }
echo "✅ dépôt conforme : longueur, encodage, modes, syntaxe, LICENSE, aucune soumission automatisée, ${PORTEE#✅ }, aucune couleur à la main, coprofirst lu à une version publiée, aucun moteur web, ce qu'une session laisse effacé à une porte, aperçus d'une saisie à une porte, aucun worktree suivi, relance des tests bornée, passage vide refusé, un passage à la fois, simulateur choisi sans hasard, attentes par le point commun, tickets de la concordance, simulation sous #if DEBUG, règles servies lues, séparateurs générés, Label identifiés lus en un élément, mise en page sur la classe de taille, actualiser par .actualisable (⌘R), rechercher par le point commun (⌘F), hôtes fictifs réservés, ${IDENTITES#✅ }, jetons masqués, détection « documentation seule », job « Dépôt » à une étape, jobs macOS plafonnés et exigés par l’agrégat, classes de l’iPad seul jouées sur iPad, ${DISTANTS#✅ }, ${TOUCHERS#✅ } ; ${PARITE#✅ } ; ${FIXTURES#✅ } ; $(grep '^✅' <<< "$CONFIDENTIALITE" | sed 's/^✅ //') ; ${DEPENDANCES#✅ } ($(wc -l <<< "$FICHIERS" | tr -d ' ') fichiers)"
