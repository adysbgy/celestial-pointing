import Foundation
import CelestialEngine

/// Kalimat yang diumumkan VoiceOver saat keadaan engine **berubah**.
///
/// **Kenapa ini ada.** Jam sudah mengumumkan perubahan keadaan sejak lama
/// (`PointingView`), tetapi iPhone **tidak pernah**: sampai sekarang tidak ada
/// satu pun `AccessibilityNotification` di app iPhone. Janji produknya sama di
/// kedua perangkat — "keadaan yang berubah harus terdengar, bukan hanya
/// terlihat" — tetapi hanya satu yang memenuhinya. Dan tidak ada layar yang
/// terlihat salah: jam berbunyi, iPhone diam, masing-masing tampak benar
/// sendiri. Ini kelas yang sudah berulang di repo ini: dua permukaan yang
/// seharusnya sama, tetapi hanya satu yang diperbaiki.
///
/// Kalimatnya tinggal di sini, bukan di view, karena **keduanya** sudah pernah
/// menjadi cacat nyata:
///
/// 1. **Dua versi kebenaran.** Versi lama menyusun kalimatnya sendiri di dalam
///    `PointingView`. Begitu iPhone ikut mengumumkan, kalimat itu harus ada di
///    dua tempat — dan cepat atau lambat keduanya berbeda pendapat tentang apa
///    yang diucapkan untuk keadaan yang sama, dengan hanya satu yang diuji.
///    Di sini satu fungsi melayani kedua app.
/// 2. **Teks yang dihasilkan tidak bisa dijangkau katalog.** Versi lama
///    menyusunnya dari literal di dalam view (`"Terkunci pada \(name)."`),
///    jadi `Localizable.xcstrings` tidak bisa menjangkaunya dan pengguna Bahasa
///    Inggris mendengar kalimat Indonesia tanpa ada yang menyadarinya — aturan
///    4 menyapu literal `Apps/`, tetapi `Apps/PointAndKnowWatch/Sources/`
///    bukan satu-satunya tempat teks bisa bersembunyi. Lewat `LocalizedText`,
///    tiap kalimat punya kunci katalog dan masuk `allKeys`, tempat gerbang
///    paritas (Aturan 6) memeriksanya.
///
/// **Batasnya, dan ini penting.** Fungsi ini hanya menyusun **kalimat**; ia
/// tidak memutuskan **kapan** mengumumkan. Yang memutuskan adalah pemanggil,
/// yang wajib mengumumkan pada **perubahan keadaan** saja, bukan pada tiap
/// sampel sensor 20 Hz — kalau tidak, VoiceOver mengucapkan "Terkunci"
/// berpuluh kali per menit dan menutupi semua hal lain yang ingin dibaca
/// pengguna.
public enum StateAnnouncement {

    /// Kalimat pengumuman untuk satu cuplikan.
    ///
    /// Nama objek dibaca dari `snapshot.answeredObject` — predikat yang
    /// **sama** dengan yang dipakai `LockArrival`, pesan ke iPhone, dan riwayat
    /// keyakinan. Itu bukan kerapian: `intent` sengaja dipertahankan saat
    /// keadaan turun kembali ke `.pointing`, jadi membacanya di sini akan
    /// mengumumkan objek lama persis seperti hasil pengukuran sekarang —
    /// false confidence dalam bentuk audio.
    ///
    /// Kalimat panduan pun diambil dari `snapshot.guidanceText`, **sumber yang
    /// sama** dengan yang tampil di layar, jadi suara dan layar tidak bisa
    /// menyebut dua hal berbeda untuk cuplikan yang sama.
    public static func text(for snapshot: PointingSnapshot) -> String {
        switch snapshot.state {
        case .lock:
            guard let name = snapshot.answeredObject?.name, !name.isEmpty else {
                return TextLocalization.text(.announceLocked)
            }
            return TextLocalization.text(.announceLockedOn, name)
        case .uncertain:
            return TextLocalization.text(.announceUncertain,
                          snapshot.guidanceText)
        case .unavailable:
            return TextLocalization.text(.announceUnavailable,
                          snapshot.guidanceText)
        case .idle, .pointing, .searching:
            return TextLocalization.text(.announceState,
                          snapshot.state.shortLabel, snapshot.guidanceText)
        }
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    /// Kunci dan nilai bawaan untuk kalimat pengumuman perubahan keadaan.
    ///
    /// Bentuknya memakai `%@`, bukan interpolasi Swift: bagian yang disisipkan
    /// (nama objek, panduan) sudah diterjemahkan sendiri, jadi terjemahan
    /// Inggrisnya harus bisa **menempatkan** bagian itu sesuai tata bahasanya —
    /// dan itu tidak mungkin kalau posisinya dipaku di kode.
    static let announceLockedOn = LocalizedText(
        key: "pointing.announce.lockedOn",
        id: "Terkunci pada %@.")
    static let announceLocked = LocalizedText(
        key: "pointing.announce.locked",
        id: "Terkunci.")
    static let announceUncertain = LocalizedText(
        key: "pointing.announce.uncertain",
        id: "Kurang yakin. %@")
    static let announceUnavailable = LocalizedText(
        key: "pointing.announce.unavailable",
        id: "Sensor mati. %@")
    static let announceState = LocalizedText(
        key: "pointing.announce.state",
        id: "%@. %@")
}
