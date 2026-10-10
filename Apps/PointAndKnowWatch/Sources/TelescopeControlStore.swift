import SwiftUI
import WatchKit
import CelestialEngine
import PointingKit

/// Satu sumber keadaan kontrol teleskop di jam (ADR-009), dipakai bersama
/// oleh bilah Stop di layar utama dan bagian GoTo di panel identifikasi.
/// Aturannya tetap di `TelescopeControlModel` (PointingKit, teruji).
@MainActor
final class TelescopeControlStore: ObservableObject {
    @Published private(set) var model = TelescopeControlModel()
    /// Detak 1 dtk: laporan yang menua harus mengubah tampilan walau tidak
    /// ada pesan baru.
    @Published private(set) var now = Date()

    private weak var link: WatchLinkService?
    private var tick: Timer?
    private var pollTask: Task<Void, Never>?
    private var observers: [Any] = []
    private static let featureOffKey = "telescope.featureKnownOff"

    init() {
        model.featureKnownOff = UserDefaults.standard.bool(forKey: Self.featureOffKey)
    }

    func bind(_ link: WatchLinkService) {
        guard self.link == nil else { return }
        self.link = link
        observers.append(link.$telescopeStatus.sink { [weak self] status in
            guard let self, let status else { return }
            self.apply(status)
        })
        observers.append(link.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.syncReachability() }
        })
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        syncReachability()
    }

    private func apply(_ status: TelescopeStatus) {
        model.status = status
        let off = status.state == .disabled
        if model.featureKnownOff != off {
            model.featureKnownOff = off
            UserDefaults.standard.set(off, forKey: Self.featureOffKey)
        }
    }

    private func syncReachability() {
        guard let link else { return }
        let reachable = link.isPhoneReachable
        guard model.isReachable != reachable else { return }
        model.isReachable = reachable
        pollTask?.cancel()
        guard reachable else { return }
        // `applicationContext` bisa tertahan >10 dtk (terukur di simulator:
        // 17 dtk), jadi selama iPhone terjangkau keadaan juga ditanya
        // langsung tiap 3 dtk.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.pollLiveStatus()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func pollLiveStatus() {
        link?.live.requestTelescopeStatus { [weak self] result in
            guard case .replied(let reply) = result, let readiness = reply.telescope else { return }
            DispatchQueue.main.async {
                self?.apply(TelescopeStatus(readiness: readiness, at: Date(), detail: "live"))
            }
        }
    }

    // MARK: Tindakan

    func confirm(objectID: String) { model.confirm(objectID: objectID) }
    func clearConfirmation() { model.clearConfirmation() }

    func goTo(name: String) {
        guard let link, let id = model.confirmedObjectID, model.beginGoTo(now: Date()) else { return }
        link.live.goTo(objectID: id, name: name) { [weak self] result in
            DispatchQueue.main.async {
                self?.model.finishGoTo(result)
                if case .replied(let r) = result, r.accepted {
                    WKInterfaceDevice.current().play(.start)
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }

    func stop() {
        guard let link else { return }
        model.beginStop()
        WKInterfaceDevice.current().play(.stop)
        link.live.stop { [weak self] result in
            DispatchQueue.main.async {
                self?.model.finishStop(result)
                if case .replied(let r) = result, r.accepted {
                    WKInterfaceDevice.current().play(.success)
                } else {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }
}

/// Bilah Stop yang selalu ada di layar utama selama slew **mungkin** berjalan
/// — terlepas dari kartu konfirmasi, dan juga untuk slew yang dimulai di
/// iPhone.
struct TelescopeStopBar: View {
    @ObservedObject var store: TelescopeControlStore

    var body: some View {
        let state = store.model.effectiveState(now: store.now)
        if store.model.showsStop(now: store.now) {
            VStack(spacing: 2) {
                Button(role: .destructive) {
                    store.stop()
                } label: {
                    Label(TelescopeControlText.stop, systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PointingTone.danger.color)
                // Hitam di atas merah terang (~7:1); putih hanya ~3:1.
                .foregroundStyle(.black)
                .disabled(store.model.lastAction == .sendingStop)
                .accessibilityHint(TelescopeControlText.state(state))
                Label(TelescopeControlText.state(state), systemImage: TelescopeControlText.symbol(state))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
