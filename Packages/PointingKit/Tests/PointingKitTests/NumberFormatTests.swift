import XCTest
@testable import PointingKit

/// Format angka untuk tampilan: pemisah desimal harus mengikuti bahasa yang
/// sedang dipakai, bukan apa pun yang bawaan di perangkat.
final class NumberFormatTests: XCTestCase {

    /// **Isolasi antar-uji.** `NumberFormat` menyimpan bahasa aktif di satu
    /// proses, jadi uji yang memasangnya bocor ke semua uji berikutnya bila
    /// tidak dilepas. Bocornya tidak muncul sebagai kegagalan yang jujur: ia
    /// muncul sebagai angka yang tiba-tiba memakai koma di berkas lain —
    /// persis kelas kesalahpahaman yang gerbang ini hunts.
    override func setUp() {
        super.setUp()
        NumberFormat.reset()
        // Katalog ikut dilepas: sejak satuan laju diambil dari katalog
        // (`RowSpeech.spokenRate` membaca `.rowSpeechDegreesPerSecond`), satu
        // uji yang memasang terjemahan akan bocor ke berkas lain — dan
        // kebocoran itu muncul sebagai angka dengan satuan yang salah, bukan
        // sebagai kegagalan.
        TextLocalization.reset()
    }

    override func tearDown() {
        NumberFormat.reset()
        TextLocalization.reset()
        super.tearDown()
    }

    // MARK: - Pemisah desimal

    /// **Titik adalah salah pada layar Bahasa Indonesia.**
    ///
    /// Semua baris angka di kedua app dulu memakai `String(format: "%.1f")`
    /// tanpa `locale:`, jadi pemisah desimal ikut bawaan perangkat — dan
    /// pada perangkat berbahasa Indonesia hasilnya `42.5°`, bukan `42,5°`.
    /// Ini bukan kosmetik: pemisah desimal adalah bagian dari cara membaca
    /// angka, dan `42.5` di locale koma bisa terbaca sebagai `425`.
    func testDecimalSeparatorFollowsTheActiveLanguage() {
        let value = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(value, "42,5",
                       "Bahasa Indonesia memakai koma sebagai pemisah desimal")
    }

    /// Pemisah desimal harus **dibaca dari bahasa aktif**, bukan dari lokasi
    /// perangkat — supaya angka yang sama tampil sama di semua orang yang
    /// membaca app ini dengan bahasa yang sama.
    func testSameLanguageProducesTheSameSeparator() {
        let a = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        let b = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "en_US"),
                          "tanda baca desimal memang berbeda antar bahasa")
    }

    /// Bahasa yang tidak dikenal tidak boleh membuat format kosong atau gagal.
    ///
    /// Format yang gagal berarti baris angkanya hilang — lebih buruk daripada
    /// pemisah yang salah.
    func testUnknownLocaleFallsBackToSomethingReadable() {
        let value = NumberFormat.decimal(42.5, fractionDigits: 1, localeId: "zz_ZZ")
        XCTAssertFalse(value.isEmpty)
        XCTAssertTrue(value.contains("4"))
    }

    /// Pembulatan harus tetap dihormati: inilah yang membuat permintaan nol
    /// digit dan satu digit berbeda artinya.
    func testFractionDigitsAreRespected() {
        let whole = NumberFormat.decimal(42.56, fractionDigits: 0, localeId: "id_ID")
        XCTAssertFalse(whole.contains(","), "nol digit desimal tidak boleh menambah koma")
        let one = NumberFormat.decimal(42.56, fractionDigits: 1, localeId: "id_ID")
        XCTAssertTrue(one.contains(","))
    }

    /// Nilainya harus persis seperti yang dimasukkan — pembulatan hanya
    /// dipegang oleh `fractionDigits`.
    func testValueIsNotOtherwiseDistorted() {
        XCTAssertEqual(NumberFormat.decimal(-6.2, fractionDigits: 1, localeId: "id_ID"), "-6,2")
        XCTAssertEqual(NumberFormat.decimal(0, fractionDigits: 0, localeId: "id_ID"), "0")
    }

    /// Derajat dan persen memakai helper yang sama, karena keduanya punya
    /// aturan pemisah yang sama.
    ///
    /// `0.624` dipilih, bukan `0.625`: `String(format:)` memakai pembulatan
    /// bankir, jadi `0.625` menjadi `62`, bukan `63`. Itu perilaku yang sama
    /// dengan `%.0f` yang sudah dipakai app sebelum helper ini ada, jadi
    /// sengaja **tidak** dibetulkan di sini. Mengganti algoritme pembulatan
    /// adalah keputusan terpisah yang harus berdiri sendiri, bukan bawaan
    /// diam-diam dari perbaikan pemisah desimal.
    func testDegreesAndPercentShareTheSeparatorRule() {
        let degrees = NumberFormat.degrees(42.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(degrees, "42,5°")
        let percent = NumberFormat.percent(0.624, fractionDigits: 0, localeId: "id_ID")
        XCTAssertEqual(percent, "62%")
        // Pecahan yang tidak bulat tetap memakai koma.
        let fractional = NumberFormat.percent(0.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(fractional, "50,0%")
    }

    // MARK: - Bahasa yang belum terpasang

    /// Tanpa bridge, Bahasa Indonesia adalah bahasa UI app ini — jadi bawaan
    /// **wajib** memakai koma. Bridge yang belum terpasang bukan alasan untuk
    /// menampilkan angka dalam bahasa yang salah untuk pembaca app ini, dan
    /// Linux tidak punya `.lproj` sama sekali, jadi setiap uji tanpa bridge
    /// melewati nilai bawaan ini.
    func testDefaultLanguageIsIndonesianNotTheProcessLocale() {
        XCTAssertEqual(NumberFormat.activeLocaleId, "id_ID")
        XCTAssertEqual(NumberFormat.decimal(42.5, fractionDigits: 1), "42,5",
                       "bawaan harus Bahasa Indonesia, bukan locale proses")
    }

    // MARK: - Bridge: jalur yang benar-benar jalan di perangkat

    /// **Ini jalur yang dipakai app.** Semua uji lain menyebut `localeId:`
    /// secara eksplisit, jadi tanpa uji ini tidak ada satu pun yang
    /// menjalankan jalur yang benar-benar berjalan di perangkat: bahasa aktif
    /// yang dipasang bridge dari `Locale.preferredLanguages`.
    func testInstalledLanguageIsTheOneUsedByDefault() {
        NumberFormat.install(localeId: "en_US")
        XCTAssertEqual(NumberFormat.activeLocaleId, "en_US")
        XCTAssertEqual(NumberFormat.decimal(42.5, fractionDigits: 1), "42.5",
                       "bridge yang terpasang harus jadi sumber bahasa")

        NumberFormat.install(localeId: "id_ID")
        XCTAssertEqual(NumberFormat.degrees(42.5), "42,5°")
    }

    /// `reset()` benar-benar melepas bahasa — kalau tidak, satu uji yang
    /// memasang `en_US` akan membuat semua uji berikutnya mengukur
    /// Bahasa Inggris, dan suite tetap hijau.
    func testResetReleasesTheInstalledLanguage() {
        NumberFormat.install(localeId: "en_US")
        NumberFormat.reset()
        XCTAssertEqual(NumberFormat.activeLocaleId, NumberFormat.defaultLocaleId)
    }

    /// Bahasa yang dipasang **ikut mengunci** pemisah, bukan cuma identifier
    /// yang tersimpan. Tanpa ini, `install` bisa jujur menyimpan `en_US` dan
    /// formatnya tetap memakai locale proses — persis bentuk "hijau yang tidak
    /// hijau" yang repo ini berulang-ulang hunted.
    func testInstalledLanguageActuallyChangesTheSeparator() {
        NumberFormat.install(localeId: "id_ID")
        let indonesian = NumberFormat.decimal(42.5, fractionDigits: 1)
        NumberFormat.install(localeId: "en_US")
        let english = NumberFormat.decimal(42.5, fractionDigits: 1)
        XCTAssertNotEqual(indonesian, english,
                          "bahasa terpasang tidak boleh jadi hiasan pada properti")
        XCTAssertEqual(english, "42.5")
    }

    // MARK: - Derajat bertanda (lintang & declinasi)

    /// **Tanda wajib ikut tercetak** — inilah satu-satunya alasan fungsi ini
    /// ada terpisah dari `degrees`.
    ///
    /// Ditemukan dengan mengukur, bukan membaca: format `"%+.4f"` diganti
    /// `"%.4f"` (tanda `+` dibuang) lalu seluruh suite dijalankan —
    /// **773 uji tetap hijau, nol kegagalan.** Tidak satu pun gerbang
    /// menyentuh fungsi ini, padahal satu-satunya pemanggilnya
    /// (`DiagnosticsView.swift`) menampilkannya sebagai baris **declinasi**
    /// objek: `+41,9°` (utara) dan `-41,9°` (selatan) adalah dua belahan
    /// langit yang berbeda, dan tanpa tanda keduanya tercetak `41,9°`.
    ///
    /// Ini kelas cacat yang sama dengan `.contains("kalibrasi")` di
    /// `ConfidenceTraceTests`: nilai yang tampak wajar, tidak ada yang merah.
    func testSignedDegreesPrintsTheSign() {
        XCTAssertEqual(NumberFormat.signedDegrees(41.9, fractionDigits: 1, localeId: "id_ID"),
                       "+41,9°", "declinasi utara harus bertanda +")
        XCTAssertEqual(NumberFormat.signedDegrees(-41.9, fractionDigits: 1, localeId: "id_ID"),
                       "-41,9°", "declinasi selatan harus bertanda -")
    }

    /// Nol tetap **bertanda**: `+0,0°` adalah ekuator, dan itu bukan `0,0°`
    /// yang tanpa konteks terbaca sebagai "tidak ada nilai".
    ///
    /// `%+` memang mencetak `+0,0`; yang dijaga di sini bahwa tidak ada yang
    /// kelak "merapikan" nol menjadi tanpa tanda.
    func testSignedDegreesKeepsTheSignOnZero() {
        XCTAssertEqual(NumberFormat.signedDegrees(0, fractionDigits: 1, localeId: "id_ID"),
                       "+0,0°")
    }

    /// Pemisah desimal ikut bahasa, sama seperti `degrees`.
    ///
    /// Tanpa ini, versi bertanda bisa memakai locale proses sementara versi
    /// biasa memakai bahasa app — dua baris di layar yang sama dengan aturan
    /// pemisah berbeda.
    func testSignedDegreesFollowsTheActiveLanguage() {
        XCTAssertEqual(NumberFormat.signedDegrees(41.9, fractionDigits: 1, localeId: "en_US"),
                       "+41.9°")
    }

    // MARK: - Satuan laju

    /// Satuan harus ikut tercetak, dan **satuannya milik berkas ini**.
    ///
    /// Baris laju pergelangan dipakai di tiga layar (`PointingView`,
    /// `Experiment1View`, `LinkView`) dan angka tanpa satuan tidak bisa
    /// ditafsirkan: "12" pada baris yang mengukur gerak tangan bisa dibaca
    /// sebagai derajat, ketukan, atau detik. Satuan `"/dtk"` ditulis di sini —
    /// **bukan** dibaca dari katalog; yang penting ia tidak hilang, karena
    /// pemanggil di view tidak menambahkannya sendiri.
    func testDegreesPerSecondCarriesItsUnit() {
        let value = NumberFormat.degreesPerSecond(12.5, fractionDigits: 1, localeId: "id_ID")
        XCTAssertEqual(value, "12,5°/dtk")
        XCTAssertTrue(value.hasSuffix("°/dtk"),
                      "satuan laju harus '/dtk', bukan angka telanjang: \(value)")
    }

    /// Nol digit tetap membuang koma — aturan yang sama dengan `degrees`.
    ///
    /// Nilainya `12,5` dibulatkan **bankir** oleh `String(format:)`, jadi
    /// hasilnya `12`, bukan `13`. Perilaku itu diwarisi dari `degrees` dan
    /// sengaja tidak dibetulkan di sini (lihat catatan pembulatan di
    /// `testDegreesAndPercentShareTheSeparatorRule`).
    func testDegreesPerSecondRespectsFractionDigits() {
        let whole = NumberFormat.degreesPerSecond(12.5, fractionDigits: 0, localeId: "id_ID")
        XCTAssertEqual(whole, "12°/dtk")
        XCTAssertFalse(whole.contains(","))
    }
}