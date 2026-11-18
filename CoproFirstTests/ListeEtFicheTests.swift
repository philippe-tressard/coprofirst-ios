// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import SwiftUI
import Testing

@testable import CoproFirst

/// La liste et la fiche côte à côte (#222) : la largeur de la liste, en classe régulière.
struct ListeEtFicheTests {
    @Test func uneColonneBorneeTientSaLargeurIdeale() {
        let partage = Partage.parDefaut
        #expect(partage.largeurDeLaListe(dans: 1376) == Mise.listeIdeale, "iPad 13 pouces en paysage")
        #expect(partage.largeurDeLaListe(dans: 1032) == Mise.listeIdeale, "en portrait")
    }

    @Test func laListeNePrendJamaisPlusQueLaMoitie() {
        let partage = Partage.liste(ideale: 400, min: 300, max: 440)
        #expect(partage.largeurDeLaListe(dans: 694) == 347, "Split View aux deux tiers : la fiche reste la plus large")
        #expect(partage.largeurDeLaListe(dans: 500) == 300, "jamais sous la borne basse")
    }

    @Test func leCarnetCoupeAuPli() {
        #expect(Partage.proportion(0.5).largeurDeLaListe(dans: 900) == 450)
        #expect(Partage.proportion(1.4).largeurDeLaListe(dans: 900) == 900, "une part bornée à 1")
        #expect(Partage.proportion(-1).largeurDeLaListe(dans: 900) == 0)
    }

    @Test func laFicheVaOuLaClasseDeTailleLeDit() {
        #expect(Disposition.pour(.compact, colonneFournie: true) == .pile, "iPhone, Split View étroit : la pile")
        #expect(Disposition.pour(nil, colonneFournie: false) == .pile)
        #expect(Disposition.pour(.regular, colonneFournie: true) == .colonne, "iPad : la colonne de la page")
        #expect(Disposition.pour(.regular, colonneFournie: false) == .coteACote, "sans colonne : le repli")
    }

    /// L'iPad en portrait : deux colonnes, la page en classe compacte ; en paysage, liste et
    /// fiche côte à côte. Liste, fiche et barre en portrait étaient illisibles.
    @Test func laPageDeLaBarreEstCompacteEnPortrait() {
        #expect(ClasseDeLaPage.pour(CGSize(width: 820, height: 1180)) == .compact, "iPad 11 pouces en portrait")
        #expect(ClasseDeLaPage.pour(CGSize(width: 1032, height: 1376)) == .compact, "iPad 13 pouces en portrait")
        #expect(ClasseDeLaPage.pour(CGSize(width: 1180, height: 820)) == .regular, "en paysage : rien ne change")
        #expect(ClasseDeLaPage.pour(.zero) == .regular, "pas encore mesurée : la classe de la barre")
        #expect(Disposition.pour(ClasseDeLaPage.pour(CGSize(width: 820, height: 1180)), colonneFournie: true) == .pile)
    }

    /// Le titre d'un menu se règle par UN modificateur, la colonne ouverte ou non (#279) :
    /// un `if` donnait deux identités à la page, qui bouclait en s'ouvrant.
    @MainActor @Test func leTitreDeMenuSuitLaColonneEtLaTaille() {
        #expect(TitreDeMenu.mode(colonneOuverte: true, taille: .large) == .enTete, "une fiche à côté")
        #expect(TitreDeMenu.mode(colonneOuverte: true, taille: .accessibility3) == .enTete)
        #expect(TitreDeMenu.mode(colonneOuverte: false, taille: .large) == .grand)
        #expect(TitreDeMenu.mode(colonneOuverte: false, taille: .accessibility3) == .enLigne, "le très grand texte")
    }

    /// Le titre en tête, l'action de la page passe à droite : iOS 26 retire la gauche (#223).
    @MainActor @Test func lActionDeMenuPasseADroiteQuandLeTitreEstEnTete() {
        #expect(TitreDeMenu.actionADroite(colonneOuverte: true, taille: .large), "une fiche à côté")
        #expect(!TitreDeMenu.actionADroite(colonneOuverte: false, taille: .large))
        #expect(!TitreDeMenu.actionADroite(colonneOuverte: false, taille: .accessibility3))
    }

    /// Une liste qui disparaît après l'apparition de la suivante ne ferme pas la colonne
    /// de celle-ci (Liste → Archives, un onglet qui change).
    @MainActor @Test func uneSeuleListeOccupeLaColonne() {
        let colonne = ColonneDeFiche()
        let premiere = UUID()
        let seconde = UUID()
        colonne.ouvrir(par: premiere, partage: .parDefaut)
        colonne.ouvrir(par: seconde, partage: .proportion(0.5))
        colonne.fermer(par: premiere)
        #expect(colonne.ouverte, "la seconde l'occupe toujours")
        #expect(colonne.partage == .proportion(0.5))
        colonne.montrer(.init(id: 1, vue: AnyView(EmptyView())), par: premiere)
        #expect(colonne.contenu == nil, "l'ancienne n'y montre plus rien")
        colonne.montrer(.init(id: 2, vue: AnyView(EmptyView())), par: seconde)
        #expect(colonne.contenu?.id == AnyHashable(2))
        colonne.fermer(par: seconde)
        #expect(!colonne.ouverte && colonne.contenu == nil, "fermée : la page reprend la largeur")
    }

    @Test func laColonneParDefautResteDansSesBornes() {
        #expect(Mise.listeMin <= Mise.listeIdeale && Mise.listeIdeale <= Mise.listeMax)
    }
}
