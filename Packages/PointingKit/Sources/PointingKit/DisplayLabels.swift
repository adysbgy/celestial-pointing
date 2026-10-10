import Foundation
import CelestialEngine

/// Label tampilan untuk nilai yang bentuknya dibuat untuk mesin, bukan untuk
/// orang.
///
/// **Kenapa berkas ini ada.** `rawValue` enum berbahasa Inggris
/// (`"high"`, `"stateRequest"`, `"sirius"`) adalah **bentuk kabel**: ia aman
/// diserialisasi, aman dibandingkan, dan aman disimpan di berkas ekspor. Yang
/// tidak aman adalah ketika bentuk itu dipakai sebagai *teks di layar* — dan
/// itulah yang terjadi di lima tempat sebelum berkas ini ada, termasuk di baris
/// paling menonjol di Experiment 1 yang menampilkan `sirius` di tempat
/// seharusnya tertulis `Sirius`.
///
/// Yang membuat kelas ini bertahan lama: setiap alat kecil **benar secara
/// terpisah**. `Catalogue` memang menyimpan slug `sirius`; `LinkMessageKind`
/// memang dinamai dalam bahasa Inggris; `ConfidenceLevel` sudah punya
/// `displayName` yang benar. Semuanya tepat untuk mesin. Yang tidak pernah ada
/// adalah satu tempat yang berkata "ini untuk layar, ambil yang ini" — jadi
/// pemanggil mengambil `rawValue` satu per satu, dan tiap satu terlihat
/// meyakinkan.
///
/// Dua aturan yang tidak boleh dilanggar di sini:
///
/// 1. **Id bukan nama.** `Catalogue.brightStars` menyimpan id `sirius` (slug
///    kecil, stabil) berdampingan dengan name `Sirius` (label, bisa diubah).
///    Keduanya benar; hanya yang satu boleh tampil. Dan label **dihitung
///    saat render**, tidak pernah disimpan di dalam rekaman — bukan hanya
///    karena katalog bisa berubah, tapi karena nama yang membeku di dalam
///    dataset akan menjadi label usang yang tidak pernah ikut berubah bersama
///    katalog maupun lokalisasi. Ini alasan yang sama yang dipakai
///    `ComplicationDigest` untuk menyimpan `ObjectKind` mentah, bukan
///    labelnya.
/// 2. **Jangan menebak.** Id yang tidak dikenal menghasilkan `nil`, bukan
///    nama karangan. `nil` berarti pemanggil menampilkan id apa adanya — dan
///    id mentah yang disajikan sebagai **pengenal teknik** itu jujur,
///    bukan kebohongan. Yang tidak jujur justru slug yang disamarkan jadi nama.
public enum DisplayLabel {

    /// Nama tampilan untuk id objek katalog atau benda tata surya.
    ///
    /// - Parameters:
    ///   - id: `CelestialObject.id` — slug katalog (`"sirius"`) atau
    ///     `EphemerisBody.rawValue` (`"jupiter"`).
    ///   - catalogue: katalog yang **sama** dengan yang dipakai engine.
    ///     Sengaja parameter, bukan nilai bawaan: kalau bawaannya
    ///     `Catalogue.brightStars` sementara app menjalankan resolver dengan
    ///     katalog lain, labelnya bisa menunjuk nama untuk id yang tidak
    ///     sedang dipertimbangkan engine — dan itu persis jenis nama yang
    ///     terlihat benar tanpa punya dasar.
    /// - Returns: nama untuk ditampilkan, atau `nil` bila id tidak dikenal.
    public static func objectName(forObjectID id: String,
                                  catalogue: [CelestialObject]) -> String? {
        // Katalog dulu: di sinilah slug katalog berasal, dan nama yang tepat
        // sudah tersimpan berdampingan dengannya.
        if let match = catalogue.first(where: { $0.id == id }) {
            return match.name
        }
        // Benda tata surya: id-nya `EphemerisBody.rawValue`. Nama
        // Bahasa Indonesianya sudah ada di engine (`displayName`), jadi
        // bentuk defaultnya tidak dikarang di sini — dan bentuknya
        // **dialokalkan** oleh `BodyName`, bukan dipakai apa adanya.
        // `displayName` mentah akan membekukan `Saturnus` ke layar
        // walau bahasa perangkat English; lihat `BodyName`.
        if let body = EphemerisBody(rawValue: id) {
            return BodyName.text(body)
        }
        // Tidak dikenal. `nil` — bukan id yang disamarkan jadi nama, dan
        // bukan nama yang ditebak dari id.
        return nil
    }

    /// Nama tampilan untuk id, dengan **id apa adanya** bila tak dikenal —
    /// untuk pemanggil yang tidak punya pemisahan "tahu/tidak tahu" dan
    /// hanya butuh satu string.
    ///
    /// Sengaja mengembalikan **id** saat tak dikenal, bukan string kosong:
    /// string kosong membuat baris terlihat kosong tanpa penjelasan, sementara
    /// id mentah setidaknya menyatakan "ini pengenal, bukan nama". Daftarnya
    /// kecil dan tertutup (katalog + 7 benda), jadi `nil` hanya terjadi bila
    /// dataset rusak — dan yang penting di kasus itu adalah **tidak
    /// mengarang nama**.
    public static func objectNameOrIdentifier(forObjectID id: String,
                                              catalogue: [CelestialObject]) -> String {
        objectName(forObjectID: id, catalogue: catalogue) ?? id
    }
}

public extension LinkMessageKind {

    /// Label Bahasa Indonesia untuk jenis pesan.
    ///
    /// **Kenapa `rawValue` tidak bisa dipakai.** `kind` adalah kunci
    /// serialisasi pada `plist` — ia harus tetap `pointingState` apa adanya
    /// supaya kedua perangkat dan berkas ekspor yang sudah tersimpan tetap
    /// cocok. Yang tidak boleh terjadi adalah nilai yang sama itu ikut tampil
    /// di layar sebagai `stateRequest`.
    ///
    /// Karena itu bentuk kabel dan label dipisahkan: `rawValue` untuk mesin,
    /// `displayName` untuk orang. Mengganti satu bentuk dengan bentuk yang
    /// benar untuk lapisan lain adalah pembatalan diam-diam yang tidak akan
    /// pernah ketahuan dari layar — pesannya sampai, tapi tidak terbaca.
    ///
    /// Uji `DisplayLabelTests` menjaga bahwa tidak ada label yang **sama
    /// dengan** `rawValue`-nya, karena itulah tanda accessor ini hilang.
    var displayName: String { TextLocalization.text(displayText) }

    /// Kunci + nilai bawaan untuk label jenis pesan ini.
    var displayText: LocalizedText {
        switch self {
        case .pointingState:    return .linkKindPointingState
        case .calibrationReady: return .linkKindCalibrationReady
        case .policyUpdate:     return .linkKindPolicyUpdate
        case .stateRequest:     return .linkKindStateRequest
        case .acknowledgement:  return .linkKindAcknowledgement
        }
    }
}
