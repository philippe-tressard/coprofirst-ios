# SPDX-FileCopyrightText: 2026 Philippe TRESSARD
# SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore
"""Le PLANCHER : la version de coprofirst sur laquelle l'app se génère — et le seul
endroit où elle s'écrit (`scripts/generer.py` et `scripts/concordance.py` la lisent).

L'app parle à des installations de versions différentes (vagues Urgence, Standard,
Fixe). Elle se génère donc sur la plus ANCIENNE version servie par une installation
connue : un contrat plus récent rendrait obligatoires des champs qu'une installation
plus ancienne n'envoie pas, et ses réponses ne se décoderaient plus. Ce n'est pas un
retard, c'est un choix.

Monter le plancher est une DÉCISION, prise quand toutes les installations connues ont
dépassé la nouvelle version : le ticket « à monter » de la concordance quotidienne dit
ce qu'elle exigera (champs nouvellement requis, fichiers qui changent). On change alors
`VERSION` et `RAISON`, puis `python3 scripts/generer.py`, dans la même PR.

Le plancher ne se croit pas sur parole : la concordance quotidienne MESURE le contrat
que sert chaque installation de `INSTALLATIONS` (`version_contrat` de GET /config, #83).
Une installation SOUS le plancher est un écart (l'app ne s'y ouvrirait plus) ; toutes
AU-DESSUS, le ticket « a-monter » dit jusqu'où le plancher peut monter.
"""

# Les installations connues dont la concordance mesure le contrat servi : des adresses
# publiques, nommées ici et nulle part ailleurs. Ce n'est pas un annuaire — l'app n'en a
# aucun, et n'en lit aucun (spec multi-coproprietes §4.1 bis de coprofirst).
INSTALLATIONS = ("demo.coprofirst.fr", "5hostachy.fr")

VERSION = "v3.101.0"
RAISON = (
    "contrat 2.0.0 : la notation des prestataires (trois états, récapitulatif par exercice "
    "et par intervention, modifier son avis — coprofirst#2728 à #2745, coprofirst-ios#207). "
    "Montée décidée le 15/11/2026 par le coordinateur des sessions, sur délégation écrite de "
    "Philippe (« demande au coordinateur ») ; fusionnée quand demo.coprofirst.fr et "
    "5hostachy.fr servent le contrat 2.0.0"
)
