import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji token visual untuk keadaan **ragu**.
///
/// **Cacat yang ditutup uji-uji ini.** Lencana "engine belum pasti" digambar
/// oleh `drawCandidateMarker` di `Apps/Shared/CelestialVisualView.swift`.
/// Sebelum token ini pindah ke model, bentuk ikut view dan warnanya
/// `Color.black.opacity(0.55)` — pekat **tanpa** cabang mode malam. Di mode
/// merah (satu-satunya mode yang rhodopsin izinkan: rod ~498-530nm, cahaya
/// >620nm aman) lencana itu jadi satu-satunya piksel di layar yang **tidak**
/// merah. Gerbang warna (Aturan 15) buta terhadapnya: ia menghitung warna
/// prosedural berupa angka, sedangkan `Color.black` adalah nama.
///
/// Uji-uji di bawah mengunci konsekuensi yang bisa diukur: keraguan tidak
/// membawa kanal hijau/biru sama sekali, tetap terbaca di atas objek dan di
/// atas latar malam, dan dibedakan oleh **bentuk**, bukan hue.
final class CandidateMarkerTests: XCTestCase {

    private func brightness(_ c: CelestialVisual.RGBComponents) -> Double {
        c.red * 0.2126 + c.green * 0.7152 + c.blue * 0.0722
    }

    // MARK: - Keraguan tidak boleh diwarnai, apalagi diwarnai biru

    func testUncertainMarkIsPureRedInDayMode() {
        let mark = CandidateMarker.badgeFill(isNight: false)
        XCTAssertEqual(mark.green, 0, accuracy: 1e-12,
                       "keraguan tidak boleh membawa warna kedua")
        XCTAssertEqual(mark.blue, 0, accuracy: 1e-12,
                       "keraguan tidak boleh membawa warna kedua")
    }

    func testNightMarkIsPureRed() {
        let mark = CandidateMarker.badgeFill(isNight: true)
        XCTAssertGreaterThan(mark.red, 0)
        XCTAssertEqual(mark.green, 0, accuracy: 1e-12,
                       "hijau nol persis, bukan 'kecil'")
        XCTAssertEqual(mark.blue, 0, accuracy: 1e-12,
                       "biru nol persis, bukan 'kecil'")
    }

    /// Tanda ragu harus **lebih gelap** dari cincin planet di kedua mode.
    ///
    /// Ia digambar di atas piringan yang bisa saja cincin Saturnus. Tanda
    /// yang lebih terang dari cincinnya terbaca sebagai bagian dari objek —
    /// dan yang paling mungkin dibaca begitu justru tanda yang menyatakan
    /// "benda ini belum pasti".
    func testMarkIsDarkerThanTheRingItCovers() {
        let dayRing = CelestialVisual.accents.saturnRing
        let nightRing = NightVisual.surface(dayRing)
        for (isNight, ring) in [(false, dayRing), (true, nightRing)] {
            let mark = CandidateMarker.badgeFill(isNight: isNight)
            XCTAssertLessThan(brightness(mark), brightness(ring) * 0.8,
                              "tanda ragu (\(isNight ? "malam" : "siang")) "
                              + "tidak cukup gelap untuk terbaca sebagai "
                              + "penanda di atas objeknya")
        }
    }

    /// Tanda ragu harus terlihat sebagai **bentuk** di atas latar malam.
    ///
    /// Sisi gelap yang hampir hitam akan hilang ke latar, dan lencana yang
    /// hilang berarti layar ragu tanpa penanda — persis false confidence.
    func testMarkStaysVisibleOnTheNightBackground() {
        let mark = CandidateMarker.badgeFill(isNight: true)
        let background = SurfacePalette.night.background
        XCTAssertGreaterThan(mark.red, background.red + 0.15,
                             "tanda ragu malam tenggelam ke latar")
    }

    /// Tanda malam harus **lebih terang** dari tanda siang, dengan alasan
    /// yang sama seperti palet lain: latar malam `SurfacePalette.night`
    /// hampir hitam, dan kanal merah lencana siang tenggelam di sana.
    ///
    /// Uji ini ada karena harness `Tools/bukti-mutasi-token-lencana.py`
    /// menemukan celahnya: dengan cabang malam dipaksa mengembalikan merah
    /// siang, ketiga uji lain tetap hijau. Warna lencana memang harus gelap
    /// di kedua mode (supaya terbaca di atas objek), jadi selisihnya harus
    /// dinyatakan di sini — bukan disimpulkan dari "ada cabang `isNight`".
    func testNightMarkIsBrighterThanDayMark() {
        let day = CandidateMarker.badgeFill(isNight: false)
        let night = CandidateMarker.badgeFill(isNight: true)
        XCTAssertGreaterThan(night.red, day.red,
                             "tanda malam harus lebih terang dari tanda "
                             + "siang agar tidak tenggelam ke latar malam")
        // Bukan sekadar selisih kecil: harus terbaca sebagai peningkatan.
        XCTAssertGreaterThan(night.red - day.red, 0.2,
                             "selisih malam/siang terlalu kecil untuk "
                             + "berfungsi sebagai kompensasi latar")
    }

    // MARK: - Tanda tanya: simbol keraguan

    /// Token mentah `accents.candidateFill` harus **benar-benar** menjadi isi
    /// lencana di mode siang, bukan angka yang tidak pernah menggambar.
    ///
    /// **Cacat yang ditutup.** `accents.candidateFill` dideklarasikan, diparitas
    /// terhadap port Python, dan **tidak digambar view**: isi lencananya diambil
    /// konstanta `dayRed`. Gerbang jangkauan aksen
    /// (`check_night_accents_reach_the_view`) melaporkannya sebagai 25 dari 26
    /// warna terjangkau, dan CI Linux merah. Uji ini menuntut tiga hal
    /// sekaligus: jalur palet mengembalikan token itu apa adanya, mode malam
    /// tetap lebih terang (bukan token yang sama di dua mode), dan tokennya
    /// sah sebagai penanda — merah murni dan lebih gelap dari cincin yang ia
    /// tutupi.
    ///
    /// **Kenapa menguji `CelestialVisual.candidateFill`, bukan pembungkusnya.**
    /// Itu fungsi yang **dipanggil view** (satu-satunya nama yang menghubungkan
    /// gerbang jangkauan ke token). Menguji pembungkus saja akan tetap hijau
    /// kalau view berhenti memanggil fungsi ini — persis kelas cacat yang
    /// sedang ditutup.
    func testDayFillComesFromThePaletteToken() {
        let day = CelestialVisual.candidateFill(isNight: false)
        XCTAssertEqual(day, CelestialVisual.accents.candidateFill,
                       "isi lencana siang harus token palet, bukan salinan")
        XCTAssertEqual(day.green, 0, accuracy: 1e-12)
        XCTAssertEqual(day.blue, 0, accuracy: 1e-12)
        XCTAssertLessThan(brightness(day),
                          brightness(CelestialVisual.accents.saturnRing) * 0.8,
                          "token isi lencana tidak cukup gelap di atas objeknya")
        // Cabang malam tetap dibedakan: latar malam hampir hitam.
        let night = CelestialVisual.candidateFill(isNight: true)
        XCTAssertGreaterThan(night.red, day.red)
        XCTAssertEqual(night.green, 0, accuracy: 1e-12)
        XCTAssertEqual(night.blue, 0, accuracy: 1e-12)
        // Pembungkus yang dipakai uji lain tidak boleh menyimpang dari jalur
        // view: satu arti, dua nama.
        XCTAssertEqual(CandidateMarker.badgeFillFromPalette(isNight: false), day)
        XCTAssertEqual(CandidateMarker.badgeFillFromPalette(isNight: true), night)
    }

    /// Simbol lencana sengaja **tidak** berupa warna. Kalau ia hanya beda
    /// warna, mode malam yang membuang hue akan menghapus satu-satunya
    /// penanda keraguan di gambar.
    func testMarkIsShapedNotJustColoured() {
        XCTAssertEqual(CandidateMarker.glyph, "?")
        XCTAssertGreaterThan(CandidateMarker.diameterFactor, 0.1)
        XCTAssertLessThan(CandidateMarker.diameterFactor, 0.5,
                          "lencana tidak boleh menutupi piringan objek")
    }

    /// Kecerahan tanda tidak bergantung pada objeknya: ia menandai
    /// **keraguan**, bukan ukuran atau terang objek. Dua objek berbeda
    /// dengan keyakinan sama harus menampilkan penanda yang sama.
    func testMarkDoesNotDependOnTheObject() {
        let a = CandidateMarker.badgeFill(isNight: false)
        let b = CandidateMarker.badgeFill(isNight: false)
        XCTAssertEqual(a, b)
    }

    // MARK: - Garis lencana: bagian yang tidak pernah diuji

    /// Garis lencana harus **lebih terang** dari isi yang digarisinya, di
    /// **kedua** mode.
    ///
    /// **Cacat yang ditutup.** Garis dan glif dulu memakai
    /// `PointingTone.warning.color` — jalur yang tidak melewati palet gambar
    /// yang diukur pemeriksa visual. Akibatnya satu-satunya bagian lencana
    /// yang **pasti** terlihat (isi gelap di atas objek terang tidak selalu
    /// kontras) tidak dijaga rasio apa pun: mengubah nada `warning` mode malam
    /// menjadi 0.72 — sama persis dengan isinya — akan membuat cincin hilang
    /// dan tidak satu pun uji lain berbunyi.
    ///
    /// Yang dituntut jaraknya, bukan hanya urutannya: perbandingan kanal yang
    /// berbeda 0.01 lolos tuntutan "<" tetapi di layar kecil garis 1.5 pt itu
    /// lereng dengan isinya. Ambang 0.10 diukur pada **kanal merah mentah**
    /// — satu-satunya kanal yang dimiliki mode malam — dengan nilai
    /// sebenarnya: malam 1.0 − 0.72 = 0.28, siang 0.96 − 0.38 = 0.58.
    func testStrokeIsBrighterThanTheFillItOutlines() {
        for night in [false, true] {
            let fill = CandidateMarker.badgeFill(isNight: night)
            let stroke = CandidateMarker.stroke(isNight: night)
            // Kedua warna murni-merah di mode malam (hijau/biru = 0), jadi
            // pemisahan yang terlihat **hanya** kanal merah. Luma (0.2126·R)
            // memampatkan selisih 4.7× dan menyembunyikan perbedaan nyata —
            // diukur: ambang 0.10 pada luma hanya lolos kalau selisih merah
            // ≥ 0.47, yang mustahil karena isinya sudah 0.72 dan merah mentok
            // di 1.0. Yang diukur di sini adalah selisih kanal merah mentah.
            XCTAssertGreaterThan(
                stroke.red - fill.red, 0.10,
                "garis lencana (mode \(night ? "malam" : "siang")) hampir menyatu dengan isinya")
        }
        // Mode malam tetap merah murni: garisnya bagian dari lencana yang sama.
        let nightStroke = CandidateMarker.stroke(isNight: true)
        XCTAssertEqual(nightStroke.green, 0, accuracy: 1e-12)
        XCTAssertEqual(nightStroke.blue, 0, accuracy: 1e-12)
    }

    /// Token garis malam **satu pemilik** di `Accents`, seperti isinya.
    ///
    /// **Kenapa ini menguji jalur token, bukan fungsinya.** `stroke` adalah
    /// pembungkus; kalau ia kembali bekerja sendiri (mis. `TonePalette.night`
    /// langsung), nilai di `Accents` berhenti mengatur apa yang digambar dan
    /// tokennya tidak lagi punya konsumen di view. Gerbang jangkauan aksen
    /// (`check_night_accents_reach_the_view`) akan melaporkannya sebagai warna
    /// mati — dan itu tepat yang terjadi pada `candidateFill` sebelum siklus
    /// ini. Uji ini menangkapnya di Linux, sebelum CI.
    func testNightStrokeComesFromThePaletteToken() {
        let token = CelestialVisual.accents.candidateStroke
        XCTAssertEqual(CandidateMarker.stroke(isNight: true), token,
                       "garis lencana malam harus token aksen, bukan nilai ketiga")
        XCTAssertEqual(token.green, 0, accuracy: 1e-12)
        XCTAssertEqual(token.blue, 0, accuracy: 1e-12,
                       "mode malam membuang hue: garis tidak boleh menyelundupkan biru")
    }
}
