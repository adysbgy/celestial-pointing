import Foundation
import Combine
import os
import CelestialEngine
import PointingKit

/// iPhone sebagai jembatan jam → Stellarium desktop (ADR-016).
///
/// Saat aktif: lokasi iPhone dikirim ke Stellarium sekali, jam diminta
/// mengalirkan arah tunjuk, dan setiap sampel memutar pandangan Stellarium.
/// Saat jam terkunci pada sebuah objek (atau objek dikonfirmasi), Stellarium
/// menyorot dan mengikutinya; begitu kunci lepas, pandangan bebas lagi.
/// Satu permintaan pandangan dalam perjalanan pada satu waktu — yang datang
/// saat sibuk dibuang, karena arah lama tidak berguna.
@MainActor
final class StellariumBridge: ObservableObject {
    enum Status: Equatable { case off, connecting, connected, failed(String) }

    static let enabledKey = "stellarium.enabled"
    static let addressKey = "stellarium.address"

    @Published private(set) var status: Status = .off {
        didSet { Self.log.info("status \(String(describing: self.status), privacy: .public)") }
    }
    private static let log = Logger(subsystem: "dev.celestial.pointandknow", category: "stellarium")

    private let link: PhoneLinkService
    private weak var engine: PointingEngine?
    private var base: URL?
    private var viewInFlight = false
    private var focusedID: String?
    private var cancellables: Set<AnyCancellable> = []

    init(link: PhoneLinkService) {
        self.link = link
        link.onMirrorSample = { [weak self] sample in self?.handle(sample) }
        link.onReachable = { [weak self] in
            guard let self, self.status != .off else { return }
            self.link.requestMirror(true)
        }
        // Objek yang dikonfirmasi di jam ikut disorot.
        link.$lastConfirmed
            .compactMap { $0?.message.objectID }
            .sink { [weak self] id in self?.focus(id) }
            .store(in: &cancellables)
    }

    /// Terapkan pengaturan (dipanggil saat sakelar/alamat berubah dan saat app aktif).
    func apply(enabled: Bool, address: String, engine: PointingEngine) {
        self.engine = engine
        guard enabled, let base = StellariumMirror.baseURL(from: address) else {
            if status != .off { link.requestMirror(false) }
            status = .off
            self.base = nil
            return
        }
        self.base = base
        status = .connecting
        Task {
            do {
                _ = try await send(StellariumMirror.statusRequest(base: base))
                _ = try await send(StellariumMirror.locationRequest(base: base, observer: engine.controller.observer,
                                                                    name: "Point & Know"))
                _ = try await send(StellariumMirror.focusRequest(base: base, objectID: nil))
                focusedID = nil
                status = .connected
                link.requestMirror(true)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    /// Kirim lokasi baru ke Stellarium (lokasi sungguhan sering datang
    /// setelah jembatan tersambung).
    func updateLocation(_ observer: Observer) {
        guard status == .connected, let base else { return }
        Task { _ = try? await send(StellariumMirror.locationRequest(base: base, observer: observer,
                                                                    name: "Point & Know")) }
    }

    private func handle(_ sample: MirrorSample) {
        Self.log.info("sample alt \(sample.pointing.altitudeDeg) az \(sample.pointing.azimuthDeg) obj \(sample.lockedObjectID ?? "-", privacy: .public)")
        guard status == .connected, let base else { return }
        if sample.lockedObjectID != focusedID {
            focus(sample.lockedObjectID)
            return
        }
        guard sample.lockedObjectID == nil, !viewInFlight else { return }
        viewInFlight = true
        Task {
            _ = try? await send(StellariumMirror.viewRequest(base: base, pointing: sample.pointing))
            viewInFlight = false
        }
    }

    private func focus(_ id: String?) {
        guard status == .connected, let base else { return }
        focusedID = id
        Task { _ = try? await send(StellariumMirror.focusRequest(base: base, objectID: id)) }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        Self.log.info("\(request.httpMethod ?? "GET", privacy: .public) \(request.url?.path ?? "", privacy: .public) -> \(code)")
        guard code == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
