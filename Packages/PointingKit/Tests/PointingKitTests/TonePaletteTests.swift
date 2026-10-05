import XCTest
@testable import PointingKit

/// Menguji **warna nada** (label keadaan, badge keyakinan, ikon kalibrasi)
/// memenuhi kontras WCAG — sama ketatnya dengan teks permukaan.
///
/// Warna nada dulunya hidup di `Apps/Shared/NightMode.swift` sebagai daftar
/// warna yang ditulis manual, dan **lolos dari gate** karena uji
/// `PointingPresentationTests` hanya memeriksa enum `tone`, bukan keluarannya
/// sebagai warna. Akibatnya mode malam mengirimkan `red 0.50 / 0.62 / 0.80`,
/// yang masing-masing **di bawah 4.5:1** — tiga dari lima nada tidak terbaca
/// sebagai teks justru di mode yang dipilih supaya penglihatan malam terjaga.
/// File ini menutup celah itu: sekarang warna nada punya gerbang sendiri,
/// sejajar dengan `SurfacePaletteTests`.
final class TonePaletteTests: XCTestCase {

    // MARK: - Kebenaran perhitungan warna nada

    /// Warna nada **bukan** warna sistem yang bergerak antar OS.
    ///
    /// Kalau `TonePalette` memanggil `.cyan` / `.green` / ..., nilainya bisa
    /// bergeser di iOS/watchOS berikutnya **tanpa satu uji pun menyentuhnya**,
    /// dan gerbang kontras di bawah menjadi bodong. Jadi kita menuntut warna
    /// nada terdiri dari `SurfaceColor` buatan sendiri.
    func testDayTonesArePinnedColorsNotSystemColors() {
        let tones = TonePalette.day
        // Cukup memastikan mereka bukan warna sistem: warna sistem di sini
        // diwakili oleh Color, bukan SurfaceColor. Keberadaan SurfaceColor
        // (struct PointingKit sendiri) adalah bukti bahwa nilai dipin.
        XCTAssertEqual(tones.neutral, SurfaceColor(red: 0.784, green: 0.800, blue: 0.835))
        XCTAssertEqual(tones.active, SurfaceColor(red: 0.310, green: 0.780, blue: 0.900))
        XCTAssertEqual(tones.success, SurfaceColor(red: 0.290, green: 0.830, blue: 0.470))
        XCTAssertEqual(tones.warning, SurfaceColor(red: 0.960, green: 0.700, blue: 0.290))
        XCTAssertEqual(tones.danger, SurfaceColor(red: 1.000, green: 0.420, blue: 0.420))
    }

    /// Mode malam **harus** merah murni: hijau dan biru nol di semua nada.
    ///
    /// Ini bukan rasa — ini syarat fisik mode malam. Kalau nada membiarkan
    /// sedikit hijau/biru, cacat yang sama yang pernah ada di permukaan
    /// (sebelum `testNightPaletteContainsNoGreenOrBlueAtAll`) muncul kembali
    /// lewat jalur warna nada.
    func testNightTonesContainNoGreenOrBlue() {
        for tone in PointingTone.allCases {
            let c = TonePalette.night.color(for: tone)
            XCTAssertEqual(c.green, 0, "\(tone) malam: hijau harus nol")
            XCTAssertEqual(c.blue, 0, "\(tone) malam: biru harus nol")
        }
    }

    /// Urutan kecerahan nada malam **tidak boleh berbalik** (setiap nada
    /// se-terang atau lebih terang dari yang sebelumnya). Di mode malam
    /// selisihnya praktis tak terlihat (lihat komentar palet), tapi kalau
    /// urutannya pernah dibalik tanpa sengaja, maknanya berubah diam-diam.
    func testNightToneBrightnessOrderingIsNonDecreasing() {
        let reds: [Double] = PointingTone.allCases.map {
            TonePalette.night.color(for: $0).red
        }
        // Tiap nada harus setidaknya se-terang nada sebelumnya.
        for i in 1..<reds.count {
            XCTAssertGreaterThanOrEqual(reds[i], reds[i - 1] - 1e-9,
                "urutan kecerahan nada malam tidak boleh berbalik")
        }
    }

    // MARK: - Klaim WCAG: teks nada

    /// Semua nada siang ≥ 4.5:1 terhadap **setiap** permukaan yang mungkin
    /// ditimpanya — latar, kartu, dan kartu tingkat dua. Kasus terburuk adalah
    /// permukaan paling terang (`surface2`).
    func testDayTonesMeetWCAGAAAgainstEverySurface() {
        let palette = SurfacePalette.day
        let surfaces = [palette.background, palette.surface1, palette.surface2]
        for tone in PointingTone.allCases {
            let color = palette.tones.color(for: tone)
            for surface in surfaces {
                let ratio = color.contrastRatio(against: surface)
                XCTAssertGreaterThanOrEqual(ratio, 4.5,
                    "siang \(tone): \(ratio):1 terhadap permukaan < 4.5")
            }
        }
    }

    /// Semua nada malam ≥ 4.5:1 terhadap **setiap** permukaan malam.
    ///
    /// Inilah uji yang **seharusnya gagal** pada nilai lama:
    /// red 0.50 → 1.49:1, 0.62 → 2.06:1, 0.80 → 3.10:1, semuanya di bawah
    /// ambang. Dengan nilai baru (0.94 … 1.0) kelimanya ≥ 4.5:1.
    func testNightTonesMeetWCAGAAAgainstEverySurface() {
        let palette = SurfacePalette.night
        let surfaces = [palette.background, palette.surface1, palette.surface2]
        for tone in PointingTone.allCases {
            let color = palette.tones.color(for: tone)
            for surface in surfaces {
                let ratio = color.contrastRatio(against: surface)
                XCTAssertGreaterThanOrEqual(ratio, 4.5,
                    "malam \(tone): \(ratio):1 terhadap permukaan < 4.5")
            }
        }
    }

    // MARK: - Klaim WCAG: isi kapsul badge

    /// Isi kapsul badge **siang** harus menjaga kontras teks nada di atasnya.
    ///
    /// Badge memakai warna nada yang sama untuk teks dan latar, jadi kontrasnya
    /// bergantung pada campuran keduanya. Kita menghitung isi sebagai nada @
    /// 0.2 di atas permukaan paling terang, lalu menjadikannya opak — dan
    /// menuntut teks nada ≥ 4.5:1 *terhadap isi badge itu sendiri*.
    func testBadgeFillsStayLegibleOnEverySurfaceTheyCanLandOn() {
        let palette = SurfacePalette.day
        for tone in PointingTone.allCases {
            let fill = palette.badgeFills.fill(for: tone)
            let text = palette.tones.color(for: tone)
            let ratio = text.contrastRatio(against: fill)
            XCTAssertGreaterThanOrEqual(ratio, 4.5,
                "siang badge \(tone): teks \(ratio):1 terhadap isi < 4.5")
        }
    }

    /// Di mode malam, isi badge adalah **permukaan tingkat dua**, bukan warna
    /// nada. Syaratnya: teks nada tetap ≥ 4.5:1 terhadap isi badge itu, dan
    /// isi badge tidak membiarkan hijau/biru (supaya badge tetap "merah murni"
    /// di bawah mode malam).
    func testNightBadgeFillsAreSurfaceNotToneAndLegible() {
        let palette = SurfacePalette.night
        for tone in PointingTone.allCases {
            let fill = palette.badgeFills.fill(for: tone)
            // Isi badge = permukaan, bukan warna nada → tidak boleh merah penuh.
            XCTAssertLessThan(fill.red, 0.5,
                "malam badge \(tone): isi harus permukaan, bukan warna nada")
            XCTAssertEqual(fill.green, 0, "malam badge \(tone): hijau nol")
            XCTAssertEqual(fill.blue, 0, "malam badge \(tone): biru nol")
            let ratio = palette.tones.color(for: tone)
                .contrastRatio(against: fill)
            XCTAssertGreaterThanOrEqual(ratio, 4.5,
                "malam badge \(tone): teks \(ratio):1 terhadap isi < 4.5")
        }
    }

    /// Gerbang berlaku untuk **kedua** mode lewat satu pintu: `SurfacePalette`.
    ///
    /// `tones` dan `badgeFills` memilih palet berdasarkan `isNight`, jadi uji
    /// ini memastikan tidak ada mode yang lolos dari gate hanya karena ia
    /// "bukan yang sedang diedit".
    func testBothModesExposeLegibleTonesThroughActivePalette() {
        for mode in [SurfacePalette.day, SurfacePalette.night] {
            for tone in PointingTone.allCases {
                let ratio = mode.tones.color(for: tone)
                    .contrastRatio(against: mode.lightestSurface)
                XCTAssertGreaterThanOrEqual(ratio, 4.5,
                    "\(mode.isNight ? "malam" : "siang") \(tone): \(ratio):1 < 4.5")
            }
        }
    }

    // MARK: - Nada tahap kalibrasi

    /// **Nada setiap tahap kalibrasi, disisir seluruhnya.**
    ///
    /// Peta ini dulu hidup di `CalibrationView` sebagai `phaseTone`, jadi
    /// tahap baru bisa mendapat `.neutral` di layar tanpa satu uji pun
    /// menyentuhnya. Sekarang ia milik model, dan uji ini menyisir
    /// `CalibrationPhase.allCases` supaya penambahan tahap tidak bisa lolos
    /// dengan warna yang tidak diuji.
    func testEveryCalibrationPhaseCarriesALegibleTone() {
        // Tahap yang belum mulai harus netral, yang sedang mengumpulkan aktif,
        // dan yang siap/dipakai sukses — nilai absolut, bukan sekadar
        // "berbeda satu sama lain".
        XCTAssertEqual(CalibrationPhase.idle.tone, .neutral)
        XCTAssertEqual(CalibrationPhase.collecting.tone, .active)
        XCTAssertEqual(CalibrationPhase.ready.tone, .success)
        XCTAssertEqual(CalibrationPhase.applied.tone, .success)

        // Dan setiap nada itu benar-benar terbaca di atas kartu, di kedua mode.
        for mode in [SurfacePalette.day, SurfacePalette.night] {
            for phase in CalibrationPhase.allCases {
                let ratio = mode.tones.color(for: phase.tone)
                    .contrastRatio(against: mode.surface1)
                XCTAssertGreaterThanOrEqual(ratio, 4.5,
                    "\(mode.isNight ? "malam" : "siang") \(phase): \(ratio):1 di atas kartu < 4.5")
            }
        }
    }

    /// **Nada `ready` dan `applied` harus sama.**
    ///
    /// Keduanya berarti "kalibrasi sudah boleh dipakai", dan pengguna melihat
    /// kartu yang sama sebelum dan sesudah menekan "Pakai". Kalau nadanya
    /// berbeda, satu-satunya perubahan di layar adalah warna — dan warna
    /// bukan informasi, terutama di mode malam di mana semua nada menyempit
    /// ke satu merah. Uji ini menjaga bahwa keduanya tetap satu arti.
    func testReadyAndAppliedShareTheSameTone() {
        XCTAssertEqual(CalibrationPhase.ready.tone, CalibrationPhase.applied.tone)
    }
}
