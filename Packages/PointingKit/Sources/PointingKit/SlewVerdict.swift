import Foundation
import CelestialEngine

/// Putusan GoTo — **mengapa** teleskop boleh atau tidak boleh bergerak.
///
/// **Kenapa berkas ini ada.** `SlewPlanner` sudah menghitung putusan
/// keselamatan sejak FASE 3: `SlewDecision.rejected(hazards:)` membawa daftar
/// bahaya yang konkret (`sunProximity`, `belowHorizon`, `lowConfidence`, …),
/// dan `PointingController.slewDecision(date:)` menyambungkannya ke engine yang
/// berjalan. Semua itu **dihitung lalu tidak pernah dibaca satu layar pun**:
/// `slewDecision` nol pemanggil di seluruh `Apps/`.
///
/// Akibatnya, satu-satunya aturan keras PRD yang menyangkut **keselamatan alat**
/// — "POINT → OBJECT ID → SAFE GOTO", dan larangan menggerakkan motor dari
/// sudut pergelangan — tidak punya wajah di layar. Pengguna tidak bisa tahu
/// apakah teleskopnya boleh bergerak, dan kalau tidak, mengapa. Yang paling
/// berbahaya: penolakan karena `sunProximity` terlihat persis sama dengan
/// penolakan karena `lowConfidence`, padahal yang pertama melindungi
/// peralatan dan mata dari cahaya Matahari, dan yang kedua hanya soal
/// ketelitian.
///
/// Ini kelas cacat yang sama dengan `SearchHint` dan katalog `.deepSky`:
/// **bagiannya benar, jalurnya tidak pernah disambungkan** — dan tidak bisa
/// dilihat dari layar, karena tidak ada yang tampil untuk dilihat.
///
/// **Batas yang dijaga.** Berkas ini hanya menerjemahkan putusan yang **sudah**
/// diambil `SlewPlanner`; ia tidak pernah memutuskan apa pun, dan tidak bisa
/// melunakkan penolakan menjadi izin. `verdictText` mengembalikan `nil` tepat
/// saat `SlewDecision` mengizinkan — jadi mustahil menampilkan peringatan di
/// sebelah GoTo yang justru aman, dan mustahil menyembunyikan alasan di
/// sebelah GoTo yang ditolak.
public extension SlewHazard {

    /// Kalimat untuk ditampilkan ke pengguna, dalam bahasa aktif.
    ///
    /// Lewat `TextLocalization` dengan alasan yang sama seperti
    /// `SearchHint.message`: teks ini berasal dari `switch` di dalam paket,
    /// jadi ia tidak pernah menjadi literal `Text("…")` yang bisa dijangkau
    /// aturan 4 — dan tanpa jalur ini ia hanya akan punya Bahasa Indonesia.
    var message: String { TextLocalization.text(text) }

    /// Kunci + nilai bawaan untuk kalimat ini.
    var text: LocalizedText {
        switch self {
        case .sunProximity:      return .slewHazardSunProximity
        case .belowAltitudeLimit: return .slewHazardBelowAltitudeLimit
        case .belowHorizon:      return .slewHazardBelowHorizon
        case .tooFaint:          return .slewHazardTooFaint
        case .noTarget:          return .slewHazardNoTarget
        case .lowConfidence:     return .slewHazardLowConfidence
        case .sunPositionUnknown: return .slewHazardSunPositionUnknown
        }
    }
}

public extension SlewDecision {

    /// Apakah ada putusan yang perlu diberitahukan ke pengguna.
    ///
    /// `false` saat GoTo **aman** — bukan karena putusannya hilang, tapi
    /// karena tidak ada yang perlu diperingatkan. Sama seperti `searchHint`
    /// yang `nil` saat ada objek.
    var hasVerdict: Bool { !isAllowed }

    /// Kalimat jujur untuk ditampilkan; **`nil` bila GoTo aman**.
    ///
    /// **Kenapa `nil`, bukan kalimat "aman".** Sama alasannya dengan
    /// `Resolution.searchHint`: putusan ini adalah penjelasan atas sebuah
    /// **masalah**. Kalau ia juga bisa berbunyi saat aman, pemanggil harus
    /// ingat memeriksa keadaan sebelum menampilkannya — dan satu tempat yang
    /// lupa akan menuliskan "ditolak" di sebelah GoTo yang justru berjalan.
    /// Dengan `nil` sebagai satu-satunya jawaban untuk "aman", mustahil
    /// menampilkan keduanya sekaligus.
    ///
    /// Semua bahaya disebutkan, bukan hanya yang pertama: dua sebab yang
    /// berbeda menuntut tindakan yang berbeda (menunggu Matahari menjauh vs.
    /// memperbaiki kalibrasi), dan menyebut salah satunya saja menyembunyikan
    /// sebab lain yang tetap menghalangi.
    var verdictText: String? {
        guard case .rejected(let hazards) = self, !hazards.isEmpty else { return nil }
        let reasons = hazards.map { $0.message }
        return TextLocalization.text(.slewVerdictRejectedPrefix) + " " + reasons.joined(separator: " ")
    }
}

public extension LocalizedText {

    /// Pembuka kalimat putusan. Dipisah dari kalimat bahayanya supaya
    /// terjemahan bisa menaruh kata "ditolak" di tempat yang benar dalam
    /// kalimatnya sendiri, bukan menempelkannya ke tiap bahaya.
    static let slewVerdictRejectedPrefix = LocalizedText(
        key: "slew.verdict.rejected.prefix",
        id: "GoTo ditolak:")

    static let slewHazardSunProximity = LocalizedText(
        key: "slew.hazard.sunProximity",
        id: "Terlalu dekat Matahari.")

    static let slewHazardBelowAltitudeLimit = LocalizedText(
        key: "slew.hazard.belowAltitudeLimit",
        id: "Di luar batas ketinggian teleskop.")

    static let slewHazardBelowHorizon = LocalizedText(
        key: "slew.hazard.belowHorizon",
        id: "Masih di bawah horizon.")

    static let slewHazardTooFaint = LocalizedText(
        key: "slew.hazard.tooFaint",
        id: "Terlalu redup untuk diamati.")

    static let slewHazardNoTarget = LocalizedText(
        key: "slew.hazard.noTarget",
        id: "Tidak ada objek yang bisa diarahkan.")

    static let slewHazardLowConfidence = LocalizedText(
        key: "slew.hazard.lowConfidence",
        id: "Engine belum cukup yakin objek mana yang dimaksud.")

    static let slewHazardSunPositionUnknown = LocalizedText(
        key: "slew.hazard.sunPositionUnknown",
        id: "Posisi Matahari tidak diketahui, jadi pengaman tidak bisa dijalankan.")
}
