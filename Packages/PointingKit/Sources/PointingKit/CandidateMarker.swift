import Foundation

// MARK: - Penanda "engine ragu" pada gambar

/// Warna & bentuk lencana yang menandai **kandidat**, bukan identitas.
///
/// **Kenapa token ini ada di model, bukan di view.** Lencana ini satu-satunya
/// penanda bahwa gambar di sebelahnya **tidak** mengklaim identitas
/// (`CelestialVisualView.isConfirmed == false`). Ia dikerjakan dua hal
/// sekaligus, dan keduanya bisa salah tanpa ada teks di layar yang bisa
/// membantah:
///
/// 1. **Warnanya.** View lama memakai `Color.black.opacity(0.55)` — hitam
///    pekat **tanpa mode malam**. Di mode merah (satu-satunya mode yang
///    rhodopsin izinkan: rod ~498-530nm, cahaya >620nm aman), tanda keraguan
///    jadi satu-satunya piksel yang **tidak** merah di seluruh layar.
///    Gerbang warna (Aturan 15) tidak bisa melihatnya: ia menghitung warna
///    **prosedural** (angka), sedangkan `Color.black` adalah nama.
/// 2. **Bentuknya.** Warna saja tidak cukup. Mode malam membuang hue, jadi
///    lencana yang hanya dibedakan warnanya menghilang bersama hue-nya. Yang
///    tersisa harus **bentuk** — tanda tanya (`glyph`), dengan ukuran yang
///    tidak menutupi piringan objeknya (`diameterFactor`).
///
/// Karena itu warnanya dinyatakan di sini sebagai kanal merah saja, dan
/// kedua mode menghasilkan merah murni: hijau & biru **nol**, bukan "kecil".
public enum CandidateMarker {

    /// Isi lencana, dalam warna **merah murni** di kedua mode.
    ///
    /// - Parameter isNight: mode malam (merah) aktif.
    ///
    /// Siang tetap merah karena (a) merah bukan warna objek mana pun di
    /// palet — Mars paling dekat, tetapi lencana ini digambar **di atas**
    /// objeknya dan bukan pada permukaannya, dan (b) kalau siang memakai
    /// abu-abu, lencana yang sama menjadi dua benda berbeda di dua mode, dan
    /// yang pertama kali lupa diperbarui adalah yang jarang dilihat.
    public static func badgeFill(isNight: Bool) -> CelestialVisual.RGBComponents {
        .init(red: isNight ? nightRed : dayRed, green: 0, blue: 0)
    }

    /// Isi lencana yang datang **dari palet**, untuk kedua mode.
    ///
    /// **Kenapa ada dua fungsi dengan niat sama.** Isi lencana punya dua syarat
    /// yang saling tarik: `accents.candidateFill` — warna yang dibaca port
    /// Python dan dijaga gerbang paritas malam — harus benar-benar
    /// **menggambar** (sebelum siklus ini ia tidak: view hanya membaca
    /// `badgeFill`, jadi tokennya dilaporkan mati, 25 dari 26, dan CI Linux
    /// merah); dan mode siang/malam harus tetap **berbeda**
    /// (`testNightMarkIsBrighterThanDayMark`).
    ///
    /// Angkanya tinggal di `CelestialVisual.candidateFill(isNight:)` — extension
    /// di `NightVisual.swift`, berkas yang sama dengan `accents` — karena
    /// gerbang jangkauan hanya menelusuri `func` yang **berkasnya** sama dengan
    /// tempat `Accents` dideklarasikan. Fungsi di sini adalah nama yang dipakai
    /// view dan uji `CandidateMarkerTests`; ia tidak menambah angka sendiri,
    /// hanya meneruskan.
    public static func badgeFillFromPalette(isNight: Bool) -> CelestialVisual.RGBComponents {
        CelestialVisual.candidateFill(isNight: isNight)
    }

    /// Kanal merah siang.
    ///
    /// Lebih gelap dari `accents.saturnRing` (0.86) dengan margin jauh lebih
    /// besar dari selisih piksel mini, supaya lencana terbaca sebagai penanda
    /// di atas cincin — bukan sebagai bagian dari cincin itu.
    static let dayRed: Double = 0.38

    /// Kanal merah malam. Lebih terang dari kanal merah `SurfacePalette.night`
    /// background supaya lencananya tidak tenggelam ke latar saat mode malam.
    static let nightRed: Double = 0.72

    /// Simbol di dalam lencana.
    ///
    /// Tanda tanya, bukan warna: satu-satunya saluran yang **tidak** dibuang
    /// mode malam.
    public static let glyph = "?"

    /// Warna **garis** lencana dan glifnya.
    ///
    /// **Kenapa ikut ke sini, bukan tetap `PointingTone.warning.color` di
    /// view.** Lencana adalah satu benda: isi, garis, dan tanda tanya. Dulu
    /// isinya diatur di satu tempat (tanpa mode malam) dan garisnya di tempat
    /// lain (`PointingTone`, sudah merah di mode malam), jadi bentuknya
    /// sendiri tidak pernah bisa diuji sebagai satu kesatuan. Dua uji di sini
    /// menuntut yang tidak terlihat dari angka mana pun saja: garis dan glif
    /// harus **lebih terang** dari isinya, dan isinya harus **lebih gelap**
    /// dari cincin yang ditutupinya — dua arah yang bisa saja sama-sama
    /// terpenuhi oleh warna yang salah kalau keduanya tidak diuji bersama.
    ///
    /// Nilainya **satu pemilik** per mode: mode siang memakai nada `warning`
    /// `TonePalette.day` (amber, yang gerbang kontras nada sudah jaga), mode
    /// malam memakai token `accents.candidateStroke` (merah murni, 0.96).
    ///
    /// **Kenapa mode malam tidak memakai `TonePalette.night.warning` (0.982).**
    /// Token itu hanya 0.262 di atas isi lencana malam (0.72) — cukup sebagai
    /// perbandingan kanal, tetapi garis 1.5 pt yang hampir menyatu dengan
    /// isinya tidak terbaca sebagai cincin di layar kecil jam. Token aksen
    /// **1.0** — merah penuh, masih di atas nada 0.982 — memberi jarak 0.28
    /// terhadap isi: cukup jelas sebagai garis tanpa menjadi objek kedua di
    /// layar. Angka itu milik `Accents`, jadi palet tetap pemiliknya; uji
    /// `testStrokeIsBrighterThanTheFillItOutlines` mengukur jaraknya.
    public static func stroke(isNight: Bool) -> CelestialVisual.RGBComponents {
        // Dua cabang dari **dua tipe berbeda** (`RGBComponents` milik palet
        // gambar, `SurfaceColor` milik palet nada), jadi konversinya dilakukan
        // per cabang, bukan pada hasil `? :` — Swift menolak cabang yang
        // tipenya berbeda sebelum sempat mengubahnya.
        if isNight {
            let token = CelestialVisual.accents.candidateStroke
            return CelestialVisual.RGBComponents(red: token.red, green: token.green,
                                                 blue: token.blue)
        }
        let tone = TonePalette.day.warning
        return CelestialVisual.RGBComponents(red: tone.red, green: tone.green,
                                             blue: tone.blue)
    }

    /// Diameter lencana, sebagai pecahan dari diameter objek.
    ///
    /// Batas atasnya bukan selera: lencana yang lebih besar dari ~separuh
    /// piringan menutupi ciri yang justru sedang **disamarkan** dan bisa
    /// terbaca sebagai objek lain. Batas bawahnya: lebih kecil dari ini, tanda
    /// tanya tidak terbaca di kartu jam 38pt.
    public static let diameterFactor: Double = 0.28
}
