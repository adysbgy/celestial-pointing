import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CelestialEngine

/// Pendamping Stellarium (ADR-016, Docs/PRODUCT_V2_IDEA.md §3).
///
/// Arah tunjuk jam ditampilkan di Stellarium desktop lewat plugin *Remote
/// Control* (HTTP, port bawaan 8090) di Wi-Fi yang sama. Jalurnya:
/// jam → iPhone (`MirrorSample`, `sendMessage` tanpa antre, ≤ 4 Hz) →
/// Stellarium (`POST /api/main/view`). Saat objek terkunci atau dikonfirmasi,
/// Stellarium diminta menyorotnya (`POST /api/main/focus`).
///
/// Stellarium **opsional** (keputusan Ady): pengenalan tetap berjalan luring
/// di jam dan iPhone. Data Stellarium tidak disalin ke app — kita hanya
/// berbicara dengan API-nya.
public enum StellariumMirror {

    public static let defaultPort = 8090

    // MARK: Konvensi arah

    /// Parameter `az`/`alt` untuk `POST /api/main/view`, dalam radian.
    ///
    /// Kerangka alt-az Stellarium: x = **Selatan**, y = Timur, z = zenit, dan
    /// `az` diukur dari Selatan ke arah Timur. Azimut kita diukur dari Utara
    /// ke Timur, jadi `az_stellarium = 180° − az_kita`. Diverifikasi terhadap
    /// Stellarium 26.3 sungguhan: `az=0` → vektor (+x) = Selatan, dan Saturnus
    /// (az 269.36° dari Utara) terbaca (x 0.0104, y −0.922).
    public static func viewAngles(_ h: HorizontalCoord) -> (azRad: Double, altRad: Double) {
        let az = SkyMath.normalizeDeg(180 - h.azimuthDeg)
        return (az * .pi / 180, h.altitudeDeg * .pi / 180)
    }

    /// Nama objek yang dikenali Stellarium untuk id katalog kita.
    /// Messier → "M42"; bintang dan planet → nama Inggris berhuruf besar awal.
    public static func objectName(forID id: String) -> String {
        if id.count >= 2, id.first == "m", id.dropFirst().allSatisfy(\.isNumber) {
            return id.uppercased()
        }
        return id.prefix(1).uppercased() + id.dropFirst()
    }

    // MARK: Permintaan HTTP

    /// Alamat dasar dari masukan pengguna ("192.168.1.20", "mac.local:8090",
    /// atau URL lengkap). `nil` bila tidak sah.
    public static func baseURL(from address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var raw = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        if let url = URL(string: raw), url.port == nil, let host = url.host, !host.isEmpty {
            raw = "\(url.scheme ?? "http")://\(host):\(defaultPort)"
        }
        guard let url = URL(string: raw), let host = url.host, !host.isEmpty else { return nil }
        return url.appendingPathComponent("api")
    }

    public static func statusRequest(base: URL) -> URLRequest {
        URLRequest(url: base.appendingPathComponent("main/status"), timeoutInterval: 3)
    }

    public static func viewRequest(base: URL, pointing: HorizontalCoord) -> URLRequest {
        let a = viewAngles(pointing)
        return form(base.appendingPathComponent("main/view"),
                    ["az": String(format: "%.6f", a.azRad), "alt": String(format: "%.6f", a.altRad)])
    }

    /// Sorot dan ikuti objek. `nil` = lepaskan pilihan (pandangan bebas lagi).
    public static func focusRequest(base: URL, objectID: String?) -> URLRequest {
        form(base.appendingPathComponent("main/focus"), ["target": objectID.map(objectName(forID:)) ?? ""])
    }

    public static func locationRequest(base: URL, observer: Observer, name: String) -> URLRequest {
        form(base.appendingPathComponent("location/setlocationfields"),
             ["latitude": String(format: "%.5f", observer.latitudeDeg),
              "longitude": String(format: "%.5f", observer.longitudeDeg),
              "name": name])
    }

    static func form(_ url: URL, _ fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields.keys.sorted().map { key in
            let value = fields[key]!.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(key)=\(value)"
        }.joined(separator: "&").data(using: .utf8)
        return request
    }
}

/// Satu sampel arah tunjuk untuk cermin Stellarium (jam → iPhone).
public struct MirrorSample: Equatable, Sendable {
    public static let plistKey = "mirror.v1"
    /// iPhone → jam: minta (atau hentikan) aliran sampel.
    public static let requestKey = "mirror.request.v1"

    public var pointing: HorizontalCoord
    public var sentAt: Date
    /// Objek terkunci saat ini, bila ada.
    public var lockedObjectID: String?
    /// Keadaan alur di jam (`PointingState.rawValue`) — untuk kartu
    /// "Langsung dari jam" di iPhone (ADR-021). Opsional: versi lama tanpa ini.
    public var state: String?

    public init(pointing: HorizontalCoord, sentAt: Date = Date(), lockedObjectID: String? = nil,
                state: String? = nil) {
        self.pointing = pointing
        self.sentAt = sentAt
        self.lockedObjectID = lockedObjectID
        self.state = state
    }

    public var plist: [String: Any] {
        var inner: [String: Any] = ["alt": pointing.altitudeDeg, "az": pointing.azimuthDeg,
                                    "t": sentAt.timeIntervalSince1970]
        if let lockedObjectID { inner["obj"] = lockedObjectID }
        if let state { inner["st"] = state }
        return [Self.plistKey: inner]
    }

    public init?(plist: [String: Any]) {
        guard let inner = plist[Self.plistKey] as? [String: Any],
              let alt = inner["alt"] as? Double, let az = inner["az"] as? Double,
              let t = inner["t"] as? Double, alt.isFinite, az.isFinite else { return nil }
        self.init(pointing: HorizontalCoord(altitudeDeg: alt, azimuthDeg: az),
                  sentAt: Date(timeIntervalSince1970: t),
                  lockedObjectID: inner["obj"] as? String,
                  state: inner["st"] as? String)
    }

    public static func request(_ on: Bool) -> [String: Any] { [requestKey: on] }
    public static func isRequest(_ plist: [String: Any]) -> Bool? { plist[requestKey] as? Bool }
}

/// Pembatas laju cermin: kirim paling sering tiap `minInterval`, dan hanya
/// bila arahnya bergeser berarti — atau objek terkuncinya berganti — kecuali
/// sudah `keepAlive` detik tanpa kiriman.
///
/// **Kenapa ada `keepAlive`.** Saat terkunci dan diam, arahnya hampir tidak
/// bergeser, jadi tanpa ini hanya **satu** sampel yang pernah terkirim. Pesan
/// `sendMessage` tanpa antre bisa hilang (jam baru terjangkau, iPhone baru
/// dibuka); sampel tunggal yang hilang membuat Stellarium tidak pernah tahu.
/// Ditemukan saat uji ujung-ke-ujung di simulator berpasangan.
public struct MirrorThrottle: Sendable {
    public var minInterval: TimeInterval
    public var minMoveDeg: Double
    public var keepAlive: TimeInterval
    private var last: MirrorSample?

    public init(minInterval: TimeInterval = 0.25, minMoveDeg: Double = 0.3, keepAlive: TimeInterval = 2) {
        self.minInterval = minInterval
        self.minMoveDeg = minMoveDeg
        self.keepAlive = keepAlive
    }

    public mutating func shouldSend(_ sample: MirrorSample) -> Bool {
        if let last {
            let elapsed = sample.sentAt.timeIntervalSince(last.sentAt)
            if sample.lockedObjectID != last.lockedObjectID || sample.state != last.state {
                self.last = sample
                return true
            }
            guard elapsed >= minInterval else { return false }
            guard elapsed >= keepAlive
                    || SkyMath.angularSeparationHorizontalDeg(sample.pointing, last.pointing) >= minMoveDeg else {
                return false
            }
        }
        last = sample
        return true
    }
}

// MARK: - Teks

/// Teks pengaturan pendamping Stellarium (ADR-016).
public enum StellariumText {
    public static var title: String { TextLocalization.text(.stellTitle) }
    public static var toggle: String { TextLocalization.text(.stellToggle) }
    public static var address: String { TextLocalization.text(.stellAddress) }
    public static var hint: String { TextLocalization.text(.stellHint) }
    public static var connected: String { TextLocalization.text(.stellConnected) }
    public static var connecting: String { TextLocalization.text(.stellConnecting) }
    public static func failed(_ reason: String) -> String { TextLocalization.text(.stellFailed, reason) }
}

public extension LocalizedText {
    static let stellTitle = LocalizedText(key: "stell.title", id: "Stellarium")
    static let stellToggle = LocalizedText(key: "stell.toggle", id: "Tampilkan arah tunjuk di Stellarium")
    static let stellAddress = LocalizedText(key: "stell.address", id: "Alamat Mac (IP)")
    static let stellHint = LocalizedText(key: "stell.hint", id: "Buka Stellarium di Mac pada Wi‑Fi yang sama. Plugin Remote Control harus menyala (port 8090).")
    static let stellConnected = LocalizedText(key: "stell.connected", id: "Tersambung ke Stellarium")
    static let stellConnecting = LocalizedText(key: "stell.connecting", id: "Menyambung…")
    static let stellFailed = LocalizedText(key: "stell.failed", id: "Tidak tersambung: %@")

    static let stellariumKeys: [LocalizedText] = [
        .stellTitle, .stellToggle, .stellAddress, .stellHint, .stellConnected, .stellConnecting, .stellFailed,
    ]
}
