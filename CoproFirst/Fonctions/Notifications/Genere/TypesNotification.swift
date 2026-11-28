// GÉNÉRÉ par scripts/generer.py — NE PAS MODIFIER À LA MAIN.
// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
//
// swift-format-ignore-file
// Source : philippe-tressard/coprofirst v3.126.10 (commit 803696b615c922d3c0b93f69e2c81c6fa44c3e4c), api/app/utils/types_notification.py#TYPES_NOTIFICATION, api/app/utils/types_notification.py#TYPE_PAR_DEFAUT (constantes-clients.json).

/// Ce que la cloche montre de chaque type d'alerte (coprofirst#2802, #226).
enum TypesNotification {
    /// Par type d'alerte (`NotificationRecue.type`) : son pictogramme et son libellé.
    static let parType: [String: TypeNotification] = [
        "communaute_idee": TypeNotification(pictogramme: "lightbulb", libelle: "Idée"),
        "communaute_reponse": TypeNotification(pictogramme: "message-square-text", libelle: "Réponse"),
        "document": TypeNotification(pictogramme: "file-text", libelle: "Document"),
        "moderation": TypeNotification(pictogramme: "flag", libelle: "Modération"),
        "sondage": TypeNotification(pictogramme: "bar-chart-3", libelle: "Sondage"),
        "system": TypeNotification(pictogramme: "settings", libelle: "Système"),
        "ticket_update": TypeNotification(pictogramme: "ticket", libelle: "Affaire"),
        "urgence": TypeNotification(pictogramme: "zap", libelle: "Alerte"),
        "vigik": TypeNotification(pictogramme: "key-round", libelle: "Badge"),
    ]

    /// Un type que l'app ne connaît pas encore.
    static let parDefaut = TypeNotification(pictogramme: "bell", libelle: "Notification")
}
