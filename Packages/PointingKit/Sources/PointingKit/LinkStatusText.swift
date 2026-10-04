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
        String(format: TextLocalization.text(.linkStatusSendFailed), reason)
    }

    /// Pengiriman berhasil; `kindName` adalah nama jenis pesan untuk manusia.
    public static func sent(_ kindName: String) -> String {
        String(format: TextLocalization.text(.linkStatusSent), kindName)
    }

    // MARK: - Penerimaan di iPhone

    /// Jam melihat sebuah objek bernama `name`.
    public static func watchSaw(_ name: String) -> String {
        String(format: TextLocalization.text(.linkStatusWatchSaw), name)
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
}
