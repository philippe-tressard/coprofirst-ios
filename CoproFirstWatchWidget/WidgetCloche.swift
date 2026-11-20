// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import WidgetKit

/// Le widget de l'Apple Watch (#226, lot 3), pendant de la tuile et de la complication de
/// Wear OS : dans la pile de widgets, une phrase — « 2 nouvelles alertes · dont 1 urgente » ;
/// sur le cadran, le logo de CoproFirst, avec un point s'il y a du non lu. Ni titre, ni corps,
/// ni nom de résidence : d'autres le voient aussi. Un toucher ouvre l'app.
///
/// Il ne lit rien sur le réseau et ne garde aucun jeton : il relit le résumé que l'app écrit
/// dans l'App Group après chaque lecture (`PartageDuResume`), et l'app le fait recharger.
@main
struct WidgetCloche: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.coprofirst.app.cloche", provider: ChronologieCloche()) { entree in
            VueWidgetCloche(resume: entree.resume)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(TextesMontre.widgetNom)
        .description(TextesMontre.widgetDescription)
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner])
    }
}

struct EntreeCloche: TimelineEntry {
    let date: Date
    let resume: ResumeCloche
}

/// Une seule entrée, le résumé écrit par l'app : c'est l'app qui demande la relecture
/// (`Surfaces`, au premier plan comme en arrière-plan), jamais une horloge du widget.
struct ChronologieCloche: TimelineProvider {
    func placeholder(in context: Context) -> EntreeCloche {
        EntreeCloche(date: .now, resume: .compte(nonLues: 2, urgentes: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeCloche) -> Void) {
        let lu = EntreeCloche(date: .now, resume: PartageDuResume.lire())
        completion(context.isPreview ? placeholder(in: context) : lu)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeCloche>) -> Void) {
        completion(Timeline(entries: [EntreeCloche(date: .now, resume: PartageDuResume.lire())], policy: .never))
    }
}

struct VueWidgetCloche: View {
    let resume: ResumeCloche
    @Environment(\.widgetFamily) private var famille

    var body: some View {
        switch famille {
        case .accessoryRectangular:
            Text(resume.phrase)
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(MiseMontre.reductionDuWidget)
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            LogoAuPoint(point: resume.pointNonLu)
        }
    }
}

/// Le logo de CoproFirst (sa licence, `LicenseRef-CoproFirst-Logo`, jamais redessiné) et, s'il y
/// a du non lu, un point au coin, à la couleur de danger de la charte. Le cadran teinte l'image
/// à sa guise : le point y reste un point.
struct LogoAuPoint: View {
    let point: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .widgetAccentable()
            if point {
                Circle()
                    .fill(Palette.seine.danger)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(MiseMontre.pointDuWidget, anchor: .topTrailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(point ? TextesMontre.complicationNonLu : TextesMontre.complicationRien)
    }
}
