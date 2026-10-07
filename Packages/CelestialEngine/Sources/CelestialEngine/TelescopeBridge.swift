import Foundation

// MARK: - Sumbu & kerangka

/// Sumbu mekanis teleskop.
///
/// **Kenapa hanya dua jenis, bukan daftar merek.** Dokumen kelayakan §17
/// meminta kontrol teleskop dimodelkan sebagai lapisan kemampuan
/// berorientasi-protokol: "logika produk tidak boleh tahu apakah implementasi
/// saat ini Seestar, Alpaca generik, atau adapter lain." Yang benar-benar
/// membedakan perintah ke motor hanyalah **jenis sumbunya**, jadi itu saja
/// yang dikenali di sini. Merek hidup di `TelescopeTransport`, di lapisan app.
public enum MountAxis: String, Codable, Equatable, Sendable, CaseIterable {
    /// Alt-az: sumbu 1 = altitude, sumbu 2 = azimuth.
    case altitudeAzimuth
    /// Ekuatorial: sumbu 1 = right ascension, sumbu 2 = deklinasi.
    case equatorial

    public var name: String {
        switch self {
        case .altitudeAzimuth: return "Alt-Az"
        case .equatorial: return "Ekuatorial"
        }
    }
}

/// Kerangka ekuatorial sebuah koordinat.
///
/// **Kenapa kerangkanya harus dinyatakan, bukan disimpulkan.** Katalog repo
/// ini menyimpan bintang dalam **J2000**, sedangkan benda tata surya datang
/// dari efemeris dalam **of-date** (`EphemerisSample`). Mengirim koordinat ke
/// mount tanpa menyebut kerangkanya berarti mount menafsirkan salah satunya
/// dengan kerangka yang salah. Untuk bintang, selisihnya ~0,3° pada 2026 —
/// lihat `SkyMath.precessJ2000ToDate` — dan itu galat yang tidak akan terlihat
/// siapa pun di layar mana pun.
public enum CoordinateFrame: String, Codable, Equatable, Sendable, CaseIterable, Hashable {
    case j2000
    case ofDate

    public var name: String {
        switch self {
        case .j2000: return "J2000"
        case .ofDate: return "Of-date"
        }
    }
}

/// Bentuk target yang diterima mount — jenisnya mengikuti sumbu mount.
///
/// **Kenapa satu enum, bukan dua field opsional.** Koordinat ekuatorial dan
/// horizontal tidak bisa saling menggantikan, dan mount hanya menerima salah
/// satunya. Enum membuat "dua-duanya terisi" dan "tidak ada yang terisi"
/// mustahil, jadi tidak ada keadaan setengah jadi yang bisa lolos ke motor.
/// Tipe `EquatorialCoord` dan `HorizontalCoord` yang sudah teruji dipakai
/// ulang — tidak ada tipe koordinat ketiga yang perlu dijaga.
public enum MountTarget: Equatable, Sendable, Codable {
    /// Untuk mount ekuatorial. `frame` menyatakan kerangka `coord`.
    case equatorial(EquatorialCoord, frame: CoordinateFrame)
    /// Untuk mount alt-az. Arah horizontal selalu "sekarang", jadi tidak ada
    /// kerangka ekuatorial yang perlu disebut.
    case horizontal(HorizontalCoord)
}

// MARK: - Kemampuan mount

/// Apa yang bisa dilakukan mount yang sedang terhubung.
///
/// Dokumen §18 menuntut "read device state and verify mount readiness" sebagai
/// langkah tersendiri sebelum GoTo, dan §18 juga menuntut versi firmware
/// menjadi bagian matriks uji. Keduanya adalah **data tentang mount**, bukan
/// tentang objek langit, jadi keduanya tinggal di sini.
public struct TelescopeCapability: Equatable, Sendable, Codable {

    /// Sumbu yang dimiliki mount.
    public var axes: MountAxis

    /// Kerangka ekuatorial yang bisa diterima mount.
    ///
    /// Hanya relevan untuk mount ekuatorial. Mount alt-az menerima arah
    /// horizontal, yang tidak punya kerangka ekuatorial.
    public var supportedFrames: Set<CoordinateFrame>

    /// Versi firmware yang **diuji**. §18: "firmware version must be part of
    /// the POC test matrix" — jadi ia disimpan bersama mountnya, bukan
    /// dicatat belakangan dari log.
    public var firmwareVersion: String

    /// Apakah mount bisa menghentikan gerakan di tengah jalan.
    ///
    /// §20 menuntut Abort/Stop tersedia. Kalau mount tidak bisa, itu keadaan
    /// yang harus **diketahui sebelum** perintah pertama, bukan ditemukan saat
    /// tombol darurat ditekan.
    public var canAbort: Bool

    public init(axes: MountAxis,
                supportedFrames: Set<CoordinateFrame>,
                firmwareVersion: String,
                canAbort: Bool) {
        self.axes = axes
        self.supportedFrames = supportedFrames
        self.firmwareVersion = firmwareVersion
        self.canAbort = canAbort
    }
}

// MARK: - Perintah yang sudah lolos gerbang

/// Perintah ke motor yang sudah melewati seluruh pemeriksaan.
///
/// **Aturan keras PRD yang ditegakkan di sini**: sudut pergelangan tidak
/// pernah menjadi gerak motor. Sama seperti `SlewCommand`, tipe ini **tidak
/// punya inisialisator publik**. Satu-satunya jalan membuatnya adalah
/// `TelescopeBridge.command(for:observer:date:)`, dan jalan itu menolak
/// apa pun yang bukan `SlewDecision.allowed`.
public struct TelescopeCommand: Equatable, Sendable {

    /// Id objek yang sudah diidentifikasi.
    public let objectID: String
    /// Nama tampilan objek — dibawa supaya log POC bisa dibaca manusia.
    public let objectName: String
    /// Posisi objek, dalam bentuk yang diminta sumbu mount.
    public let target: MountTarget
    /// Tingkat keyakinan identifikasi saat perintah dibuat.
    public let confidence: ConfidenceLevel
    /// Waktu perintah dibuat. Koordinat dihitung pada saat **ini**, bukan
    /// dipakai ulang dari saat resolusi — lihat `TelescopeBridge`.
    public let issuedAt: Date

    init(objectID: String,
         objectName: String,
         target: MountTarget,
         confidence: ConfidenceLevel,
         issuedAt: Date) {
        self.objectID = objectID
        self.objectName = objectName
        self.target = target
        self.confidence = confidence
        self.issuedAt = issuedAt
    }
}

/// Alasan sebuah perintah tidak bisa dibuat.
///
/// Setiap kasus membawa **sebab yang konkret**, bukan sekadar "gagal". Ini
/// kelas yang sama dengan `SlewHazard`: pengguna yang melihat penolakan harus
/// bisa tahu apa yang harus diperbaiki.
public enum TelescopeBridgeError: Error, Equatable {
    /// Putusan slew tidak mengizinkan gerakan. Bahayanya dibawa serta supaya
    /// pemanggil menampilkan alasannya, bukan menyembunyikannya.
    case notAllowed(hazards: [SlewHazard])
    /// Mount tidak punya sumbu yang dibutuhkan.
    case unsupportedAxis(MountAxis)
    /// Mount tidak bisa menerima kerangka ekuatorial yang diminta.
    case unsupportedFrame(CoordinateFrame)
    /// Posisi objek tidak bisa dihitung — Matahari, atau efemeris gagal.
    /// Tidak pernah ditebak: lebih baik menolak daripada menggerakkan
    /// teleskop ke tempat yang salah.
    case targetHasNoPosition(String)
    /// Mount tidak bisa menghentikan gerakan, dan itu belum diterima
    /// pengguna. Lihat `TelescopeSession`.
    case mountCannotAbort
}

// MARK: - Jembatan

/// Menerjemahkan putusan slew yang **sudah** aman menjadi perintah motor.
///
/// **Kenapa berkas ini ada.** `SlewPlanner` sudah memutuskan boleh/tidak
/// bergerak, dan `SlewCommand` sudah membawa objek + arah horizontalnya.
/// Yang belum ada adalah langkah §18 berikutnya: "resolve confirmed celestial
/// target into the coordinate representation required by the chosen control
/// path". Mount ekuatorial tidak bisa menerima arah horizontal, dan mount
/// alt-az tidak butuh RA/Dec — dan tidak satu pun dari itu boleh disimpulkan
/// diam-diam.
///
/// **Batas yang dijaga.** Tipe ini tidak pernah memutuskan boleh/tidak
/// bergerak. Ia hanya menerjemahkan putusan yang sudah diambil, dan tidak bisa
/// melunakkan penolakan menjadi izin: `command(...)` mengembalikan
/// `.notAllowed` tepat saat `SlewDecision` menolak.
public struct TelescopeBridge {

    public let resolver: PointingResolver
    public let capability: TelescopeCapability

    /// Kerangka ekuatorial yang diminta untuk mount ekuatorial.
    ///
    /// **Kenapa J2000 sebagai bawaan.** Katalog repo ini J2000, dan kerangka
    /// itulah yang biasanya diasumsikan model penunjukan mount — mengirim
    /// of-date ke mount yang mempresesi sendiri berarti mempresesi dua kali.
    /// Pilihannya **dinyatakan**, bukan disimpulkan: mount yang memakai
    /// of-date cukup memberi tahu lewat parameter ini, dan mount yang tidak
    /// mendukungnya ditolak terang-terangan, bukan diam-diam dikonversi.
    public let preferredFrame: CoordinateFrame

    public init(resolver: PointingResolver,
                capability: TelescopeCapability,
                preferredFrame: CoordinateFrame = .j2000) {
        self.resolver = resolver
        self.capability = capability
        self.preferredFrame = preferredFrame
    }

    /// Terjemahkan putusan slew menjadi perintah motor.
    ///
    /// Gagal-tertutup: apa pun yang tidak bisa diverifikasi menghasilkan
    /// `.failure`, tidak pernah perintah yang "kira-kira benar".
    ///
    /// - Parameters:
    ///   - decision: hasil `SlewPlanner.plan(...)`.
    ///   - observer: lokasi pengamat — dibutuhkan untuk konversi ke horizontal.
    ///   - date: waktu **perintah**, bukan waktu resolusi.
    public func command(for decision: SlewDecision,
                        observer: Observer,
                        date: Date) -> Result<TelescopeCommand, TelescopeBridgeError> {

        guard case .allowed(let slew) = decision else {
            return .failure(.notAllowed(hazards: decision.hazards))
        }

        let object = slew.object
        guard object.kind != .sun else {
            return .failure(.targetHasNoPosition(object.id))
        }

        let jd = SkyMath.julianDate(from: date)

        // 1. Posisi objek dalam kerangka "sekarang" (of-date).
        //
        //    Untuk benda tata surya posisinya diambil ULANG di sini, bukan
        //    dipakai ulang dari resolusi: Bulan bergerak ~0,5°/jam, jadi
        //    koordinat yang berumur beberapa menit sudah bergeser. Untuk
        //    bintang, presesi J2000 → of-date.
        let ofDate: EquatorialCoord
        switch object.kind {
        case .star, .deepSky:
            ofDate = SkyMath.precessJ2000ToDate(
                EquatorialCoord(raDeg: object.raDeg, decDeg: object.decDeg), jd: jd
            )
        case .moon, .planet:
            guard let body = EphemerisBody(rawValue: object.id), body.isPointable else {
                return .failure(.targetHasNoPosition(object.id))
            }
            guard let ephemeris = resolver.ephemeris,
                  let sample = try? ephemeris.apparent(body, at: date, from: observer) else {
                return .failure(.targetHasNoPosition(object.id))
            }
            ofDate = EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg)
        case .sun:
            // Sudah dijaga di atas; diulang supaya `switch` tetap ekshaustif
            // dan menambah `ObjectKind` baru tidak bisa lolos tanpa dibaca.
            return .failure(.targetHasNoPosition(object.id))
        }

        // 2. Bentuk yang diminta sumbu mount.
        let target: MountTarget
        switch capability.axes {
        case .equatorial:
            guard capability.supportedFrames.contains(preferredFrame) else {
                return .failure(.unsupportedFrame(preferredFrame))
            }
            let equatorial = preferredFrame == .j2000
                ? SkyMath.precessDateToJ2000(ofDate, jd: jd)
                : ofDate
            target = .equatorial(equatorial, frame: preferredFrame)
        case .altitudeAzimuth:
            // Arah horizontal harus dihitung dari posisi of-date — kalau
            // koordinat J2000 diserahkan langsung ke `equatorialToHorizontal`,
            // bintang meleset ~0,3°.
            target = .horizontal(
                SkyMath.equatorialToHorizontal(ofDate, observer: observer, jd: jd)
            )
        }

        return .success(TelescopeCommand(
            objectID: object.id,
            objectName: object.name,
            target: target,
            confidence: slew.confidence,
            issuedAt: date
        ))
    }
}

// MARK: - Transport (diimplementasikan lapisan app)

/// Kesiapan mount, dibaca dari perangkat.
public enum TelescopeReadiness: String, Codable, Equatable, Sendable {
    /// Siap menerima GoTo.
    case ready
    /// Sedang bergerak — perintah baru harus ditolak, bukan diantre.
    case slewing
    /// Terhubung tapi belum siap (mis. sedang homing).
    case notReady
    /// Tidak terhubung.
    case disconnected
}

/// Keadaan gerak mount.
public enum TelescopeMotionState: String, Codable, Equatable, Sendable {
    case idle, slewing, aborted, unknown
}

/// Sambungan nyata ke teleskop.
///
/// **Kenapa protokol, bukan struct konkret.** §17: logika produk tidak boleh
/// tahu mereknya. Implementasi (Seestar, Alpaca, simulator) hidup di lapisan
/// app; paket ini hanya tahu kontraknya. Itu juga yang membuat seluruh
/// orkestrasi di bawah bisa diuji di Linux tanpa perangkat keras — §18
/// menuntut POC diuji pada Seestar fisik, tapi urutan langkahnya sendiri bisa
/// dibuktikan di sini lebih dulu.
public protocol TelescopeTransport: AnyObject {
    /// Versi firmware perangkat yang sedang terhubung.
    var firmwareVersion: String { get }
    /// Baca kesiapan mount (§18 langkah 4).
    func readState() throws -> TelescopeReadiness
    /// Kirim perintah GoTo (§18 langkah 6).
    func goTo(_ command: TelescopeCommand) throws
    /// Hentikan gerakan (§20).
    func abort() throws
}

// MARK: - Catatan percobaan POC

/// Hasil satu percobaan GoTo.
public enum TelescopeOutcome: String, Codable, Equatable, Sendable {
    /// Perintah tidak pernah sampai ke motor — gerbang yang menolak.
    case refused
    /// Perintah terkirim tanpa galat.
    case issued
    /// Perintah terkirim tapi mount melaporkan galat.
    case failed
    /// Dihentikan atas permintaan.
    case aborted
}

/// Satu baris log percobaan POC.
///
/// §18 menuntut setiap percobaan mencatat "firmware version, command path,
/// response, timeout/error, and final pointing outcome". Tipe ini adalah
/// bentuk data dari tuntutan itu, dan ia `Codable` supaya bisa diekspor ke
/// berkas dataset seperti arsip eksperimen yang sudah ada.
public struct TelescopeAttempt: Equatable, Codable, Sendable {
    public var objectID: String
    public var target: MountTarget
    public var confidence: ConfidenceLevel
    public var firmwareVersion: String
    /// Jalur perintah yang dipakai, mis. `"seestar-community-v2"`. §18:
    /// "Pin the Seestar firmware used for POC and document the exact
    /// community command path."
    public var commandPath: String
    public var outcome: TelescopeOutcome
    /// Balasan perangkat, bila ada.
    public var response: String?
    /// Galat yang dilaporkan, bila ada. Untuk `.refused`, ini alasan gerbang.
    public var errorDescription: String?
    public var timestamp: Date

    public init(objectID: String,
                target: MountTarget,
                confidence: ConfidenceLevel,
                firmwareVersion: String,
                commandPath: String,
                outcome: TelescopeOutcome,
                response: String? = nil,
                errorDescription: String? = nil,
                timestamp: Date) {
        self.objectID = objectID
        self.target = target
        self.confidence = confidence
        self.firmwareVersion = firmwareVersion
        self.commandPath = commandPath
        self.outcome = outcome
        self.response = response
        self.errorDescription = errorDescription
        self.timestamp = timestamp
    }
}

// MARK: - Sesi

/// Menjalankan satu percobaan GoTo dan mencatatnya.
///
/// Memisahkan "menerjemahkan putusan" (`TelescopeBridge`) dari "berbicara
/// dengan perangkat" (`TelescopeTransport`) punya satu akibat yang penting
/// untuk kejujuran: **penolakan tidak pernah menyentuh perangkat keras.**
/// Kalau gerbangnya menolak, `execute` tidak memanggil transport sama sekali
/// — jadi mount yang tidak terhubung pun tidak bisa "kebetulan" bergerak.
public struct TelescopeSession {

    public let bridge: TelescopeBridge
    private let transport: TelescopeTransport
    private let commandPath: String
    /// Apakah pengguna sudah menerima risiko mount tanpa Abort (§20).
    private let acceptsNoAbort: Bool

    public init(bridge: TelescopeBridge,
                transport: TelescopeTransport,
                commandPath: String,
                acceptsNoAbort: Bool = false) {
        self.bridge = bridge
        self.transport = transport
        self.commandPath = commandPath
        self.acceptsNoAbort = acceptsNoAbort
    }

    /// Jalankan satu percobaan GoTo.
    ///
    /// **Batas yang jujur.** Yang dicatat di sini adalah perintah **terkirim**,
    /// bukan perintah **selesai**. §18 menuntut "monitor state until complete
    /// or failed", dan itu menunggu perangkat — jadi ia tugas lapisan app yang
    /// bisa `await`. Yang dijaga di sini adalah bahwa setiap langkah sebelum
    /// perangkat disentuh tidak bisa dilewati.
    public func execute(_ decision: SlewDecision,
                        observer: Observer,
                        date: Date) -> TelescopeAttempt {

        // §20: mount tanpa kemampuan Abort hanya boleh dipakai setelah
        // risikonya diterima secara eksplisit. Diperiksa SEBELUM perintah
        // dibuat, jadi tidak ada perintah yang lahir dari mount seperti itu.
        guard acceptsNoAbort || bridge.capability.canAbort else {
            return record(outcome: .refused,
                          objectID: decision.allowedObjectID ?? "—",
                          target: nil,
                          confidence: .low,
                          error: TelescopeBridgeError.mountCannotAbort,
                          timestamp: date)
        }

        switch bridge.command(for: decision, observer: observer, date: date) {
        case .failure(let error):
            return record(outcome: .refused,
                          objectID: decision.allowedObjectID ?? "—",
                          target: nil,
                          confidence: .low,
                          error: error,
                          timestamp: date)
        case .success(let command):
            do {
                try transport.goTo(command)
                return TelescopeAttempt(
                    objectID: command.objectID,
                    target: command.target,
                    confidence: command.confidence,
                    firmwareVersion: transport.firmwareVersion,
                    commandPath: commandPath,
                    outcome: .issued,
                    timestamp: date
                )
            } catch {
                return TelescopeAttempt(
                    objectID: command.objectID,
                    target: command.target,
                    confidence: command.confidence,
                    firmwareVersion: transport.firmwareVersion,
                    commandPath: commandPath,
                    outcome: .failed,
                    errorDescription: String(describing: error),
                    timestamp: date
                )
            }
        }
    }

    /// Hentikan gerakan.
    ///
    /// §20: Abort **tidak pernah** bergantung pada kesiapan mount maupun pada
    /// apakah ada perintah yang sedang berjalan. Menolak Abort karena "tidak
    /// ada yang bergerak" berarti tombol darurat yang bisa mati sendiri.
    public func abort(now: Date) -> TelescopeAttempt {
        do {
            try transport.abort()
            return TelescopeAttempt(
                objectID: "—",
                target: .horizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)),
                confidence: .low,
                firmwareVersion: transport.firmwareVersion,
                commandPath: commandPath,
                outcome: .aborted,
                timestamp: now
            )
        } catch {
            return TelescopeAttempt(
                objectID: "—",
                target: .horizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)),
                confidence: .low,
                firmwareVersion: transport.firmwareVersion,
                commandPath: commandPath,
                outcome: .failed,
                errorDescription: String(describing: error),
                timestamp: now
            )
        }
    }

    private func record(outcome: TelescopeOutcome,
                        objectID: String,
                        target: MountTarget?,
                        confidence: ConfidenceLevel,
                        error: TelescopeBridgeError,
                        timestamp: Date) -> TelescopeAttempt {
        TelescopeAttempt(
            objectID: objectID,
            // Perintah yang ditolak tidak punya target. Nilai di bawah tidak
            // pernah sampai ke motor — `outcome == .refused` dan transport
            // tidak dipanggil sama sekali.
            target: target ?? .horizontal(HorizontalCoord(altitudeDeg: 0, azimuthDeg: 0)),
            confidence: confidence,
            firmwareVersion: transport.firmwareVersion,
            commandPath: commandPath,
            outcome: outcome,
            errorDescription: String(describing: error),
            timestamp: timestamp
        )
    }
}

private extension SlewDecision {
    /// Id objek bila GoTo diizinkan; `nil` bila ditolak.
    var allowedObjectID: String? {
        guard case .allowed(let command) = self else { return nil }
        return command.object.id
    }
}

// MARK: - Kebutuhan jaringan lokal (§19)

/// Deklarasi yang harus ada di Info.plist agar iPhone boleh bicara ke
/// teleskop di jaringan lokal.
///
/// **Kenapa ini ada sebagai data.** §19: komunikasi langsung ke host lokal
/// menuntut `NSLocalNetworkUsageDescription`, dan browsing Bonjour menuntut
/// entri `NSBonjourServices`. Keduanya adalah **kunci Info.plist yang
/// kelupaan** — dan kegagalannya bukan galat yang terbaca: aplikasinya hanya
/// diam-diam tidak menemukan teleskop. Menaruhnya di sini membuat lapisan app
/// bisa membacanya, dan menjadikannya sesuatu yang bisa diuji.
public struct TelescopeNetworkRequirements: Equatable, Sendable {

    /// Kunci Info.plist yang wajib ada.
    public static let localNetworkUsageKey = "NSLocalNetworkUsageDescription"
    /// Kunci daftar tipe layanan Bonjour.
    public static let bonjourServicesKey = "NSBonjourServices"

    /// Kalimat yang ditampilkan iOS saat meminta izin jaringan lokal.
    public var usageDescription: String
    /// Tipe layanan Bonjour yang di-browse. Kosong berarti tidak memakai
    /// Bonjour — dan kalau kosong, entri `NSBonjourServices` tidak perlu ada.
    public var bonjourServiceTypes: [String]

    public init(usageDescription: String, bonjourServiceTypes: [String] = []) {
        self.usageDescription = usageDescription
        self.bonjourServiceTypes = bonjourServiceTypes
    }

    /// Apakah entri `NSBonjourServices` dibutuhkan.
    public var needsBonjourDeclaration: Bool { !bonjourServiceTypes.isEmpty }
}
