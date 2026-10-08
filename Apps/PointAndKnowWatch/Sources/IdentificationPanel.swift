import SwiftUI
import WatchKit
import CelestialEngine
import PointingKit

/// Point → Identify → Confirm di jam (ADR-007).
///
/// Pencocokan sepenuhnya lokal di jam (resolver + katalog + efemeris di
/// perangkat); iPhone hanya dibutuhkan untuk **menerima** konfirmasi. Tanpa
/// iPhone, konfirmasi tetap berhasil di jam dan dicatat sebagai riwayat
/// (`LiveSendResult.recordedOnly`).
struct IdentificationPanel: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var link: WatchLinkService

    enum Delivery: Equatable { case sending, live, recordedOnly, failed }

    struct Confirmation: Equatable {
        let object: CelestialObject
        var delivery: Delivery
    }

    @State private var confirmation: Confirmation?

    private var outcome: IdentificationOutcome { .from(engine.snapshot) }

    var body: some View {
        VStack(spacing: 6) {
            if let confirmation {
                confirmedCard(confirmation)
            } else {
                outcomeView
            }
            // Ambang belum terukur: selalu terlihat, supaya tidak ada demo
            // yang menyiratkan akurasi yang sudah divalidasi.
            Text(verbatim: IdentificationText.sigmaLine(engine.controller.resolver.confidencePolicy))
                .font(.caption2)
                .foregroundStyle(.secondary)
                // Dibaca VoiceOver sebagai kalimat, bukan "sigma 10 titik 0".
                .accessibilityLabel(IdentificationText.sigmaAccessibility(
                    engine.controller.resolver.confidencePolicy))
        }
    }

    @ViewBuilder
    private var outcomeView: some View {
        switch outcome {
        case .unavailable:
            EmptyView()
        case .holdSteady:
            // Ikon + teks: keadaan tidak pernah hanya dibedakan warna.
            Label(IdentificationText.holdSteady, systemImage: "hand.raised")
                .font(.headline)
                .accessibilityAddTraits(.updatesFrequently)
        case .notSure:
            Label(IdentificationText.notSure, systemImage: "questionmark.circle")
                .font(.footnote)
                .multilineTextAlignment(.center)
        case .single(let object):
            confirmButton(object, prominent: true)
        case .possibleMatches(let objects):
            Label(IdentificationText.possibleMatches, systemImage: "list.bullet")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(objects, id: \.id) { confirmButton($0, prominent: false) }
        }
    }

    @ViewBuilder
    private func confirmButton(_ object: CelestialObject, prominent: Bool) -> some View {
        let button = Button {
            confirm(object)
        } label: {
            Text(IdentificationText.confirm(object.name))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        // VoiceOver membaca label tombol apa adanya: "Konfirmasi Saturnus".
        if prominent {
            button.buttonStyle(.borderedProminent)
                .tint(PointingTone.success.color)
                // Teks hitam di atas hijau terang: putih hanya ~1,8:1, hitam ~11:1.
                .foregroundStyle(.black)
                // Ketuk dua kali (Double Tap) mengonfirmasi tanpa menurunkan
                // lengan dari arah tunjuk.
                .handGestureShortcut(.primaryAction)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func confirmedCard(_ c: Confirmation) -> some View {
        VStack(spacing: 4) {
            Label(IdentificationText.confirmed(c.object.name), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(deliveryText(c.delivery))
                .font(.footnote)
                .foregroundStyle(c.delivery == .failed ? PointingTone.danger.color : .secondary)
                .multilineTextAlignment(.center)
            Button(IdentificationText.pointAgain) { confirmation = nil }
                .buttonStyle(.bordered)
        }
        .accessibilityElement(children: .combine)
    }

    private func deliveryText(_ d: Delivery) -> String {
        switch d {
        case .sending: return IdentificationText.sending
        case .live: return IdentificationText.deliveredLive
        case .recordedOnly: return IdentificationText.deliveredRecorded
        case .failed: return IdentificationText.deliveryFailed
        }
    }

    private func confirm(_ object: CelestialObject) {
        confirmation = Confirmation(object: object, delivery: .sending)
        // Konfirmasi sudah terjadi di jam begitu diketuk: haptic sekarang,
        // bukan menunggu iPhone.
        WKInterfaceDevice.current().play(.success)
        link.live.confirm(objectID: object.id, name: object.name) { result in
            let delivery: Delivery
            switch result {
            case .replied(let reply): delivery = reply.accepted ? .live : .failed
            case .recordedOnly: delivery = .recordedOnly
            case .failed: delivery = .failed
            }
            DispatchQueue.main.async {
                guard confirmation?.object == object else { return }
                confirmation?.delivery = delivery
                if delivery == .failed { WKInterfaceDevice.current().play(.failure) }
            }
        }
    }
}
