import Foundation
import CelestialEngine

/// Nama bintang: **kelas spektralnya**, dan jalur yang membuat warnanya sampai
/// ke telinga VoiceOver.
///
/// **Kenapa berkas ini ada.** `StarColorSpeech` sudah menjanjikan bahwa
/// pengguna VoiceOver mendapat warna bintang yang sama dengan yang dilihat
/// mata. Janji itu terpenuhi di tingkat fungsi — `spokenStarColor` diuji, pita
/// B−V diuji, tabel 25 bintang diuji — tetapi **rantainya putus satu sambungan
/// sebelum sampai ke layar**. Pemanggilnya di `ObjectDetailView` memakai
/// `CelestialVisual` yang dirakit dari `CelestialObject` (`CelestialVisual(object:)`),
/// dan jalur itu tidak mengisi `objectID` untuk bintang. Tanpa id, tabel warna
/// tidak bisa ditanyakan, `colorIndexBV` jatuh ke `unknownStarColorIndex`
/// (`NaN`), `spokenStarColor` mengembalikan `nil`, dan yang terdengar hanyalah
/// "Rigel, bintang". Bukan salah warna — **diam**.
///
/// Itu kelas yang sama dengan sisa repo ini: setiap gerbang hijau, dan yang
/// diukur bukan bagian yang bermasalah. Karena itu ujinya
/// (`StarNameSpeechTests`) sengaja **tidak merakit visual dengan tangan**; ia
/// menempuh jalur yang dipakai view.
///
/// **Batas yang dinyatakan.** Kelas spektral di sini berasal dari komentar
/// tabel warna di `CelestialVisual` (`"rigel": -0.03, // B8 — biru`) dan
/// diuji **kesamaannya** dengan komentar itu. Kelas yang salah di kedua tempat
/// — komentar dan tabel — tidak bisa ditangkap uji mana pun di repo ini; yang
/// dijamin adalah tidak ada dua daftar yang berbeda pendapat.
public extension CelestialVisual {

    /// Kelas spektral sebuah bintang, dari id-nya — atau `nil` bila tidak ada.
    ///
    /// `nil` dan **bukan tebakan** untuk id yang tidak ada di katalog
    /// (`matahari`, `bulan`, id kosong). Warna bintang hanya menentukan
    /// **huruf** kelasnya; angkanya (B8 vs B2) tidak bisa dipulihkan darinya,
    /// dan mengarang angka akan terdengar sama berwibawanya dengan yang benar.
    /// Diam lebih baik daripada kelas yang salah diucapkan.
    static func spectralClass(forStarID id: String) -> String? {
        starSpectralClassByID[id]
    }

    /// Kelas spektral yang layak diucapkan.
    ///
    /// Kosong diperlakukan sebagai tidak diketahui: `""` diucapkan sebagai
    /// jeda, dan pemanggil yang meneruskan string kosong lebih mungkin lupa
    /// daripada sengaja.
    static func spokenStarClass(spectralClass: String?) -> String? {
        guard let spectralClass, !spectralClass.isEmpty else { return nil }
        return spectralClass
    }

    /// Kalimat kelas spektral, siap ditempel setelah nama bintang.
    ///
    /// Berbentuk kalimat (`"kelas spektral %@"`) dan bukan sekadar `"B8"`,
    /// karena VoiceOver membaca `"Rigel, B8"` sebagai dua ejaan tanpa
    /// hubungan; `"kelas spektral B8"` menyebutkan apa yang diucapkan.
    ///
    /// **Kenapa ia punya `isConfirmed:`, padahal warnanya sudah punya
    /// penjaganya sendiri.** Kelas spektral adalah ciri pengenal yang
    /// berdiri sendiri — `M1` di katalog 25 bintang ini menunjuk Betelgeuse
    /// atau Antares, sama langsungnya dengan warna merahnya. Karena ia bukan
    /// turunan warna, penjaga di `spokenStarColor(isConfirmed:)` tidak
    /// menaunginya: dulu fungsi ini tidak punya parameter itu sama sekali,
    /// sehingga ia diucapkan pada setiap keadaan, termasuk saat engine ragu.
    /// Yang terjadi waktu itu adalah suara yang lebih yakin daripada
    /// layarnya — VoiceOver menyebut "kelas spektral M1" sementara titik di
    /// layar abu-abu "tidak mengklaim" dan badge-nya bertuliskan "Ragu".
    ///
    /// Tanpa parameter ini pula, Aturan 34/36 tidak pernah melihat fungsi
    /// ini: daftar aksesor yang mereka periksa dibaca dari deklarasi
    /// ber-`isConfirmed:`, dan deklarasi tanpa parameter itu tidak ada di
    /// daftar. Jadi penjaganya kini **terlihat oleh gerbang yang sudah ada**,
    /// bukan hanya oleh uji ini.
    ///
    /// Tanpa nilai bawaan, dengan alasan yang sama seperti
    /// `spokenStarColor(isConfirmed:)`: pemanggil yang lupa harus gagal
    /// kompilasi, bukan diam-diam mengucapkan klaim.
    static func spokenStarClassLine(spectralClass: String?,
                                    isConfirmed: Bool) -> String? {
        guard isConfirmed else { return nil }
        guard let spectralClass = spokenStarClass(spectralClass: spectralClass) else {
            return nil
        }
        return TextLocalization.text(Self.starClassLineLine(spectralClass: spectralClass),
                                     spectralClass)
    }

    /// Kunci katalog untuk kalimat kelas — **fungsi murni**, tanpa bundle.
    ///
    /// Murni karena alasan yang sudah berulang di repo ini:
    /// `TextLocalization` mengembalikan Bahasa Indonesia di Linux, jadi
    /// menguji kalimatnya langsung hanya menguji nilai bawaan. Yang diuji
    /// terpisah adalah **kunci** yang dipilih (di sini) dan **bentuk
    /// Inggris**-nya (uji terpisah yang memasang terjemahan).
    static func starClassLineLine(spectralClass: String) -> LocalizedText {
        .starClassLine
    }

    /// Warna bintang untuk diucapkan, **dari indeks** — untuk pemanggil yang
    /// memegang angka, bukan visual (mis. uji yang memasang bahasa Inggris
    /// pada satu nilai).
    ///
    /// Ia memakai penjaga yang sama dengan `spokenStarColor(isConfirmed:)`
    /// lewat `drawableStarColorIndex`, jadi tidak ada jalur kedua yang bisa
    /// melupakan `isConfirmed`.
    static func spokenStarColorLine(colorIndexBV: Double, isConfirmed: Bool) -> String? {
        let drawable = drawableStarColorIndex(colorIndexBV, isConfirmed: isConfirmed)
        guard !drawable.isNaN else { return nil }
        return TextLocalization.text(starColorText(drawable))
    }

    /// Kelas spektral per id bintang di `starColorIndex`.
    ///
    /// **Kenapa tabel terpisah, bukan tiga kolom di `starColorIndex`.** Tabel
    /// warna itu dipakai gambar (`starRGB`) dan dibaca uji-uji warnanya;
    /// menambahkan kolom kepadanya mengubah bentuk yang sudah dijaga tanpa
    /// alasan. Kedua tabel dijaga **sepakat** oleh
    /// `testSpokenClassAgreesWithTheColourTableComment`, yang membaca
    /// komentar sumber warna — jadi tabel ini tidak bisa diam-diam menjadi
    /// daftar kedua yang berbeda pendapat.
    static let starSpectralClassByID: [String: String] = [
        "sirius": "A1",
        "canopus": "F0",
        "arcturus": "K0",
        "vega": "A0",
        "capella": "G8",
        "rigel": "B8",
        "procyon": "F5",
        "achernar": "B6",
        "betelgeuse": "M1",
        "hadar": "B1",
        "altair": "A7",
        "acrux": "B0",
        "aldebaran": "K5",
        "spica": "B1",
        "antares": "M1",
        "pollux": "K0",
        "fomalhaut": "A3",
        "deneb": "A2",
        "regulus": "B8",
        "castor": "A1",
        "bellatrix": "B2",
        "alioth": "A1",
        "alnitak": "O9",
        "dubhe": "K0",
        "polaris": "F7"
    ]
}

// MARK: - Katalog kunci

public extension LocalizedText {

    /// `%1$@`-nya berisi kelas spektral (`B8`), yang sama di semua bahasa.
    static let starClassLine = LocalizedText(key: "star.class.line.spoken.label",
                                             id: "kelas spektral %1$@")
}
