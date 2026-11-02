// SPDX-FileCopyrightText: 2026 Philippe TRESSARD
// SPDX-License-Identifier: AGPL-3.0-or-later WITH LicenseRef-CoproFirst-AppStore

import SwiftUI
import VisionKit

/// Le QR code de la fiche d'arrivée : il porte l'adresse du site de la résidence.
struct ScannerQRView: View {
    let reconnu: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
                    CameraQR(reconnu: reconnu)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView(
                        "Caméra indisponible",
                        systemImage: "camera.metering.unknown",
                        description: Text("Cet appareil ne peut pas lire de QR code. Saisissez l'adresse du site.")
                    )
                }
            }
            .navigationTitle("Scanner le QR code")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// La caméra, réglée pour les seuls QR codes ; le premier lu referme la feuille.
private struct CameraQR: UIViewControllerRepresentable {
    let reconnu: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controleur = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        controleur.delegate = context.coordinator
        try? controleur.startScanning()
        return controleur
    }

    func updateUIViewController(_ controleur: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(reconnu: reconnu) }

    final class Coordinateur: NSObject, DataScannerViewControllerDelegate {
        let reconnu: (String) -> Void
        private var dejaLu = false

        init(reconnu: @escaping (String) -> Void) {
            self.reconnu = reconnu
        }

        func dataScanner(
            _ scanner: DataScannerViewController, didAdd elements: [RecognizedItem], allItems: [RecognizedItem]
        ) {
            guard !dejaLu else { return }
            for case .barcode(let code) in elements {
                if let texte = code.payloadStringValue, AdresseInstallation.normaliser(texte) != nil {
                    dejaLu = true
                    scanner.stopScanning()
                    reconnu(texte)
                    return
                }
            }
        }
    }
}
