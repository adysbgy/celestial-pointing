import XCTest
@testable import PointingKit

/// Menguji **klaim** yang dibuat brief UX: kontras teks ≥ 4.5:1 (WCAG AA).
///
/// Uji kontras yang tidak pernah merah bukan bukti apa pun — ia hanya
/// membuktikan bahwa angka yang sudah benar tetap benar. Karena itu satu uji di
/// sini sengaja dipatok **melebihi** ambang WCAG dengan alasan yang tercatat:
/// secondary yang pas di 4.5:1 tepat di batas akan terlihat redup di layar jam
/// yang sangat redup, dan batas itu tidak memperhitungkan keterbacaan di bawah
/// kondisi penglihatan yang justru jadi use case utama produk ini.
final class SurfacePaletteTests: XCTestCase {

    // MARK: - Kebenaran perhitungan

    func testContrastRatioIsSymmetricAndBounded() {
        let a = SurfaceColor(red: 0.1, green: 0.1, blue: 0.1)
        let b = SurfaceColor(red: 0.9, green: 0.9, blue: 0.9)
        XCTAssertEqual(a.contrastRatio(against: b),
                       b.contrastRatio(against: a), accuracy: 1e-12)
        // Putih di atas hitam = 21:1, nilai tertinggi WCAG.
        XCTAssertEqual(SurfaceColor(red: 1, green: 1, blue: 1)
                        .contrastRatio(against: SurfaceColor(red: 0, green: 0, blue: 0)),
                       21, accuracy: 1e-9)
        // Warna yang sama dengan dirinya sendiri = 1:1, tidak boleh nol atau
        // negatif (kelekuan float bisa membuat pembagiannya tidak stabil).
        XCTAssertEqual(a.contrastRatio(against: a), 1, accuracy: 1e-12)
    }

    /// Menahan regresi ke "luminance rata-rata".
    ///
    /// Abu tengah 0.5 sRGB punya kecerahan relatif ~0.214, bukan ~0.5. Kalau
    /// transfer non-linier dihilangkan, luminance-nya jadi 0.5 dan rasio
    /// kontras terhadap hitam terhitung 10.4:1 — padahal benar-benar hanya
    /// 4.6:1. Kesalahan 2.2× itu cukup untuk membuat teks 8pt lolos ambang
    /// WCAG padahal di layar ia nyaris tak terbaca. Ini persis kesalahan yang
    /// paling mungkin dibuat, jadi ia dipatok di sini.
    func testLuminanceAppliesNonLinearTransferNotAverage() {
        let midGrey = SurfaceColor(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(midGrey.relativeLuminance, 0.2140, accuracy: 0.001)
        XCTAssertLessThan(midGrey.relativeLuminance, 0.5)
    }

    // MARK: - Klaim yang dibuat brief

    func testDayPaletteMeetsWCAGAAOnEverySurfaceItSitsOn() {
        XCTAssertGreaterThanOrEqual(
            SurfacePalette.day.weakestTextContrast,
            SurfacePalette.minimumTextContrast,
            "Teks harian harus terbaca di latar, kartu, dan kartu tingkat dua")
    }

    func testNightPaletteMeetsWCAGAAOnEverySurfaceItSitsOn() {
        XCTAssertGreaterThanOrEqual(
            SurfacePalette.night.weakestTextContrast,
            SurfacePalette.minimumTextContrast,
            "Teks mode malam harus terbaca di latar, kartu, dan kartu tingkat dua")
    }

    /// Mode malam **tidak boleh** hanya "cukup kontras" — ia juga tidak boleh
    /// menyiarkan hijau/biru sedikit pun, karena itu justru bagian yang
    /// membatalkan alasan mode malam ada.
    func testNightPaletteContainsNoGreenOrBlueAtAll() {
        let night = SurfacePalette.night
        let all: [SurfaceColor] = [
            night.background, night.surface1, night.surface2,
            night.textPrimary, night.textSecondary,
            night.accentStart, night.accentEnd,
        ]
        for color in all {
            XCTAssertEqual(color.green, 0, " hijau harus nol, bukan diredupkan")
            XCTAssertEqual(color.blue, 0, " biru harus nol, bukan diredupkan")
        }
    }

    // MARK: - Surface stepping

    func testSurfaceSteppingGoesDeeperToNearer() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let steps = palette.surfaceSteps
            XCTAssertGreaterThan(steps.backgroundTo1, 0,
                "\(name): kartu harus lebih terang dari latar")
            XCTAssertGreaterThan(steps.surface1To2, 0,
                "\(name): lapisan ketiga harus lebih terang dari kartu")
        }
    }

    /// Di kanvas gelap, bayangan tidak terlihat — kedalaman hanya bisa datang
    /// dari perbedaan kecerahan. Kalau langkah-langkahnya sekecil itu, kartu dan
    /// latar praktis satu bidang.
    func testSurfaceSteppingIsBigEnoughToSeeInTheDark() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let steps = palette.surfaceSteps
            XCTAssertGreaterThan(steps.backgroundTo1, SurfacePalette.minimumVisibleSurfaceStep,
                "\(name): selisih kecerahan kartu-latar terlalu tipis untuk terlihat")
            XCTAssertGreaterThan(steps.surface1To2, SurfacePalette.minimumVisibleSurfaceStep,
                "\(name): selisih kecerahan lapisan ketiga-kartu terlalu tipis")
        }
    }

    /// **Komposisi alpha benar-benar dihitung, bukan dikira-kira.**
    ///
    /// Operasi ini punya satu bentuk yang paling mudah salah: menganggap
    /// `alpha` di atas latar **terang** sama dengan `alpha` di atas latar
    /// **gelap**. Yang benar adalah campuran linier, dan karena kontras
    /// bergantung pada latar, dua hasilnya bisa berbeda jauh.
    ///
    /// Uji ini menahan bentuk salah itu di sumbernya, karena `composited` akan
    /// dipakai untuk membuktikan cacat nyata di bawah — kalau operasinya
    /// sendiri salah, bukti itu tidak berarti apa-apa.
    func testCompositingIsLinearAndDependsOnTheBackdrop() {
        let tone = SurfaceColor(red: 0.94, green: 0.47, blue: 0.27)
        let dark = SurfaceColor(red: 0.039, green: 0.039, blue: 0.059)
        let light = SurfaceColor(red: 0.9, green: 0.9, blue: 0.9)

        let overDark = tone.composited(over: dark, alpha: 0.12)
        XCTAssertEqual(overDark.red, 0.12 * 0.94 + 0.88 * 0.039, accuracy: 1e-12)
        XCTAssertEqual(overDark.green, 0.12 * 0.47 + 0.88 * 0.039, accuracy: 1e-12)

        // Latar mengubah hasilnya — inilah kenapa warna ini tidak boleh
        // "dikira" tanpa menghitung latarnya.
        let overLight = tone.composited(over: light, alpha: 0.12)
        XCTAssertGreaterThan(overLight.red, overDark.red)
        XCTAssertNotEqual(overLight, overDark)

        // Alpha penuh = warnanya sendiri; alpha nol = latarnya sendiri.
        XCTAssertEqual(tone.composited(over: dark, alpha: 1), tone)
        XCTAssertEqual(tone.composited(over: dark, alpha: 0), dark)
    }

    /// **Regresi: kartu yang membangun latarnya sendiri dari warna nada.**
    ///
    /// Kartu tahap kalibrasi pernah menggambar dirinya dengan
    /// `tone.color.opacity(0.12)` di atas latar, bukan dari token permukaan.
    /// Di mode malam, nada paling redup yang benar-benar dipakai tahap
    /// (`.neutral`, merah 0.94) di atas latar malam menghasilkan merah ~0.152 —
    /// **di atas plafon kontras** mode malam (`surface2 * 1.12` ≈ 0.101), jadi
    /// teksnya yang berwarna nada yang sama jatuh ke **4.32:1**, di bawah
    /// ambang 4.5 yang brief nyatakan.
    ///
    /// Yang diuji di sini bukan angka satu warna, melainkan bahwa **konvensi
    /// itu sendiri keluar dari token**: nada apa pun, di atas latar mode malam,
    /// menghasilkan warna yang tidak ada di palet — sehingga kontrasnya tidak
    /// pernah dijamin. Itu sebabnya perbaikannya mengarah ke `surfaceCard`,
    /// bukan ke nilai alpha yang lebih kecil (yang hanya akan menyembunyikan
    /// cacat yang sama sampai nada berikutnya ditambahkan).
    func testAToneTintedCardBackgroundCannotBeTrustedForContrast() {
        let night = SurfacePalette.night
        let tone = TonePalette.night.neutral
        let tinted = tone.composited(over: night.background, alpha: 0.12)

        // Warnanya bukan permukaan mana pun yang kontrasnya sudah diuji.
        XCTAssertNotEqual(tinted, night.surface1)
        XCTAssertNotEqual(tinted, night.surface2)
        // Dan ia lebih terang dari lapisan terdalam, jadi hierarki permukaan
        // terbalik: kartu paling tidak penting justru paling menyala.
        XCTAssertGreaterThan(tinted.red, night.surface2.red,
            "kartu bernada lebih terang dari lapisan terdalam — hierarki permukaan terbalik")

        // Akibat yang sebenarnya: teks nada itu di atas latarnya sendiri.
        let ratio = tone.contrastRatio(against: tinted)
        XCTAssertLessThan(ratio, SurfacePalette.minimumTextContrast,
            "kalau ini tidak lagi merah, cacatnya sudah tertutup — dan uji ini "
            + "harus diganti, bukan dihapus")
    }

    /// Dan konvensi yang **benar** — `surfaceCard` — memang menahan kontras
    /// untuk seluruh nada, di kedua mode. Ini pasangan positif dari uji di
    /// atas: bukan cuma "yang salah itu salah", tapi "yang benar itu benar".
    func testTheSurfaceTokenPathHoldsContrastForEveryTone() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            for tone in PointingTone.allCases {
                let card = palette.surface1
                let ratio = palette.tones.color(for: tone).contrastRatio(against: card)
                XCTAssertGreaterThanOrEqual(ratio, SurfacePalette.minimumTextContrast,
                    "\(name) \(tone): \(ratio):1 di atas kartu surface1 < 4.5")
            }
        }
    }

    /// Latar **bukan** pure black, dan hari selalu **sejuk** (biru > merah).
    ///
    /// Di OLED, hitam pekat = piksel mati, dan tidak ada gradasi yang bisa
    /// menggambar kedalaman di atasnya. `#0A0A0F` yang disengaja membiarkan
    /// permukaan di atasnya punya sesuatu untuk naik dari. Catatan: mode
    /// malam tidak punya sifat dingin — ia merah murni, jadi tes dingin
    /// ini hanya berlaku di mode siang.
    func testBackgroundIsNotPureBlackAndDayBackgroundIsCool() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(palette.background.red, 0.01,
                "\(name): latar hitam pekat mematikan gradien dan kedalaman")
        }
        let day = SurfacePalette.day
        XCTAssertGreaterThan(day.background.blue, day.background.red,
            "siang: latar harus sedikit ke ungu — warna langit malam, bukan abu netral")
        // Mode malam tetap punya pemisah merah, walau tidak "dingin".
        XCTAssertGreaterThan(SurfacePalette.night.background.red,
                             SurfacePalette.night.background.green,
                             "malam: pemisah merah tidak boleh hilang total")
    }

    // MARK: - Pengetasan yang disengaja, dengan alasannya

    /// Secondary **pada ambang** 4.5:1 akan lolos WCAG, tapi di layar jam yang
    /// sangat redup teks sekunder praktis hilang — dan metadata (RA/Dec/mag)
    /// justru lapisan yang paling sering dikorbankan saat UI dirapatkan. Karena
    /// itu ambang lokal lebih ketat dari WCAG, dan alasannya dicatat supaya
    /// tidak nanti "diperbaiki" balik ke 4.5.
    ///
    /// **Catatan fisika yang menjaga ambang ini tetap bermakna:** mode malam
    /// dibatasi 5.25:1 — merah murni di atas hitam *tidak bisa* lebih terang
    /// dari itu, berapa pun layar itu dinaikkan. Jadi "secondary redup" di mode
    /// malam hanya punya ruang kanal merah 1.00 → ~0.93, dan pengetasan di sini
    /// memakai ruang yang benar-benar tersedia, bukan ruang borongan.
    func testSecondaryTextIsMoreThanBarelyLegible() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(
                palette.textSecondary.contrastRatio(against: palette.surface2),
                SurfacePalette.minimumTextContrast + 0.1,
                "\(name): secondary yang pas di batas WCAG hilang di layar redup")
        }
    }

    /// Menjaga pengetasan di atas tetap punya isi: kalau primary dan secondary
    /// kembar, "secondary" tidak berarti apa-apa dan lapisan petunjuk hilang.
    ///
    /// Yang diuji adalah **perbedaan nyata**, bukan "harus berbeda" yang longgar.
    /// Dan untuk mode malam, perbedaannya diuji dalam kanal yang benar: warna
    /// merah murni dengan hijau/biru nol tidak bisa dibandingkan lewat
    /// luminance penuh tanpa membuat setiap pasangan tampak hampir identik.
    func testSecondaryIsActuallyDistinguishableFromPrimary() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let drop = palette.textPrimary.red - palette.textSecondary.red
            XCTAssertGreaterThan(drop, 0.04,
                "\(name): secondary tidak bisa dibedakan dari primary")
        }
    }

    /// Kontras mode malam memang dibatasi 5.25:1. Ini bukan cacat — itu
    /// konsekuensi fisik dari "merah murni", dan mencatatnya sebagai batas
    /// hampir penting: tanpa itu, orang yang menyukainya akan menaikkan
    /// primary dan menurunkan secondary ke abu pucat demi "kontras", lalu
    /// membatalkan seluruh alasan mode malam ada.
    func testNightModeContrastCeilingIsKnownAndBounded() {
        let ceiling = SurfaceColor(red: 1, green: 0, blue: 0)
            .contrastRatio(against: SurfaceColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(ceiling, 5.252, accuracy: 0.01,
                       "plafon kontras merah murni di atas hitam harus tetap dalam yang tercatat")
        XCTAssertGreaterThan(SurfacePalette.night.weakestTextContrast, 4.5)
    }

    // MARK: - Latar yang benar-benar digambar

    /// **Regresi: kontras diuji terhadap warna yang tidak pernah muncul di
    /// layar.**
    ///
    /// Latar app bukan `background` datar. Ia gradien dari `surface2` yang
    /// diredupkan di atas `background` — dan gradien itu digambar di balik
    /// **segalanya**, termasuk di belakang kartu. Karena itu satu-satunya
    /// latar yang kartu pernah bertemu bukan `background`, melainkan campuran
    /// di puncak gradien itu.
    ///
    /// Seluruh klaim WCAG di berkas ini dihitung terhadap `background`,
    /// `surface1`, dan `surface2` — tiga warna token. Campuran gradiennya
    /// tidak pernah masuk ke himpunan itu, jadi langkah kartu-latar bisa
    /// menyusut di bawah ambang "terlihat di gelap" tanpa satu pun uji yang
    /// merah. Diukur pada alpha 0.55 (nilai lama): siang **0.0137**, malam
    /// **0.0018**, terhadap ambang 0.02 — malam praktis satu bidang, dan itu
    /// tepat mode yang dipakai di gelap, tempat ambang ini ada untuk bekerja.
    ///
    /// Uji ini menahan alpha atmosfer dari **model**, bukan dari view: view
    /// tidak bisa dijalankan di Linux, jadi angka yang tidak punya nama di
    /// model adalah angka yang tidak bisa dijaga siapa pun.
    func testThePaintedBackdropStillLeavesTheCardAVisibleStep() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            let step = SurfacePalette.largestChannelGap(from: backdrop, to: palette.surface1)
            XCTAssertGreaterThan(step, SurfacePalette.minimumCardLadderMargin,
                "\(name): kartu tenggelam ke latar gradien (\(step) ≤ "
                + "\(SurfacePalette.minimumCardLadderMargin)) — kedalaman hilang tepat di "
                + "mode yang dipakai di gelap")
        }
    }

    /// Arah kedua dari uji di atas: gradien latar **tidak boleh mati**.
    ///
    /// Menurunkan alpha sampai nol akan membuat uji sebelumnya hijau tanpa
    /// memperbaiki apa pun — kartunya memang lebih terang dari latar datar,
    /// tapi atmosfernya hilang dan rasa premium yang dibeli brief ikut hilang.
    /// Jadi lantainya diuji juga, bukan hanya langit-langitnya.
    ///
    /// Lantainya **satu langkah kuantisasi sRGB**, bukan ambang "langkah
    /// permukaan" yang lebih besar: gradien latar tidak dimaksudkan untuk
    /// dibaca sebagai lapisan, hanya untuk terasa. Yang bisa diklaim tanpa
    /// mengarang ambang baru adalah bahwa puncaknya jatuh di kuantisasi yang
    /// berbeda dari latar — di bawah itu, ia secara literal warna latar.
    func testTheBackdropStillHasAtmosphere() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            let atmosphere = SurfacePalette.largestChannelGap(
                from: palette.background, to: backdrop)
            XCTAssertGreaterThanOrEqual(atmosphere, SurfacePalette.minimumBackdropAtmosphere,
                "\(name): gradien latar jatuh di bawah satu langkah kuantisasi "
                + "(\(atmosphere) < \(SurfacePalette.minimumBackdropAtmosphere)) — menghapusnya "
                + "adalah cara termudah membuat uji langkah kartu hijau")
        }
    }

    /// Gradien latar bukan permukaan kartu: kalau puncaknya **lebih terang**
    /// dari kartu, hierarki terbalik — latar paling belakang justru paling
    /// menyala, dan "makin dekat ke pengguna makin terang" berhenti benar.
    func testTheBackdropNeverOutshinesTheCards() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            let backdrop = palette.backdrop(
                atmosphereAlpha: SurfacePalette.backdropAtmosphereAlpha)
            XCTAssertLessThan(backdrop.red, palette.surface1.red,
                "\(name): puncak latar lebih terang dari kartu — hierarki permukaan terbalik")
        }
    }

    /// Aksen boleh lebih vibrant dari teks, tapi harus tetap bisa
    /// dibedakan dari permukaannya — kalau aksen kontrasnya sama dengan
    /// permukaan, elemen "aktif" jadi tidak terlihat aktif.
    func testAccentStandsOutFromTheBackground() {
        for (name, palette) in [("siang", SurfacePalette.day), ("malam", SurfacePalette.night)] {
            XCTAssertGreaterThan(
                palette.accentEnd.contrastRatio(against: palette.background),
                2.0,
                "\(name): aksen tidak terlihat di atas latar")
            XCTAssertGreaterThan(
                palette.accentEnd.contrastRatio(against: palette.surface2),
                2.0,
                "\(name): aksen tidak terlihat di atas kartu")
        }
    }

    // MARK: - Pemilih palet aktif (keadaan saklar → palet)

    /// Keadaan saklar harus memetakan ke palet yang **sepakat** dengan
    /// keadaannya sendiri, bukan sekadar "memilih sesuatu".
    ///
    /// Ini mengunci kecacatan yang dulu buta di `Apps/`: badan
    /// `SurfacePalette.active` memilih palet untuk 26 situs (latar, kartu,
    /// teks, aksen, garis rambut, nada, badge, layar redup), hidup di
    /// `Apps/` yang tidak pernah dibangun `swift-test.sh`, dan keempat
    /// mutasinya — `.day`, `.night`, saklar dibalik, acak — **semuanya**
    /// lolos ke-44 aturan UI. Mutasi paling sunyi (`return .day`) membuat
    /// mode malam memancarkan biru & hijau penuh sementara tombol bulan
    /// menyala, merusak adaptasi gelap rod 20–40 menit tanpa satu pun
    /// teks di layar yang membantahnya.
    func testTheSelectedPaletteAgreesWithItsOwnNightClaim() {
        for enabled in [false, true] {
            let palette = NightPaletteSelector.palette(isNightModeEnabled: enabled)
            XCTAssertEqual(
                NightPaletteSelector.isNight(palette), enabled,
                "palet terpilih untuk saklar \(enabled ? "nyala" : "mati") " +
                "tidak sepakat dengan klaim malamnya sendiri")
        }
    }

    /// Palet siang salah dipilih saat saklar mati, dan sebaliknya — kedua
    /// arah, supaya uji tidak lulus cuma karena "selalu malam" juga sepakat.
    func testDayAndNightAreEachSelectedOnlyWhenTheirSwitchSaysSo() {
        XCTAssertFalse(NightPaletteSelector.isNight(
            NightPaletteSelector.palette(isNightModeEnabled: false)),
            "saklar mati mengembalikan palet malam")
        XCTAssertTrue(NightPaletteSelector.isNight(
            NightPaletteSelector.palette(isNightModeEnabled: true)),
            "saklar nyala mengembalikan palet siang")
    }

    // MARK: - Token kepekatan garis rambut & lapisan atas

    /// Garis rambut mode malam **wajib** lebih pekat dari siang.
    ///
    /// Ini bukan selera: di palet malam kanal hijau dan biru adalah nol,
    /// jadi satu-satunya kanal yang bisa membedakan garis dari permukaan di
    /// belakangnya adalah merah. Dengan kepekatan siang, garis itu jatuh di
    /// bawah satu langkah kuantisasi sRGB dan berhenti menjadi batas.
    ///
    /// Uji ini menahan dua angka yang dulu hidup sebagai literal di
    /// `Apps/Shared/SurfaceTokens.swift` — lapisan yang tidak pernah dibangun
    /// `swift-test.sh`, sehingga mengganti keduanya tidak memerahkan apa pun.
    func testHairlineIsMoreVisibleInNightModeThanInDayMode() {
        XCTAssertGreaterThan(SurfacePalette.hairlineNightOpacity,
                             SurfacePalette.hairlineDayOpacity,
                             "garis rambut malam harus lebih pekat dari siang")

        // Keduanya harus benar-benar terlihat terhadap kartu yang sama, dan
        // tidak boleh jadi garis penuh (yang akan terbaca sebagai elemen
        // sendiri, bukan pemisah tipis).
        for alpha in [SurfacePalette.hairlineNightOpacity,
                      SurfacePalette.hairlineDayOpacity] {
            XCTAssertGreaterThan(alpha, 0.0, "garis rambut tak terlihat")
            XCTAssertLessThan(alpha, 1.0, "garis rambut jadi elemen, bukan pemisah")
        }
    }

    /// Pemilihan kepekatan garis rambut membaca **isi paletnya**, bukan
    /// saklar yang menghasilkannya: kalau keduanya bisa berbeda pendapat,
    /// layar bisa menggambar garis mode siang di atas palet malam.
    func testHairlineOpacityFollowsThePaletteNotTheSwitch() {
        XCTAssertEqual(
            SurfacePalette.hairlineOpacity(for: NightPaletteSelector.palette(isNightModeEnabled: true)),
            SurfacePalette.hairlineNightOpacity)
        XCTAssertEqual(
            SurfacePalette.hairlineOpacity(for: NightPaletteSelector.palette(isNightModeEnabled: false)),
            SurfacePalette.hairlineDayOpacity)
    }

    /// Lapisan `overlay` harus tetap terbaca satu tingkat di atas kartu,
    /// tetapi teks sekunder di atasnya tetap memenuhi WCAG AA 4.5:1.
    ///
    /// Yang dihitung adalah warna **hasil komposisi**, bukan `surface2`
    /// murni: itulah warna yang benar-benar digambar, dan yang tidak diukur
    /// selama angka 0.92 ditulis sebagai literal di `Apps/`.
    func testOverlayLayerKeepsSecondaryTextReadableInBothModes() {
        for enabled in [false, true] {
            let palette = NightPaletteSelector.palette(isNightModeEnabled: enabled)
            let composited = palette.surface2.composited(
                over: palette.surface1, alpha: SurfacePalette.overlaySurfaceOpacity)
            let contrast = palette.textSecondary.contrastRatio(against: composited)
            XCTAssertGreaterThanOrEqual(
                contrast, SurfacePalette.minimumTextContrast,
                "teks sekunder di atas lapisan overlay mode "
                + (enabled ? "malam" : "siang")
                + " hanya \(contrast):1, di bawah ambang "
                + "\(SurfacePalette.minimumTextContrast):1")
        }
    }

    /// Angka 0.92 bukan hiasan: ia harus **kurang dari 1** (lapisan harus
    /// benar-benar mencampur) dan cukup dekat untuk masih terasa satu
    /// keluarga dengan `surface2`.
    func testOverlayOpacityActuallyBlendsTowardTheCardBelow() {
        XCTAssertGreaterThan(SurfacePalette.overlaySurfaceOpacity, 0.0)
        XCTAssertLessThan(SurfacePalette.overlaySurfaceOpacity, 1.0,
                          "opasitas 1 berarti lapisan overlay identik dengan surface2")
        let palette = SurfacePalette.day
        let composited = palette.surface2.composited(
            over: palette.surface1, alpha: SurfacePalette.overlaySurfaceOpacity)
        // Hasil campuran harus di antara kedua permukaan — itu yang membuat
        // lapisan ini "satu tingkat di atas kartu", bukan permukaan ketiga.
        XCTAssertGreaterThan(
            SurfacePalette.largestChannelGap(from: palette.surface1, to: composited), 0.0,
            "lapisan overlay jatuh persis di permukaan kartunya sendiri")
        XCTAssertLessThan(
            SurfacePalette.largestChannelGap(from: palette.surface2, to: composited), 0.01,
            "lapisan overlay tidak komposisi, bahkan identik dengan surface2")
    }

    // MARK: - Kilau kaca: kilau yang tidak boleh membatalkan mode malam

    /// **Regresi: kilau kaca membocorkan biru & hijau ke mode malam.**
    ///
    /// `surfaceCard` menaruh `.ultraThinMaterial.opacity(0.10)` di atas alas
    /// token. Material di atas permukaan gelap menghasilkan lapisan **terang**,
    /// dan karena ia berada di lapis paling depan, ia mencampur ke kanal hijau
    /// dan biru kartu. Diukur pada kepekatan 0.10: kanal yang seharusnya
    /// `0.000` naik ke `0.042`.
    ///
    /// Yang dikorbankan bukan estetika. Seluruh alasan mode malam ada adalah
    /// menjaga rhodopsin: rod paling sensitif ~498–530nm, jadi hijau dan biru
    /// harus **nol**, bukan redup. Satu lapisan hiasan di atas setiap kartu
    /// membatalkan itu di seluruh app sekaligus, dan tidak ada teks di layar
    /// yang bisa membuat pengguna curiga bahwa mode malamnya bocor.
    ///
    /// Uji ini memakai **batas atas**, bukan sampel: `.ultraThinMaterial`
    /// tidak bisa dirender di Linux, jadi yang dihitung adalah kasus terburuk
    /// (material = putih penuh). Kalau batas atasnya nol, material apa pun
    /// aman — itu satu-satunya bentuk klaim yang jujur di sini.
    func testGlassSheenNeverLeaksGreenOrBlueIntoNightMode() {
        let night = SurfacePalette.night
        let alpha = SurfacePalette.glassSheenAlpha(for: night)
        XCTAssertEqual(alpha, 0,
            "mode malam masih memasang kilau kaca pada kepekatan \(alpha); "
            + "setiap kepekatan > 0 membocorkan kanal 498–530nm")

        // Batas atas: material putih penuh pada kepekatan itu di atas kartu.
        let worstCase = SurfaceColor(red: 1, green: 1, blue: 1)
            .composited(over: night.surface1, alpha: alpha)
        XCTAssertEqual(worstCase.green, 0, accuracy: 1e-12,
            "kanal hijau kartu mode malam bukan nol")
        XCTAssertEqual(worstCase.blue, 0, accuracy: 1e-12,
            "kanal biru kartu mode malam bukan nol")
    }

    /// **Regresi: kilau kaca menjatuhkan kontras teks malam di bawah 4.5:1.**
    ///
    /// Ini kerusakan yang **berbeda** dari kebocoran kanal di atas, dan
    /// keduanya datang dari angka yang sama. Diukur pada kepekatan lama 0.10:
    /// `textPrimary` 5.13 → 4.35 dan `textSecondary` 4.67 → 3.99, keduanya di
    /// bawah ambang yang brief nyatakan.
    ///
    /// Kenapa ini penting justru di mode malam: merah murni di atas hitam
    /// hanya punya plafon 5.25:1 (fisika, bukan selera), jadi seluruh anggaran
    /// kontras mode malam sudah terpakai sebelum hiasan apa pun. Tidak ada
    /// "kurangi sedikit" yang menyelamatkan — satu-satunya angka yang aman
    /// adalah nol, dan itulah yang dikunci di sini.
    ///
    /// Diukur sebagai batas atas (material = putih penuh), sama seperti uji
    /// kebocoran: nilai sebenarnya di perangkat tidak pernah lebih buruk.
    func testGlassSheenKeepsNightTextAboveTheContrastFloor() {
        let night = SurfacePalette.night
        let alpha = SurfacePalette.glassSheenAlpha(for: night)
        let white = SurfaceColor(red: 1, green: 1, blue: 1)

        let card = white.composited(over: night.surface1, alpha: alpha)
        for (name, text) in [("utama", night.textPrimary),
                             ("sekunder", night.textSecondary)] {
            let ratio = text.contrastRatio(against: card)
            XCTAssertGreaterThanOrEqual(
                ratio, SurfacePalette.minimumTextContrast,
                "teks \(name) mode malam di atas kartu berkilau hanya \(ratio):1, "
                + "di bawah ambang \(SurfacePalette.minimumTextContrast):1")
        }
    }

    /// Dan pasangan positifnya: di mode siang kilau itu **memang ada**, dan
    /// tetap menahan kontras. Tanpa uji ini, "perbaikan" yang menghapus kilau
    /// dari kedua mode akan lolos — padahal brief memintanya, dan siang punya
    /// anggaran kontras yang cukup (16.96:1) untuk membayarnya.
    func testGlassSheenStillExistsInDayModeAndKeepsContrast() {
        let day = SurfacePalette.day
        let alpha = SurfacePalette.glassSheenAlpha(for: day)
        XCTAssertGreaterThan(alpha, 0,
            "kilau kaca hilang juga di mode siang — brief memintanya, dan siang "
            + "punya anggaran kontras untuk membayarnya")
        XCTAssertLessThanOrEqual(alpha, 0.25,
            "kilau \(alpha) terlalu pekat: ia mulai menggeser warna permukaan, "
            + "bukan lagi sekadar kilau")

        // Batas atas yang sama, dan **teks sekunder** yang menentukan — ia
        // yang paling dekat ke ambang.
        let white = SurfaceColor(red: 1, green: 1, blue: 1)
        let card = white.composited(over: day.surface1, alpha: alpha)
        for (name, text) in [("utama", day.textPrimary),
                             ("sekunder", day.textSecondary)] {
            let ratio = text.contrastRatio(against: card)
            XCTAssertGreaterThanOrEqual(
                ratio, SurfacePalette.minimumTextContrast,
                "teks \(name) mode siang di atas kartu berkilau hanya \(ratio):1")
        }
    }

    /// Kilau dipilih dari **isi** palet, bukan dari saklar yang menghasilkannya.
    ///
    /// Sama kelasnya dengan `hairlineOpacity`: dua jalur yang bisa berbeda
    /// pendapat tentang "ini mode malam?" adalah dua jalur yang suatu hari
    /// akan berbeda. Di sini yang diuji adalah pemilihnya benar-benar membaca
    /// palet — memanggilnya dengan palet malam dan palet siang harus memberi
    /// dua angka berbeda, dan angka malam harus nol.
    func testGlassSheenIsChosenFromThePaletteNotFromASwitch() {
        XCTAssertEqual(SurfacePalette.glassSheenAlpha(for: .night),
                       SurfacePalette.glassSheenNightAlpha)
        XCTAssertEqual(SurfacePalette.glassSheenAlpha(for: .day),
                       SurfacePalette.glassSheenDayAlpha)
        XCTAssertNotEqual(SurfacePalette.glassSheenAlpha(for: .night),
                          SurfacePalette.glassSheenAlpha(for: .day),
                          "kedua mode memakai kepekatan kilau yang sama: pemilihnya "
                          + "tidak membaca palet")
    }

    // MARK: - Teks di atas aksen

    /// Label tombol utama harus terbaca di atas **aksen**, bukan di atas kartu.
    ///
    /// **Cacat yang dijaga.** `.borderedProminent` menint latarnya dengan
    /// `accentGradient`, jadi labelnya tidak pernah duduk di `surface1`.
    /// Tidak ada token untuk teks-di-atas-aksen, jadi labelnya jatuh ke
    /// `.primary` — putih. Terukur: putih 3.70:1 di atas aksen biru dan
    /// 4.12:1 di atas aksen ungu, keduanya **di bawah** 4.5:1; di mode malam
    /// 4.00:1, juga di bawah. Label tombol terpenting app ini karena itu tidak
    /// pernah lolos WCAG, dan tidak ada gerbang yang berbunyi — karena seluruh
    /// uji kontras yang ada membandingkan teks dengan **permukaan**.
    ///
    /// Uji ini mengukur ketiga ujung yang benar-benar dipakai (biru siang,
    /// ungu siang, merah malam). Kalau aksen digeser lebih terang, ia merah.
    func testOnAccentTextIsReadableOnEveryAccentItSitsOn() {
        for (nama, palet) in [("siang", SurfacePalette.day),
                              ("malam", SurfacePalette.night)] {
            for (ujung, aksen) in [("awal", palet.accentStart),
                                   ("akhir", palet.accentEnd)] {
                let rasio = palet.onAccent.contrastRatio(against: aksen)
                XCTAssertGreaterThanOrEqual(
                    rasio, SurfacePalette.minimumTextContrast,
                    "label tombol mode \(nama) di atas aksen \(ujung) hanya "
                    + "\(rasio):1 — di bawah ambang \(SurfacePalette.minimumTextContrast)")
            }
        }
    }

    /// Putih **bukan** jawabannya, dan uji ini mengunci alasannya.
    ///
    /// Kalau seseorang "memperbaiki" label tombol dengan `.white`, uji di atas
    /// akan merah — tetapi pesannya akan terbaca seperti salah pilih warna.
    /// Yang sebenarnya terjadi: putih di atas aksen produk ini **memang tidak
    /// lolos**, di kedua mode. Uji ini menahan kesimpulan itu supaya
    /// perbaikannya tidak dibalik menjadi "putih sedikit lebih redup".
    func testWhiteOnAccentFailsSoTheTokenCannotBeWhite() {
        let putih = SurfaceColor(red: 1, green: 1, blue: 1)
        for (nama, palet) in [("siang", SurfacePalette.day),
                              ("malam", SurfacePalette.night)] {
            for (ujung, aksen) in [("awal", palet.accentStart),
                                   ("akhir", palet.accentEnd)] {
                XCTAssertLessThan(
                    putih.contrastRatio(against: aksen),
                    SurfacePalette.minimumTextContrast,
                    "putih di atas aksen \(ujung) mode \(nama) tiba-tiba lolos: "
                    + "kalau aksennya berubah, token `onAccent` harus ditinjau ulang, "
                    + "bukan uji ini yang dilonggarkan")
            }
        }
    }

    /// Di mode malam, teks-di-atas-aksen tidak boleh membocorkan hijau/biru.
    ///
    /// Seluruh alasan mode malam adalah kanal 498–530nm ditekan ke nol. Satu
    /// label putih di tengah layar merah adalah tepat piksel yang merusak
    /// adaptasi gelap yang seluruh palet ini ada untuk menjaganya.
    func testOnAccentTextInNightModeEmitsNoGreenOrBlue() {
        XCTAssertEqual(SurfacePalette.night.onAccent.green, 0,
                       "teks di atas aksen mode malam memancarkan hijau")
        XCTAssertEqual(SurfacePalette.night.onAccent.blue, 0,
                       "teks di atas aksen mode malam memancarkan biru")
    }
}