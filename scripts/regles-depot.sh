#!/bin/bash
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
#
# regles-depot.sh — les règles par motif de verifier-depot.sh : leurs motifs, leur refus
# (`refus_<règle> CHEMIN FICHIER` rend le motif, ou rien) et leur autotest, qui prouve le
# refus dans les deux sens. SOURCÉ par verifier-depot.sh, qui les appelle et compte les
# échecs ; découpé de lui pour tenir sous 500 lignes (standards/02 §6). Rien ne s'y lance :
# des définitions seules.

# Les couleurs se GÉNÈRENT depuis les sources de coprofirst, dans la `Palette`
# (scripts/generer.py) : aucune couleur écrite à la main dans le code Swift de l'app.
COULEURS_MAIN='Color\(red:|UIColor\(red:|colorLiteral|RVBA\(0x|Color\.(red|blue|green|orange|yellow|purple|pink|black|white|gray)\b'
# Les seuls fichiers qui en portent : chaque palette générée (`Palette+<code>.swift`).
# Une dispense qui ne couvre plus de couleur échoue : une exception sans objet se retire.
DISPENSES_COULEUR='^CoproFirst/Charte/Palette\+[A-Z][a-z]+\.swift$'
# Un fichier qu'un générateur écrit dans le dossier d'un menu (`Fonctions/<Menu>/Genere/`, ou `Commun/<Domaine>/Genere/`)
# dit en 1re ligne qu'il est généré ; ses teintes, il les nomme dans la `Palette` (#34).
EN_TETE_GENERE='^// GÉNÉRÉ par scripts/generer\.py — NE PAS MODIFIER'
GENERE='^CoproFirst/(Fonctions|Commun)/[^/]+/Genere/[^/]+\.swift$'
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_couleur() {
  local couleur
  couleur=$(grep -noE "$COULEURS_MAIN" "$2" | head -1)
  if [[ "$1" =~ $DISPENSES_COULEUR ]]; then
    [ -n "$couleur" ] || echo "dispensé de la règle des couleurs sans en porter aucune — retirer la dispense"
    return
  fi
  if [[ "$1" =~ $GENERE ]] && ! head -1 "$2" | grep -qE "$EN_TETE_GENERE"; then
    echo "fichier de Genere/ sans l'en-tête « GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER » en 1re ligne"
  elif [ -n "$couleur" ]; then
    echo "couleur écrite à la main ($couleur) — un jeton de la Palette (générée)"
  fi
}
# Autotest, dans les deux sens : un contrôle qui ne refuse rien ne prouve rien.
autotest_couleurs() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.\nlet c = RVBA(0x01, 0x02, 0x03, 1)\n' > "$d/declare"
  printf '// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.\nlet t = \\.kanbanAg\n' > "$d/propre"
  printf '// Écrit à la main.\nlet c = RVBA(0x01, 0x02, 0x03, 1)\n' > "$d/nu"
  printf '// Écrit à la main.\nlet n = 1\n' > "$d/sans"
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/declare")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/propre")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Genere/T.swift "$d/sans")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Fonctions/M/Vue.swift "$d/nu")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Fonctions/M/Vue.swift "$d/sans")" ] || ok=1
  [ -z "$(refus_couleur CoproFirst/Charte/Palette+Seine.swift "$d/nu")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Charte/Palette+Seine.swift "$d/sans")" ] || ok=1
  [ -n "$(refus_couleur CoproFirst/Charte/PaletteKanban.swift "$d/nu")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}

# Une génération lit coprofirst à une version PUBLIÉE, et par `_source.py` seul (#34) :
# aucun autre script de génération n'ouvre un clone, une branche ou l'arbre de travail.
LECTURE_DIRECTE='COPROFIRST_RACINE|/Volumes/|subprocess|urllib|git (show|archive|-C)|rev-parse|\bHEAD\b|raw\.githubusercontent|refs/heads'
GENERATION='^scripts/(generer[^/]*|concordance[^/]*|generateurs/[^/]+)$'
SOURCE_UNIQUE='scripts/generateurs/_source.py'
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_lecture() {
  local trouve
  [[ "$1" =~ $GENERATION ]] || return
  if [ "$1" = "$SOURCE_UNIQUE" ]; then
    # La source elle-même : une version publiée, jamais une branche ni l'arbre d'un clone.
    trouve=$(grep -noE '\bHEAD\b|refs/heads|git |COPROFIRST_RACINE|/Volumes/' "$2" | head -1)
    [ -z "$trouve" ] || echo "la source lit autre chose qu'une version publiée ($trouve)"
    grep -q 'refs/tags/' "$2" || echo "la source ne lit plus l'archive d'une étiquette (refs/tags/)"
    return
  fi
  trouve=$(grep -noE "$LECTURE_DIRECTE" "$2" | head -1)
  [ -z "$trouve" ] || echo "lit coprofirst en direct ($trouve) — passer par ctx (generateurs/_source.py)"
}
autotest_lecture() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf 'x = subprocess.run(["git", "-C", f, "rev-parse", "HEAD"])\n' > "$d/tete"
  printf 'texte = ctx.lire("front/src/lib/pages.ts")\n' > "$d/propre"
  printf 'URL = "https://codeload.github.com/d/tar.gz/refs/tags/v1"\n' > "$d/source"
  printf 'URL = "https://codeload.github.com/d/tar.gz/refs/heads/main"\n' > "$d/branche"
  [ -n "$(refus_lecture scripts/generateurs/x.py "$d/tete")" ] || ok=1
  [ -n "$(refus_lecture scripts/generer.py "$d/tete")" ] || ok=1
  [ -z "$(refus_lecture scripts/generateurs/x.py "$d/propre")" ] || ok=1
  [ -z "$(refus_lecture scripts/verifier-logo.sh "$d/tete")" ] || ok=1
  [ -z "$(refus_lecture "$SOURCE_UNIQUE" "$d/source")" ] || ok=1
  [ -n "$(refus_lecture "$SOURCE_UNIQUE" "$d/branche")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}

# La consultation hors ligne (#101) : ce qu'une session laisse sur l'appareil (jeton,
# lecture gardée, copies ouvertes) s'efface à UNE porte, `oublierCeQuiEstGarde` — un
# `Trousseau.supprimer(` ailleurs effacerait le jeton en laissant la lecture lisible. Et
# un fichier protégé se lit par `fichierConsultable` : un `fichierProtege(` appelé par
# un écran partirait sur le réseau pendant la consultation.
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_porte_session() {
  local code
  code=$(grep -vE '^[[:space:]]*///?' "$2")
  case "$1" in
    CoproFirst/Session/Trousseau.swift | CoproFirst/Session/LectureGardee/ServiceHorsLigne.swift) ;;
    *) grep -qE 'Trousseau\.supprimer\(' <<< "$code" &&
      echo "Trousseau.supprimer( hors de oublierCeQuiEstGarde — le jeton partirait sans la lecture gardée" ;;
  esac
  case "$1" in
    CoproFirst/Session/* | CoproFirst/Donnees/ServiceSimule*) ;;
    *) grep -E 'fichierProtege\(' <<< "$code" | grep -qvE 'func fichierProtege\(' &&
      echo "fichierProtege( lu par un écran — passer par fichierConsultable (consultation hors ligne)" ;;
  esac
}
autotest_porte_session() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        Trousseau.supprimer(pour: installation.hote)\n' > "$d/jeton"
  printf '        let d = try await service.fichierProtege(chemin, dans: i)\n' > "$d/fichier"
  printf '    /// pas de Trousseau.supprimer( ici : fichierProtege( non plus\n        x()\n' > "$d/commentaire"
  printf '    func fichierProtege(_ chemin: String, dans i: Installation) async throws -> Data {\n' > "$d/definition"
  [ -n "$(refus_porte_session CoproFirst/Session/ServiceAPI+Compte.swift "$d/jeton")" ] || ok=1
  [ -z "$(refus_porte_session CoproFirst/Session/LectureGardee/ServiceHorsLigne.swift "$d/jeton")" ] || ok=1
  [ -n "$(refus_porte_session CoproFirst/Commun/PiecesJointes/X.swift "$d/fichier")" ] || ok=1
  [ -z "$(refus_porte_session CoproFirst/Session/LectureGardee/X.swift "$d/fichier")" ] || ok=1
  [ -z "$(refus_porte_session CoproFirst/Commun/X.swift "$d/commentaire")" ] || ok=1
  [ -z "$(refus_porte_session CoproFirst/Commun/X.swift "$d/definition")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}

# L'aperçu servi d'une saisie (#129, #130, #135) passe par UNE porte, `ApercuServi` : le
# délai, la réponse périmée ignorée et le hors ligne y sont écrits une fois. Un écran
# qui appellerait la route ou le service lui-même recopierait le mécanisme, ou s'en
# passerait. $1 : chemin dans le dépôt ; $2 : le fichier à lire.
refus_porte_apercu() {
  local code
  code=$(grep -vE '^[[:space:]]*///?' "$2")
  case "$1" in
    CoproFirst/Donnees/ServiceApercus.swift) ;;
    *) grep -qE 'post(LecturesApercu|PerimetresLibelle|NomsAffiche)\(' <<< "$code" &&
      echo "route d'aperçu appelée hors de ServiceApercus — poser ApercuServi" ;;
  esac
  case "$1" in
    CoproFirst/Commun/Apercu/* | CoproFirst/Donnees/ServiceApercus.swift | CoproFirst/Donnees/FixturesApercus.swift) ;;
    *) grep -qE '\.apercus\b|ServiceApercus\b|EtatApercu\b|ApercuSaisie\.delai' <<< "$code" &&
      echo "aperçu demandé hors d'ApercuServi (délai, réponse périmée, hors ligne) — poser QuiLaLira, LieuDeLaSaisie ou NomDeLaSaisie" ;;
  esac
}
autotest_porte_apercu() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        let r = try await client(i.adresse).postNomsAffiche(body: .json(corps))\n' > "$d/route"
  printf '            let nom = try? await parcours.service.apercus?.nomAffiche(s, dans: i)\n' > "$d/service"
  printf '            try await Task.sleep(for: ApercuSaisie.delai)\n' > "$d/delai"
  printf '    /// jamais .apercus ni postNomsAffiche( ici : ApercuServi\n        x()\n' > "$d/commentaire"
  printf '        NomDeLaSaisie(saisie: s, identifiant: "profil.nom")\n' > "$d/ecran"
  [ -n "$(refus_porte_apercu CoproFirst/Fonctions/Profil/X.swift "$d/route")" ] || ok=1
  [ -z "$(refus_porte_apercu CoproFirst/Donnees/ServiceApercus.swift "$d/route")" ] || ok=1
  [ -n "$(refus_porte_apercu CoproFirst/Fonctions/Profil/X.swift "$d/service")" ] || ok=1
  [ -n "$(refus_porte_apercu CoproFirst/Fonctions/Affaires/X.swift "$d/delai")" ] || ok=1
  [ -z "$(refus_porte_apercu CoproFirst/Commun/Apercu/X.swift "$d/service")" ] || ok=1
  [ -z "$(refus_porte_apercu CoproFirst/Fonctions/Profil/X.swift "$d/commentaire")" ] || ok=1
  [ -z "$(refus_porte_apercu CoproFirst/Fonctions/Profil/X.swift "$d/ecran")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}

# Une attente par prédicat (le focus du clavier, un onglet retenu) passe par le point
# d'attente commun et son plafond (#123) : écrite sur place, chacune portait son délai,
# et 3 s ne tiennent pas sur un runner qui met 2 s par requête d'accessibilité.
# Une attente d'EXISTENCE aussi (#147) : `apparait()`, `disparait()`, `sonde()` — 200
# délais étaient écrits sur place, et les 8 s de la feuille des notifications ont rendu
# `main` rouge (865eed4) sans que l'app ait tort. Aucun délai chiffré ne revient.
ATTENTE_SUR_PLACE='expectation\(for:|waitForExpectations|XCTNSPredicateExpectation|XCTWaiter|[^.[:alnum:]]wait\(for:'
EXISTENCE_SUR_PLACE='waitFor(Non)?Existence\(|(timeout|delai): *[0-9]|TimeInterval *= *[0-9]'
# Une sonde se LIT (boucle, chemin facultatif, absence) : affirmée, elle refait d'un
# délai court un verdict sur l'app.
SONDE_AFFIRMEE='XCTAssertTrue\(.*(\.sonde\(\)|sonde: true)'
POINT_ATTENTE=CoproFirstUITests/Attente.swift
# $1 : chemin dans le dépôt ; $2 : le fichier à lire. Rend le motif du refus, ou rien.
refus_attente() {
  local trouve
  [ "$1" != "$POINT_ATTENTE" ] || return 0
  # Le code seul : un commentaire qui explique l'interdit a le droit de le nommer.
  trouve=$(grep -nE "$ATTENTE_SUR_PLACE" "$2" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || { echo "attente par prédicat écrite sur place (ligne ${trouve%%:*}) — element.attendre(\"…\"), $POINT_ATTENTE"; return; }
  trouve=$(grep -nE "$EXISTENCE_SUR_PLACE" "$2" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || { echo "attente ou délai écrits sur place (ligne ${trouve%%:*}) — element.apparait(), .disparait() ou .sonde(), $POINT_ATTENTE"; return; }
  trouve=$(grep -nE "$SONDE_AFFIRMEE" "$2" | grep -vE '^[0-9]+:[[:space:]]*///?' | head -1)
  [ -z "$trouve" ] || echo "sonde affirmée par XCTAssertTrue (ligne ${trouve%%:*}) — une présence s'affirme par element.apparait(), $POINT_ATTENTE"
}
autotest_attente() {
  local d ok=0
  d=$(mktemp -d) || return 1
  printf '        expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: champ)\n        waitForExpectations(timeout: 3)\n' > "$d/focus"
  printf '        wait(for: [visible], timeout: 3)\n' > "$d/visible"
  printf '        XCTAssertTrue(champ.attendre("hasKeyboardFocus == true"))\n        // jamais waitForExpectations(timeout: 3)\n' > "$d/commun"
  printf '        XCTAssertTrue(tout.waitForExistence(timeout: 8))\n' > "$d/existence"
  printf '        XCTAssertTrue(tout.waitForNonExistence(timeout: Attente.plafond))\n' > "$d/disparition"
  printf '    private func lu(_ app: XCUIApplication, delai: TimeInterval = 8) -> Bool {\n' > "$d/delai"
  printf '        XCTAssertTrue(feuilleOuverte(app, delai: 10))\n' > "$d/appel"
  printf '        XCTAssertTrue(carte.sonde(), "la carte est là")\n' > "$d/sonde"
  printf '        XCTAssertTrue(tout.apparait())\n        for _ in 0..<8 where !carte.sonde() { app.swipeUp() }\n        XCTAssertFalse(lu(app, sonde: true))\n        // jamais waitForExistence(timeout: 8)\n' > "$d/verbes"
  for cas in existence disparition delai appel sonde; do
    [ -n "$(refus_attente CoproFirstUITests/CommunauteUITests.swift "$d/$cas")" ] || ok=1
  done
  [ -z "$(refus_attente CoproFirstUITests/CommunauteUITests.swift "$d/verbes")" ] || ok=1
  [ -z "$(refus_attente "$POINT_ATTENTE" "$d/existence")" ] || ok=1
  [ -n "$(refus_attente CoproFirstUITests/RetourUITests.swift "$d/focus")" ] || ok=1
  [ -n "$(refus_attente CoproFirstUITests/ConnexionUITests.swift "$d/visible")" ] || ok=1
  [ -z "$(refus_attente CoproFirstUITests/RetourUITests.swift "$d/commun")" ] || ok=1
  [ -z "$(refus_attente "$POINT_ATTENTE" "$d/focus")" ] || ok=1
  rm -rf "${d:?}"
  return $ok
}
