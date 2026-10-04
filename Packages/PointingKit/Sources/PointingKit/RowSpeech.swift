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
        return "\(title): \(value)"
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
    public static func spokenRate(_ degPerSec: Double, precision: Int) -> String {
        String(format: "%.\(precision)f derajat per detik", degPerSec)
    }

    /// Sudut dalam bentuk **kata**.
    public static func spokenDegrees(_ deg: Double) -> String {
        String(format: "%.1f derajat", deg)
    }

    /// Sudut dengan jumlah desimal yang mengikuti **tampilannya**.
    ///
    /// Kenapa presisinya ikut: baris teknis menampilkan RA/Dec dengan empat
    /// desimal (`%.4f°`). Mengucapkannya dengan satu desimal berarti suara
    /// dan layar menyebut angka yang berbeda untuk nilai yang sama — dan
    /// baris ini justru dipakai untuk **membandingkan** dua kolom angka.
    public static func spokenDegrees(_ deg: Double, precision: Int) -> String {
        String(format: "%.\(precision)f derajat", deg)
    }

    /// Galat pointing dalam bentuk **kata**.
    public static func spokenError(_ deg: Double) -> String {
        String(format: "galat %.1f derajat", deg)
    }
}
