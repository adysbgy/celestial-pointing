import Foundation
import CelestialEngine

/// Nada visual untuk sebuah keadaan.
///
/// Dipisahkan dari SwiftUI supaya **janji tampilan bisa diuji**: PRD melarang
/// membuat engine terlihat lebih yakin daripada keadaannya. Kalau `uncertain`
/// dan `lock` memakai nada yang sama, seluruh aturan anti-false-lock di engine
/// jadi sia-sia di layar. Uji `PointingPresentationTests` menjaga itu.
public enum PointingTone: String, Equatable, Sendable {
    /// Belum ada apa-apa (idle).
    case neutral
    /// Sedang bekerja (pointing, searching).
    case active
    /// Jawaban yakin (lock).
    case success
    /// Ada jawaban tapi ragu (uncertain).
    case warning
    /// Tidak bisa dipakai (sensor hilang).
    case danger
}

public extension PointingState {

    /// Nada visual keadaan ini.
    var tone: PointingTone {
        switch self {
        case .idle: return .neutral
        case .pointing, .searching: return .active
        case .lock: return .success
        case .uncertain: return .warning
        case .unavailable: return .danger
        }
    }

    /// Nama SF Symbol untuk keadaan ini.
    var symbolName: String {
        switch self {
        case .idle: return "scope"
        case .pointing: return "location.north.line"
        case .searching: return "sparkle.magnifyingglass"
        case .lock: return "checkmark.circle.fill"
        case .uncertain: return "questionmark.circle"
        case .unavailable: return "exclamationmark.triangle"
        }
    }

    /// Label singkat untuk layar jam.
    var shortLabel: String {
        switch self {
        case .idle: return "Siap"
        case .pointing: return "Arahkan"
        case .searching: return "Mencari"
        case .lock: return "Terkunci"
        case .uncertain: return "Kurang yakin"
        case .unavailable: return "Sensor mati"
        }
    }

    /// Kalimat penjelasan — apa yang harus dilakukan pengguna.
    var guidance: String {
        switch self {
        case .idle: return "Angkat jam dan arahkan ke langit."
        case .pointing: return "Tahan arah tunjuk sampai jam berhenti bergerak."
        case .searching: return "Belum ada objek di arah itu."
        case .lock: return "Objek dikenali dengan keyakinan tinggi."
        case .uncertain: return "Ada kandidat, tapi belum cukup yakin untuk memastikan."
        case .unavailable: return "Jam tidak memberi data gerak. Coba lagi."
        }
    }

    /// Apakah keadaan ini boleh ditampilkan seolah pasti.
    var looksConfident: Bool { self == .lock }
}

public extension ConfidenceLevel {
    /// Label Indonesia untuk ditampilkan.
    var displayName: String {
        switch self {
        case .high: return "Yakin"
        case .medium: return "Ragu"
        case .low: return "Tidak tahu"
        }
    }

    /// Nada visual tingkat keyakinan.
    ///
    /// Medium sengaja `warning`, bukan `success`: engine yang ragu harus
    /// terlihat ragu.
    var tone: PointingTone {
        switch self {
        case .high: return .success
        case .medium: return .warning
        case .low: return .danger
        }
    }
}

public extension PointingSnapshot {

    /// Objek yang layak ditampilkan di panel detail.
    ///
    /// Saat keadaan punya jawaban (`lock`/`uncertain`) itu jawaban engine.
    /// Saat `searching`, objek terakhir yang pernah terkunci dipertahankan
    /// supaya panel tidak kosong hanya karena pergelangan bergerak sedikit —
    /// dan panel itu **wajib** ditandai lewat `isDisplayingStaleObject`.
    ///
    /// Logikanya ditaruh di sini, bukan di pembungkus UI, karena ia menegakkan
    /// aturan PRD: objek lama tidak boleh tampil seolah hasil pengukuran
    /// sekarang. Di sini ia bisa diuji di Linux bersama janji tampilan lain.
    func displayedObject(lastLocked: CelestialObject?) -> CelestialObject? {
        if let best = intent?.best { return best }
        return state == .searching ? lastLocked : nil
    }

    /// Apakah objek yang ditampilkan adalah sisa dari pandangan sebelumnya.
    ///
    /// **Yang menentukan adalah apakah keadaan punya jawaban sekarang**
    /// (`state.hasAnswer`), bukan dari mana objek itu diambil. Mesin keadaan
    /// sengaja mempertahankan `intent` supaya tampilan tidak berkedip, jadi
    /// `intent?.best` tetap terisi objek **dari arah tunjuk sebelumnya** saat
    /// keadaan sudah kembali `pointing`. Menilai "basi" dari `intent?.best ==
    /// nil` karena itu justru melaporkan "bukan sisa" untuk objek yang paling
    /// basi — dan peringatan di layar tidak pernah bisa muncul.
    func isDisplayingStaleObject(lastLocked: CelestialObject?) -> Bool {
        displayedObject(lastLocked: lastLocked) != nil && !state.hasAnswer
    }

    /// Apakah identitas objek boleh **diklaim oleh gambar**.
    ///
    /// Ambang ini sengaja **lebih ketat** daripada `isDisplayingStaleObject`,
    /// dan perbedaannya bukan sekadar rasa. `hasAnswer` mencakup `.lock`
    /// **dan** `.uncertain`: pada `.uncertain` engine memang punya kandidat,
    /// tapi ia menyatakan diri kurang yakin. Menurunkan `isConfirmed` dari
    /// `!isStale` karena itu meloloskan **seluruh ciri pengenal** tepat pada
    /// keadaan ragu — cincin Saturnus, pita Jupiter, kutub Mars — sementara
    /// badge di sebelahnya bertuliskan "Ragu".
    ///
    /// Gambar yang lebih yakin daripada teksnya adalah bentuk false
    /// confidence yang paling sulit ditangkap: teksnya jujur, dan mata
    /// membaca gambar lebih dulu daripada badge. Karena itu ambangnya
    /// `state.looksConfident` (hanya `.lock`) — predikat yang **sudah ada dan
    /// sudah diuji**, bukan yang baru ditulis untuk keperluan ini.
    func confirmsIdentity(lastLocked: CelestialObject?) -> Bool {
        displayedObject(lastLocked: lastLocked) != nil && state.looksConfident
    }

    /// Objek yang berlaku **untuk arah tunjuk sekarang**.
    ///
    /// `bestObject` sengaja mempertahankan objek terakhir supaya panel jam tidak
    /// berkedip saat pergelangan bergerak sedikit — itu benar untuk tampilan,
    /// yang menandai objek sisa sebagai sisa. Untuk apa pun yang **mengirim atau
    /// merekam** "apa yang engine katakan sekarang" (pesan ke iPhone, riwayat
    /// keyakinan), objek yang dipertahankan itu bukan jawaban: ia berasal dari
    /// arah tunjuk sebelumnya. Yang berlaku hanya saat keadaan punya jawaban.
    var answeredObject: CelestialObject? { state.hasAnswer ? intent?.best : nil }

    /// Tingkat keyakinan yang berlaku untuk arah tunjuk sekarang.
    ///
    /// `nil` saat keadaan tidak punya jawaban — termasuk saat `intent` masih
    /// membawa keyakinan lama. Keyakinan yang menempel pada keadaan tanpa
    /// jawaban adalah klaim yang tidak berlaku.
    var answeredLevel: ConfidenceLevel? { state.hasAnswer ? intent?.level : nil }

    /// Jarak kandidat terbaik ke arah tunjuk, hanya bila ada jawaban sekarang.
    ///
    /// Ini angka yang dipakai `ConfidenceModel` untuk memutuskan; jarak dari
    /// resolusi lama bukan jarak sekarang, jadi ia tidak boleh ikut terekam.
    var answeredSeparationDeg: Double? {
        state.hasAnswer ? intent?.candidates.first?.separationDeg : nil
    }

    /// Arah tunjuk yang boleh dilaporkan sebagai pengukuran **sekarang**.
    ///
    /// `calibratedPointing` sengaja dipertahankan di cuplikan supaya panel jam
    /// tidak berkedip saat pergelangan bergerak, jadi ia **tetap terisi** saat
    /// sensor mati — dengan nilai terakhir sebelum sensor hilang. Bagi layar jam
    /// itu aman: keadaan `unavailable` ditampilkan tepat di sebelah angkanya.
    /// Bagi apa pun yang **dikirim atau ditampilkan di tempat lain** tidak ada
    /// penanda seperti itu, sehingga azimut/ketinggian dari beberapa detik lalu
    /// terbaca sebagai bacaan sekarang. Yang berlaku hanya bila sensor benar-
    /// benar hidup.
    ///
    /// Satu predikat dipakai bersama oleh layar jam (`PointingEngine.pointing`)
    /// dan pesan ke iPhone (`PointingLinkMessage.state(from:)`) supaya kedua
    /// jalur tidak bisa lagi berbeda pendapat tentang kapan arah tunjuk berlaku.
    var reportedPointing: HorizontalCoord? { hasSensor ? calibratedPointing : nil }
}

/// Ringkasan sekali-pakai untuk **complication jam** (WidgetKit).
///
/// **Kenapa bentuk ini, bukan struct Codable milik app.** Complication berjalan
/// di proses terpisah dan tidak boleh menarik `PointingKit`/`CelestialEngine`
/// ke dalam target extension-nya. Yang perlu ia tahu hanyalah beberapa
/// nilai sederhana — nama objek, keadaan — yang sudah dihitung di app. Tapi
/// aturan merangkumnya ("jangan tampilkan nama sebagai jawaban kalau ragu")
/// adalah **janji tampilan**, dan janji itu harus bisa diuji di Linux bareng
/// `confirmsIdentity` yang lain. Maka bentuk ini:
/// - `Codable` & `Sendable` supaya bisa disimpan/diteruskan lintas proses,
/// - **tidak** menyimpan objek engine, jadi tidak ada cara satu nama ditulis
///   dengan dua ejaan berbeda,
/// - logika `headline`/`hasAnswer`/`isConfirmed` diuji di `PointingKitTests`.
///
/// **Kenapa menyimpan `ObjectKind`, bukan labelnya.** Label Bahasa Indonesia
/// milik tiap jenis benda (`"Objek langit dalam"`, `"Bintang"`, …) adalah
/// urusan **lapisan aplikasi** — ia tinggal di `Apps/Shared`, bukan di engine,
/// dan boleh berubah sewaktu-waktu saat UX berubah. Kalau label ikut di-*snapshot*,
/// maka setiap perubahan label jadi **data lama yang salah** di complication
/// sampai app menyimpan ulang. Menyimpan `ObjectKind` (nilai engine yang stabil)
/// membuat label selalu dihitung saat render — satu sumber label, selalu mutakhir.
public struct ComplicationDigest: Codable, Sendable, Equatable {
    /// Keadaan engine (`PointingState` rawValue — `String, Codable`).
    public var stateRaw: String
    /// Nama objek terkunci, bila ada.
    public var objectName: String?
    /// Jenis objek sebagai `ObjectKind` mentah (bukan label tampilan).
    public var objectKindRaw: String?
    /// Apakah identitas terkonfirmasi (`state.looksConfident`, hanya `.lock`).
    public var isConfirmed: Bool
    /// Kapan ringkasan ini ditulis.
    public var updatedAt: Date

    public init(stateRaw: String,
                objectName: String?,
                objectKindRaw: String?,
                isConfirmed: Bool,
                updatedAt: Date) {
        self.stateRaw = stateRaw
        self.objectName = objectName
        self.objectKindRaw = objectKindRaw
        self.isConfirmed = isConfirmed
        self.updatedAt = updatedAt
    }

    /// Bangun digest dari cuplikan engine + objek terakhir yang terkunci.
    ///
    /// App tidak pernah menyusun string status sendiri — ia melepas keputusan
    /// "tampil sebagai apa" ke sini, supaya complication, status card, dan
    /// panel detail tidak punya tiga versi aturan yang berbeda.
    public init(snapshot: PointingSnapshot, lastLocked: CelestialObject?) {
        let object = snapshot.displayedObject(lastLocked: lastLocked)
        self.init(stateRaw: snapshot.state.rawValue,
                  objectName: object?.name,
                  objectKindRaw: object?.kind.rawValue,
                  isConfirmed: snapshot.confirmsIdentity(lastLocked: lastLocked),
                  updatedAt: Date())
    }

    /// Keadaan sebagai enum, atau `nil` bila `stateRaw` tak dikenal.
    public var state: PointingState? { PointingState(rawValue: stateRaw) }

    /// Jenis objek sebagai enum, atau `nil` bila tidak ada / tak dikenal.
    public var objectKind: ObjectKind? {
        objectKindRaw.flatMap { ObjectKind(rawValue: $0) }
    }

    /// Apakah snapshot ini berisi hasil pengenalan yang layak dipajang.
    ///
    /// Sama persis dengan `PointingState.hasAnswer`: `.lock` **dan** `.uncertain`.
    /// `.uncertain` tetap dihitung sebagai "ada jawaban" karena memang ada
    /// kandidat — yang ditahan adalah klaim *pasti*-nya lewat `isConfirmed`,
    /// bukan keberadaannya.
    public var hasAnswer: Bool { state?.hasAnswer ?? false }

    /// Baris utama complication: nama objek bila terkunci, atau label keadaan.
    ///
    /// **`uncertain` tetap menampilkan nama kandidat**, sama seperti layar
    /// utama — menutupinya di sini akan membuat complication berbeda dari app
    /// dan menyembunyikan informasi yang memang jujur ("ada kandidat, belum
    /// pasti"). Yang dijaga `isConfirmed`: identitas tidak pernah diklaim pasti.
    public var headline: String {
        if let name = objectName, hasAnswer {
            return name
        }
        return state?.shortLabel ?? "Point & Know"
    }

    /// Label keadaan untuk fallback (mis. saat nama kosong).
    public var stateLabel: String { state?.shortLabel ?? "Point & Know" }
}
