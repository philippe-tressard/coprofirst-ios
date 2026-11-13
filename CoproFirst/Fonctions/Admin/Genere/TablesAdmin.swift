// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.89.0 (commit 10b85f3356d538254bfdca6f54270063c9008d4b), front/src/lib/pages.ts#PAGES, front/src/lib/taches.ts#LIBELLE_TACHE, front/src/lib/taches.ts#STATUTS_TACHE, front/src/lib/roles.ts#ATTRIBUTS_ROLE, front/src/lib/roles.ts#ATTRIBUTS_STATUT (tables-clients.json).
// swiftlint:disable line_length

/// Ce que le site écrit du Paramétrage et que le contrat ne sert pas.
enum TablesAdmin {
    /// Le descriptif de chaque onglet de la page `admin` (texte du site).
    static let descriptifs: [String: String] = [
        "a_traiter": "Ce qui attend un geste de l'administrateur : comptes à valider, commandes d'accès, demandes de modification de profil.",
        "utilisateurs": "Tous les comptes : statut, bâtiment, rôles, modification et suppression.",
        "audit_lots": "Les associations entre comptes et lots, pour repérer et retirer les affectations erronées.",
        "telemetry": "Statistiques d'utilisation : qui utilise quoi, et quand — par jour, sur 30 jours, sur 12 mois ou par année.",
        "imports": "Charger un tableur du syndic — lots et copropriétaires, télécommandes ou badges Vigik — et le rapprocher des lots.",
        "copropriete": "L'identité et les références de la copropriété : nom, adresse, logo, syndic.",
        "perimetres": "L'arborescence des bâtiments et des espaces que l'on peut viser.",
        "equipements": "Ce sur quoi l’on intervient — ascenseur, chauffage, plomberie… : leur nom, leur icône, et les périmètres où ils se trouvent.",
        "lots": "Les lots selon le règlement — ce qui les dessert, leurs périmètres, et ce qui ne tombe pas juste.",
        "fonctionnement": "Les délais d’archivage et de relance, le gestionnaire du site et les alertes qu’il reçoit.",
        "legal": "Les mentions légales et la politique de confidentialité.",
        "services": "Les services de la copropriété sur un seul écran : ce qui est activé, ce qu'on perd en le coupant, et le lien vers ses réglages.",
        "smtp": "L'envoi des courriels et la relève des réponses par courriel.",
        "whatsapp": "Le canal de diffusion de la résidence : connexion du groupe et pied des messages.",
        "ia": "Le fournisseur, la clé et le réglage de chaque usage de l'assistant.",
        "pages": "L'icône, le libellé de menu, le titre, la description et les onglets de chaque page, et leur ordre dans le menu.",
        "connexion": "Le sous-titre de la page de connexion, et ce que dit le pied de chaque page.",
        "emails": "Le texte et la mise en page de chaque courriel envoyé par le site, avec l'historique des envois.",
        "installation": "Cette installation : son rôle, sa version, son inscription au registre et son bail.",
        "maintenance": "Les tâches automatiques, leur historique et leur déclenchement manuel.",
        "installations": "Les installations CoproFirst inscrites au registre de la référence : leur état, leur contrat, leurs services.",
    ]
    /// L'adresse de chaque onglet sur le site, sous celle de la résidence.
    static let routes: [String: String] = [
        "a_traiter": "/admin",
        "utilisateurs": "/admin?onglet=utilisateurs",
        "audit_lots": "/admin?onglet=audit_lots",
        "telemetry": "/admin?onglet=telemetry",
        "imports": "/admin?onglet=imports",
        "copropriete": "/admin?onglet=copropriete",
        "perimetres": "/admin?onglet=perimetres",
        "equipements": "/admin?onglet=equipements",
        "lots": "/admin?onglet=lots",
        "fonctionnement": "/admin?onglet=fonctionnement",
        "legal": "/admin?onglet=legal",
        "services": "/admin?onglet=services",
        "smtp": "/admin?onglet=smtp",
        "whatsapp": "/admin?onglet=whatsapp",
        "ia": "/admin?onglet=ia",
        "pages": "/admin?onglet=pages",
        "connexion": "/admin?onglet=connexion",
        "emails": "/admin?onglet=emails",
        "installation": "/admin?onglet=installation",
        "maintenance": "/admin?onglet=maintenance",
        "installations": "/admin?onglet=installations",
    ]
    /// Le nom de chaque tâche planifiée (`LIBELLE_TACHE`), par son code servi.
    static let libellesTache: [String: String] = [
        "maintenance": "Maintenance hebdomadaire",
        "backup": "Sauvegarde quotidienne",
        "bascule": "Bascule actif/standby",
        "telemetrie": "Agrégation télémétrie",
        "health_watch": "Surveillance du site",
        "reliability": "Contrôles de fiabilité",
        "auto_deploy": "Déploiement automatique",
        "export_hors_site": "Copie hors site (manuelle)",
        "mise_a_jour": "Mise à jour de la version",
        "remise_a_zero_demo": "Remise à zéro de la démo",
        "conservation_affaires": "Conservation des affaires",
        "correctifs_systeme": "Correctifs du système",
        "audit_securite": "Audit de sécurité nocturne",
        "canari_ia": "Canari de l'assistant IA",
    ]
    /// Le libellé de chaque statut de santé d'une tâche.
    static let libellesStatut: [String: String] = [
        "ok": "À jour",
        "en_cours": "En cours",
        "pas_actif": "Pas actif à l’heure",
        "rapport_perdu": "Rapport non reçu",
        "vigilance": "Points de vigilance",
        "manquante": "Exécution manquante",
        "erreur": "En échec",
        "aucune_execution": "Aucun rapport reçu",
    ]
    /// Ce que chaque statut veut dire, en une phrase du site.
    static let aidesStatut: [String: String] = [
        "ok": "Un rapport est arrivé dans le délai attendu.",
        "en_cours": "La tâche a signalé son démarrage et n’a pas encore rendu son compte rendu.",
        "pas_actif": "Ce nœud n’a pas exécuté la tâche depuis plus de deux nuits, mais l’autre nœud l’a fait : la tâche ne tourne que sur le nœud actif, et après un failover un nœud peut ne pas être actif deux nuits de suite. Au-delà de trois nuits, ou si la tâche elle-même est en retard, la ligne passe au rouge.",
        "rapport_perdu": "La tâche a DÉMARRÉ — elle a écrit son battement de début — mais son compte rendu n'est jamais arrivé. Le ménage a donc bien eu lieu ; c'est la chaîne de remontée qui est rompue. Chercher du côté du réseau, de la clé de maintenance ou du format de la charge utile, pas du côté de la tâche.",
        "vigilance": "Le dernier rapport relève des points à surveiller, sans échec. Leur liste est dans « Contrôles de fiabilité », plus bas.",
        "manquante": "Aucun rapport depuis plus longtemps que la périodicité de la tâche.",
        "erreur": "Le dernier rapport signale un échec.",
        "aucune_execution": "Aucun rapport en base pour cette tâche. Cela ne prouve pas qu'elle n'a pas tourné : un rapport peut avoir échoué à remonter, ou avoir été purgé. Vérifier le journal du nœud avant de conclure.",
    ]
    /// La teinte de chaque statut : la classe `badge-*` du site (`PastilleTeinte`).
    static let teintesStatut: [String: String] = [
        "ok": "badge-green",
        "en_cours": "badge-green",
        "pas_actif": "badge-gray",
        "rapport_perdu": "badge-orange",
        "vigilance": "badge-orange",
        "manquante": "badge-red",
        "erreur": "badge-red",
        "aucune_execution": "badge-red",
    ]
    /// La teinte d'un rôle (`BADGE_ROLE`) ; gris pour une clé inconnue.
    static let teintesRole: [String: String] = [
        "résident": "badge-gray",
        "propriétaire": "badge-teal",
        "conseil_syndical": "badge-blue",
        "admin": "badge-orange",
        "externe": "badge-yellow",
        "operateur": "badge-purple",
    ]
    /// La teinte d'un statut de compte (`BADGE_STATUT`) ; gris pour une clé inconnue.
    static let teintesStatutCompte: [String: String] = [
        "copropriétaire_résident": "badge-green",
        "copropriétaire_bailleur": "badge-blue",
        "locataire": "badge-purple",
        "syndic": "badge-orange",
        "mandataire": "badge-gray",
        "aidant": "badge-yellow",
        "admin_technique": "badge-orange",
    ]
    /// Un statut de compte abrégé, pour une liste dense (`LIBELLES_STATUT_ABREGE`).
    static let abregesStatutCompte: [String: String] = [
        "copropriétaire_résident": "Copro. résident",
        "copropriétaire_bailleur": "Copro. bailleur",
        "locataire": "Locataire",
        "syndic": "Syndic",
        "mandataire": "Mandataire",
        "aidant": "Aidant (proche)",
        "admin_technique": "Compte technique",
    ]
    /// Les statuts de compte dans l'ordre du site : le filtre « Type » des utilisateurs.
    static let ordreStatutsCompte: [String] = ["copropriétaire_résident", "copropriétaire_bailleur", "locataire", "syndic", "mandataire", "aidant", "admin_technique"]
}
// swiftlint:enable line_length
