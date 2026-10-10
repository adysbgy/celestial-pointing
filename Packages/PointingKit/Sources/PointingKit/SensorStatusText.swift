import Foundation

/// Kalimat status sensor & izin yang **dihasilkan** di luar view.
///
/// **Kenapa ini ada.** Kalimat ini adalah satu-satunya jalur sampai pesan
/// "izin ditolak" dan "sensor tidak tersedia" ke layar — dan PRD menuntut
/// penolakan izin **terlihat**, bukan senyap. Tetapi teksnya hidup sebagai
/// literal di dalam `LocationProvider`, `MotionLogger`, dan `PointingEngine`:
/// ditugaskan ke properti (`note = "…"`, `sensorNote = "…"`), bukan diteruskan
/// ke `Text("…")`. Aturan 4 menyapu literal yang menjadi argumen langsung, jadi
/// ia tidak pernah melihat bentuk ini, dan **tidak satu pun** dari kalimat itu
/// ada di `Localizable.xcstrings`. Pengguna Bahasa Inggris melihat "Izin lokasi
/// ditolak" tanpa satu pun gerbang merah — persis kelas "hijau yang tidak
/// hijau" yang sudah berulang di repo ini.
///
/// **Kenapa di paket, bukan di view.** Kalimat yang sama muncul di **dua** app
/// (jam dan iPhone menampilkan `location.note`), dan dua salinan sudah mulai
/// menyimpang: pesan kegagalan lokasi disusun di dua tempat dengan bentuk yang
/// berbeda. Lewat sini keduanya membaca frasa yang sama dan katalognya satu.
///
/// **Batasnya.** Yang disediakan adalah kalimat siap pakai; kapan ia ditampilkan
/// tetap milik masing-masing view. Status lokasi yang tidak pernah dibaca UI
/// (`notRequested`, `searching`, `waiting`, `unknown`) ikut masuk katalog karena
/// menambahnya nanti berarti menambah kunci yang bisa lupa diterjemahkan —
/// murah sekarang, mahal saat sudah lupa.
public enum SensorStatusText {

    // MARK: - Sensor gerak

    /// Pesan saat perangkat ini tidak menyediakan device motion.
    public static var motionMissing: String {
        TextLocalization.text(.sensorMotionMissing)
    }

    /// Catatan engine saat data gerak tidak tersedia.
    public static var motionUnavailable: String {
        TextLocalization.text(.sensorMotionUnavailable)
    }

    /// Sensor gerak berhenti di tengah pemakaian, dengan pesan sistemnya.
    ///
    /// **Kenapa pesan sistemnya harus dibungkus, tidak ditampilkan apa adanya.**
    /// `CMMotionManager` menyerahkan `error.localizedDescription`, dan itu
    /// teks **sistem** — ia mengikuti bahasa perangkat, bukan bahasa yang
    /// sedang membaca katalog. Menampilkannya langsung berarti satu baris di
    /// layar berbahasa Inggris di tengah layar yang serba Indonesia, dan
    /// tidak ada gerbang yang melihatnya: ia bukan literal di `Apps/`
    /// (Aturan 4), bukan penugasan berakhiran Note (Aturan 12), dan bukan
    /// argumen `String(format:)` (Aturan 13) — ia argumen fungsi.
    ///
    /// Nama sumbernya tetap **ditampilkan**, bukan disembunyikan di balik
    /// kalimat generik: dua kegagalan yang berbeda tidak boleh terbaca sama
    /// pada baris yang dipakai untuk memutuskan apakah jamnya masih bisa
    /// dipakai. Alasan yang sama dengan
    /// `ObserverLocation.sourceDisplayName` untuk sumber tak dikenal.
    public static func motionFailed(_ message: String) -> String {
        TextLocalization.text(.sensorMotionFailed, message)
    }

    // MARK: - Lokasi

    /// Status awal sebelum izin diminta.
    public static var locationNotRequested: String {
        TextLocalization.text(.sensorLocationNotRequested)
    }

    /// Status saat lokasi sedang dicari.
    public static var locationSearching: String {
        TextLocalization.text(.sensorLocationSearching)
    }

    /// Status saat menunggu jawaban izin lokasi.
    public static var locationWaiting: String {
        TextLocalization.text(.sensorLocationWaiting)
    }

    /// Status saat izin lokasi ditolak (versi pendek untuk baris status).
    public static var locationDeniedStatus: String {
        TextLocalization.text(.sensorLocationDeniedStatus)
    }

    /// Status saat status izin tidak dikenal sistem.
    public static var locationUnknownStatus: String {
        TextLocalization.text(.sensorLocationUnknownStatus)
    }

    /// Penjelasan saat izin lokasi ditolak — apa yang bisa dilakukan pengguna.
    ///
    /// Ini yang wajib terlihat saat penolakan (PRD): bukan hanya "ditolak",
    /// tapi bahwa langit dihitung untuk lokasi darurat dan cara memperbaikinya.
    public static var locationDeniedNote: String {
        TextLocalization.text(.sensorLocationDeniedNote)
    }

    /// Status saat izin lokasi **dibatasi** perangkat (versi pendek).
    ///
    /// Terpisah dari `locationDeniedStatus` karena penyebabnya berbeda dan
    /// tindakannya berbeda. Lihat `locationRestrictedNote`.
    public static var locationRestrictedStatus: String {
        TextLocalization.text(.sensorLocationRestrictedStatus)
    }

    /// Penjelasan saat izin lokasi **dibatasi** perangkat, bukan ditolak.
    ///
    /// **Kenapa ini kunci sendiri, bukan varian dari `locationDeniedNote`.**
    /// `CLAuthorizationStatus` memisahkan `.denied` dari `.restricted`, dan
    /// pemisahan itu ada bukan tanpa alasan: `.denied` berarti pengguna
    /// menolak dan **bisa** mengubahnya di Pengaturan; `.restricted` berarti
    /// perangkatnya tidak mengizinkan — Pembatasan Orang Tua atau profil MDM —
    /// dan **tidak ada satu pun layar Pengaturan** yang bisa mengubahnya.
    ///
    /// Versi sebelumnya memetakan keduanya ke satu kalimat: "Buka Pengaturan
    /// untuk mengizinkan". Untuk pengguna `.restricted` itu petunjuk yang
    /// **tidak bisa berhasil** — ia akan mencari layar yang tidak ada, gagal,
    /// dan menyimpulkan aplikasinya rusak. Itu kebohongan yang sama bentuknya
    /// dengan visual yang mengklaim identitas saat engine ragu: menuntun ke
    /// kepastian yang tidak dimiliki aplikasi. PRD menuntut penolakan izin
    /// terlihat dan **jelas**; "jelas" di sini berarti sebabnya benar.
    public static var locationRestrictedNote: String {
        TextLocalization.text(.sensorLocationRestrictedNote)
    }

    /// Status akurasi lokasi yang diterima.
    public static func locationAccuracy(meters: Double) -> String {
        TextLocalization.text(.sensorLocationAccuracy, meters)
    }

    /// Status saat lokasi gagal, dengan pesan sistem.
    public static func locationFailedStatus(_ message: String) -> String {
        TextLocalization.text(.sensorLocationFailedStatus, message)
    }

    /// Penjelasan saat lokasi gagal, dengan pesan sistem.
    public static func locationFailedNote(_ message: String) -> String {
        TextLocalization.text(.sensorLocationFailedNote, message)
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    /// Kunci dan nilai bawaan untuk status sensor & izin.
    static let sensorMotionMissing = LocalizedText(
        key: "sensor.motion.missing",
        id: "Perangkat ini tidak menyediakan device motion.")
    static let sensorMotionUnavailable = LocalizedText(
        key: "sensor.motion.unavailable",
        id: "Data gerak tidak tersedia.")
    /// Kegagalan sensor gerak di tengah pemakaian; `%@` pesan sistemnya.
    ///
    /// Masuk daftar karena `MotionLogger.handleFailure` menyimpan
    /// `error.localizedDescription` **apa adanya** ke `unavailableReason`,
    /// dan properti itu dirender `Text(reason)` di dua layar. Teks sistem
    /// mengikuti bahasa perangkat, bukan bahasa katalog — jadi barisnya
    /// satu-satunya yang tidak bisa diterjemahkan. Lihat
    /// `SensorStatusText.motionFailed`.
    static let sensorMotionFailed = LocalizedText(
        key: "sensor.motion.failed",
        id: "Sensor gerak berhenti: %@")

    static let sensorLocationNotRequested = LocalizedText(
        key: "sensor.location.notRequested",
        id: "Lokasi belum diminta")
    static let sensorLocationSearching = LocalizedText(
        key: "sensor.location.searching",
        id: "Mencari lokasi…")
    static let sensorLocationWaiting = LocalizedText(
        key: "sensor.location.waiting",
        id: "Menunggu izin lokasi…")
    static let sensorLocationDeniedStatus = LocalizedText(
        key: "sensor.location.denied.status",
        id: "Izin lokasi ditolak — memakai lokasi bawaan")
    static let sensorLocationUnknownStatus = LocalizedText(
        key: "sensor.location.unknown.status",
        id: "Status lokasi tidak dikenal")
    static let sensorLocationDeniedNote = LocalizedText(
        key: "sensor.location.denied.note",
        id: "Izin lokasi ditolak. Buka Pengaturan untuk mengizinkan, atau pakai lokasi bawaan (Jakarta).")
    /// Status singkat saat izin lokasi **dibatasi** perangkat, bukan ditolak
    /// pengguna. Terpisah dari `sensor.location.denied.status` karena
    /// tindakannya berbeda — lihat `sensor.location.restricted.note`.
    static let sensorLocationRestrictedStatus = LocalizedText(
        key: "sensor.location.restricted.status",
        id: "Izin lokasi dibatasi perangkat — memakai lokasi bawaan")
    /// Penjelasan saat izin lokasi dibatasi perangkat (Pembatasan Orang Tua /
    /// MDM). **Sengaja tidak menyuruh membuka Pengaturan**, karena tidak ada
    /// layar Pengaturan yang bisa mengubahnya — petunjuk yang tidak bisa
    /// berhasil membuat pengguna menyimpulkan aplikasinya rusak.
    static let sensorLocationRestrictedNote = LocalizedText(
        key: "sensor.location.restricted.note",
        id: "Izin lokasi dibatasi perangkat (mis. Pembatasan Orang Tua atau profil sekolah). Bukan aplikasi ini yang memblokirnya, jadi tidak ada pengaturan di sini yang bisa mengubahnya. Aplikasi tetap berjalan dengan lokasi bawaan (Jakarta).")
    static let sensorLocationAccuracy = LocalizedText(
        key: "sensor.location.accuracy",
        id: "Lokasi ±%.0f m")
    static let sensorLocationFailedStatus = LocalizedText(
        key: "sensor.location.failed.status",
        id: "Lokasi gagal: %@")
    static let sensorLocationFailedNote = LocalizedText(
        key: "sensor.location.failed.note",
        id: "Lokasi gagal: %@. Memakai lokasi bawaan (Jakarta).")
}
