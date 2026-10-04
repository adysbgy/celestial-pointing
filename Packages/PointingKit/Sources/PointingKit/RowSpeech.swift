import CelestialEngine
import Foundation

/// Teks yang **diucapkan** untuk baris "judul … nilai" dan nilai bertanda
/// satuan — satu sumber, teruji di Linux.
///
/// **Kenapa berkas ini ada.** Baris detail (`row`) dipakai di tiga layar
/// (`DiagnosticsView`, `LinkView`, `Experiment1View`) dengan bentuk yang
/// **identik**: `Text(title)` — `Spacer()` — `Text(value)`. Dua dari tiga
/// mengucapkannya sebagai satu pengumuman (`"\(title): \(value)"`); satu tidak
/// mengucapkan apa pun. Akibatnya VoiceOver membaca **dua elemen tanpa
/// hubungan** — "Laju pergelangan" lalu "0.5°/dtk" — dan pada baris yang
/// nilainya simbol, yang terdengar bukan kalimat.
///
/// Ini kelas cacat yang sudah dua kali muncul di repo ini: **dua jalur yang
/// seharusnya sama, tapi hanya satu yang diperbaiki**. Perbaikannya bukan
/// menambal yang tertinggal — melainkan membuat ketiganya memakai satu
/// sumber, sehingga tidak ada lagi jalur yang bisa tertinggal.
///
/// Kenapa di `PointingKit`, bukan di tiap view: kalimat yang diucapkan adalah
/// **janji produk**. "0.5°/dtk" yang terbaca apa adanya tidak terlihat salah
/// di layar mana pun, dan tidak ada uji di `Apps/` yang bisa menangkapnya —
/// berkas SwiftUI tidak ikut terbangun di Linux. Di sini ia bisa diuji.
///
/// **Batas yang dulu terbuka, dan sekarang ditutup.** Seluruh berkas ini
/// mengembalikan frasa **Bahasa Indonesia** yang tidak melewati
/// `TextLocalization`, jadi tidak satu pun punya kunci katalog: Aturan 6
/// (paritas `LocalizedText.allKeys`) tidak melihatnya, dan Aturan 4 tidak
/// menyapu `Packages/`. Akibatnya pengguna Bahasa Inggris mendengar
/// "5.0 derajat per detik" dan "galat 2.5 derajat" tanpa satu pun gerbang
/// merah — kelas yang sama dengan `SensorStatusText`, `CalibrationText`,
/// `ObjectSpeech`, dan `ExperimentText`. Sekarang setiap frasa punya kunci
/// (`row.speech.*`), jadi menghapusnya dari katalog menjadi MERAH.
public enum RowSpeech {

    /// Satu pengumuman untuk baris "judul … nilai".
    ///
    /// Tanpa penggabungan, VoiceOver membaca judul dan nilai sebagai dua
    /// elemen terpisah tanpa hubungan: "Matahari" lalu "-12" tanpa konteks
    /// apa yang diukur.
    ///
    /// - Parameter value: nilai apa adanya, mengikuti tampilan. Satuan di
    ///   dalamnya **tidak** diubah di sini — baris yang memang menampilkan
    ///   simbol tetap menampilkannya, dan pengucapannya diurus oleh
    ///   `spokenRow` bila nilainya bertanda.
    public static func label(title: String, value: String) -> String {
        guard !title.isEmpty else { return value }
        return String(format: TextLocalization.text(.rowSpeechLabel), title, value)
    }

    /// Baris yang nilainya **sudah dalam bentuk yang bisa diucapkan**.
    ///
    /// Dipakai bila pemanggil sudah mengubah angkanya jadi kata (mis.
    /// `"Laju pergelangan 5 derajat per detik."`).
    public static func spokenRow(title: String, spokenValue: String) -> String {
        label(title: title, value: spokenValue)
    }

    /// Kalimat keadaan untuk pengumuman, berbentuk **"Keadaan: X."**
    ///
    /// Ini bukan `spokenRow`: yang terakhir adalah baris **judul…nilai**
    /// (dipakai `SkyContextView`, `CalibrationView`, `LinkView`), sedangkan
    /// yang ini adalah **kalimat** — keadaan diumumkan sebagai kalimat, lalu
    /// kalimat panduan menyusul sebagai kalimat tersendiri.
    ///
    /// Bentuk lengkapnya sebelumnya hidup sebagai literal
    /// `"Keadaan: \(state.shortLabel)."` di dalam view. Yang salah bukan cuma
    /// literalnya: awalan "Keadaan:" adalah kata yang harus ikut
    /// diterjemahkan, dan menaruhnya di kode membuat pembaca layar berbahasa
    /// Inggris tetap membaca "Keadaan" sebelum membaca sisanya.
    public static func stateLine(_ state: PointingState) -> String {
        String(format: TextLocalization.text(.rowSpeechStateLine),
               state.shortLabel)
    }

    /// Laju pergelangan dalam bentuk **kata**, bukan simbol.
    ///
    /// "0.5°/dtk" terbaca oleh mata dan tidak terbaca oleh suara: "/dtk" bukan
    /// kata, dan "°" bukan satuan lisan. Ini padanannya.
    ///
    /// Presisinya **satu desimal, mengikuti tampilan** (`String(format:
    /// "%.1f°/dtk", …)`). Ini bukan detail kosmetik: laju pergelangan saat
    /// diam bernilai di bawah 1, jadi pembulatan ke nol akan mengucapkan
    /// "0 derajat per detik" untuk tampilan yang tertulis "0.4°/dtk" — suara
    /// dan layar menyebut dua angka berbeda untuk nilai yang sama.
    public static func spokenRate(_ degPerSec: Double) -> String {
        spokenRate(degPerSec, precision: 1)
    }

    /// Laju dengan jumlah desimal yang mengikuti **tampilannya**.
    ///
    /// Kenapa presisinya ikut: laju pergelangan saat diam bernilai di bawah 1
    /// dan ditampilkan sebagai `"%.1f°/dtk"`. Kalau yang diucapkan
    /// dibulatkan ke nol, terdengar "0 derajat per detik" untuk layar yang
    /// tertulis "0.4°/dtk" — **suara dan layar menyebut dua angka berbeda
    /// untuk nilai yang sama**. Cacat ini persis sekelas dengan RA/Dec di
    /// `spokenDegrees`, jadi penanganannya dibuat sama.
    ///
    /// Presisi masuk sebagai **angka**, bukan sebagai `%@` yang sudah jadi
    /// `"%.1f"`: `String(format:)` tidak bisa memakai specifier yang datang
    /// dari nilai runtime, dan menyerahkan penyusunannya ke pemanggil berarti
    /// setiap pemanggil harus tahu bentuk format yang benar.
    public static func spokenRate(_ degPerSec: Double, precision: Int) -> String {
        let unit = TextLocalization.text(.rowSpeechDegreesPerSecond)
        return String(format: "%.\(precision)f \(unit)", degPerSec)
    }

    /// Sudut dalam bentuk **kata**.
    public static func spokenDegrees(_ deg: Double) -> String {
        spokenDegrees(deg, precision: 1)
    }

    /// Sudut dengan jumlah desimal yang mengikuti **tampilannya**.
    ///
    /// Kenapa presisinya ikut: baris teknis menampilkan RA/Dec dengan empat
    /// desimal (`%.4f°`). Mengucapkannya dengan satu desimal berarti suara
    /// dan layar menyebut angka yang berbeda untuk nilai yang sama — dan
    /// baris ini justru dipakai untuk **membandingkan** dua kolom angka.
    public static func spokenDegrees(_ deg: Double, precision: Int) -> String {
        let unit = TextLocalization.text(.rowSpeechDegrees)
        return String(format: "%.\(precision)f \(unit)", deg)
    }

    /// Galat pointing dalam bentuk **kata**.
    ///
    /// Bentuknya `"%@ %.1f %@"`: kata "galat" dan satuan "derajat" datang dari
    /// katalog, sehingga bahasa lain bisa menyusunnya sendiri. Menyisipkan
    /// angkanya lebih dulu lalu menerjemahkan hasilnya tidak mungkin —
    /// katalog bekerja pada template, bukan pada hasil akhir.
    ///
    /// **Kenapa urutan tipe specifier-nya dijaga gerbang, bukan hanya
    /// diuji.** Argumennya `(String, Double, String)`, jadi penerjemah yang
    /// menulis `"%.1f %@ %@"` — wajar, ia ingin angkanya di depan — memberi
    /// `%.1f` sebuah `String`. Di CoreFoundation itu **crash**, bukan sekadar
    /// keluaran yang salah; glibc memaafkannya, jadi bentuk itu hijau di
    /// Linux dan meledak hanya di perangkat pengguna. Karena itu urutan tipe
    /// wajib sama dengan template kode, dan Aturan 11 memeriksanya untuk
    /// **setiap** kunci di katalog — bukan hanya yang ini.
    ///
    /// Batasnya jujur: bahasa yang menuntut angka di depan **tidak bisa**
    /// diterjemahkan lewat katalog saja. Itu memang benar — memindahkan
    /// specifier bertipe berbeda butuh tahu tipe argumennya, jadi perubahan
    /// itu harus lewat kode, bukan lewat berkas terjemahan.
    public static func spokenError(_ deg: Double) -> String {
        String(format: TextLocalization.text(.rowSpeechError),
               TextLocalization.text(.rowSpeechErrorWord),
               deg,
               TextLocalization.text(.rowSpeechDegrees))
    }

    /// Baris laju pergelangan untuk **pengumuman**, bukan untuk layar.
    ///
    /// **Kenapa bukan `spokenRate`.** `spokenRate` menghasilkan "0.5 derajat
    /// per detik" sebagai **nilai** — benar untuk jadi argumen `spokenRow`.
    /// Pengumuman kartu keadaan jam butuh kalimat sendiri: ia menyebut
    /// **apa** yang diukur ("laju pergelangan") lalu angkanya, karena sekali
    /// itu terdengar, tidak ada lagi baris layar yang mengiringinya. Tanpa
    /// pemisahan itu, pengumuman berbunyi "0.5 derajat per detik" dan
    /// pendengar tidak tahu itu laju tangan atau laju bintang.
    ///
    /// Presisi mengikuti **tampilannya** (`%.0f°/dtk` di kartu keadaan jam),
    /// dengan alasan yang sama seperti `spokenRate`: suara dan layar tidak
    /// boleh menyebut angka berbeda untuk nilai yang sama.
    public static func spokenWristRate(_ degPerSec: Double) -> String {
        String(format: TextLocalization.text(.rowSpeechWristRate),
               TextLocalization.text(.rowSpeechWristRateWord),
               degPerSec,
               TextLocalization.text(.rowSpeechDegrees))
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    /// Penggabungan satu baris "judul: nilai" untuk VoiceOver.
    ///
    /// Dua sisipan, dan pemisahnya (`": "`) milik katalog: sebagian bahasa
    /// memakai titik dua yang berbeda atau tidak memakainya sama sekali.
    static let rowSpeechLabel = LocalizedText(
        key: "row.speech.label",
        id: "%@: %@")

    /// Satuan sudut dalam bentuk kata.
    static let rowSpeechDegrees = LocalizedText(
        key: "row.speech.degrees",
        id: "derajat")

    /// Satuan laju sudut dalam bentuk kata.
    static let rowSpeechDegreesPerSecond = LocalizedText(
        key: "row.speech.degreesPerSecond",
        id: "derajat per detik")

    /// Kata yang menyebut **apa yang diukur** oleh galat pointing.
    ///
    /// Tanpa kata ini, "2.5 derajat" terdengar seperti nilai apa saja.
    static let rowSpeechErrorWord = LocalizedText(
        key: "row.speech.errorWord",
        id: "galat")

    /// Kalimat galat lengkap: kata, satuan, lalu angkanya.
    ///
    /// Urutannya milik katalog supaya bahasa lain bisa menaruh angkanya di
    /// tempat yang benar — urutan Indonesia menaruh angka di akhir.
    static let rowSpeechError = LocalizedText(
        key: "row.speech.error",
        id: "%@ %.1f %@")

    /// Kalimat pengumuman laju pergelangan, lengkap dengan kata "per detik".
    ///
    /// Terpisah dari `rowSpeechDegreesPerSecond` ("derajat per detik") karena
    /// dua ini dipakai di tempat berbeda: yang satu adalah **nilai** baris
    /// tabel, yang ini **kalimat** pengumuman. Menggabungkannya memaksa
    /// salah satu kehilangan konteksnya.

    /// Kalimat laju pergelangan: **"kata, angka, satuan"** — urutan yang sama
    /// dengan `row.speech.error` di atas, dan alasannya sama: angka tidak
    /// pernah diucapkan sendirian, dan urutan katanya milik terjemahan.
    ///
    /// **Bentuk specifier-nya terkunci** oleh Aturan 11 di `swift-ui-lint.sh`.
    /// Nilai aslinya `"%@ %.0f %@ per detik."` punya urutan tipe `@ f @`,
    /// sedangkan terjemahannya hanya punya `%.0f` — persis kelas yang
    /// **crash di CoreFoundation** dan lolos diam-diam di glibc, jadi
    /// `swift-test.sh` hijau sementara CI macOS merah. Karena `%.0f` tidak
    /// boleh bertemu `String` pada posisi tetap, keduanya disamakan dengan
    /// konvensi `row.speech.error`: angka diserahkan sebagai argumen dan
    /// katalog yang memiliki ejaannya.
    static let rowSpeechWristRate = LocalizedText(
        key: "row.speech.wristRate",
        id: "%@ %.0f %@ per detik.")

    /// Kata yang menyebut **apa** yang diukur oleh laju pada pengumuman.
    static let rowSpeechWristRateWord = LocalizedText(
        key: "row.speech.wristRateWord",
        id: "Laju pergelangan")

    /// Awalan kalimat keadaan: `"Keadaan: %@."`
    ///
    /// `%@` = `PointingState.shortLabel`, yang **sendiri** sudah punya kunci
    /// (`pointing.state.*.label`). Dua lapis terjemahan, dan itu memang perlu:
    /// kata "Keadaan" tidak bisa ikut dari labelnya sendiri, karena bentuk
    /// kalimatnya berbeda dari bentuk labelnya.
    static let rowSpeechStateLine = LocalizedText(
        key: "row.speech.stateLine",
        id: "Keadaan: %@.")
}
