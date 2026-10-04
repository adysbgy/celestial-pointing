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
    /// Bentuknya `"%@ %@ <angka>"` dengan **dua** sisipan: kata "galat" dan
    /// kata "derajat" datang dari katalog, sehingga bahasa lain bisa
    /// menempatkannya di urutan yang berbeda (mis. "error 2.5 degrees").
    /// Menyisipkan angkanya lebih dulu lalu menerjemahkan hasilnya tidak
    /// mungkin — katalog bekerja pada template, bukan pada hasil akhir.
    public static func spokenError(_ deg: Double) -> String {
        String(format: TextLocalization.text(.rowSpeechError),
               TextLocalization.text(.rowSpeechErrorWord),
               deg,
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
}
