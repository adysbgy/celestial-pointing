import SwiftUI
import CelestialEngine
import PointingKit

/// Bagian GoTo di panel identifikasi (ADR-009). Stop **tidak** di sini: ia
/// ada di `TelescopeStopBar` di atas layar utama, supaya selalu terjangkau.
///
/// - GoTo hanya untuk objek yang dikonfirmasi **langsung** ke iPhone, saat
///   iPhone terjangkau dan teleskop dilaporkan siap (laporan ≤ 10 dtk).
///   Double Tap **tidak** dipasang ke GoTo.
/// - Tidak ada antrean dan tidak ada coba-ulang.
struct TelescopeControlSection: View {
    @ObservedObject var store: TelescopeControlStore
    let objectName: String?

    var body: some View {
        let now = store.now
        let model = store.model
        let state = model.effectiveState(now: now)
        let stopShown = model.showsStop(now: now)
        if state != .disabled || model.lastAction != .none {
            VStack(spacing: 4) {
                // Saat Stop tampil, bilah Stop di atas sudah menyebut keadaan.
                if !stopShown {
                    Label(TelescopeControlText.state(state), systemImage: TelescopeControlText.symbol(state))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if model.canGoTo(now: now), let objectName {
                    Button {
                        store.goTo(name: objectName)
                    } label: {
                        Label(TelescopeControlText.goTo(objectName), systemImage: "scope")
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else if model.showsPhoneUnreachable(now: now) && state != .disabled {
                    Label(TelescopeControlText.phoneUnreachable, systemImage: "iphone.slash")
                        .font(.footnote)
                }
                if let line = TelescopeControlText.action(model.lastAction) {
                    Text(line)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
