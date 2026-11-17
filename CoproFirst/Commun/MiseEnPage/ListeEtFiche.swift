// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// Une liste et la fiche de l'élément choisi (#222), écrit UNE fois pour tous les écrans
/// liste → fiche — et pour le carnet de l'iPhone pliable (#119), qui le reprend.
///
/// - **Classe compacte** (iPhone, iPad en Split View étroit) : la pile d'aujourd'hui, la
///   fiche poussée par-dessus la liste (`navigationDestination(item:)`).
/// - **Classe régulière** (iPad, pliable déplié) : la liste à gauche, la fiche à droite,
///   dans la COLONNE DE FICHE que fournit la page (`ColonneDeFiche`) — une pile sœur de
///   la sienne : son titre, sa barre d'outils et ce qu'elle pousse restent dans sa
///   colonne, la liste ne se perd pas, sa rangée soulignée (`rangeeChoisie`). Rien de
///   choisi : `vide`. Sans colonne fournie, liste et fiche côte à côte ici même — un
///   repli : la fiche y partage la barre de la page (`Disposition`).
///
/// La décision se prend sur la classe de taille HORIZONTALE, jamais sur l'appareil :
/// `verifier-depot.sh` refuse toute lecture de l'idiome dans ce dossier. La sélection
/// appartient à l'appelant, dans un `@State` de son écran — que le changement de
/// présentation (pli, Split View) reconstruit : une liste qui se nomme (`memoire:`) la
/// retrouve dans la `MemoireDesSelections` de la résidence, et le marque-page du pliable
/// la garde sur disque (#119). Sans nom, la fiche se referme au changement.
struct ListeEtFiche<Element: Hashable, Liste: View, Fiche: View, Vide: View>: View {
    @Binding var selection: Element?
    let partage: Partage
    /// Le nom de la liste dans sa page, pour retrouver l'élément ouvert (`MemoireDesSelections`).
    let memoire: String?
    let liste: Liste
    let fiche: (Element) -> Fiche
    let vide: Vide
    @Environment(\.horizontalSizeClass) private var classe
    @Environment(\.colonneDeFiche) private var colonne
    @Environment(\.selectionsDeLaPage) private var selections
    @Environment(\.palette) private var palette
    /// Qui occupe la colonne de fiche : cette liste, tant qu'elle est à l'écran.
    @State private var jeton = UUID()
    /// La mémoire ne se relit qu'à la CONSTRUCTION de la liste : en pile, revenir d'une fiche
    /// fait réapparaître la liste avant que le `nil` du retour soit noté — la fiche se rouvrait.
    @State private var repriseFaite = false

    init(
        selection: Binding<Element?>,
        partage: Partage = .parDefaut,
        memoire: String? = nil,
        @ViewBuilder liste: () -> Liste,
        @ViewBuilder fiche: @escaping (Element) -> Fiche,
        @ViewBuilder vide: () -> Vide
    ) {
        _selection = selection
        self.partage = partage
        self.memoire = memoire
        self.liste = liste()
        self.fiche = fiche
        self.vide = vide()
    }

    var body: some View {
        disposee.onChange(of: selection) { _, choisi in noter(choisi) }
    }

    @ViewBuilder
    private var disposee: some View {
        switch disposition {
        case .pile:
            listeQuiChoisit.navigationDestination(item: $selection) { ficheSeule($0) }
                .onAppear { _ = reprendre() }
        case .colonne:
            dansLaColonne
        case .coteACote:
            GeometryReader { cadre in
                HStack(spacing: 0) {
                    listeQuiChoisit
                        .environment(\.ficheOuverte, selection.map(AnyHashable.init))
                        .frame(width: partage.largeurDeLaListe(dans: cadre.size.width))
                    Divider().ignoresSafeArea(edges: .bottom)
                    NavigationStack {
                        if let selection {
                            ficheSeule(selection).id(selection)
                        } else {
                            vide.frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.bg)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .onAppear { _ = reprendre() }
        }
    }

    /// L'élément que la liste avait ouvert, si elle n'en a pas : rendu à l'appelant.
    private func reprendre() -> Element? {
        guard !repriseFaite else { return selection }
        repriseFaite = true
        guard selection == nil, let memoire, let selections else { return selection }
        let repris = selections.memoire.reprendre(Element.self, sous: selections.cle(memoire))
        if let repris { selection = repris }
        return repris
    }

    private func noter(_ choisi: Element?) {
        guard let memoire, let selections else { return }
        selections.memoire.noter(choisi, sous: selections.cle(memoire))
    }

    private var disposition: Disposition { .pour(classe, colonneFournie: colonne != nil) }

    /// La liste, et ce que ses `LienDeFiche` choisissent : un autre type que `Element`
    /// est une erreur d'écriture, pas un choix.
    private var listeQuiChoisit: some View {
        liste.environment(
            \.choixDeFiche,
            ChoixDeFiche(enPile: disposition == .pile) { valeur in
                guard let element = valeur.base as? Element else {
                    return assertionFailure("LienDeFiche de \(type(of: valeur.base)) dans une liste de \(Element.self)")
                }
                selection = element
            })
    }

    /// La fiche, sans le choix de la liste : ses propres liens ne choisissent pas pour elle.
    private func ficheSeule(_ element: Element) -> some View {
        fiche(element).environment(\.choixDeFiche, nil)
    }

    /// La liste seule ici ; sa fiche part dans la colonne de la page.
    private var dansLaColonne: some View {
        listeQuiChoisit
            .environment(\.ficheOuverte, selection.map(AnyHashable.init))
            .onAppear {
                // La reprise AVANT d'ouvrir la colonne : sinon « Aucune sélection », puis la fiche.
                let choisi = reprendre()
                colonne?.ouvrir(par: jeton, partage: partage)
                publier(choisi)
            }
            .onDisappear { colonne?.fermer(par: jeton) }
            .onChange(of: selection) { _, choisi in publier(choisi) }
    }

    private func publier(_ choisi: Element?) {
        // Le fond de la page sous « Aucune sélection » : sans lui, la colonne gardait celui du
        // système (blanc, noir au sombre) à côté d'une page teintée par la palette.
        let vue =
            choisi.map { AnyView(ficheSeule($0)) }
            ?? AnyView(vide.frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.bg))
        colonne?.montrer(.init(id: choisi.map(AnyHashable.init), vue: vue), par: jeton)
    }
}

/// Où va la fiche d'une `ListeEtFiche` — décidé sur la classe de taille seule.
enum Disposition: Equatable {
    /// Poussée par-dessus la liste (classe compacte : iPhone, Split View étroit).
    case pile
    /// Dans la colonne de fiche de la page, pile sœur à droite de la liste.
    case colonne
    /// À côté de la liste, dans la pile de la page : le repli sans colonne fournie.
    case coteACote

    static func pour(_ classe: UserInterfaceSizeClass?, colonneFournie: Bool) -> Self {
        guard classe == .regular else { return .pile }
        return colonneFournie ? .colonne : .coteACote
    }
}

extension ListeEtFiche where Vide == FicheVide {
    /// Sans fiche choisie : « Aucune sélection », comme les apps du système.
    init(
        selection: Binding<Element?>,
        partage: Partage = .parDefaut,
        memoire: String? = nil,
        @ViewBuilder liste: () -> Liste,
        @ViewBuilder fiche: @escaping (Element) -> Fiche
    ) {
        self.init(selection: selection, partage: partage, memoire: memoire, liste: liste, fiche: fiche) {
            FicheVide()
        }
    }
}

/// La fiche quand rien n'est choisi : « Aucune sélection », comme les apps du système.
struct FicheVide: View {
    var body: some View {
        ContentUnavailableView(ListeEtFicheTextes.aucuneSelection, systemImage: "sidebar.left")
    }
}

/// Le partage de la largeur entre la liste et la fiche, en classe régulière.
enum Partage: Equatable, Sendable {
    /// Une colonne de liste à sa largeur idéale, bornée — la fiche prend le reste.
    case liste(ideale: CGFloat, min: CGFloat, max: CGFloat)
    /// Une part de la largeur pour la liste : le carnet, `.proportion(0.5)`, coupé au pli.
    case proportion(Double)

    /// La colonne de liste des apps du système (`Mise.listeIdeale`…).
    static let parDefaut = Partage.liste(ideale: Mise.listeIdeale, min: Mise.listeMin, max: Mise.listeMax)

    /// La largeur de la liste dans `largeur` : jamais plus de la moitié pour une colonne
    /// bornée, sans quoi un iPad en Split View régulier laisserait une fiche plus étroite
    /// que sa liste.
    func largeurDeLaListe(dans largeur: CGFloat) -> CGFloat {
        switch self {
        case .liste(let ideale, let min, let max):
            return Swift.max(min, Swift.min(ideale, max, largeur / 2))
        case .proportion(let part):
            return largeur * Swift.min(Swift.max(part, 0), 1)
        }
    }
}

enum ListeEtFicheTextes {
    static let aucuneSelection = "Aucune sélection"
}
