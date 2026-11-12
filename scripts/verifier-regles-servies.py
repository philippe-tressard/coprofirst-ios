#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Ce que le serveur SERT ne se recalcule plus dans l'app (#83, `standards/09` §8).

Le 10/11/2026, l'app rangeait encore les cartes du Kanban par une table générée depuis
le front (`colonneParStatut`), déduisait des rôles qui peut glisser une carte, archiver
ou supprimer une annonce, et lisait les états clos dans une liste figée — alors que le
contrat 1.14.0 sert `colonne_kanban`, `peut_*`, `categorie_libelle`, `perimetre_libelle`
et `GET /tickets/referentiels`. Chaque copie divergeait au premier arbitrage du serveur.

Ce contrôle refuse le RETOUR de chaque table ou prédicat retiré, dans le code de l'app
(`CoproFirst/**/*.swift`) comme dans les générateurs (`scripts/generateurs/*.py`), qui
pourraient le réécrire. Chaque motif nomme ce qu'on lit à la place.

Une dispense se déclare avec sa raison ; une dispense qui ne couvre plus rien échoue.

Usage :
  python3 scripts/verifier-regles-servies.py            juge le dépôt
  python3 scripts/verifier-regles-servies.py --autotest prouve qu'il refuse et accepte

Sortie : 0 conforme, 1 retour d'une règle retirée, 2 INCONNU (rien à juger).
"""

from __future__ import annotations

import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[1]

#: (motif, ce qu'on lit à la place). Un motif vise la COPIE, jamais le champ servi :
#: `lu.colonnesKanban` (le type généré du contrat) reste permis.
RETIREES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bTablesAffaires\.(colonneParStatut|statutParColonne|colonnesKanban|statutsClos|categorieParCode)\b"),
     "la colonne et la clôture servies (`colonne_kanban`, `close`, `GET /tickets/referentiels`)"),
    (re.compile(r"\bstatic let (colonneParStatut|statutParColonne|colonnesKanban|statutsClos)\b"),
     "les référentiels servis (`ReferentielsAffaires`), jamais une table écrite ou générée"),
    (re.compile(r"\b(COLONNE_PAR_STATUT_TICKET|STATUTS_TICKET_CLOS)\b"),
     "les référentiels servis : le générateur ne lit plus ces tables du front"),
    # #128 : le site PUBLIE ces deux tables (`tables-clients.json`) ; l'app ne les lit pas
    # pour autant — la colonne et la clôture sont servies avec l'affaire.
    (re.compile(r"\btable\(\s*[\"'](colonneParStatutTicket|statutsTicketClos)[\"']"),
     "les référentiels servis : ces tables publiées ne se génèrent pas dans l'app"),
    (re.compile(r"\bpeutRepondre\(moi:"),
     "`peut_repondre` de l'affaire (`DroitsServisAffaire`)"),
    (re.compile(r"\bvar estConseil: Bool \{ roles\b|\.contains\(\"(conseil_syndical|admin)\"\)"),
     "un `peut_*` servi ; à défaut, « modère » servi (`est_moderateur`, `DroitsOnglet.cs`)"),
    # #105 : les catégories offertes et les états d'une Suite sont servis.
    (re.compile(r"\bTablesAffaires\.(categories|ordreDesStatuts)\b|\bstatic let (ordreDesStatuts|categories: \[CategorieAffaire\])"),
     "les catégories permises et les états proposables servis (`ReferentielsAffaires.permises`, `.proposables`)"),
    (re.compile(r"\.reserveCS\b"), "`permise` des référentiels (`categorie_permise` du serveur)"),
    # « Modérer » déduit du profil (`DroitsAffaires.moderateur`) décidait encore des catégories de
    # « Modifier » et d'une phrase de « Nouvelle affaire ». Le paramètre du serveur SIMULÉ
    # (`lus(moderateur:)`), qui calcule `permise` comme le vrai, n'est pas visé — ni
    # `estModerateur`, le champ SERVI du profil (#136).
    (re.compile(r"\.moderateur\b|\b(let|var) moderateur\b"),
     "ce que le serveur permet à CE compte (`ReferentielsAffaires.permises`, `.poseLesReservees`)"),
    # #127 : le crayon d'une affaire est `peut_corriger`, comme le site — `peut_modifier`
    # ne dit plus que le droit sur le CONTENU (`DetailAffaire.contenuFige`).
    (re.compile(r"\.modifier, \.options:\s*affaire\.droits\.modifier\b"),
     "le crayon servi (`DroitsServisAffaire.corriger`, `peut_corriger`)"),
    # #127 : le crayon ne se déduit plus de `peut_modifier` — le repli d'une installation
    # antérieure au contrat 1.21.0 est retiré avec la montée du plancher à 1.26.0.
    (re.compile(r"\bpeutCorriger \?\? [\w.]*\b(modifier|peutModifier)\b"),
     "le crayon servi seul (`peut_corriger`) : non servi, il n'est pas offert"),
    # #127 et #105, réunis : l'état d'une affaire en clair est SERVI — avec l'objet
    # (`statut_libelle`, `nouveau_statut_libelle`, `suivi_actualite_libelle`), sinon par ses
    # référentiels (`statuts[].libelle`). UNE écriture : `StatutsAffaire.libelle(_:servi:dans:)`
    # (`PastilleStatut.swift`). La table du site n'a plus de libellé, pas même en repli :
    # seule la teinte se génère (`StatutsAffaire.pastilles`).
    (re.compile(r"\bStatutsAffaire\.parCode\b|\(libelle: String, pastille: String\)"),
     "l'état en clair servi (`StatutsAffaire.libelle(_:servi:dans:)`) ; la teinte : `StatutsAffaire.pastilles`"),
    # #135 : « Prénom NOM » est SERVI (`nom_affiche`…) et se lit du type généré. Le repli
    # `FormatsDuSite.nom(affiche:prenom:nom:)` ne sert plus qu'aux deux fichiers dispensés
    # (une fiche renommée pas encore enregistrée, un annuaire gardé en cache) : ailleurs,
    # il referait le repli « installation antérieure » retiré avec le plancher à 1.26.0.
    (re.compile(r"\bFormatsDuSite\.nom\("),
     "le nom servi (`nom_affiche`, `locataire_nom_affiche`…), lu du type généré"),
    (re.compile(r"\\\([^()]*\bprenom\b[^()]*\) \\\([^()]*\bnom\b"),
     "le nom servi (`nom_affiche`), lu du type généré — jamais un prénom et un nom accolés"),
    # #136 : « CS ou admin » est SERVI (`est_moderateur`) — le site ne publie plus de
    # population de rôles pour le dire, et aucune ne revient ici.
    (re.compile(r"\bOngletsDuSite\.(rolesCS|rolesProprioOuCS)\b|\bstatic let (rolesCS|rolesProprioOuCS)\b"),
     "`est_moderateur` servi, lu par `DroitsOnglet` (`cs`, `proprioOuCS`)"),
    # #138 : « le mien » est SERVI (`est_auteur`) ; aucun identifiant de compte ne se compare.
    (re.compile(r"\bauteurId == moi\b"),
     "`est_auteur` servi (`MessageAffaire(_:)`)"),
    #  #130 : le lieu d'un contenu se LIT (`perimetre_libelle`) ; nommer des codes par
    #  l'arbre recopie la règle du serveur (`utils/perimetres/libelles.py`).
    (re.compile(r"\blibelles\([^)]*parmi:|\blieu\([^)]*\b(repli|arbre):"),
     "le lieu servi (`perimetre_libelle`) par `LieuServi.lieu(_:)` — aucun repli sur l'arbre ni sur un libellé"),
    # #125 : les numéros d'une fiche sont SERVIS (`telephones`), découpés par le serveur.
    (re.compile(r"\bdecoupes\("),
     "`telephones` servi (`PrestataireRead`) — l'app ne découpe pas `telephone`"),
    # #89 : le bannissement en cours est SERVI (`communaute_banni`), jugé à l'heure du serveur.
    (re.compile(r"\bbanni\(maintenant:|\bjusquAu\.map \{ \$0 > "),
     "`communaute_banni` servi (`BanCommunaute.banni`) — jamais une date comparée à l'heure du téléphone"),
]

#: chemin → raison. Une dispense dit pourquoi le motif n'y est pas une règle recopiée.
DISPENSES: dict[str, str] = {
    "CoproFirst/Fonctions/Admin/Utilisateurs/EtatUtilisateursAdmin.swift":
        "compte les membres du conseil parmi les comptes listés — une donnée affichée, pas un droit du lecteur",
    "CoproFirst/Fonctions/EspaceCS/Annuaire/ServiceAnnuaireCS.swift":
        "une fiche de l'annuaire renommée, pas encore enregistrée, n'a plus de nom servi : le repli la nomme "
        "jusqu'à l'écran de `POST /noms/affiche` (lot à part, #87)",
    "CoproFirst/Fonctions/Annuaire/ServiceAnnuaire.swift":
        "un annuaire gardé en cache avant #135 se relit sans `nom_affiche` : le repli le nomme",
}


def fichiers(racine: pathlib.Path) -> list[pathlib.Path]:
    return sorted([*(racine / "CoproFirst").rglob("*.swift"), *(racine / "scripts" / "generateurs").glob("*.py")])


def juger(racine: pathlib.Path) -> tuple[list[str], int]:
    """Rend les refus et le nombre de fichiers jugés."""
    refus: list[str] = []
    dispenses_utiles: set[str] = set()
    jugés = fichiers(racine)
    for f in jugés:
        chemin = f.relative_to(racine).as_posix()
        for n, ligne in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            for motif, remede in RETIREES:
                if not motif.search(ligne):
                    continue
                if chemin in DISPENSES:
                    dispenses_utiles.add(chemin)
                    continue
                refus.append(f"{chemin}:{n} : règle retirée qui revient ({motif.search(ligne).group(0)}) — lire {remede}")
    for chemin in sorted(set(DISPENSES) - dispenses_utiles):
        refus.append(f"{chemin} : dispensé sans plus rien couvrir — retirer la dispense")
    return refus, len(jugés)


def autotest() -> int:
    """Dans les deux sens : un contrôle qui ne refuse rien ne prouve rien."""
    fautifs = [
        "    var colonne: String? { TablesAffaires.colonneParStatut[statut] }",
        "    static let statutsClos: Set<String> = [\"résolu\"]",
        '    par_statut = table_simple(texte, "COLONNE_PAR_STATUT_TICKET")',
        '    clos = ctx.table("statutsTicketClos", [str])',
        "        if DroitsAffaire.peutRepondre(moi: profil) {",
        '    var estConseil: Bool { roles.contains("conseil_syndical") || estAdmin }',
        '        return roles.contains("admin")',
        "        affaire.estActualite ? [] : TablesAffaires.ordreDesStatuts",
        "        let permises = TablesAffaires.categories.filter { moderateur || !$0.reserveCS }",
        "    static let ordreDesStatuts: [String] = [\"ouvert\", \"en_ag\"]",
        "            affaire.estActualite && !droits.moderateur",
        "        return droits.moderateur",
        "    let moderateur: Bool",
        "            case .modifier, .options: affaire.droits.modifier",
        "        morceaux.append(StatutsAffaire.parCode[affaire.statut]?.libelle ?? affaire.statut)",
        "        servi?.nulSiVide ?? parCode[code]?.libelle ?? StatutsAffaire.parCode[code]?.libelle ?? code",
        '        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.parCode[statut]?.pastille ?? "badge-gray")',
        "    static let parCode: [String: (libelle: String, pastille: String)] = [",
        "        let nom = FormatsDuSite.nom(compte.prenom, compte.nom)",
        "    var nomAffiche: String { FormatsDuSite.nom(affiche: nomServi, prenom: prenom, nom: nom) }",
        "        detail.droits.corriger = servi?.peutCorriger ?? detail.droits.modifier",
        "    static let rolesCS: Set<String> = [\"conseil_syndical\", \"admin\"]",
        "            proprioOuCS: !portes.isDisjoint(with: OngletsDuSite.rolesProprioOuCS),",
        "        lieu(servi, repli: libelles(codes, parmi: arbre).joined(separator: \", \"))",
        "    var lieu: String? { LieuServi.lieu(perimetreLibelle, repli: perimetreLabel) }",
        "            prestataire.telephones = servis[lu.id]?.telephones ?? decoupes(lu.telephone)",
        "        banniServi ?? (interdit || (jusquAu.map { $0 > maintenant } ?? false))",
        '                Text("\\(compte.prenom) \\(compte.nom)").font(.headline)',
        '        let nom = { residents.first { $0.id == id }.map { "\\($0.prenom ?? "") \\($0.nom ?? "")" } }',
        "            cs: !portes.isDisjoint(with: OngletsDuSite.rolesCS),",
        "            deMoi: moi != nil && message.auteurId == moi,",
        "        let ouvre = Perimetre.libelles(acces.perimetreCible, parmi: perimetres)",
    ]
    sains = [
        "            colonnes: lu.colonnesKanban.map { ColonneKanban(id: $0.code) },",
        '    for c in ctx.table("colonnesKanban", [{"id": str, "color": str}]):',
        "            colonne: ticket.colonneKanban, peutDeplacer: ticket.peutDeplacerAuKanban ?? false,",
        "    private var estConseil: Bool { DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs }",
        '        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.pastilles[statut] ?? "badge-gray")',
        '            "carnet": bool(c.get("carnet")), "reservee": bool(c.get("reserveCS")),',
        "        affaire.estActualite ? [] : affaire.referentiels.proposables",
        "    static func lus(moderateur: Bool = true) throws -> ReferentielsAffaires {",
        "            servie.permise = moderateur || !categorie.reservee",
        "        poseLesReservees ? \"L'équipement aussi.\" : \"Le conseil syndical désigne l'équipement.\"",
        "            case .modifier, .options: affaire.droits.corriger",
        "        morceaux.append(StatutsAffaire.libelle(affaire.statut, servi: affaire.statutLibelle))",
        "            nomAffiche: lu.nomAffiche, nomAideAffiche: lu.nomAideAffiche.nulSiVide)",
        "                corriger: ticket.peutCorriger ?? false),",
        "            proprioOuCS: !portes.isDisjoint(with: OngletsDuSite.rolesProprietaire) || modere,",
        "            lieu: LieuServi.lieu(lue.perimetreLibelle), formatLabel: lue.formatLabel, images: lue.images,",
        "            telephones: lu.telephones)",
        "                banni: lu.communauteBanni ?? false),",
        "        let nouveau = StatutsAffaire.libelle(nouveauStatut, servi: nouveauStatutLibelle, dans: servis)",
        "        servi?.nulSiVide ?? referentiels.statuts.first { $0.code == code }?.libelle ?? code",
        '            let cle = email.isEmpty ? "\\(bail.locatairePrenom ?? "")|\\(bail.locataireNom ?? "")" : email',
        "            id: message.id, contenu: message.contenu, date: message.creeLe, deMoi: message.estAuteur ?? false,",
        "        let ouvre = acces.lieu",
        "            perimetrePrecise: LieuServi.lieu(evolution.perimetrePreciseLibelle))",
    ]
    echecs = [f for f in fautifs if not any(m.search(f) for m, _ in RETIREES)]
    echecs += [s for s in sains if any(m.search(s) for m, _ in RETIREES)]
    for e in echecs:
        print(f"❌ autotest : mal jugé — {e.strip()}")
    if not echecs:
        print(f"✅ autotest : {len(fautifs)} retours refusés, {len(sains)} lectures servies acceptées")
    return 1 if echecs else 0


def main() -> int:
    if "--autotest" in sys.argv[1:]:
        return autotest()
    refus, jugés = juger(RACINE)
    if jugés == 0:
        print("❓ INCONNU : aucun fichier à juger (CoproFirst/**/*.swift, scripts/generateurs/*.py)")
        return 2
    for r in refus:
        print(f"❌ {r}")
    if refus:
        return 1
    print(f"✅ {jugés} fichiers : aucune règle servie recalculée (#83, #105)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
