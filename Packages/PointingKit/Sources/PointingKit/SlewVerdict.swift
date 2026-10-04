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

    /// Apakah bahaya ini menyangkut **keselamatan alat & mata**, bukan mutu
    /// pengamatan.
    ///
    /// **Kenapa harus dipisahkan, dan kenapa di sini.** Semua bahaya di
    /// `SlewDecision` ditolak dengan cara yang sama (teleskop tidak bergerak),
    /// tapi tidak semua **sama pentingnya**. Tiga di antaranya berarti
    /// mengarahkan teleskop bisa **merusak peralatan atau melukai mata**:
    /// cahaya Matahari yang masuk ke lensa memanaskannya, dan melihatnya
    /// merusak retina. Sisanya (`belowHorizon`, `tooFaint`, `noTarget`,
    /// `lowConfidence`) hanya berarti "tidak ada yang bisa diamati sekarang" —
    /// mengecewakan, tidak berbahaya.
    ///
    /// Kalau dua kelas itu digambar dengan bobot visual yang sama, pengguna
    /// membaca sekilas akan menganggap "terlalu redup" sama mendesaknya dengan
    /// "terlalu dekat Matahari" — dan yang paling berbahaya justru yang paling
    /// mudah diabaikan. Berkas ini lahir untuk memisahkan dua penolakan yang
    /// dulu "terlihat persis sama"; tanpa pemisahan **bobot**, pemisahan
    /// kalimatnya berhenti di tengah jalan.
    ///
    /// **Kenapa `sunPositionUnknown` ikut kelas keselamatan.** Ia bukan
    /// bahaya yang diamati, melainkan **pengaman yang tidak bisa dijalankan**:
    /// kalau posisi Matahari tidak diketahui, `SlewPlanner` sengaja
    /// gagal-tertutup dan menolak, karena ia tidak bisa membuktikan teleskop
    /// aman dari Matahari. Menaruhnya di kelas mutu akan membuatnya terlihat
    /// seperti soal ketelitian, padahal ia adalah keselamatan yang tidak bisa
    /// diverifikasi — persis keadaan yang paling tidak boleh diremehkan.
    var isSafety: Bool {
        switch self {
        case .sunProximity, .belowAltitudeLimit, .sunPositionUnknown:
            return true
        case .belowHorizon, .tooFaint, .noTarget, .lowConfidence:
            return false
        }
    }

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

    /// Seberapa mendesak putusan ini — dipakai untuk memilih warna peringatan.
    ///
    /// **Kenapa ini ada, padahal `verdictText` sudah punya semua sebabnya.**
    /// Berkas ini lahir untuk memisahkan dua penolakan yang dulu "terlihat
    /// persis sama": `sunProximity` (melindungi peralatan dan **mata** dari
    /// cahaya Matahari) dan `lowConfidence` (soal ketelitian). Tapi versi
    /// pertama hanya memisahkan **kalimatnya** — `SlewVerdictBanner`
    /// menggambar keduanya dengan warna peringatan yang sama dan ikon yang
    /// sama. Jadi pemisahan itu berhenti tepat di titik yang paling
    /// menentukan: pengguna yang membaca sekilas tetap melihat satu jenis
    /// peringatan untuk dua bahaya yang berbeda kelas, dan yang paling
    /// berbahaya justru yang paling mudah disamakan dengan yang sepele.
    ///
    /// Warna **bukan** satu-satunya pembeda — di Mode Malam warna nada
    /// menyempit jadi nyaris tak terbedakan (lihat `TonePalette`). Karena itu
    /// nada di sini dipasangkan dengan ikon di view: di mode malam ikon yang
    /// tetap membedakannya. Tapi dasar keputusannya **satu**, di sini, supaya
    /// kedua permukaan (jam dan iPhone) tidak bisa berbeda pendapat.
    ///
    /// **Kenapa `danger` untuk seluruh kelas keselamatan.** Ketiga bahaya
    /// keselamatan sama-sama berarti "teleskop tidak boleh bergerak karena
    /// bisa merusak alat atau membahayakan mata", dan perbedaan di antara
    /// ketiganya adalah soal *sebab*, bukan soal *tingkat bahaya*. Memberi
    /// mereka tiga warna berbeda akan mengarang gradasi yang tidak ada, dan
    /// gradasi yang dikarang justru melemahkan yang paling serius.
    var verdictTone: PointingTone {
        guard case .rejected(let hazards) = self, !hazards.isEmpty else { return .success }
        // Bahaya keselamatan lebih dulu, dan ia menang atas bahaya mutu.
        // Urutannya penting: putusan bisa memuat keduanya sekaligus
        // (`sunProximity` **dan** `belowAltitudeLimit`), dan memilih "yang
        // pertama" berarti warna bergantung pada urutan array — yang
        // kebetulan terurut menurut `rawValue`, bukan menurut kepentingan.
        if hazards.contains(where: { $0.isSafety }) { return .danger }
        return .warning
    }

    /// Nama SF Symbol untuk putusan ini.
    ///
    /// **Kenapa ikon, padahal sudah ada warna.** Di Mode Malam seluruh palet
    /// menyempit jadi satu warna merah (lihat `TonePalette`), jadi `danger` dan
    /// `warning` **tidak bisa lagi dibedakan lewat warna** — tepat di mode yang
    /// paling sering dipakai saat mengamati langit. Kalau pembeda satu-satunya
    /// hilang, pengguna Mode Malam kembali ke masalah awal: "terlalu dekat
    /// Matahari" dan "terlalu redup" terlihat sama. Ikon tidak ikut menyempit,
    /// jadi ia yang memikul pembedaan itu. Karena itu ikon ditentukan di sini,
    /// di samping `verdictTone` — bukan di view — supaya kedua permukaan
    /// memakai pembeda yang sama persis.
    var verdictSymbolName: String {
        verdictTone == .danger ? "exclamationmark.triangle.fill" : "info.circle"
    }

    /// Kalimat putusan, **hanya bila ada bahaya keselamatan**; `nil` untuk
    /// bahaya mutu maupun GoTo yang aman.
    ///
    /// **Kenapa butuh varian terpisah, padahal `verdictText` sudah ada.**
    /// Layar Always-On (`ReducedLuminanceView`) sengaja hanya memuat hal yang
    /// **tidak boleh terlewat** — dua kata status dan satu nama objek. Di sana
    /// setiap baris tambahan mengambil ruang dari yang paling penting, jadi
    /// "terlalu redup untuk diamati" tidak layak masuk: ia mengecewakan, bukan
    /// berbahaya, dan pengguna bisa mengetahuinya begitu mengangkat pergelangan.
    /// "Terlalu dekat Matahari" berbeda kelas: kalau ia hilang dari layar
    /// redup, pengguna melihat nama objek terkunci tanpa satu pun tanda bahwa
    /// teleskop **menolak bergerak** — dan itu satu-satunya jenis penolakan
    /// yang menghilang dari pandangan justru saat pengguna paling tidak
    /// mencarinya.
    ///
    /// Ambangnya memakai `isSafety` yang sama dengan `verdictTone`, bukan daftar
    /// bahaya yang ditulis ulang: kalau suatu saat sebuah bahaya dipindahkan
    /// kelasnya, warna dan kehadiran di layar redup ikut berpindah bersama —
    /// tidak ada dua daftar yang bisa berbeda pendapat.
    var safetyWarningText: String? {
        guard case .rejected(let hazards) = self,
              hazards.contains(where: { $0.isSafety }) else { return nil }
        return verdictText
    }

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
