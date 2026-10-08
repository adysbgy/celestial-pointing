import SwiftUI
import WatchKit
import CelestialEngine
import PointingKit

/// GoTo / Stop di jam (ADR-009). Aturan ada di `TelescopeControlModel`
/// (PointingKit, teruji); view ini hanya menampilkan dan mengirim.
///
/// - GoTo hanya untuk objek yang dikonfirmasi **langsung** ke iPhone, saat
///   iPhone terjangkau dan teleskop dilaporkan siap (laporan ≤ 10 dtk).
/// - Stop tampil setiap kali teleskop sedang atau mungkin bergerak — juga
///   setelah "Tunjuk lagi". Double Tap **tidak** dipasang ke GoTo: gerakan
///   motor harus ketukan yang disengaja.
/// - Tidak ada antrean dan tidak ada coba-ulang: gagal ditampilkan apa adanya.
struct TelescopeControlSection: View {
    @ObservedObject var link: WatchLinkService
    @Binding var control: TelescopeControlModel
    let objectName: String?

    var body: some View {
        // Dievaluasi ulang tiap detik supaya laporan yang menua menjadi
        // "tidak diketahui" walau tidak ada pesan baru.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
        .onAppear { sync() }
        .onChange(of: link.telescopeStatus) { _, _ in sync() }
        .onChange(of: link.isPhoneReachable) { _, _ in sync() }
        // `applicationContext` bisa tertahan >10 dtk (terukur di simulator:
        // jeda 17 dtk), jadi selama iPhone terjangkau keadaan juga ditanya
        // langsung tiap 3 dtk. Laporan yang lebih tua tidak menimpa yang
        // lebih baru (`TelescopeControlModel.status`).
        .task(id: link.isPhoneReachable) {
            guard link.isPhoneReachable else { return }
            while !Task.isCancelled {
                pollLiveStatus()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func sync() {
        if let status = link.telescopeStatus { control.status = status }
        control.isReachable = link.isPhoneReachable
    }

    private func pollLiveStatus() {
        link.live.requestTelescopeStatus { result in
            guard case .replied(let reply) = result, let readiness = reply.telescope else { return }
            DispatchQueue.main.async {
                control.status = TelescopeStatus(readiness: readiness, at: Date(), detail: "live")
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let state = control.effectiveState(now: now)
        // Teleskop mati dan tidak ada yang perlu dihentikan: tidak ada baris.
        if state != .disabled || control.showsStop(now: now) {
            VStack(spacing: 4) {
                Label(TelescopeControlText.state(state), systemImage: TelescopeControlText.symbol(state))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if control.showsStop(now: now) {
                    Button(role: .destructive) {
                        stop()
                    } label: {
                        Label(TelescopeControlText.stop, systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PointingTone.danger.color)
                    // Hitam di atas merah terang (~7:1); putih hanya ~3:1.
                    .foregroundStyle(.black)
                    .disabled(control.lastAction == .sendingStop)
                    .accessibilityHint(TelescopeControlText.state(state))
                }

                if control.canGoTo(now: now), let objectName {
                    Button {
                        goTo(objectName)
                    } label: {
                        Label(TelescopeControlText.goTo(objectName), systemImage: "scope")
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else if control.showsPhoneUnreachable(now: now) && state != .disabled {
                    Label(TelescopeControlText.phoneUnreachable, systemImage: "iphone.slash")
                        .font(.footnote)
                }

                if let line = TelescopeControlText.action(control.lastAction) {
                    Text(line)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func goTo(_ name: String) {
        guard let id = control.confirmedObjectID, control.beginGoTo(now: Date()) else { return }
        link.live.goTo(objectID: id, name: name) { result in
            DispatchQueue.main.async {
                control.finishGoTo(result)
                if case .replied(let r) = result, r.accepted {
                    WKInterfaceDevice.current().play(.start)
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }

    private func stop() {
        control.beginStop()
        WKInterfaceDevice.current().play(.stop)
        link.live.stop { result in
            DispatchQueue.main.async {
                control.finishStop(result)
                if case .replied(let r) = result, r.accepted {
                    WKInterfaceDevice.current().play(.success)
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
}
