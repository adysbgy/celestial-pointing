import Foundation
import CelestialEngine

/// Alasan engine **tidak** menemukan objek — dalam bentuk yang bisa dikatakan
/// ke pengguna.
///
/// **Kenapa berkas ini ada.** `PointingResolver.diagnose` sudah menghitung
/// alasan setiap penolakan sejak awal: setiap benda yang tidak lolos penyaring
/// masuk ke `Resolution.rejected` bersama `Visibility`-nya
/// (`belowHorizon`, `tooFaint`, `tooCloseToSun`, `daylight`), dan
/// `SkyContext.isDark` menyatakan apakah langit sedang terang. Semua itu
/// **dihitung lalu tidak pernah dibaca siapa pun** — `rejected` nol konsumen di
/// seluruh repo.
///
/// Akibatnya jam selalu menampilkan satu kalimat yang sama, "Belum ada objek di
/// arah itu.", untuk situasi yang sangat berbeda: langit masih siang, semua
/// bintang sedang di bawah horizon, atau benda di arah itu memang terlalu
/// redup. Ketiganya butuh tindakan yang berbeda dari pengguna — menunggu
/// gelap, mengarah ke tempat lain, atau menerima bahwa tidak ada yang bisa
/// dilihat — dan mesin yang jujur seharusnya mengatakannya, bukan menyembunyikan
/// perbedaan itu di balik satu kalimat.
///
/// Ini bukan "menambah fitur": seluruh informasi sudah ada dan sudah benar.
/// Yang hilang hanya jalur dari tempat ia dihitung ke tempat ia dibaca — kelas
/// cacat yang sama dengan `.deepSky` yang tak pernah tersambung ke katalog.
///
/// **Batas yang dijaga.** `SearchHint` hanya menyatakan **mengapa tidak ada
/// objek**; ia tidak pernah mengklaim ada objek. Ia tidak muncul saat ada
/// jawaban (`intent.best != nil`), jadi ia tidak bisa dipakai untuk menaikkan
/// keyakinan palsu. Yang dilakukannya justru sebaliknya: mengganti "tidak tahu"
/// yang seragam menjadi penjelasan yang bisa diperiksa.
public enum SearchHint: String, Equatable, Sendable, CaseIterable {

    /// Langit belum cukup gelap — Matahari masih di atas ambang gelap.
    ///
    /// Diperiksa **pertama** dan dari `context.isDark`, bukan dari alasan
    /// per-benda. Alasannya: `VisibilityFilter.classify` memeriksa ketinggian
    /// lebih dulu, jadi saat siang sebagian benda dilaporkan `belowHorizon`
    /// dan sebagian `daylight` — himpunan alasan yang bercampur, dan menebak
    /// dari situ bisa salah. Terang/gelap adalah sifat **langit**, bukan sifat
    /// satu benda, jadi tempat membacanya juga sifat langit.
    case daylight

    /// Langit sudah gelap, tetapi **semua** benda yang dipertimbangkan sedang
    /// di bawah horizon.
    case allBelowHorizon

    /// Semua benda di kerucut terlalu redup untuk ambang magnitudo saat ini.
    case allTooFaint

    /// Semua benda terlalu dekat dengan Matahari untuk diamati dengan aman.
    case allTooCloseToSun

    /// Ada benda yang lolos penyaring, tetapi tidak satu pun masuk kerucut arah
    /// tunjuk — atau penyaring menolaknya dengan alasan yang bercampur,
    /// sehingga tidak ada satu sebab yang jujur untuk disebutkan.
    ///
    /// Ini juga hasil saat katalog kosong atau efemeris gagal seluruhnya:
    /// "tidak ada yang cocok" tetap benar, dan mengarang sebab yang lebih
    /// spesifik justru melanggar aturan jujur.
    case noCandidates
}

public extension Resolution {

    /// Mengapa resolusi ini tidak menghasilkan objek — `nil` bila **ada** objek.
    ///
    /// **Kenapa `nil` saat ada objek, bukan `case` tersendiri.** Sebuah hint
    /// adalah penjelasan atas *ketiadaan* jawaban. Kalau ia juga bisa ada saat
    /// jawaban ada, pemanggil harus ingat memeriksa keadaan sebelum
    /// menampilkannya — dan satu tempat yang lupa memeriksa akan menampilkan
    /// "semua benda di bawah horizon" di sebelah nama objek yang justru
    /// terkunci. Dengan `nil` sebagai satu-satunya jawaban untuk "ada objek",
    /// mustahil menampilkan keduanya sekaligus.
    var searchHint: SearchHint? {
        // Ada jawaban -> tidak ada yang perlu dijelaskan.
        guard intent.best == nil else { return nil }

        // Terang/gelap dulu: ia sifat langit, dan ia menjelaskan mengapa
        // benda-benda di atas horizon pun tidak muncul.
        if !context.isDark { return .daylight }

        // Tidak ada yang ditolak penyaring: tidak ada benda di kerucut arah
        // tunjuk (atau katalog/efemeris kosong). Jujur: "tidak ada yang cocok".
        guard !rejected.isEmpty else { return .noCandidates }

        // Satu sebab saja yang disebutkan, dan hanya bila **seragam**. Alasan
        // yang bercampur (mis. separuh terlalu redup, separuh di bawah horizon)
        // tidak punya satu kalimat jujur, jadi jatuh ke `noCandidates`.
        let reasons = Set(rejected.map(\.visibility))
        if reasons == Set([.belowHorizon]) { return .allBelowHorizon }
        if reasons == Set([.tooFaint]) { return .allTooFaint }
        if reasons == Set([.tooCloseToSun]) { return .allTooCloseToSun }
        return .noCandidates
    }
}

// MARK: - Teks

public extension SearchHint {

    /// Kalimat untuk ditampilkan ke pengguna, dalam bahasa aktif.
    ///
    /// Lewat `TextLocalization` dengan alasan yang sama seperti
    /// `ObjectKind.displayName`: teks ini berasal dari `switch` di dalam paket,
    /// jadi ia **tidak pernah** menjadi literal `Text("…")` yang bisa
    /// dijangkau aturan 4 — dan tanpa jalur ini ia hanya akan punya Bahasa
    /// Indonesia.
    var message: String { TextLocalization.text(text) }

    /// Kunci + nilai bawaan untuk kalimat ini.
    var text: LocalizedText {
        switch self {
        case .daylight:        return .searchHintDaylight
        case .allBelowHorizon: return .searchHintBelowHorizon
        case .allTooFaint:     return .searchHintTooFaint
        case .allTooCloseToSun: return .searchHintTooCloseToSun
        case .noCandidates:    return .searchHintNoCandidates
        }
    }
}

public extension LocalizedText {

    static let searchHintDaylight = LocalizedText(
        key: "pointing.search.hint.daylight",
        id: "Langit masih terang — bintang belum terlihat.")
    static let searchHintBelowHorizon = LocalizedText(
        key: "pointing.search.hint.belowHorizon",
        id: "Semua objek di katalog sedang di bawah horizon.")
    static let searchHintTooFaint = LocalizedText(
        key: "pointing.search.hint.tooFaint",
        id: "Objek di arah itu terlalu redup untuk dilihat.")
    static let searchHintTooCloseToSun = LocalizedText(
        key: "pointing.search.hint.tooCloseToSun",
        id: "Objek terlalu dekat dengan Matahari untuk diamati.")
    static let searchHintNoCandidates = LocalizedText(
        key: "pointing.search.hint.noCandidates",
        id: "Belum ada objek yang cocok di arah itu.")
}

public extension PointingSnapshot {

    /// Kalimat panduan yang jujur untuk cuplikan ini.
    ///
    /// **Kenapa ini ada, bukan view yang memilih.** Sama seperti
    /// `PointingState.shortLabel`: kalimat ini tampil di jam, di iPhone, dan
    /// di pengumuman VoiceOver. Kalau tiap layar memilih sendiri, jam bisa
    /// berkata "langit masih terang" sementara iPhone berkata "belum ada objek"
    /// untuk cuplikan yang sama — dua versi kebenaran, dan hanya satu yang
    /// diuji. Aturannya di sini: satu sumber, diuji di Linux.
    ///
    /// Saat keadaan `.searching` **dan** ada alasan yang bisa disebutkan,
    /// alasan itu yang dipakai. Selain itu jatuh ke `PointingState.guidance`
    /// yang netral — bukan karena alasan hilang, tapi karena satu-satunya
    /// keadaan yang punya alasan jujur memang `.searching`.
    var guidanceText: String {
        if state == .searching, let hint = searchHint { return hint.message }
        return state.guidance
    }
}
