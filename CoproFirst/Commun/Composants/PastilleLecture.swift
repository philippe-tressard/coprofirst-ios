// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI

/// « Qui la lit » sur une carte (`PastilleLecture.svelte` du site, #129) : la teinte des
/// badges bleus, les pictogrammes des lecteurs, le libellé court, le cadenas quand seuls
/// ceux du périmètre lisent. **Rien** quand personne n'est exclu (`par_defaut`) ni quand
/// l'installation ne la sert pas.
///
/// Elle ne s'ouvre pas au toucher : sur une carte, le toucher ouvre le contenu, où la
/// phrase entière se lit (`LectureDetaillee`). VoiceOver lit la phrase de la bulle.
struct PastilleLecture: View {
    let lecture: Lecture?
    /// Un sondage : « Qui le lit ».
    var masculin = false
    @Environment(\.palette) private var palette

    var body: some View {
        if let lecture = Lecture.aMontrer(lecture) {
            let (texte, fond) = PastilleTeinte.teintes("badge-blue")
            HStack(spacing: 3) {
                ForEach(Array(lecture.icones.enumerated()), id: \.offset) { _, nom in
                    Image(systemName: Pictogrammes.symbole(nom))
                }
                Text(lecture.court).lineLimit(1)
                if lecture.perimetreReserve { Image(systemName: Pictogrammes.symbole("lock")) }
            }
            .font(.caption2.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .foregroundStyle(palette[keyPath: texte])
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(palette[keyPath: fond], in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(lecture.enClair(masculin: masculin))
        }
    }
}

/// « Qui la lit » sur le détail d'un contenu : la pastille, puis la phrase entière — ce
/// que la bulle du site montre au toucher, ici visible (`ux-patterns-ios` : jamais un
/// survol seul). Rien quand personne n'est exclu, comme sur la carte.
struct LectureDetaillee: View {
    let lecture: Lecture?
    var masculin = false
    @Environment(\.palette) private var palette

    var body: some View {
        if let lecture = Lecture.aMontrer(lecture) {
            VStack(alignment: .leading, spacing: 6) {
                Text(masculin ? "Qui le lit" : "Qui la lit")
                    .styleLibelle()
                    .accessibilityAddTraits(.isHeader)
                PastilleLecture(lecture: lecture, masculin: masculin)
                    .accessibilityHidden(true)
                Text(lecture.titre)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                Text(lecture.phraseEntiere)
                    .font(.subheadline)
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("lecture.detail")
        }
    }
}

/// Le lieu d'un contenu, tel que servi (`LieuServi`) : l'épingle et le libellé — rien
/// pour le périmètre par défaut. Taille et teinte : celles de la ligne qui le porte.
struct EtiquetteLieu: View {
    let lieu: String?

    var body: some View {
        if let lieu { Label(lieu, systemImage: "mappin").accessibilityLabel("Lieu : \(lieu)") }
    }
}
