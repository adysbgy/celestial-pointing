import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk jalur teks yang **dihasilkan** di `PointingKit` — yang katalog
/// string tidak pernah bisa capai selama ia ditulis sebagai string biasa.
///
/// **Kenapa uji ini ada, dan apa yang sebenarnya dijaganya.** Aturan 4 di
/// `./swift-ui-lint.sh` menyapu literal `Text("...")` di `Apps/` dan melaporkan
/// hijau. Itu benar, dan ia tetap hijau sekarang — padahal 20 kunci baru
/// (`pointing.state.*`, `confidence.level.*`, `link.kind.*`) tidak punya
/// jejak apa pun di `Apps/`: labelnya di-*switch* di dalam paket. Kalau suatu
/// saat kunci katalognya dihapus satu per satu, seluruh teks yang paling
/// sering dibaca sekilas di app ini bisa kehilangan terjemahannya tanpa satu
/// pun gerbang yang merah.
///
/// Yang bisa diuji di Linux ada **dua** dan keduanya di sini:
///
/// 1. **Kontrak tampilan** — tanpa bridge terpasang, Bahasa Indonesia harus
///    tampil persis seperti sebelumnya. Ini yang membuat perubahan ini aman:
///    nilainya bisa dibandingkan literal, bukan lewat alasan.
/// 2. **Ketahanan** — saat bridge terpasang, terjemahan dipakai; saat kunci
///    hilang atau terjemahan kosong, ia **tidak** kembali ke string kosong.
///
/// Yang **tidak** bisa diuji di sini dicatat jujur di bawah setiap uji yang
/// menyangkutnya: apakah `Bundle` benar-benar membaca `.xcstrings` di
/// perangkat adalah wilayah CI dan perangkat, bukan Linux.
final class TextLocalizationTests: XCTestCase {

    // MARK: - Isolasi antar-uji

    /// `TextLocalization` adalah singleton proses, jadi satu uji yang memasang
    /// `Lookup` akan bocor ke semua uji berikutnya bila tidak dilepas.
    /// Kebocoran seperti itu **tidak** muncul sebagai kegagalan yang jujur:
    /// ia muncul sebagai "katalog terpasang sendiri", dan suite pun tetap hijau.
    override func setUp() {
        super.setUp()
        TextLocalization.reset()
    }

    override func tearDown() {
        TextLocalization.reset()
        super.tearDown()
    }

    // MARK: - Kontrak Bahasa Indonesia (tanpa bridge)

    /// Setiap keadaan punya label **berbeda**, dan tidak ada yang kosong.
    ///
    /// Ini dijaga karena label keadaan adalah layar pertama yang dilihat
    /// pengguna. Keduanya benar secara terpisah — `switch` bisa mengembalikan
    /// teks yang sama untuk dua keadaan dan `isEmpty` tetap false — jadi
    /// keduanya harus diuji.
    func testEveryStateKeepsItsOwnNonEmptyIndonesianLabel() {
        let states: [PointingState] = [.idle, .pointing, .searching,
                                      .lock, .uncertain, .unavailable]
        let labels = states.map { $0.shortLabel }
        for (state, label) in zip(states, labels) {
            XCTAssertFalse(label.isEmpty, "\(state) tanpa label")
            XCTAssertEqual(label, state.stateLabelText.indonesian,
                           "\(state) tidak lagi memakai nilai bawaan Bahasa Indonesia")
        }
        XCTAssertEqual(Set(labels).count, states.count,
                       "dua keadaan memakai label yang sama: \(labels)")
    }

    /// Kalimat panduan tidak boleh sama untuk dua keadaan berbeda.
    ///
    /// Yang membuat ini perlu diuji terpisah dari label: `guidance` adalah
    /// yang **dibaca** orang untuk tahu harus melakukan apa, dan dua keadaan
    /// dengan kalimat sama berarti app memberi instruksi yang tidak
    /// membedakan "sudah terkunci" dari "sedang mencari".
    func testEveryStateKeepsItsOwnGuidance() {
        let states: [PointingState] = [.idle, .pointing, .searching,
                                      .lock, .uncertain, .unavailable]
        let guidance = states.map { $0.guidance }
        for (state, text) in zip(states, guidance) {
            XCTAssertFalse(text.isEmpty, "\(state) tanpa panduan")
            XCTAssertEqual(text, state.stateGuidanceText.indonesian)
        }
        XCTAssertEqual(Set(guidance).count, states.count,
                       "dua keadaan memakai panduan yang sama: \(guidance)")
    }

    /// Nilai bakunya persis seperti **sebelum** perubahan ini.
    ///
    /// Dikunci dengan literal, bukan dengan `.indonesian` — kalau uji memakai
    /// `.indonesian` untuk kedua sisi, ia hanya membuktikan bahwa kedua sisi
    /// bergerak bersama, dan typo pada nilainya lolos. Kuncinya adalah sumber
    /// kebenarannya: teks Bahasa Indonesia yang tertulis di katalog.
    func testDefaultTextIsExactlyTheIndonesianItShippedWith() {
        // Angka ini bukan "harus tetap begitu selamanya" — ia menyatakan
        // bahwa nilai bawaan di dalam tipe adalah teks yang benar, dan
        // katalog punya padanan Inggris yang **beda** dari nilai bakunya
        // (lihat uji terjemahan di bawah).
        XCTAssertEqual(PointingState.lock.shortLabel, "Terkunci")
        XCTAssertEqual(PointingState.uncertain.shortLabel, "Kurang yakin")
        XCTAssertEqual(PointingState.unavailable.shortLabel, "Sensor mati")
        XCTAssertEqual(PointingState.idle.shortLabel, "Siap")
        XCTAssertEqual(PointingState.pointing.shortLabel, "Arahkan")
        XCTAssertEqual(PointingState.searching.shortLabel, "Mencari")

        XCTAssertEqual(PointingState.lock.guidance,
                       "Objek dikenali dengan keyakinan tinggi.")
        XCTAssertEqual(PointingState.uncertain.guidance,
                       "Ada kandidat, tapi belum cukup yakin untuk memastikan.")

        XCTAssertEqual(ConfidenceLevel.high.displayName, "Yakin")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Ragu")
        XCTAssertEqual(ConfidenceLevel.low.displayName, "Tidak tahu")

        XCTAssertEqual(LinkMessageKind.calibrationReady.displayName, "Kalibrasi")
        XCTAssertEqual(LinkMessageKind.policyUpdate.displayName, "Ambang keyakinan")
    }

    /// Nilaibawaan harus **tidak sama** dengan terjemahan Inggrisnya.
    ///
    /// Kalau ada kunci yang tertukar, nilai bawaan dan padanannya akan sama —
    /// dan seluruh bukti "terjemahan benar-benar dipakai" ikut hilang bersama
    /// pembeda itu. Uji ini menjaga agar bukti itu selalu ada.
    func testDefaultsDifferFromTheirEnglishTranslations() {
        // Known-good pairs, ditulis tangan dari isi katalog.
        let pairs: [(LocalizedText, String)] = [
            (.stateLockLabel, "Locked"),
            (.stateUncertainLabel, "Not certain"),
            (.stateUnavailableLabel, "Sensor unavailable"),
            (.levelHigh, "Certain"),
            (.levelMedium, "Uncertain"),
            (.linkKindCalibrationReady, "Calibration ready"),
        ]
        for (text, english) in pairs {
            XCTAssertNotEqual(text.indonesian, english,
                              "\(text.rawValue): nilai bawaan sama dengan terjemahan")
        }
    }

    // MARK: - Bridge / terjemahan

    /// Saat bridge terpasang, teks aktif mengikuti apa yang dikembalikan.
    func testInstalledLookupWinsOverTheDefaultValue() {
        TextLocalization.install { key in key == "pointing.state.lock.label" ? "Locked" : nil }
        XCTAssertEqual(PointingState.lock.shortLabel, "Locked")
        // Yang tidak punya terjemahan harus tetap jatuh ke Bahasa Indonesia —
        // bridge yang mengembalikan `nil` bukan berarti "tampilkan kosong".
        XCTAssertEqual(PointingState.idle.shortLabel, "Siap")
    }

    /// Terjemahan **kosong** diperlakukan sama dengan tidak ada.
    ///
    /// `Bundle.localizedString` mengembalikan `value` yang diberi, jadi
    /// terjemahan kosong bisa terjadi bila katalog punya entri tanpa `stringUnit`.
    /// Kalau bridge mempercayakannya, baris di layar menjadi kosong tanpa
    /// penjelasan — persis yang dilarang di `LocalizedText.text`.
    func testEmptyTranslationFallsBackToIndonesian() {
        TextLocalization.install { _ in "" }
        XCTAssertEqual(PointingState.lock.shortLabel, "Terkunci")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Ragu")
    }

    /// Kunci tanpa teks bawaan tetap menampilkan **sesuatu**.
    ///
    /// String kosong adalah kegagalan diam yang paling berbahaya di UI: baris
    /// terlihat kosong dan tidak ada yang bisa menanyakinya kenapa. Kunci
    /// mentah setidaknya jujur — ia menyatakan pengenal, bukan teks.
    func testKeyWithoutDefaultNeverRendersAsEmptyString() {
        let orphan = LocalizedText(key: "pointing.state.tidak.ada.label", id: "")
        XCTAssertEqual(TextLocalization.text(orphan), "pointing.state.tidak.ada.label")

        // Junction: bridge yang terpasang tapi mengembalikan `nil` untuknya.
        TextLocalization.install { _ in nil }
        XCTAssertEqual(TextLocalization.text(orphan), "pointing.state.tidak.ada.label")
    }

    // MARK: - Paritas katalog (dipakai aturan 6 di swift-ui-lint.sh)

    /// `allKeys` adalah sumber untuk gerbang paritas, jadi ia harus benar
    /// **sebagai daftar**: tanpa duplikat, tanpa kunci kosong, dan lengkap
    /// (20 kunci). Hitungan dikunci dengan angka supaya kunci yang hilang
    /// tidak bisa lolos hanya karena "tidak ada yang menyebutnya".
    func testDeclaredKeysAreUniqueNonEmptyAndComplete() {
        let keys = LocalizedText.allKeys
        XCTAssertEqual(keys.count, 30, "jumlah kunci berubah — perbarui gerbang & katalog")
        XCTAssertEqual(Set(keys.map(\.rawValue)).count, keys.count, "ada kunci kembar")
        for key in keys {
            XCTAssertFalse(key.rawValue.isEmpty, "kunci kosong")
            XCTAssertFalse(key.indonesian.isEmpty, "\(key.rawValue) tanpa nilai bawaan")
            XCTAssertFalse(key.rawValue.contains(" "),
                           "kunci \(key.rawValue) mengandung spasi — itu teks, bukan kunci")
        }
    }

    /// Setiap keadaan harus punya kunci, dan kuncinya harus **namespace**.
    ///
    /// Alasan namespace diuji: `"Kalibrasi"` sudah ada di katalog sebagai
    /// **judul layar kalibrasi**, sementara `link.kind.calibrationReady.label`
    /// juga berbunyi "Kalibrasi" untuk hal berbeda. Kalau suatu saat kunci
    /// diturunkan dari teksnya sendiri, keduanya akan menyatu diam-diam.
    func testStateAndLevelKeysAreNamespacedAndDistinct() {
        var keys: [LocalizedText: String] = [:]
        for state in [PointingState.idle, .pointing, .searching,
                      .lock, .uncertain, .unavailable] {
            let label = state.stateLabelText
            XCTAssertEqual(label.rawValue.hasPrefix("pointing.state."), true,
                           "\(state) label tanpa namespace")
            XCTAssertNil(keys[label], "kunci label dipakai dua keadaan: \(label.rawValue)")
            keys[label] = state.shortLabel

            let guidance = state.stateGuidanceText
            XCTAssertTrue(guidance.rawValue.hasPrefix("pointing.state."),
                          "\(state) panduan tanpa namespace")
            XCTAssertNotEqual(guidance.rawValue, label.rawValue,
                              "label dan panduan satu keadaan berbagi kunci")
        }
        for level in [ConfidenceLevel.high, .medium, .low] {
            let text = level.displayText
            XCTAssertTrue(text.rawValue.hasPrefix("confidence.level."),
                          "\(level) tanpa namespace")
            XCTAssertNotEqual(text.indonesian, "Kalibrasi")
        }
    }

    // MARK: - Label jenis benda

    /// Sepuluh label jenis benda harus punya nilai bawaan Bahasa Indonesia yang
    /// **persis seperti sebelum** perpindahan berkasnya ke paket.
    ///
    /// Nilainya dikunci dengan literal, bukan dengan `.indonesian`: kalau uji
    /// memakai `.indonesian` untuk kedua sisi, ia hanya membuktikan kedua sisi
    /// bergerak bersama, dan typo pada nilainya lolos — persis jebakan yang
    /// pernah menangkap salah eja pada siklus sebelumnya.
    func testKindLabelsAreExactlyTheIndonesianTheyShippedWith() {
        XCTAssertEqual(ObjectKind.star.displayName, "Bintang")
        XCTAssertEqual(ObjectKind.planet.displayName, "Planet")
        XCTAssertEqual(ObjectKind.moon.displayName, "Bulan")
        XCTAssertEqual(ObjectKind.sun.displayName, "Matahari")
        XCTAssertEqual(ObjectKind.deepSky.displayName, "Objek langit dalam")

        XCTAssertEqual(ObjectKind.star.spokenName, "bintang")
        XCTAssertEqual(ObjectKind.planet.spokenName, "planet")
        XCTAssertEqual(ObjectKind.moon.spokenName, "bulan")
        XCTAssertEqual(ObjectKind.sun.spokenName, "matahari")
        XCTAssertEqual(ObjectKind.deepSky.spokenName, "objek langit jauh")
    }

    /// Setiap jenis punya label sendiri, untuk tampilan **dan** pengucapan.
    ///
    /// Dua pengujian terpisah karena keduanya bisa benar sendiri-sendiri:
    /// `switch` bisa mengembalikan teks yang sama untuk dua jenis dan
    /// `isEmpty` tetap false — persis yang terjadi pada uji label keadaan
    /// lebih dulu.
    func testEveryKindKeepsItsOwnDisplayAndSpokenLabel() {
        let kinds: [ObjectKind] = [.star, .planet, .moon, .sun, .deepSky]
        let displays = kinds.map(\.displayName)
        let spokens = kinds.map(\.spokenName)
        for (index, kind) in kinds.enumerated() {
            XCTAssertFalse(displays[index].isEmpty, "\(kind) tanpa label tampilan")
            XCTAssertFalse(spokens[index].isEmpty, "\(kind) tanpa label pengucapan")
        }
        XCTAssertEqual(Set(displays).count, kinds.count,
                       "dua jenis memakai label tampilan yang sama: \(displays)")
        XCTAssertEqual(Set(spokens).count, kinds.count,
                       "dua jenis memakai label pengucapan yang sama: \(spokens)")
    }

    /// Kunci jenis benda harus ber-namespace `object.kind.` dan **tidak**
    /// berbagi kunci dengan bentuk tampilan maupun pengucapan.
    ///
    /// Yang menjaga pemisahan tampilan/pengucapan adalah alasan "frasa
    /// majemuk terdengar janggal" — jadi saat seseorang menyatukan
    /// `spokenName` ke `displayName` supaya lebih ringingkas, pemisahan ini
    /// yang harus lebih dulu merah.
    func testKindKeysAreNamespacedAndSplitByDisplayAndSpoken() {
        for kind in [ObjectKind.star, .planet, .moon, .sun, .deepSky] {
            let display = kind.displayText
            let spoken = kind.spokenText
            XCTAssertTrue(display.rawValue.hasPrefix("object.kind."),
                          "\(kind) label tampilan tanpa namespace")
            XCTAssertTrue(spoken.rawValue.hasPrefix("object.kind."),
                          "\(kind) pengucapan tanpa namespace")
            XCTAssertNotEqual(display.rawValue, spoken.rawValue,
                              "\(kind) tampilan dan pengucapan berbagi kunci")
            XCTAssertNotEqual(display.rawValue, kind.rawValue,
                              "\(kind) kunci diturunkan dari rawValue-nya sendiri")
        }
    }

    /// Label jenis benda harus ikut terjemahan, seperti label lain.
    ///
    /// Inilah bukti bahwa perpindahan ke paket itu berarti: sebelum ini,
    /// bridge yang terpasang tidak punya apa pun untuk dibaca untuk label
    /// jenis — kuncinya belum pernah ada di katalog.
    func testInstalledLookupReachesKindLabelsToo() {
        TextLocalization.install { key in
            switch key {
            case "object.kind.star.display.label":   return "Star"
            case "object.kind.deepSky.spoken.label": return "deep-sky object"
            default: return nil
            }
        }
        XCTAssertEqual(ObjectKind.star.displayName, "Star")
        XCTAssertEqual(ObjectKind.deepSky.spokenName, "deep-sky object")
        // Yang tidak diterjemahkan harus tetap Bahasa Indonesia, bukan kosong.
        XCTAssertEqual(ObjectKind.moon.displayName, "Bulan")
    }

    /// Bukti bahwa nilai bawaan != terjemahan, untuk kunci baru.
    ///
    /// Tanpa pembeda ini, bukti "terjemahan benar-benar dipakai" hilang
    /// bersama kemungkinan tertukarnya nilai bawaan dengan padanannya — dan
    /// suite tetap hijau.
    func testKindDefaultsDifferFromTheirEnglishTranslations() {
        let pairs: [(LocalizedText, String)] = [
            (.kindStarLabel, "Star"),
            (.kindMoonLabel, "Moon"),
            (.kindSunLabel, "Sun"),
            (.kindDeepSkyLabel, "Deep-sky object"),
            (.kindStarSpoken, "star"),
            (.kindDeepSkySpoken, "deep-sky object"),
        ]
        for (text, english) in pairs {
            XCTAssertNotEqual(text.indonesian, english,
                              "\(text.rawValue): nilai bawaan sama dengan terjemahan")
        }
    }
}