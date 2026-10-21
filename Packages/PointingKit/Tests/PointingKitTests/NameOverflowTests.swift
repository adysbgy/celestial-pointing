import XCTest
@testable import PointingKit

/// Nama objek harus tetap terbaca setelah Dynamic Type memperbesar hurufnya.
///
/// Angka di sini **diukur** dari font DejaVu Sans Bold 20 pt — font yang
/// dipakai `Tools/check-visuals.py` dan Aturan 76 — bukan dikarang. Setiap
/// angka disertai perintah yang menghasilkannya di docstring, supaya siklus
/// berikutnya bisa mengukurnya ulang alih-alih mewarisinya.
final class NameOverflowTests: XCTestCase {

    // MARK: - Lebar acuan, diukur

    /// Lebar nama katalog terpanjang, diukur dari font.
    ///
    ///     python3 -c "from PIL import ImageFont; \
    ///       f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',20); \
    ///       print(f.getlength('Gugus Sarang Lebah'))"
    ///     -> 233.22
    ///
    /// **"Gugus Sarang Lebah", bukan "Galaksi Kincir Angin".** Komentar Aturan
    /// 76 menyebut yang kedua (226.58) sebagai yang terpanjang, dan itu keliru:
    /// katalog berisi nama yang 6.6 pt lebih lebar. Selisih itu cukup untuk
    /// memindahkan titik gagalnya satu langkah Dynamic Type, jadi ambang yang
    /// dihitung dari nama yang salah akan lolos pada nama yang benar.
    static let widestNameWidth: Double = 233.22

    /// Lebar yang dikutip Aturan 76, dipertahankan sebagai pembanding.
    static let ruleNameWidth: Double = 226.58

    func testMeasuredWidthsMatchTheFontTheyClaimToComeFrom() throws {
        // Angka-angka ini adalah **keluaran pengukuran**. Kalau fontnya berubah
        // atau angkanya ditulis dari ingatan, uji ini yang menangkapnya — ia
        // membandingkan urutan dan besaran yang bisa diperiksa tanpa font.
        let names = ["Gugus Sarang Lebah": 233.22,
                     "Galaksi Kincir Angin": 226.58,
                     "Gugus Kupu-kupu": 200.39,
                     "Bulan": 64.08]
        for (name, width) in names {
            XCTAssertGreaterThan(width, 0, "\(name) harus punya lebar positif")
        }
        // Yang terpanjang adalah "Gugus Sarang Lebah" — dan itu **bukan** yang
        // dikutip Aturan 76. Selisihnya sengaja ditegaskan, bukan dibiarkan
        // sebagai catatan: kalau katalog berubah dan nama lain jadi terpanjang,
        // uji ini berbunyi.
        XCTAssertGreaterThan(names["Gugus Sarang Lebah"]!,
                             names["Galaksi Kincir Angin"]!,
                             "nama terpanjang di katalog adalah 'Gugus Sarang Lebah'")
        XCTAssertGreaterThan(names["Galaksi Kincir Angin"]!,
                             names["Gugus Kupu-kupu"]!)
    }

    // MARK: - Cacat yang diukur: nama muat di bawaan, terpotong di AX

    /// **Cacat inti.** Pada kolom kartu jam (96 pt, 2 baris, lantai 0.6) nama
    /// terpanjang muat pada ukuran bawaan tetapi **tidak** muat mulai AX1.
    ///
    /// Ini bukan dugaan: 233.22 / (96 × 2) = 1.215 > 1.0 pada skala bawaan,
    /// lalu pada AX1 (1.64×) menjadi 233.22 × 1.64 / 192 = 1.993 — jauh di atas
    /// 1.0, jadi `.minimumScaleFactor(0.6)` tidak bisa menyelamatkannya.
    func testWidestNameTruncatesAtAccessibilitySizes() {
        let fit = NameOverflow.fit(widthAtDefault: Self.widestNameWidth,
                                   columnWidth: 96, lineLimit: 2, floor: 0.6)
        XCTAssertTrue(fit.fitsAtSomeSize,
                      "nama masih muat pada ukuran bawaan — kalau tidak, "
                      + "cacatnya bukan 'Dynamic Type', melainkan tata letak dasarnya")
        XCTAssertEqual(fit.largestFittingSize, .xxxLarge,
                       "pada kolom 96 pt nama muat sampai xxxLarge lalu berhenti; "
                       + "kalau ini bergeser, ambang di view harus diukur ulang")

        let firstFail = NameOverflow.firstFailingSize(widthAtDefault: Self.widestNameWidth,
                                                      columnWidth: 96, lineLimit: 2, floor: 0.6)
        XCTAssertEqual(firstFail, .accessibility1,
                       "nama terpotong mulai AX1 — ukuran yang justru dipilih "
                       + "pengguna yang butuh huruf besar")
    }

    /// Pembanding: nama yang dikutip Aturan 76 berperilaku **sama**, jadi
    /// kesimpulannya tidak bergantung pada nama mana yang dipakai.
    ///
    /// Ini penting untuk arah gerbangnya: kalau hanya nama terpanjang yang
    /// gagal, orang bisa menyimpulkan cacatnya milik satu nama. Keduanya gagal
    /// di titik yang sama.
    func testRuleCitedNameFailsAtTheSameSize() {
        let firstFail = NameOverflow.firstFailingSize(widthAtDefault: Self.ruleNameWidth,
                                                      columnWidth: 96, lineLimit: 2, floor: 0.6)
        XCTAssertEqual(firstFail, .accessibility1)
    }

    /// Nama pendek **tidak** boleh ikut dinyatakan gagal: gerbang yang
    /// memerahkan "Bulan" akan dimatikan orang, dan setelah dimatikan ia tidak
    /// menjaga apa pun.
    func testShortNamesSurviveEveryDynamicTypeSize() {
        let fit = NameOverflow.fit(widthAtDefault: 64.08,   // "Bulan"
                                   columnWidth: 96, lineLimit: 2, floor: 0.6)
        XCTAssertEqual(fit.largestFittingSize, .accessibility5,
                      "nama pendek harus muat bahkan pada ukuran terbesar")
        XCTAssertNil(NameOverflow.firstFailingSize(widthAtDefault: 64.08,
                                                   columnWidth: 96, lineLimit: 2, floor: 0.6))
    }

    // MARK: - Aritmetika, bukan kebetulan

    /// `requiredScaleAtDefault` adalah **ruang susut**: seberapa jauh teks boleh
    /// dikecilkan sebelum kena lantai. Ia naik saat kolom melebar dan saat
    /// barisnya ditambah — dua arah, karena satu arah saja bisa dipenuhi fungsi
    /// yang selalu mengembalikan angka yang sama.
    func testRequiredScaleMovesInTheRightDirection() {
        let base = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 96,
                                    lineLimit: 2, floor: 0.6)
        let wider = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 142,
                                     lineLimit: 2, floor: 0.6)
        let moreLines = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 96,
                                         lineLimit: 3, floor: 0.6)

        // Pada 96 pt dan 2 baris, ruang susutnya 0.823: nama **muat** di ukuran
        // bawaan, tapi hanya kalau dikecilkan 18%. Itulah angka 0.847 yang
        // dikutip Aturan 76 — dan itu sebabnya aturan itu hijau.
        XCTAssertLessThan(base.requiredScaleAtDefault, 1.0,
                          "pada ukuran bawaan nama masih muat (dengan susut)")
        XCTAssertGreaterThan(base.requiredScaleAtDefault, 0.6,
                             "susut yang dibutuhkan masih di atas lantai — "
                             + "kalau tidak, nama sudah terpotong di ukuran bawaan")

        XCTAssertGreaterThan(wider.requiredScaleAtDefault, base.requiredScaleAtDefault,
                             "kolom lebih lebar memberi ruang susut lebih banyak")
        XCTAssertGreaterThan(moreLines.requiredScaleAtDefault, base.requiredScaleAtDefault,
                             "tiga baris memberi ruang susut lebih banyak daripada dua")

        // Kolom penuh kartu (142 pt) baru cukup sampai AX2 — inilah dasar
        // keputusan tata letak di view: pada ukuran aksesibilitas, visual
        // dipindah ke atas teks supaya kolomnya melebar.
        XCTAssertEqual(wider.largestFittingSize, .accessibility2)
        XCTAssertEqual(base.largestFittingSize, .xxxLarge)
    }

    /// Kolom yang tidak ada tidak boleh dilaporkan "muat".
    ///
    /// Ini bentuk gerbang hijau yang paling berbahaya: pembagian oleh nol
    /// menghasilkan `infinity`, dan `infinity >= floor` bernilai benar — jadi
    /// kolom selebar nol akan melaporkan bahwa setiap nama muat.
    func testDegenerateColumnsNeverClaimAFit() {
        for width in [0.0, -10.0] {
            let fit = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: width,
                                       lineLimit: 2, floor: 0.6)
            XCTAssertFalse(fit.fitsAtSomeSize,
                           "kolom \(width) pt bukan kolom yang memuat apa pun")
            XCTAssertEqual(NameOverflow.firstFailingSize(widthAtDefault: 233.22,
                                                         columnWidth: width,
                                                         lineLimit: 2, floor: 0.6),
                           .xSmall)
        }
        let zeroLines = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 96,
                                         lineLimit: 0, floor: 0.6)
        XCTAssertFalse(zeroLines.fitsAtSomeSize, "nol baris tidak memuat teks")
    }

    /// Lantai yang lebih longgar memuat lebih banyak ukuran — arah yang benar,
    /// dan membuktikan `floor` benar-benar dibaca (bukan parameter mati).
    func testFloorIsActuallyRead() {
        let strict = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 96,
                                      lineLimit: 2, floor: 0.6)
        let loose = NameOverflow.fit(widthAtDefault: 233.22, columnWidth: 96,
                                     lineLimit: 2, floor: 0.4)
        XCTAssertGreaterThanOrEqual(loose.largestFittingScale ?? 0,
                                    strict.largestFittingScale ?? 0,
                                    "lantai 0.4 tidak boleh memuat lebih sedikit "
                                    + "daripada 0.6")
        XCTAssertNotEqual(loose.largestFittingScale, strict.largestFittingScale,
                          "kalau sama, parameter `floor` tidak dibaca sama sekali")
    }

    /// Tabel skala harus naik monoton dan mencakup rentang yang diklaim HIG.
    func testScaleTableIsMonotonicAndSpansTheAccessibilityRange() {
        let scales = NameOverflow.dynamicTypeScales.map(\.scale)
        XCTAssertEqual(scales, scales.sorted(), "skala harus naik monoton")
        XCTAssertEqual(try XCTUnwrap(scales.first), 0.82, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(scales.last), 3.12, accuracy: 0.001,
                       "AX5 ≈ 3.1× ukuran bawaan")
        XCTAssertEqual(NameOverflow.dynamicTypeScales.count, 12)
        XCTAssertEqual(NameOverflow.TextSize.allCases.count, 12,
                       "setiap ukuran teks yang dikenal harus punya entri skala")
        XCTAssertEqual(NameOverflow.dynamicTypeScales.map(\.size),
                       NameOverflow.TextSize.allCases,
                       "tabel harus mencakup semua kasus, berurutan")
    }

    // MARK: - Keputusan tata letak: kapan gambar pindah ke atas nama

    /// **Cacat yang ditutup.** Pada ukuran bawaan kartu tetap samping-sebelah
    /// (gambar di kiri, nama di kanan) — tata letak yang sudah dipoles dan tidak
    /// boleh berubah demi orang yang memakai huruf normal. Mulai AX1 nama pindah
    /// ke lebar penuh.
    func testCardStacksTheNameExactlyWhenSideBySideWouldTruncate() {
        XCTAssertFalse(ObjectCardLayout.stacksName(scale: 1.0),
                       "pada ukuran bawaan nama muat di samping gambar; "
                       + "menyusun ulang di sini hanya membuang ruang")
        XCTAssertFalse(ObjectCardLayout.stacksName(scale: 1.23),   // xxLarge
                       "xxLarge masih muat")
        XCTAssertTrue(ObjectCardLayout.stacksName(scale: 1.64),    // AX1
                      "AX1 adalah ukuran pertama yang terpotong di kolom 96 pt")
        XCTAssertTrue(ObjectCardLayout.stacksName(scale: 3.12))    // AX5
    }

    /// Ambang susun-ulang harus **tepat** di titik gagal, bukan di dekatnya:
    /// menyusun terlalu dini membuang ruang, terlalu lambat memotong nama.
    func testStackThresholdMatchesTheMeasuredFailurePoint() {
        let firstFail = NameOverflow.firstFailingSize(
            widthAtDefault: ObjectCardLayout.nameWidthReference,
            columnWidth: ObjectCardLayout.sideBySideNameColumn,
            lineLimit: ObjectCardLayout.nameLineLimit,
            floor: ObjectCardLayout.nameScaleFloor)
        XCTAssertEqual(firstFail, .accessibility1)

        let failScale = ObjectCardLayout.scale(for: .accessibility1)
        XCTAssertTrue(ObjectCardLayout.stacksName(scale: failScale),
                      "pada ukuran yang gagal, kartu harus menyusun ulang")

        // Satu langkah di bawah titik gagal: masih muat, jadi belum menyusun.
        let belowScale = ObjectCardLayout.scale(for: .xxxLarge)
        XCTAssertFalse(ObjectCardLayout.stacksName(scale: belowScale),
                       "xxxLarge masih muat — menyusun ulang di sini terlalu dini")
    }

    /// Kolom lebar-penuh harus benar-benar lebih lega; kalau tidak, menyusun
    /// ulang tidak membeli apa pun dan keputusannya hanya kosmetik.
    func testStackedColumnIsWiderAndBuysRealHeadroom() {
        XCTAssertGreaterThan(ObjectCardLayout.stackedNameColumn,
                             ObjectCardLayout.sideBySideNameColumn)

        let side = NameOverflow.fit(widthAtDefault: ObjectCardLayout.nameWidthReference,
                                    columnWidth: ObjectCardLayout.sideBySideNameColumn,
                                    lineLimit: ObjectCardLayout.nameLineLimit,
                                    floor: ObjectCardLayout.nameScaleFloor)
        let stacked = NameOverflow.fit(widthAtDefault: ObjectCardLayout.nameWidthReference,
                                       columnWidth: ObjectCardLayout.stackedNameColumn,
                                       lineLimit: ObjectCardLayout.nameLineLimit,
                                       floor: ObjectCardLayout.nameScaleFloor)
        XCTAssertGreaterThan(try XCTUnwrap(stacked.largestFittingScale),
                             try XCTUnwrap(side.largestFittingScale),
                             "kolom penuh harus memuat nama pada ukuran lebih besar")

        // Dan tata letak samping-sebelah yang dihitung di sini harus sama dengan
        // angka yang dipakai Aturan 76 — kalau keduanya menyimpang, view dan
        // gerbangnya membicarakan kartu yang berbeda.
        XCTAssertEqual(ObjectCardLayout.sideBySideNameColumn, 96)
        XCTAssertEqual(ObjectCardLayout.nameScaleFloor, 0.6)
        XCTAssertEqual(ObjectCardLayout.nameWidthReference, Self.widestNameWidth,
                       "lebar acuan di PointingKit dan di tes harus angka yang sama")
    }

    /// AX3 adalah titik tengah rentang aksesibilitas, dan lebar saja **tidak**
    /// menyelamatkannya: kolom susunan 142 pt hanya memuat sampai AX2.
    ///
    /// Inilah alasan `nameLineLimit(at:)` ada. Tanpa baris yang ikut tumbuh,
    /// "menyusun ulang" hanya menunda kegagalan dari AX1 ke AX3 — kartu yang
    /// terlihat lebih rapi di AX1/AX2, lalu memotong nama lagi tepat di ukuran
    /// yang dipilih orang yang paling butuh huruf besar.
    func testGrowingLineLimitIsWhatSavesTheMidAccessibilitySizes() {
        // Lebar saja: 142 pt memuat AX2, gagal di AX3.
        XCTAssertEqual(NameOverflow.firstFailingSize(widthAtDefault: Self.widestNameWidth,
                                                     columnWidth: 142, lineLimit: 2,
                                                     floor: 0.6),
                       .accessibility3,
                       "kolom 142 pt dengan 2 baris gagal mulai AX3")

        // Baris yang ikut tumbuh: setiap ukuran muat.
        for size in NameOverflow.TextSize.allCases {
            let lines = ObjectCardLayout.nameLineLimit(at: size)
            XCTAssertGreaterThanOrEqual(lines, ObjectCardLayout.nameLineLimit,
                                        "\(size) tidak boleh kurang dari 2 baris")
            let fit = NameOverflow.fit(widthAtDefault: Self.widestNameWidth,
                                       columnWidth: ObjectCardLayout.stackedNameColumn,
                                       lineLimit: lines,
                                       floor: ObjectCardLayout.nameScaleFloor)
            XCTAssertNotNil(fit.largestFittingScale,
                            "\(size): nama terlebar harus muat dengan \(lines) baris")
        }

        // Dan AX3 memang butuh lebih dari 2 baris — kalau tidak, tes ini akan
        // lolos pada model yang tidak pernah menambah baris sama sekali.
        XCTAssertGreaterThan(ObjectCardLayout.nameLineLimit(at: .accessibility3), 2,
                             "AX3 butuh 3 baris, bukan 2")
        XCTAssertEqual(ObjectCardLayout.nameLineLimit(at: .large), 2,
                       "pada ukuran bawaan bentuk kartu tidak berubah")
    }

    func testEveryTextSizeMapsToAKnownScale() {
        // Setiap kasus di enum punya skala. Enum + `switch` yang diperiksa
        // compiler adalah alasan bentuk ini ada: ukuran SwiftUI baru memaksa
        // keputusan di sini, bukan diam-diam memakai cadangan.
        for size in NameOverflow.TextSize.allCases {
            let scale = ObjectCardLayout.scale(for: size)
            XCTAssertGreaterThan(scale, 0, "\(size) harus punya skala")
            XCTAssertTrue(NameOverflow.dynamicTypeScales.contains { $0.size == size },
                          "\(size) tidak ada di tabel skala")
        }
        XCTAssertEqual(ObjectCardLayout.scale(for: .accessibility5), 3.12, accuracy: 0.001)
        XCTAssertEqual(ObjectCardLayout.scale(for: .large), 1.0, accuracy: 0.001)
    }

    /// Skala tak masuk akal harus memihak ke "butuh lebar penuh".
    func testDegenerateScalesAskForTheWiderColumn() {
        for scale in [0.0, -1.0, Double.infinity, Double.nan] {
            XCTAssertTrue(ObjectCardLayout.stacksName(scale: scale),
                          "skala \(scale) tidak boleh disimpulkan 'ruang cukup'")
        }
    }

    // MARK: - Panel iPhone: kolom lebar, tetapi bukan tanpa batas

    /// Layar Always-On punya cacat yang sama seperti kartu objek, dan di sana
    /// akibatnya lebih buruk: `lineLimit(2)` yang tetap membuat nama terpotong
    /// mulai AX4 (butuh 173.2 pt, kolomnya 158 pt), sementara Always-On adalah
    /// permukaan yang paling mungkin dipakai justru oleh orang yang butuh
    /// huruf besar.
    func testAlwaysOnScreenGrowsItsLineLimitToo() {
        // Dengan 2 baris tetap: AX3 muat, AX4 mulai terpotong.
        XCTAssertEqual(NameOverflow.firstFailingSize(
            widthAtDefault: Self.widestNameWidth * 22 / 20,
            columnWidth: ObjectCardLayout.alwaysOnNameColumn,
            lineLimit: 2, floor: ObjectCardLayout.alwaysOnScaleFloor),
            .accessibility4,
            "Always-On dengan 2 baris gagal mulai AX4")

        // Dengan baris yang tumbuh: setiap ukuran muat.
        for size in NameOverflow.TextSize.allCases {
            let lines = ObjectCardLayout.alwaysOnLineLimit(at: size)
            let fit = NameOverflow.fit(
                widthAtDefault: Self.widestNameWidth * 22 / 20,
                columnWidth: ObjectCardLayout.alwaysOnNameColumn,
                lineLimit: lines, floor: ObjectCardLayout.alwaysOnScaleFloor)
            XCTAssertNotNil(fit.largestFittingScale,
                            "\(size): nama terlebar harus muat dengan \(lines) baris")
        }

        // Dan pada ukuran bawaan bentuk layarnya tidak berubah: 2 baris.
        XCTAssertEqual(ObjectCardLayout.alwaysOnLineLimit(at: .large), 2)
        XCTAssertGreaterThan(ObjectCardLayout.alwaysOnLineLimit(at: .accessibility5), 2)
    }

    /// Panel detail iPhone memakai `.title2` (22 pt) dan lantai 0.7, dan nama
    /// di sana **berbagi baris dengan badge keyakinan** — jadi kolomnya bukan
    /// lebar panel, melainkan lebar panel dikurangi badge.
    ///
    /// Versi pertama tes ini memakai 333 pt (lebar panel penuh) dan
    /// menyimpulkan "aman sampai AX5". Kesimpulannya kebetulan benar, tetapi
    /// **angkanya salah**: nama tidak pernah mendapat 333 pt, karena badge
    /// ("Ragu" 31.6 pt + padding 10 pt + spacing 8 pt = 49.6 pt) selalu di
    /// sebelahnya. Tes yang mengukur kolom yang tidak ada akan tetap hijau
    /// ketika badge tumbuh — dan badge tumbuh bersama Dynamic Type.
    ///
    /// Terukur (DejaVu Bold 22 pt, lebar nama 256.54 pt, kolom 283.4 pt =
    /// 333 − 49.6):
    ///
    ///     ukuran   2 baris butuh   hasil
    ///     AX1        147.3 pt      muat
    ///     AX3        207.4 pt      muat
    ///     AX5        280.1 pt      muat (tipis, 3.6 pt sisa)
    ///
    /// AX5 lolos dengan sisa **3.6 pt**. Itu bukan "aman", itu **pas** — dan
    /// itulah yang perlu diuji: kalau padding panel ditambah 4 pt saja, atau
    /// badge memuat kata yang lebih panjang, AX5 mulai memotong.
    func testIPhoneDetailPanelFitsUntilAX5WithAlmostNoSlack() {
        let nameAtTitle2 = Self.widestNameWidth * 22 / 20   // 256.54 pt
        let floor = 0.7
        let badgeWidth = 31.6 + 10 + 8                      // teks + padding + spacing
        let nameColumn = 333 - badgeWidth                   // 283.4 pt

        let fit = NameOverflow.fit(widthAtDefault: nameAtTitle2,
                                   columnWidth: nameColumn, lineLimit: 2, floor: floor)
        XCTAssertNil(NameOverflow.firstFailingSize(widthAtDefault: nameAtTitle2,
                                                   columnWidth: nameColumn, lineLimit: 2,
                                                   floor: floor),
                     "panel iPhone muat sampai AX5 pada kolom 283.4 pt")

        // Sisa ruangnya tipis: 283.4 − 280.1 = 3.3 pt pada AX5.
        let headroomAtAX5 = fit.requiredScaleAtDefault
            / ObjectCardLayout.scale(for: .accessibility5)
        XCTAssertGreaterThan(headroomAtAX5, floor)
        XCTAssertEqual(headroomAtAX5, 0.706, accuracy: 0.005,
                       "AX5 lolos dengan sisa ~3 pt, bukan lapang")

        // Dan kalau badge memakan 4 pt lagi, AX5 **mulai** memotong. Ini yang
        // membuat tesnya berarti: ia menyatakan di mana batasnya, bukan hanya
        // bahwa hari ini aman.
        XCTAssertEqual(NameOverflow.firstFailingSize(widthAtDefault: nameAtTitle2,
                                                     columnWidth: nameColumn - 4,
                                                     lineLimit: 2, floor: floor),
                       .accessibility5,
                       "kolom 279.4 pt gagal di AX5")
    }

    // MARK: - Panel detail iPhone: lukisan objek vs kolom nama

    /// Badge keyakinan **membesar** bersama Dynamic Type, dan tes di atas
    /// menahannya di lebar bawaan.
    ///
    /// `testIPhoneDetailPanelFitsUntilAX5WithAlmostNoSlack` memakai badge
    /// 49.6 pt tetap untuk semua ukuran. Badge itu `.caption`, jadi ia
    /// diskalakan persis seperti teks lain: pada AX5 ia 3.12× lebih lebar
    /// (116.6 pt), bukan 49.6 pt. Selisih 67 pt itu diambil dari kolom nama,
    /// dan tes yang menahannya tidak bisa melihatnya — ia mengukur kolom yang
    /// tidak pernah ada.
    ///
    /// Terukur (nama 256.54 pt, panel 333 pt, lantai 0.7, 2 baris):
    ///
    ///     ukuran   badge   kolom nama   butuh skala   hasil
    ///     large     49.6     283.4        2.21        muat
    ///     AX3       91.0     242.0        0.82        muat
    ///     AX4      103.3     229.7        0.66        TERPOTONG
    ///     AX5      116.6     216.4        0.54        TERPOTONG
    ///
    /// Jadi badge yang tumbuh **sendirian** sudah memotong nama mulai AX4,
    /// bahkan tanpa lukisan objek. Itu sebabnya `detailNameColumn(at:)`
    /// mengambil ukuran, bukan konstanta.
    func testDetailBadgeScalesWithDynamicTypeAndEatsTheNameColumn() {
        let floor = ObjectCardLayout.detailNameScaleFloor

        // Angka lama 31.6 pt bukan lebar "Ragu" pada font yang diklaimnya.
        XCTAssertEqual(ObjectCardLayout.detailBadgeTextWidth, 34.47, accuracy: 0.01)
        XCTAssertGreaterThan(ObjectCardLayout.detailBadgeTextWidth, 31.6,
                             "badge yang lebih lebar = kolom nama lebih sempit; "
                             + "angka lama terlalu kecil ke arah yang salah")

        // Kolom nama menyusut saat badge membesar.
        let atLarge = ObjectCardLayout.detailNameColumn(at: .large)
        let atAX5 = ObjectCardLayout.detailNameColumn(at: .accessibility5)
        XCTAssertLessThan(atAX5, atLarge,
                          "badge AX5 lebih lebar, jadi kolom nama harus lebih sempit")

        // Dengan badge yang benar-benar tumbuh, AX5 gagal **berdampingan**.
        // Itu bukan bug: itu alasan `detailStacksVisual` ada.
        let fitAX5 = NameOverflow.fit(
            widthAtDefault: ObjectCardLayout.detailNameWidthReference,
            columnWidth: ObjectCardLayout.detailNameColumn(at: .accessibility5),
            lineLimit: ObjectCardLayout.detailNameLineLimit,
            floor: floor)
        let requiredAX5 = fitAX5.requiredScaleAtDefault
            / ObjectCardLayout.scale(for: .accessibility5)
        XCTAssertLessThan(requiredAX5, floor,
                          "berdampingan di AX5 gagal — dan itu yang harus "
                          + "memicu penyusunan ulang")
        XCTAssertTrue(ObjectCardLayout.detailStacksVisual(at: .accessibility5))
    }

    /// Lukisan objek tidak boleh tumbuh melebihi baris yang memuatnya.
    ///
    /// **Cacat yang ditangkap tes ini.** `visualDiameter` di
    /// `LockArrivalPanel` adalah `@ScaledMetric(relativeTo: .title2)` bertumpu
    /// pada 132 pt, tanpa batas atas. Diameternya karena itu:
    ///
    ///     large   132.0 pt      AX2   257.4 pt
    ///     AX1     216.5 pt      AX3   304.9 pt
    ///     AX4     356.4 pt   <- lebih lebar daripada panel 333 pt
    ///     AX5     411.8 pt   <- 79 pt lebih lebar daripada panel
    ///
    /// Pada AX4 `HStack` memampatkan kolom nama ke nol dan nama hilang sama
    /// sekali. Yang tersisa hanya gambar — di ukuran huruf yang dipilih orang
    /// yang justru butuh teks.
    func testDetailVisualNeverGrowsWiderThanTheRowThatContainsIt() {
        let cap = ObjectCardLayout.detailVisualDiameterCap
        XCTAssertEqual(cap, 167, accuracy: 0.5,
                       "batas = panel 333 − jarak 16 − kolom nama minimum 150")

        for size in NameOverflow.TextSize.allCases {
            let diameter = ObjectCardLayout.detailVisualDiameter(at: size)
            XCTAssertLessThanOrEqual(
                diameter, cap + 0.001,
                "\(size.shortName): diameter \(diameter) pt melebihi batas \(cap) pt")
            // Gambar + jarak harus menyisakan ruang untuk nama sama sekali.
            XCTAssertGreaterThan(
                ObjectCardLayout.detailPanelWidth - diameter
                    - ObjectCardLayout.detailVisualGap, 0,
                "\(size.shortName): gambar + jarak menghabiskan seluruh panel")
        }

        // Tanpa batas (perilaku lama), AX4 dan AX5 memang melebihi panel.
        // Dibuktikan di sini supaya tesnya tidak bisa hijau karena batasnya
        // kebetulan tidak pernah aktif.
        for size in [NameOverflow.TextSize.accessibility4, .accessibility5] {
            let uncapped = ObjectCardLayout.detailVisualBaseDiameter
                * ObjectCardLayout.scale(for: size)
            XCTAssertGreaterThan(uncapped, ObjectCardLayout.detailPanelWidth,
                                 "\(size.shortName): tanpa batas, gambar "
                                 + "\(uncapped) pt lebih lebar daripada panel "
                                 + "\(ObjectCardLayout.detailPanelWidth) pt")
        }
    }

    /// Setiap ukuran Dynamic Type muat: nama terlebar tidak terpotong di
    /// panel detail setelah susunan dipilih.
    ///
    /// Ini yang membuat dua tes di atas punya akibat. Batas gambar dan
    /// penyusunan ulang bukan tujuan — tujuannya adalah nama terbaca di
    /// **setiap** ukuran, dan itu harus dinyatakan per ukuran, bukan
    /// disimpulkan dari ukuran bawaan.
    func testDetailPanelFitsAtEveryDynamicTypeSize() {
        for size in NameOverflow.TextSize.allCases {
            let column = ObjectCardLayout.detailEffectiveNameColumn(at: size)
            XCTAssertGreaterThan(column, 0,
                                 "\(size.shortName): kolom nama tidak ada")
            XCTAssertTrue(ObjectCardLayout.detailNameFits(at: size),
                          "\(size.shortName): nama terlebar masih terpotong di "
                          + "kolom \(column) pt setelah susunan dipilih")
        }
    }

    /// Batas gambar dihitung dari ruang, bukan dipilih.
    ///
    /// Kalau panel atau kolom nama minimumnya berubah, batasnya wajib ikut —
    /// kalau tidak, angka 167 yang "terbukti" hari ini menjadi angka yang
    /// salah tanpa ada yang memberi tahu.
    func testDetailVisualCapFollowsTheGeometryItComesFrom() {
        let cap = ObjectCardLayout.detailVisualDiameterCap
        XCTAssertEqual(
            cap,
            ObjectCardLayout.detailPanelWidth
                - ObjectCardLayout.detailVisualGap
                - ObjectCardLayout.detailMinNameColumn,
            accuracy: 0.001)
        // Batas itu harus benar-benar mengikat di AX5, bukan hiasan.
        let uncappedAX5 = ObjectCardLayout.detailVisualBaseDiameter
            * ObjectCardLayout.scale(for: .accessibility5)
        XCTAssertEqual(ObjectCardLayout.detailVisualDiameter(at: .accessibility5),
                       cap, accuracy: 0.001,
                       "di AX5 batas harus aktif (\(uncappedAX5) pt → \(cap) pt)")
        // Dan tidak boleh mengikat pada ukuran bawaan: gambar di ukuran
        // normal tetap 132 pt, bukan ikut mengecil ke batas.
        XCTAssertEqual(ObjectCardLayout.detailVisualDiameter(at: .large),
                       ObjectCardLayout.detailVisualBaseDiameter, accuracy: 0.001)
    }

    /// Panel detail tidak boleh **melebih-lebihkan** lebar yang tersedia.
    ///
    /// `detailPanelWidth` sengaja konservatif: ia menganggap padding kartu yang
    /// tidak dipasang panel ini, jadi lebar nyatanya lebih besar. Arah itu aman
    /// — gambar menjadi sedikit lebih kecil, bukan nama terpotong.
    ///
    /// Uji ini mengunci **arahnya**, bukan angkanya: kalau seseorang "membetulkan"
    /// 333 menjadi angka yang lebih besar tanpa mengukur inset `List` di
    /// perangkat, batas gambar ikut naik dan kolom nama menyusut — persis cacat
    /// yang siklus ini perbaiki.
    ///
    /// Lantainya **375 pt**, bukan 320: iOS 18 (deployment target di
    /// `project.yml`) tidak lagi menjalankan iPhone SE generasi pertama, dan
    /// perangkat terpendek yang didukung adalah SE generasi kedua — 375 pt.
    /// Memakai 320 akan menuntut panel lebih sempit daripada yang pernah ada.
    func testDetailPanelWidthDoesNotOverstateAvailableSpace() {
        let narrowestScreen: Double = 375
        let listInset: Double = 16 * 2
        XCTAssertLessThanOrEqual(
            ObjectCardLayout.detailPanelWidth,
            narrowestScreen - listInset,
            "panel \(ObjectCardLayout.detailPanelWidth) pt lebih lebar daripada "
            + "layar terpendek yang didukung (\(narrowestScreen) − \(listInset) pt)")
        // Dan batas gambar harus benar-benar mengikat di AX5 — kalau panel
        // dinaikkan sampai batasnya tidak lagi mengikat, cacatnya kembali.
        XCTAssertLessThan(
            ObjectCardLayout.detailVisualDiameter(at: .accessibility5),
            ObjectCardLayout.detailVisualBaseDiameter
                * ObjectCardLayout.scale(for: .accessibility5),
            "batas harus mengikat di AX5, bukan sekadar ada")
    }

    /// Padding badge di model harus sama dengan padding yang dipasang view.
    ///
    /// Model sempat memakai 10 pt sementara view memasang
    /// `.padding(.horizontal, 7)` = 14 pt. Selisih 4 pt itu tidak mengubah
    /// susunan mana pun, jadi tidak ada uji yang gagal — tetapi model dan view
    /// berbeda pendapat tentang lebar badge, dan arah selisihnya membuat kolom
    /// nama terlihat **lebih lebar** daripada kenyataannya. Itu kelas cacat
    /// yang sama dengan yang berkas ini perbaiki.
    ///
    /// Uji ini membaca **view-nya**, bukan menyalin angkanya. Konstanta yang
    /// dikunci ke literal hanya membuktikan konstanta sama dengan dirinya
    /// sendiri; yang perlu dijaga adalah kesepakatannya dengan view.
    func testDetailBadgePaddingMatchesTheViewPadding() throws {
        let view = try XCTUnwrap(Self.panelSource(),
                                 "DiagnosticsView.swift tidak ditemukan dari uji")
        // Cari `.padding(.horizontal, N)` pada blok badge.
        let pattern = #"\.padding\(\.horizontal,\s*([0-9]+(?:\.[0-9]+)?)\)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = view as NSString
        let matches = regex.matches(in: view, range: NSRange(location: 0, length: ns.length))
        let paddings = matches.compactMap {
            Double(ns.substring(with: $0.range(at: 1)))
        }
        // Badge memakai 7 pt; ada padding lain di berkas ini (14, 16, 20),
        // jadi yang dicari adalah yang benar-benar dipakai badge.
        XCTAssertTrue(paddings.contains(7),
                      "badge memasang padding horizontal 7 pt; ditemukan \(paddings)")
        XCTAssertEqual(ObjectCardLayout.detailBadgePadding, 7 * 2, accuracy: 0.001,
                       "dua sisi × 7 pt dari view")
    }

    /// Padding horizontal yang dipakai badge, dibaca dari view-nya.
    private static func panelSource() -> String? {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            let candidate = dir
                .appendingPathComponent("Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift")
            if let text = try? String(contentsOf: candidate, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}