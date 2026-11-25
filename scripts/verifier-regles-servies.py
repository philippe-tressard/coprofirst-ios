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

Une PORTE de version (`static let x = VersionContrat(1, 15, 0)`, comparée au contrat
servi) ne vit que tant qu'elle est AU-DESSUS du plancher (`ContratDuPlancher.swift`,
généré) : sous lui, toute installation qui s'ouvre la passe déjà, et la porte n'est plus
qu'un repli mort qui décide encore d'un geste quand la version est illisible (#254).
Une porte au plancher ou en dessous est refusée ; le plancher illisible : INCONNU.

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
sys.path.insert(0, str(RACINE / "scripts"))
import portee  # noqa: E402  (la liste des dossiers, #341)

#: (motif, ce qu'on lit à la place). Un motif vise la COPIE, jamais le champ servi :
#: `lu.colonnesKanban` (le type généré du contrat) reste permis.
RETIREES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bTablesAffaires\.(colonneParStatut|statutParColonne|colonnesKanban|statutsClos|categorieParCode)\b"),
     "la colonne et la clôture servies (`colonne_kanban`, `close`, `GET /tickets/referentiels`)"),
    (re.compile(r"\bstatic let (colonneParStatut|statutParColonne|colonnesKanban|statutsClos)\b"),
     "les référentiels servis (`ReferentielsAffaires`), jamais une table écrite ou générée"),
    (re.compile(r"\b(COLONNE_PAR_STATUT_TICKET|STATUTS_TICKET_CLOS)\b"),
     "les référentiels servis : le générateur ne lit plus ces tables du front"),
    (re.compile(r"\bpeutRepondre\(moi:"),
     "`peut_repondre` de l'affaire (`DroitsServisAffaire`)"),
    (re.compile(r"\bvar estConseil: Bool \{ roles\b|\.contains\(\"(conseil_syndical|admin)\"\)"),
     "un `peut_*` servi ; à défaut, la règle GÉNÉRÉE du site (`DroitsOnglet.cs`)"),
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
    # #127 et #105, réunis : l'état d'une affaire en clair est SERVI — avec l'objet
    # (`statut_libelle`, `nouveau_statut_libelle`, `suivi_actualite_libelle`), sinon par ses
    # référentiels (`statuts[].libelle`). UNE écriture : `StatutsAffaire.libelle(_:servi:dans:)`
    # (`PastilleStatut.swift`). La table du site n'a plus de libellé, pas même en repli :
    # seule la teinte se génère (`StatutsAffaire.pastilles`).
    (re.compile(r"\bStatutsAffaire\.parCode\b|\(libelle: String, pastille: String\)"),
     "l'état en clair servi (`StatutsAffaire.libelle(_:servi:dans:)`) ; la teinte : `StatutsAffaire.pastilles`"),
    # #135 : « Prénom NOM » est SERVI (`nom_affiche`…, contrat 1.25.0) : `FormatsDuSite.nom(servi:)`.
    # Le repli prénom-nom ne vit que dans `FormatsDuSite.nom(affiche:prenom:nom:)`, pour
    # l'ANNUAIRE seul (#87) : ailleurs, le plancher sert le nom.
    (re.compile(r"\bFormatsDuSite\.nom\((?!affiche:|servi:)"),
     "le nom servi (`nom_affiche`, `locataire_nom_affiche`…) par `FormatsDuSite.nom(servi:)`"),
    (re.compile(r"\bFormatsDuSite\.nom\(affiche:"),
     "`FormatsDuSite.nom(servi:)` : le repli prénom-nom est réservé à l'annuaire (dispensé)"),
    (re.compile(r"\\\([^()]*\bprenom\b[^()]*\) \\\([^()]*\bnom\b"),
     "le nom servi (`nom_affiche`) par `FormatsDuSite.nom(affiche:prenom:nom:)`, jamais un prénom et un nom accolés"),
    # #378 : la même composition par `joined` d'un tableau (`[auteurPrenom, auteurNom]…joined`),
    # que le motif de l'interpolation ne voyait pas : `auteur_affiche` est servi.
    (re.compile(r"\[\s*\w*[Pp]renom\w*\s*,\s*\w*[Nn]om\w*\s*\][^\n]*\.joined\("),
     "le nom servi (`auteur_affiche`, `nom_affiche`…) par `FormatsDuSite.nom(servi:)`, jamais un prénom et un nom joints"),
    # #136 : « CS ou admin » est SERVI (`est_moderateur`, contrat 1.25.0) ; `rolesCS` n'est
    # plus généré depuis v3.89.0 — la règle reste, garde contre son retour.
    (re.compile(r"\bOngletsDuSite\.rolesCS\b"),
     "`est_moderateur` servi, lu par `DroitsOnglet.cs`"),
    # #138 : « le mien » est SERVI (`est_auteur`, contrat 1.26.0).
    (re.compile(r"\bmessage\.auteurId == moi\b"),
     "`est_auteur` servi (`MessageAffaire.lus`)"),
    #  #130 : le lieu d'un contenu se LIT (`perimetre_libelle`, contrat 1.24.0) ; nommer
    #  des codes par l'arbre recopie la règle du serveur (`utils/perimetres/libelles.py`).
    (re.compile(r"\blibelles\([^)]*parmi:"),
     "le lieu servi (`perimetre_libelle`) par `LieuServi.lieu` — le repli au plancher n'a qu'un endroit"),
    # #87 : qui rédige la FAQ et qui crée un sondage est SERVI (contrat 1.20.0), plus la
    # règle du site (`$isCS`) lue par `DroitsOnglet`.
    (re.compile(r"\bvar estConseil: Bool \{ DroitsOnglet\b|\betat\.moi\?\.droits\.cs\b"),
     "`peut_rediger` et `peut_creer` servis (GET /faq/gestes, GET /sondages/gestes)"),
    # #207 : l'état d'une moyenne se lit par les seuils GÉNÉRÉS du site (`etatDeMoyenne`).
    (re.compile(r"\bmoyenne\s*[<>]=?\s*\d"),
     "`EtatAvis.deMoyenne`, sur les seuils générés (`TablesNotations.seuilsDeMoyenne`)"),
    # #227 : l'inventaire d'un bail et la gravité d'un constat, recopiés à la main depuis
    # v3.61.0 (#13), sont publiés dans tables-clients.json depuis v3.102.0.
    (re.compile(r"\bProvisoire[A-Z]\w*"),
     "les tables générées `TablesAcces.typesObjet`, `.statutsObjet`, `.gravites` (tables-clients.json)"),
    # #355 : qui voit quelle page est SERVI (`acces_menu` de GET /auth/me, contrat 2.11.0, au
    # plancher depuis v3.126.5), chaque page déclare son public (`acces`, généré) : la copie du
    # menu du site — un `switch` sur des identifiants de page, ses populations — ne revient pas.
    (re.compile(r'\b(outilDuConseil|rolesAdminSeul|rolesSansAdminSeul|estAidant)\b'
                r'|case "(prestataires|espace-cs|delegations|communaute)"'
                r"|'rolesDuDroit', '(adminSeul|sansAdminSeul)'"),
     "`acces_menu` servi, croisé avec le public généré de chaque page (`PagesOuvertes`)"),
]

#: chemin → raison. Une dispense dit pourquoi le motif n'y est pas une règle recopiée.
DISPENSES: dict[str, str] = {
    "CoproFirst/Fonctions/Admin/Utilisateurs/EtatUtilisateursAdmin.swift":
        "compte les membres du conseil parmi les comptes listés — une donnée affichée, pas un droit du lecteur",
    "CoproFirst/Fonctions/Annuaire/ServiceAnnuaire.swift":
        "un annuaire gardé avant #135 se relit sans `nom_affiche` : le repli prénom-nom (#87)",
    "CoproFirst/Fonctions/EspaceCS/Annuaire/ServiceAnnuaireCS.swift":
        "une fiche du conseil pas encore enregistrée n'a pas de nom servi : le nom saisi (#87)",
}


#: `static let nom = VersionContrat(1, 15, 0)` — une porte de version, ou le plancher.
PORTE = re.compile(r"\bstatic let (\w+) = VersionContrat\((\d+), (\d+)(?:, (\d+))?\)")
PLANCHER = "CoproFirst/Session/ContratDuPlancher.swift"


def portes(texte: str) -> list[tuple[str, tuple[int, int, int]]]:
    return [(m[1], (int(m[2]), int(m[3]), int(m[4] or 0))) for m in PORTE.finditer(texte)]


def portes_sous_le_plancher(racine: pathlib.Path) -> list[str] | None:
    """Les portes de version au plancher ou dessous ; `None` si le plancher est illisible."""
    plancher_lu = dict(portes((racine / PLANCHER).read_text(encoding="utf-8"))) if (racine / PLANCHER).exists() else {}
    plancher = plancher_lu.get("plancher")
    if plancher is None:
        return None
    refus = []
    for f in portee.fichiers(racine, portee.CODE):
        chemin = f.relative_to(racine).as_posix()
        for nom, version in portes(f.read_text(encoding="utf-8")):
            if chemin == PLANCHER and nom == "plancher":
                continue
            if version <= plancher:
                refus.append(
                    f"{chemin} : porte `{nom}` ({'.'.join(map(str, version))}) au plancher ou dessous "
                    f"({'.'.join(map(str, plancher))}) — la retirer, ou comparer au plancher (#254)")
    return refus


def fichiers(racine: pathlib.Path) -> list[pathlib.Path]:
    return sorted([*portee.fichiers(racine, portee.CODE), *(racine / "scripts" / "generateurs").glob("*.py")])


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
        '                Text("\\(compte.prenom) \\(compte.nom)").font(.headline)',
        '        let nom = { residents.first { $0.id == id }.map { "\\($0.prenom ?? "") \\($0.nom ?? "")" } }',
        "            cs: !portes.isDisjoint(with: OngletsDuSite.rolesCS),",
        "            deMoi: moi != nil && message.auteurId == moi,",
        "        let ouvre = Perimetre.libelles(acces.perimetreCible, parmi: perimetres)",
        "    private var estConseil: Bool { DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs }",
        "                    if etat.moi?.droits.cs == true {",
        "        if moyenne < 2.5 { return \"mauvais\" }",
        "        ProvisoireAcces.gravites.first { $0.code == constat.gravite }?.teinte",
        "    var nomAffiche: String { FormatsDuSite.nom(affiche: nomServi, prenom: prenom, nom: nom) }",
        "            deMoi: message.estAuteur ?? (moi != nil && message.auteurId == moi), nom: message.auteurNom,",
        '        let nom = [auteurPrenom, auteurNom].compactMap { $0 }.joined(separator: " ")',
        '        case "prestataires", "espace-cs": droits.outilDuConseil',
        '        case "delegations": droits.cs || droits.aidant',
        "        aidant = profil?.estAidant ?? false",
        "            adminSeul: !portes.isDisjoint(with: OngletsDuSite.rolesAdminSeul)",
        "    corps += f\"    static let rolesAdminSeul: Set<String> = {_ensemble(_liste(ctx, 'rolesDuDroit', 'adminSeul'))}\\n\"",
    ]
    sains = [
        "        TablesAcces.gravites.first { $0.code == constat.gravite }?.teinte",
        "            colonnes: lu.colonnesKanban.map { ColonneKanban(id: $0.code) },",
        "            colonne: ticket.colonneKanban, peutDeplacer: ticket.peutDeplacerAuKanban ?? false,",
        "            if lue.peutRediger {",
        "                    if etat.peutCreerUnSondage {",
        "        let conseil = DroitsOnglet(profil: parcours.ouverteAJour?.profil).cs",
        "        TablesNotations.seuilsDeMoyenne.first { moyenne < $0.borne }?.etat ?? TablesNotations.etatAuDela",
        '        PastilleTeinte(libelle: libelle, badge: StatutsAffaire.pastilles[statut] ?? "badge-gray")',
        '            "carnet": bool(c.get("carnet")), "reservee": bool(c.get("reserveCS")),',
        "        affaire.estActualite ? [] : affaire.referentiels.proposables",
        "    static func lus(moderateur: Bool = true) throws -> ReferentielsAffaires {",
        "            servie.permise = moderateur || !categorie.reservee",
        "        poseLesReservees ? \"L'équipement aussi.\" : \"Le conseil syndical désigne l'équipement.\"",
        "            cs: estModerateur ?? !portes.isDisjoint(with: roles),",
        "            case .modifier, .options: affaire.droits.corriger",
        "        let nouveau = StatutsAffaire.libelle(nouveauStatut, servi: nouveauStatutLibelle, dans: servis)",
        "        servi?.nulSiVide ?? referentiels.statuts.first { $0.code == code }?.libelle ?? code",
        "    var nomAffiche: String { FormatsDuSite.nom(servi: nomServi) }",
        '            let cle = email.isEmpty ? "\\(bail.locatairePrenom ?? "")|\\(bail.locataireNom ?? "")" : email',
        "                deMoi: servi?.estAuteur ?? false, nom: servi?.auteurNom,",
        "        let ouvre = acces.lieu(arbre: perimetres)",
        "            lieu: LieuServi.lieu(servi?.perimetreLibelle?.valeur))",
        "        let nom = FormatsDuSite.nom(servi: auteurAffiche)",
        '        let morceaux = [prenom, nom].compactMap { $0?.trimmingCharacters(in: .whitespaces) }',
        "        pages.filter { droits.accesMenu.contains($0.acces) }",
        '        case "admin": return palette.orange',
    ]
    # Les portes : celle sous le plancher refusée, celle au-dessus gardée, le plancher exclu.
    import tempfile

    with tempfile.TemporaryDirectory() as dossier:
        racine = pathlib.Path(dossier)
        (racine / "CoproFirst" / "Session").mkdir(parents=True)
        (racine / PLANCHER).write_text("    static let plancher = VersionContrat(2, 1, 0)\n", encoding="utf-8")
        (racine / "CoproFirst" / "Session" / "V.swift").write_text(
            "    static let logoSombre = VersionContrat(1, 15, 0)\n    static let periode = VersionContrat(2, 9)\n",
            encoding="utf-8")
        jugees = portes_sous_le_plancher(racine) or []
        if len(jugees) != 1 or "logoSombre" not in jugees[0]:
            fautifs_portes = ["porte sous le plancher : " + repr(jugees)]
        else:
            fautifs_portes = []
        (racine / PLANCHER).unlink()
        if portes_sous_le_plancher(racine) is not None:
            fautifs_portes.append("plancher absent : il fallait INCONNU")
    echecs = [f for f in fautifs if not any(m.search(f) for m, _ in RETIREES)] + fautifs_portes
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
    sous = portes_sous_le_plancher(RACINE)
    if jugés == 0 or sous is None:
        print(f"❓ INCONNU : aucun fichier à juger, ou plancher illisible ({PLANCHER})")
        return 2
    refus += sous
    for r in refus:
        print(f"❌ {r}")
    if refus:
        return 1
    print(f"✅ {jugés} fichiers : aucune règle servie recalculée (#83, #105), aucune porte sous le plancher (#254)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
