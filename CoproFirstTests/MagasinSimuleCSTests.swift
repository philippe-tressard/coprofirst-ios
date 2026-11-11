// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import Foundation
import Testing

@testable import CoproFirst

/// Le contenu de départ d'un magasin peut lire un AUTRE magasin du même service (#118 :
/// la boîte des notifications lit son volume dans ses réglages). Construit sous le verrou
/// du registre, il s'y reprenait : l'app simulée se figeait, cloche sans compte, et les
/// tests d'interface tombaient un à un sans que rien ne dise pourquoi.
///
/// Un interblocage ne rend jamais la main : la lecture part sur un fil à elle, et le
/// test n'attend qu'un délai.
@Test func unMagasinSeConstruitEnLisantUnAutre() {
    let service = ServiceSimule(delai: .zero)
    let fini = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
        let lu = MagasinSimuleCS<[Int]>.de(service) { [MagasinSimuleCS<Int>.de(service) { 3 }.valeur] }
        if lu.valeur == [3] { fini.signal() }
    }
    #expect(fini.wait(timeout: .now() + 5) == .success, "le registre s'est repris lui-même : interblocage")
}

/// Hors verrou, deux fils peuvent construire chacun leur contenu : un seul est gardé,
/// et tous lisent celui-là.
@Test func deuxFilsLisentLeMemeMagasin() async {
    let service = ServiceSimule(delai: .zero)
    let boites = await withTaskGroup(of: ObjectIdentifier.self) { groupe in
        for rang in 0..<16 {
            groupe.addTask { ObjectIdentifier(MagasinSimuleCS<[String]>.de(service) { ["\(rang)"] }) }
        }
        return await groupe.reduce(into: Set<ObjectIdentifier>()) { $0.insert($1) }
    }
    #expect(boites.count == 1)
}
