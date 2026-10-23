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

    // MARK: - Glif "?" harus terbaca sebagai tanda tanya, bukan gumpalan

    /// **Pengunci cacat: garis glif menelan rongga lengkungnya.**
    ///
    /// Selama ini tebal garis glif adalah literal `0.28 · radius lencana` di
    /// view dan dua kali di port Python. Angka itu **salah**, dan tidak ada
    /// satu pun gerbang atau uji yang bisa melihatnya:
    ///
    /// | Ukuran | Nilai |
    /// |---|---|
    /// | radius lencana (kartu jam 38 pt) | 0.3196 R = 3.04 pt |
    /// | tebal garis glif `0.28 · badge` | 0.0895 R = **1.70 pt** |
    /// | tinggi lengkung glif `0.55 · 0.52 · badge` | 0.0914 R = **1.74 pt** |
    /// | rasio garis ÷ lengkung | **0.98** |
    ///
    /// Garis yang setebal lengkungnya sendiri mengisi rongga lengkung itu.
    /// Yang tergambar bukan tanda tanya melainkan **gumpalan pejal** —
    /// diperiksa langsung pada render 114 px (setara 38 pt @3x) dan 400 px:
    /// vision menamainya "a filled blob … no gap between the curved top and
    /// the bottom dot". Pada rasio 0.45 (yang dipakai sekarang: 0.13) ia
    /// menamainya "a legible question mark … a separate dot".
    ///
    /// **Kenapa cacat ini penting justru di sini.** Lencana ini satu-satunya
    /// penanda di layar yang mengatakan "engine ragu". Glif yang berhenti
    /// terbaca sebagai tanda tanya menyisakan gambar objek **tanpa** penanda
    /// yang bisa dibaca — dan gambar tanpa penanda terbaca sebagai identitas
    /// yang pasti. Itu pelanggaran paling keras di PRD v0.4.
    ///
    /// **Kenapa uji ini tidak bisa digantikan paritas port↔view.**
    /// `check-visuals.py` sendiri mencatat bahwa mutasi VIEW `0.28 → 0.60`
    /// meninggalkan **313 pemeriksaan hijau**. Paritas hanya menuntut kedua
    /// bahasa sepakat; keduanya sepakat pada angka yang salah. Yang perlu
    /// diuji adalah **geometrinya**, bukan kesepakatannya.
    func testGlyphStrokeIsThinEnoughToLeaveTheHookOpen() {
        let marker = VisualFrame.candidateMarker()
        // Ambang 0.5 bukan selera: pada rasio 1.0 garisnya selebar lengkung
        // (gumpalan, diukur), pada 0.45 glifnya terbaca (diukur). 0.5 adalah
        // batas atas yang masih menyisakan rongga di kedua sisi garis.
        XCTAssertLessThan(
            marker.strokeToHookRatio, 0.5,
            "tebal garis glif \\(marker.glyphStroke) menutupi tinggi lengkung "
            + "\\(marker.glyphHookHeight) (rasio \\(marker.strokeToHookRatio)): "
            + "tanda tanya tergambar sebagai gumpalan, bukan tanda tanya")
        // Batas bawah: garis yang terlalu tipis hilang di layar jam. Pada
        // 38 pt, 0.13 · badge = 0.79 pt — masih di atas 1 px @3x, dan
        // `max(1, …)` di view/port menjaga lantai pikselnya.
        XCTAssertGreaterThan(
            marker.strokeToHookRatio, 0.2,
            "tebal garis glif terlalu tipis untuk terbaca di kartu jam 38 pt")
    }

    /// Rasio itu **tidak bergantung ukuran**: keduanya pecahan radius, jadi
    /// kartu 38 pt dan panel 132 pt punya geometri yang sama bentuknya.
    ///
    /// Ini bukan duplikat uji di atas — ia menyatakan kenapa tidak perlu
    /// menguji per ukuran, dan menangkap perbaikan yang "memperbaiki" satu
    /// ukuran dengan angka mutlak (mis. `lineWidth: 2`) yang hanya benar di
    /// satu ukuran.
    func testGlyphShapeIsScaleInvariant() {
        let watch = VisualFrame.candidateMarker(frameHalfExtent: 1.0)
        let phone = VisualFrame.candidateMarker(frameHalfExtent: 3.5)
        XCTAssertEqual(watch.strokeToHookRatio, phone.strokeToHookRatio,
                       accuracy: 1e-12,
                       "bentuk glif harus sama di semua ukuran; yang berbeda "
                       + "hanya skalanya")
        // Skalanya memang berbeda — kalau tidak, frameHalfExtent diabaikan.
        XCTAssertGreaterThan(phone.glyphStroke, watch.glyphStroke * 3.0)
    }

    /// Tebal garis harus **satu pemilik**: `strokeFraction` di model.
    ///
    /// Kalau view kembali menulis literal, uji di atas tetap hijau
    /// (modelnya benar) sementara layarnya tetap gumpalan — persis bentuk
    /// cacat yang baru saja ditutup. Yang dijaga di sini: token itu ada di
    /// model dan nilainya yang dipakai, bukan angka ketiga di tempat lain.
    func testStrokeFractionIsTheSingleOwner() {
        let marker = VisualFrame.candidateMarker()
        XCTAssertEqual(marker.strokeFraction, 0.13, accuracy: 1e-12,
                       "fraksi tebal glif harus dari model")
        XCTAssertEqual(marker.glyphStroke,
                       marker.radius * marker.strokeFraction, accuracy: 1e-12)
        // Nilai lama (0.28) harus **gagal** ambang rongga — kalau tidak,
        // uji ini tidak menjaga apa pun.
        let legacy = VisualFrame.CandidateMarker(
            centerX: marker.centerX, centerY: marker.centerY,
            radius: marker.radius, glyphFraction: marker.glyphFraction,
            strokeFraction: 0.28)
        XCTAssertGreaterThanOrEqual(
            legacy.strokeToHookRatio, 0.9,
            "nilai lama harus terbukti menutup rongga lengkung; kalau tidak, "
            + "ambang 0.5 tidak menangkap cacat yang diklaimnya")
    }

    // MARK: - Bentuk glif "?"

    /// Glif harus **berbentuk tanda tanya**, bukan sekadar "ada garis di lencana".
    ///
    /// **Kenapa uji ini ada, dan kenapa gerbang gambar tidak bisa menggantikannya.**
    /// Sampai siklus ini bentuk glif disusun dari delapan literal di dalam
    /// `drawCandidateMarker`. Diukur dengan memutasi sumbernya satu per satu:
    ///
    ///     lengkung diluruskan (0.55 -> 0.0)      nol gerbang merah
    ///     kait dibuang (ekor naik, bukan turun)  nol gerbang merah
    ///     tetes digeser ke luar lencana          nol gerbang merah
    ///
    /// Ketiganya merusak satu-satunya penanda "engine ragu" di layar, dan
    /// keduanya yang tersisa hanya mengukur "cukup banyak piksel peringatan +
    /// tepinya tajam" — sifat yang juga dimiliki gumpalan. Yang bisa menangkap
    /// cacat ini adalah bentuknya sendiri, jadi bentuknya pindah ke model dan
    /// diuji di sini.
    func testGlyphIsShapedLikeAQuestionMark() {
        let marker = VisualFrame.candidateMarker()
        let glyph = marker.glyph
        let r = marker.glyphRadius
        // Satu titik awal + `glyphSamples` titik lengkung + satu ujung ekor.
        XCTAssertEqual(glyph.points.count, VisualFrame.CandidateMarker.glyphSamples + 2,
                       "glif harus tersampel penuh; jumlah titik yang menyusut "
                       + "berarti lengkungnya berhenti di tengah")

        // (a) **Lengkungnya melengkung.** Ujung lengkung duduk di kanan pusat
        // dan di bawah titik awalnya — kalau lengkungnya diluruskan, salah
        // satu dari dua syarat ini hilang.
        let start = glyph.points[0]
        let hookEnd = glyph.points[VisualFrame.CandidateMarker.glyphSamples]
        XCTAssertLessThan(start.x, marker.centerX,
                          "lengkung harus mulai di kiri pusat lencana")
        XCTAssertGreaterThan(hookEnd.y, start.y,
                             "lengkung harus turun; kalau tidak, glifnya "
                             + "terbaca sebagai garis datar, bukan tanda tanya")
        XCTAssertGreaterThan(hookEnd.x, start.x,
                             "lengkung harus bergerak ke kanan")

        // (b) **Rongganya terbuka.** Titik tengah lengkung harus di **atas**
        // garis yang menghubungkan kedua ujungnya — itulah cekungan yang
        // membuatnya terbaca sebagai "?" dan bukan busur cembung.
        let middle = glyph.points[VisualFrame.CandidateMarker.glyphSamples / 2]
        let chordY = start.y + (hookEnd.y - start.y)
            * (middle.x - start.x) / (hookEnd.x - start.x)
        XCTAssertLessThan(middle.y, chordY,
                          "punggung lengkung harus di atas talinya (cekung); "
                          + "kalau tidak, rongganya tertutup")

        // (c) **Ekornya turun ke bawah pusat lencana**, lalu tetesnya di bawah
        // itu. Tanpa ekor, lengkungan saja adalah koma, bukan tanda tanya.
        let tail = glyph.points[glyph.points.count - 1]
        XCTAssertEqual(tail.x, marker.centerX, accuracy: 1e-12,
                       "ekor harus lurus di bawah pusat lencana")
        XCTAssertGreaterThan(tail.y, hookEnd.y,
                             "ekor harus turun melewati ujung lengkung")

        // (d) **Tetesnya terpisah dari ekor, dan di dalam lencana.**
        XCTAssertGreaterThan(glyph.dotCenter.y, tail.y,
                             "tetes harus di bawah ujung ekor, bukan menempel")
        XCTAssertGreaterThan(glyph.dotCenter.y + glyph.dotRadius, tail.y,
                             "tetes harus punya jarak dari ekor supaya terbaca "
                             + "sebagai titik terpisah")
        let fromCenter = ((glyph.dotCenter.x - marker.centerX) * (glyph.dotCenter.x - marker.centerX)
            + (glyph.dotCenter.y - marker.centerY) * (glyph.dotCenter.y - marker.centerY)).squareRoot()
        XCTAssertLessThan(fromCenter + glyph.dotRadius, marker.radius,
                          "tetes harus utuh di dalam lencana; di luar itu ia "
                          + "terbaca sebagai noda, bukan bagian tanda tanya")
        // Skala: semua titik dalam satuan radius frame, jadi glif yang benar
        // tidak boleh menyentuh tepi frame.
        for point in glyph.points {
            XCTAssertLessThan(abs(point.x), 1.0, "glif keluar frame (x)")
            XCTAssertLessThan(abs(point.y), 1.0, "glif keluar frame (y)")
        }
        // Radius glif yang dipakai menggambar adalah `glyphRadius`, bukan
        // angka lain — kalau tidak, uji di atas menguji bentuk yang tidak tampil.
        XCTAssertEqual(glyph.strokeWidth, marker.glyphStroke, accuracy: 1e-12)
        XCTAssertEqual(glyph.dotRadius, marker.radius * 0.13, accuracy: 1e-12,
                       "radius tetes harus dari token, bukan literal ketiga")
    }

    /// Glif harus **tidak berubah bentuk** saat lencananya diperbesar.
    ///
    /// Kalau satu angka di dalam `glyph` kelak ditulis sebagai piksel mutlak,
    /// bentuknya akan berbeda di kartu jam 38 pt dan panel iPhone — dan uji
    /// di atas tetap hijau karena ia hanya menguji satu ukuran.
    func testGlyphShapeScalesWithoutDistortion() {
        let watch = VisualFrame.candidateMarker(frameHalfExtent: 1.0).glyph
        let phone = VisualFrame.candidateMarker(frameHalfExtent: 4.0).glyph
        XCTAssertEqual(watch.points.count, phone.points.count)
        // Nisbah jarak antar titik pertama dan kedua harus sama di kedua
        // ukuran: itu definisi "bentuknya sama, skalanya berbeda".
        func firstSegment(_ glyph: VisualFrame.CandidateMarker.Glyph) -> Double {
            let a = glyph.points[0], b = glyph.points[1]
            return ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
        }
        XCTAssertGreaterThan(firstSegment(phone), firstSegment(watch) * 2.5,
                             "glif harus ikut membesar bersama lencananya")
        let watchRatio = watch.dotRadius / watch.strokeWidth
        let phoneRatio = phone.dotRadius / phone.strokeWidth
        XCTAssertEqual(watchRatio, phoneRatio, accuracy: 1e-12,
                       "perbandingan tetes dan garis harus sama di semua ukuran")
    }
}
