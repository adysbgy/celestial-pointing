import Foundation

/// Kalimat **status tautan** Watch ↔ iPhone yang tampil di layar Tautan.
///
/// **Kenapa berkas ini ada.** Kedua `LinkService` menyimpan catatan terakhir
/// ke sebuah properti (`lastNote` di iPhone, `lastMessageNote` di jam), lalu
/// `LinkView` merendernya apa adanya lewat `Text(note)`. Kalimatnya sendiri
/// lahir sebagai **literal di dalam service**, bukan di dalam argumen
/// `Text(...)`.
///
/// Akibatnya dua gerbang tetap hijau:
/// - **Aturan 4** hanya menyapu literal yang **langsung** di dalam argumen
///   `Text(...)`. Di sini literalnya ada di service, dan yang sampai ke `Text`
///   hanyalah nama variabelnya.
/// - **Aturan 6** memeriksa paritas kunci yang **dideklarasikan**. Kalimat ini
///   tidak punya kunci, jadi tidak ada yang bisa dibandingkan.
///
/// Kelasnya sama persis dengan `RowSpeech` dan `PointingLinkMessage.note` —
/// dan seperti keduanya, ia tidak bisa dilihat dari layar: pengguna Bahasa
/// Inggris membaca "Tanda terima" dan "Jam belum terhubung" dalam Bahasa
/// Indonesia, tanpa satu pun penanda bahwa itu salah.
///
/// **Kenapa di `PointingKit`, bukan di masing-masing service.** Kalimatnya
/// sama-sama dipakai dua perangkat, dan dua salinan literal akan menyimpang:
/// satu diperbaiki, satu tertinggal. Satu sumber, diuji di Linux, dipakai
/// keduanya — persis alasan `RowSpeech` ditaruh di sini.
///
/// **Yang tidak diterjemahkan, dan kenapa.** Teks galat sistem
/// (`error.localizedDescription`) **disisipkan apa adanya**: ia sudah
/// dilokalkan oleh OS ke bahasa perangkat. Menerjemahkannya lagi di sini akan
/// menimpa lokalisasi yang sudah benar dengan tebakan kita.
public enum LinkStatusText {

    // MARK: - Pengiriman dari jam

    /// Hasil kalibrasi tidak terkirim karena sesi belum aktif.
    public static var calibrationNotSent: String {
        TextLocalization.text(.linkStatusCalibrationNotSent)
    }

    /// Pesan tidak terkirim karena sesi belum aktif.
    public static var messageNotSent: String {
        TextLocalization.text(.linkStatusMessageNotSent)
    }

    /// Pengiriman gagal, dengan alasan dari sistem.
    ///
    /// `reason` **tidak** diterjemahkan di sini — `localizedDescription` sudah
    /// datang dalam bahasa perangkat.
    public static func sendFailed(_ reason: String) -> String {
        TextLocalization.text(.linkStatusSendFailed, reason)
    }

    /// Sesi tautan gagal aktif, dengan pesan sistemnya.
    ///
    /// **Kenapa perlu accessor sendiri, padahal `sendFailed` sudah ada.**
    /// Keduanya dipanggil dari tempat yang berbeda, dan bedanya persis yang
    /// membuat cacat ini lolos. `sendFailed` dipanggil di dua `LinkService`
    /// untuk kegagalan **pengiriman**. Kegagalan **aktivasi sesi** —
    /// `session(_:activationDidCompleteWith:error:)` — menyimpan
    /// `error.localizedDescription` **mentah** ke `lastNote`/`lastMessageNote`,
    /// dan kedua properti itu dirender di layar Tautan.
    ///
    /// Jadi pesan sistemnya sampai ke layar tanpa kalimat pengantar apa pun:
    /// baris yang seharusnya berbunyi "Sesi gagal aktif: …" hanya berisi
    /// teks bahasa perangkat, di tengah layar berbahasa Indonesia. Tidak ada
    /// gerbang yang melihatnya — ia bukan literal di `Apps/` (Aturan 4),
    /// bukan penugasan berakhiran Note dengan literal (Aturan 12), dan bukan
    /// argumen `String(format:)` (Aturan 13).
    ///
    /// Pesan sistemnya **tetap ditampilkan** lewat `%@`: dua kegagalan
    /// aktivasi yang berbeda tidak boleh terbaca sama pada baris yang dipakai
    /// untuk memutuskan apakah jam dan iPhone benar-benar terhubung.
    public static func activationFailed(_ reason: String) -> String {
        TextLocalization.text(.linkStatusActivationFailed, reason)
    }

    /// Pengiriman berhasil; `kindName` adalah nama jenis pesan untuk manusia.
    public static func sent(_ kindName: String) -> String {
        TextLocalization.text(.linkStatusSent, kindName)
    }

    // MARK: - Penerimaan di iPhone

    /// Jam melihat sebuah objek bernama `name`.
    public static func watchSaw(_ name: String) -> String {
        TextLocalization.text(.linkStatusWatchSaw, name)
    }

    /// Keadaan diterima dari jam, tanpa nama objek.
    public static var stateFromWatch: String {
        TextLocalization.text(.linkStatusStateFromWatch)
    }

    /// Hasil kalibrasi diterima dari jam.
    public static var calibrationFromWatch: String {
        TextLocalization.text(.linkStatusCalibrationFromWatch)
    }

    /// Ambang keyakinan diterima dari jam.
    public static var policyFromWatch: String {
        TextLocalization.text(.linkStatusPolicyFromWatch)
    }

    /// Tanda terima diterima.
    public static var acknowledgement: String {
        TextLocalization.text(.linkStatusAcknowledgement)
    }

    // MARK: - Penerimaan di jam

    /// Ambang keyakinan dari iPhone tidak sah, jadi diabaikan.
    public static var invalidPolicyIgnored: String {
        TextLocalization.text(.linkStatusInvalidPolicy)
    }

    /// Permintaan keadaan datang sebelum alur siap.
    public static var stateRequestTooEarly: String {
        TextLocalization.text(.linkStatusStateRequestTooEarly)
    }

    /// Jam belum terhubung sehingga ambang keyakinan tidak terkirim.
    public static var watchUnreachablePolicy: String {
        TextLocalization.text(.linkStatusWatchUnreachablePolicy)
    }

    /// Jam belum terhubung sehingga pesan tidak terkirim.
    public static var watchUnreachableMessage: String {
        TextLocalization.text(.linkStatusWatchUnreachableMessage)
    }

    /// Jumlah pengiriman tautan yang gagal, sebagai kalimat VoiceOver.
    ///
    /// **Kenapa ini bentuk lengkap, bukan potongan.** Pemanggil di jam
    /// menyusun kalimatnya di dalam `.accessibilityLabel` dan sebelumnya
    /// merakitnya dengan menyambung string:
    ///
    /// ```swift
    /// var text = link.isReachable ? "iPhone terhubung" : "…"
    /// text += ". \(link.sendFailureCount) kiriman gagal."
    /// ```
    ///
    /// Dua kelas cacat sekaligus. Pertama, potongannya literal — jadi tak ada
    /// kunci katalog dan pengguna Bahasa Inggris mendengar Bahasa Indonesia.
    /// Kedua, dan lebih halus: **menyambung** kalimat berarti penerjemah
    /// Bahasa lain tidak bisa mengubah **urutannya**. Bahasa yang menempatkan
    /// keterangan jumlah sebelum kata "gagal" tidak bisa mengatakannya, karena
    /// posisinya dipaku di kode. Bentuk `%@ %lld %@` membebaskan itu.
    public static func sendFailures(_ count: Int) -> String {
        TextLocalization.text(.linkStatusSendFailures,
               TextLocalization.text(.linkStatusSendFailuresWord),
               Int64(count))
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let linkStatusCalibrationNotSent = LocalizedText(
        key: "link.status.calibrationNotSent",
        id: "Kalibrasi belum terkirim: sesi belum aktif.")

    static let linkStatusMessageNotSent = LocalizedText(
        key: "link.status.messageNotSent",
        id: "Pesan belum terkirim: sesi belum aktif.")

    static let linkStatusSendFailed = LocalizedText(
        key: "link.status.sendFailed",
        id: "Gagal mengirim: %@")

    /// Aktivasi sesi tautan gagal; `%@` pesan sistemnya.
    ///
    /// Masuk daftar karena dua `LinkService` menyimpan
    /// `error.localizedDescription` **apa adanya** ke `lastNote` /
    /// `lastMessageNote` saat `activationDidCompleteWith` membawa galat, dan
    /// kedua properti itu dirender di layar Tautan. Tanpa kunci ini barisnya
    /// hanya berisi teks bahasa perangkat. Lihat
    /// `LinkStatusText.activationFailed`.
    static let linkStatusActivationFailed = LocalizedText(
        key: "link.status.activationFailed",
        id: "Sesi gagal aktif: %@")

    static let linkStatusSent = LocalizedText(
        key: "link.status.sent",
        id: "Terkirim: %@")

    static let linkStatusWatchSaw = LocalizedText(
        key: "link.status.watchSaw",
        id: "Jam melihat %@")

    static let linkStatusStateFromWatch = LocalizedText(
        key: "link.status.stateFromWatch",
        id: "Keadaan dari jam")

    static let linkStatusCalibrationFromWatch = LocalizedText(
        key: "link.status.calibrationFromWatch",
        id: "Kalibrasi dari jam")

    static let linkStatusPolicyFromWatch = LocalizedText(
        key: "link.status.policyFromWatch",
        id: "Jam mengirim ambang keyakinan")

    static let linkStatusAcknowledgement = LocalizedText(
        key: "link.status.acknowledgement",
        id: "Tanda terima")

    static let linkStatusInvalidPolicy = LocalizedText(
        key: "link.status.invalidPolicy",
        id: "Ambang keyakinan dari iPhone tidak sah — diabaikan")

    static let linkStatusStateRequestTooEarly = LocalizedText(
        key: "link.status.stateRequestTooEarly",
        id: "Permintaan keadaan datang sebelum alur siap.")

    static let linkStatusWatchUnreachablePolicy = LocalizedText(
        key: "link.status.watchUnreachablePolicy",
        id: "Jam belum terhubung — ambang belum terkirim.")

    static let linkStatusWatchUnreachableMessage = LocalizedText(
        key: "link.status.watchUnreachableMessage",
        id: "Jam belum terhubung — pesan tidak terkirim.")

    /// Kalimat jumlah pengiriman gagal, sebagai satu kesatuan.
    ///
    /// Semula pemanggil menyusunnya dengan **menyambung** string
    /// (`text += ". N kiriman gagal."`). Itu bukan sekadar masalah terjemahan:
    /// menyambung memaku **urutan** di kode, sehingga bahasa yang ingin
    /// meletakkan jumlah sebelum kata "gagal" tidak bisa mengatakannya.
    static let linkStatusSendFailures = LocalizedText(
        key: "link.status.sendFailures",
        id: ". %lld %@.")

    /// Kata yang menyebut **benda** yang gagal dikirim — "kiriman", bukan "gagal".
    ///
    /// Sengaja dipisah dari `link.status.sendFailed` ("Gagal mengirim: %@"),
    /// yang menggambarkan **satu** kejadian. Yang ini menggambarkan **jumlah**,
    /// dan dua kalimat itu memang punya bentuk berbeda.
    static let linkStatusSendFailuresWord = LocalizedText(
        key: "link.status.sendFailuresWord",
        id: "kiriman gagal")
}
