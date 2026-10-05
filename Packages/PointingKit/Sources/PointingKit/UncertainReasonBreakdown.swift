import Foundation
import CelestialEngine

/// Rincian **sebab** keraguan — hitungan per sebab, untuk layar diagnostik.
///
/// **Kenapa ini ada, kalau `diagnosis` sudah menjelaskan.** `diagnosis`
/// benar dan tidak boleh diubah: ia sengaja meringkas jadi satu kalimat,
/// memilih sebab yang **mendominasi** (> separuh sampel ragu) atau menyebut
/// semua sebab yang seri di puncak. Yang ia tidak bisa lakukan dalam satu
/// kalimat adalah menyebut **berapa kali** tiap sebab muncul.
///
/// Akibatnya ada informasi yang hilang, dan hilang dengan cara yang diam-diam:
///
/// - Saat `tooFar` mendominasi, `ambiguous` hilang dari kalimat sepenuhnya.
///   Penguji bisa menyimpulkan "semua ragu karena kalibrasi" lalu membuat
///   kalibrasi yang tidak memperbaiki apa pun.
/// - Saat tidak ada yang mendominasi dan tidak ada seri, kalimatnya
///   `diagnosisNoMeasurableCause` — "belum ada sebab yang terukur" —
///   sementara `tooFar`/`ambiguous` bisa tetap ada dengan hitungan kecil.
///   Kalimat itu menyebut **ketiadaan** sebab sementara layar menunjuk
///   sebab yang ada.
///
/// Keduanya adalah informasi yang salah arah, bukan sekadar kurang lengkap.
/// Dan keduanya elusive dari gerbang mana pun: `diagnosis` benar, uji-ujinya
/// benar, dan tidak ada layar yang salah bentuk — yang hilang adalah
/// pertanyaan yang belum pernah diajukan ("sebab mana yang muncul?").
///
/// **Kenapa bentuknya struct, bukan array di view.** Tiga hal harus
/// dijamin bersama dan tidak satu pun bisa dijamin di dalam view:
///
/// 1. **Urutan stabil.** Baris mengikuti urutan deklarasi enum, bukan urutan
///    `Dictionary` — yang di-seed per proses. Tanpa itu, rincian yang sama
///    tampil dengan urutan berbeda tiap Court's CED pada rekaman yang sama.
///    Alasan dan maknanya sama persis dengan `tiedUncertainReasons`.
/// 2. **Baris nol tidak tampil.** Menampilkan "0× ambiguitas katalog"
///    menyatakan ada kategori yang diperiksa dan kosong — padahal tidak ada
///    bukti kategori itu pernah terjadi.
/// 3. **Ambang dominasi sama dengan `diagnosis`.** Kalau rincian memakai
///    "paling banyak" sementara `diagnosis` memakai "lebih dari separuh",
///    dua layar/dua kalimat memberi jawaban berbeda untuk data yang sama —
///    2 dari 2 adalah "paling banyak" tapi seri, dan seri tidak boleh
///    menampilkan satu sebab sendirian.
///
/// **Kenapa `policy` ikut dibawa, bukan cuma `counts`.** `counts` sudah
/// dihitung memakai suatu policy; dominasi dihitung ulang dari hitungan itu
/// saja, jadi policy yang salah hanya berpengaruh pada *klasifikasi* yang
/// sudah terjadi sebelum masuk ke sini. Parameter ini disimpan supaya
/// penambahan baris di kemudian hari tidak bisa diam-diam memakai policy berbeda dari
/// yang dipakai menghitungnya.
public struct UncertainReasonBreakdown: Equatable, Sendable {

    /// Satu baris rincian: sebab + berapa kali muncul.
    public struct Row: Equatable, Sendable {

        public var reason: ConfidenceTrace.UncertainReason
        /// Berapa kali sebab ini muncul di sampel ragu.
        public var count: Int
        /// Total sampel ragu — penyebut untuk `text`.
        public var total: Int

        public init(reason: ConfidenceTrace.UncertainReason, count: Int, total: Int) {
            self.reason = reason
            self.count = count
            self.total = total
        }

        /// Bentuk "%lld dari %lld" — satu kunci, bukan jumlah + kata yang
        /// disambung di view.
        ///
        /// **Kenapa penyebut ikut tampil.** Tidak ada angka lain yang
        /// menyiapkannya: `diagnosis` tidak pernah menyebut jumlah. Dan "2"
        /// yang berdiri sendiri bisa dibaca sebagai "sebab utama" padahal
        /// minoritas — penyebutlah yang membuatnya kelihatan.
        ///
        /// **Kenapa `RowCountText`, bukan `String` langsung.** Aksesor yang
        /// mengembalikan `String` bisa ikut dipakai sebagai kunci katalog,
        /// sehingga setiap nilai baru ikut menambah kunci. Bentuk `RowCountText`
        /// menjaga bahwa yang di-*call* adalah **format**, bukan teks —
        /// pemisahan yang sama seperti `LocalizedText` vs `String`.
        public var countText: RowCountText { RowCountText(count, of: total) }
    }

    /// Baris rincian, dalam **urutan deklarasi enum**.
    ///
    /// Hanya sebab dengan hitungan **lebih dari nol**. Lihat catatan struct.
    public let rows: [Row]

    /// Total seluruh sampel ragu — jumlah semua baris.
    public let totalUncertain: Int

    /// Policy yang dipakai menghitung hitungan.
    ///
    /// Disimpan, bukan dipakai ulang: ia dihitung dari `counts` yang
    /// sudah jadi. Yang dijaga adalah bahwa nilainya **ikut terlihat**, jadi
    /// penambahan baris di Kemudian tidak bisa diam-diam memakai policy
    /// lain.
    public let policy: ConfidencePolicy

    public init(counts: [ConfidenceTrace.UncertainReason: Int],
                policy: ConfidencePolicy = ConfidencePolicy()) {
        let total = counts.values.reduce(0, +)
        // Urutan deklarasi enum, bukan urutan dictionary. `allCases` adalah
        // urutan deklarasi — stabil, bukan kebetulan hash.
        self.rows = ConfidenceTrace.UncertainReason.allCases.compactMap { reason in
            let count = counts[reason] ?? 0
            guard count > 0 else { return nil }
            return Row(reason: reason, count: count, total: total)
        }
        self.totalUncertain = total
        self.policy = policy
    }

    /// Rincian kosong — tidak ada sampel ragu sama sekali.
    public static let empty = UncertainReasonBreakdown(counts: [:])

    /// Apakah tidak ada yang bisa ditampilkan.
    ///
    /// **`rows.isEmpty` sudah cukup**, jadi kenapa ada? Karena pemanggil di
    /// view butuh satu syarat yang menyatakan * articulating* "tidak ada
    /// yang perlu ditampilkan" — dan `isEmpty` memberi nama untuk itu tanpa
    /// memaksa view tahu apa pun soal isi. Perbedaannya kecil, tapi nama itu
    /// yang dipakai di dua tempat (iPhone & complication), dan dua tempat
    /// yang menulis `rows.isEmpty` sendiri adalah dua syarat yang bisa
    /// berbeda maksudnya nanti.
    public var isEmpty: Bool { rows.isEmpty }

    /// Apakah satu sebab **benar-benar** mendominasi: lebih dari separuh
    /// sampel ragu, dan bukan `.none`.
    ///
    /// **Ambang ini sengaja sama dengan `diagnosis`, bukan "paling
    /// banyak".** 2 dari 2 adalah "paling banyak" tapi **seri**, dan seri
    /// justru keadaan yang tidak boleh menampilkan satu sebab sendirian.
    /// Mengganti `>` dengan `>=` akan membuat 2 dari 2 tampil sebagai
    /// dominan, sementara `diagnosis` untuk data itu menyebut **dua** sebab.
    ///
    /// `.none` dikecualikan karena ia bukan sebab: ia adalah ketiadaan sebab
    /// yang terukur. Mengizinkan `.none` mendominasi membuat layar
    /// menampilkan "tanpa sebab terukur: 3 dari 3" seolah-olah itu penyebab
    /// yang paling besar, sementara `diagnosis` sengaja tidak pernah
    /// menyebutnya sebagai sebab.
    public var hasDominantReason: Bool { dominantReason != nil }

    /// Sebab yang mendominasi, atau `nil` bila tidak ada / seri / `.none`.
    public var dominantReason: ConfidenceTrace.UncertainReason? {
        guard totalUncertain > 0 else { return nil }
        // Sama persis dengan penyaring `diagnosis`: `.none` tidak ikut,
        // dan harus lewat ambang lebih-dari-separuh — bukan `max`.
        let dominant = rows.filter { $0.reason != .none
            && Double($0.count) * 2 > Double(totalUncertain) }
            .max { $0.count < $1.count }?.reason
        return dominant
    }
}

/// Bentuk "%lld dari %lld" — dipakai baris rincian dan setiap pemanggil lain
/// yang butuh menampilkan hitungan terhadap totalnya.
///
/// **Kenapa struct, bukan `String(format:)` di view.** Karena formatnya
/// harus diterjemahkan: "2 dari 7" tidak bisa disusun dari dua string yang
/// disambung view, karena urutan kata berbeda di setiap bahasa dan pemanggil
/// yang menyusunnya sendiri bisa menghasilkan "2 of 7" atau "7 dari 2".
/// Satu kunci, satu tempat menyusun.
public struct RowCountText: Equatable, Sendable {

    public var count: Int
    public var total: Int

    public init(_ count: Int, of total: Int) {
        self.count = count
        self.total = total
    }

    public var text: String {
        TextLocalization.text(.rowCountOf, Int64(count), Int64(total))
    }
}

// MARK: - Label sebab

public extension ConfidenceTrace.UncertainReason {

    /// Nama sebab untuk layar, lewat katalog.
    ///
    /// Bentuknya **frasa, bukan kalimat**: "Kandidat terlalu jauh" — bukan
    /// "Ragunya karena kandidat terlalu jauh". Alasannya baris ini berdiri
    /// sendiri di daftar, dan menambah pengantar akan mengulang diri untuk
    /// tiap baris.
    ///
    /// Perhatikan bahwa kata "kandidat" ada di sini dan bukan di kunci
    /// terpisah: yang ditampilkan adalah **objek yang tidak cocok**,
    /// dan "terlalu jauh" tanpa konteks apa yang terlalu jauh akan terbaca
    /// sebagai jarak dari layar.
    var label: String { TextLocalization.text(labelText) }

    /// Kunci + nilai bawaan — fungsi murni, bisa diuji di Linux.
    ///
    /// Murni karena alasan yang sudah berulang di repo ini:
    /// `TextLocalization` mengembalikan Bahasa Indonesia di Linux (tidak ada
    /// `.lproj`), jadi menguji `label` langsung hanya menguji nilai bawaan.
    /// Yang bisa diuji — dan yang dijaga di sini — adalah **pemetaan** enum
    /// ke kunci yang benar, supaya dua sebab tidak pernah memakai kunci yang
    /// sama.
    var labelText: LocalizedText {
        switch self {
        case .tooFar: return .uncertainReasonTooFar
        case .ambiguous: return .uncertainReasonAmbiguous
        case .none: return .uncertainReasonNone
        }
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let uncertainReasonTooFar = LocalizedText(
        key: "uncertain.reason.tooFar", id: "Kandidat terlalu jauh")
    static let uncertainReasonAmbiguous = LocalizedText(
        key: "uncertain.reason.ambiguous", id: "Tetangga terlalu dekat")
    static let uncertainReasonNone = LocalizedText(
        key: "uncertain.reason.none", id: "Tanpa sebab terukur")

    /// "%lld dari %lld" — jumlah terhadap totalnya.
    static let rowCountOf = LocalizedText(key: "row.count.of", id: "%lld dari %lld")
}