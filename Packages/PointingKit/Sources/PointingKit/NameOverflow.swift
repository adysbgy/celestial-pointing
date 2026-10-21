import Foundation

/// Apakah nama objek **masih terbaca utuh** setelah Dynamic Type memperbesar
/// hurufnya — dihitung, bukan dipercaya.
///
/// **Cacat yang membuat berkas ini ada.** `swift-ui-lint.sh` Aturan 76 menjaga
/// bahwa setiap `Text(nama)` punya `.lineLimit`/`.minimumScaleFactor`. Ia
/// mengukur satu hal dengan benar: pada skala teks **bawaan** (title3 = 20 pt),
/// "Galaksi Kincir Angin" terukur 226.58 pt di kolom 96 pt kartu jam, jadi nama
/// butuh 2 baris pada skala 0.847 — di atas lantai 0.6, jadi terbaca utuh.
///
/// Yang tidak pernah diukur aturan itu: **apa yang terjadi saat hurufnya
/// membesar.** Angka 0.847 itu adalah hasil bagi pada skala 1.0. Setiap langkah
/// Dynamic Type mengalikan pembilangnya, penyebutnya tetap 96 pt. Terukur
/// (DejaVu Sans Bold, kolom 96 pt, 2 baris, lantai 0.6):
///
///     ukuran        lebar    skala wajib
///     Large         226.6      0.847   utuh
///     xxxLarge      305.9      0.628   utuh (tipis)
///     AX1           371.6      0.517   TERPOTONG
///     AX5           706.9      0.272   TERPOTONG
///
/// Jadi mulai AX1 — ukuran yang justru dipilih orang yang **butuh** huruf
/// besar — nama objek terpotong elipsis. Yang hilang bukan hiasan: "Gugus
/// Sarang Lebah" menjadi "Gugus Sarang…", dan pada katalog ini beberapa nama
/// berbagi awalan ("Galaksi Kincir Angin" / "Galaksi Andromeda" / "Galaksi
/// Triangulum"), sehingga yang terpotong justru **kata pembeda**-nya.
///
/// **Kenapa perhitungannya di `PointingKit`.** Lebar teks butuh font, dan font
/// tidak ada di Linux; tetapi **aritmetika luapan** tidak butuh font sama
/// sekali — ia butuh lebar acuan yang sudah terukur, lalu pembagian. Di sini ia
/// jadi pernyataan yang bisa gagal, bukan komentar di berkas lint yang tidak
/// bisa dijalankan uji. Lebar acuan diukur dari font DejaVu Sans Bold 20 pt
/// (font yang dipakai `check-visuals.py` dan Aturan 76) dan **diuji ulang**
/// terhadap tabel di `NameOverflowTests`.
///
/// **Yang TIDAK diklaim.**
/// - Angka lebar di sini **bukan** lebar teks San Francisco di perangkat.
///   Ia lebar DejaVu, font yang tersedia di Linux; SF sedikit lebih sempit.
///   Karena itu hasilnya dipakai sebagai **ambang kehati-hatian**, bukan
///   sebagai janji piksel: kalau SF lebih sempit, nama di perangkat terbaca
///   pada ukuran satu tingkat lebih besar daripada yang dihitung di sini.
/// - Skala Dynamic Type adalah **pendekatan** HIG, bukan tabel resmi Apple
///   yang diukur dari perangkat. Yang bisa diklaim: urutannya benar dan
///   besarannya benar (AX1 ≈ 1.6×, AX5 ≈ 3.1×), bukan bahwa 1.64 tepat.
/// - Model ini tidak tahu apa pun tentang wrapping bahasa: ia menganggap satu
///   baris butuh lebar penuh. Nama yang mengandung spasi bisa membungkus lebih
///   awal, dan itu membuat hasil sebenarnya **lebih buruk**, bukan lebih baik
///   — jadi arah kesalahannya aman.
public enum NameOverflow {

    /// Ukuran teks yang dikenal, dalam urutan naik.
    ///
    /// **Kenapa enum, bukan `String`.** Versi pertama berkas ini memetakan
    /// ukuran lewat namanya (`scale(forSizeNamed: "\(dynamicTypeSize)")`), dan
    /// itu cacat yang tidak akan tertangkap apa pun: `DynamicTypeSize` adalah
    /// enum SwiftUI yang diinterpolasi menjadi `"accessibility1"`, sementara
    /// tabelnya memakai `"AX1"`. Setiap ukuran aksesibilitas akan jatuh ke
    /// cabang "tidak dikenal" dan memakai skala terbesar — kebetulan arah yang
    /// aman di sini, tapi kebetulan yang sama bisa berbalik jadi sebaliknya.
    /// Dengan enum, pemetaan di view adalah `switch` yang diperiksa compiler:
    /// kasus SwiftUI baru memaksa keputusan, bukan diam-diam memilih cadangan.
    public enum TextSize: String, CaseIterable, Sendable {
        case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge
        case accessibility1, accessibility2, accessibility3, accessibility4, accessibility5

        /// Nama pendek untuk pesan gerbang dan dokumentasi ("AX1").
        public var shortName: String {
            switch self {
            case .accessibility1: return "AX1"
            case .accessibility2: return "AX2"
            case .accessibility3: return "AX3"
            case .accessibility4: return "AX4"
            case .accessibility5: return "AX5"
            default: return rawValue
            }
        }
    }

    /// Skala Dynamic Type per ukuran teks, relatif terhadap `.large` (= 1.0).
    ///
    /// Nilainya dibulatkan ke dua desimal dan **tidak** diklaim sebagai tabel
    /// Apple: ia pendekatan yang mempertahankan urutan dan besaran. Yang penting
    /// untuk keputusan di sini adalah di titik mana skala melewati lantai, dan
    /// itu tidak berubah oleh selisih 0.05.
    ///
    /// `.medium` dan `.large` sama-sama 1.00 karena keduanya adalah ukuran
    /// bawaan yang dipakai HIG untuk teks isi; membedakannya di sini akan
    /// mengarang selisih yang tidak ada.
    public static let dynamicTypeScales: [(size: TextSize, scale: Double)] = [
        (.xSmall, 0.82),
        (.small, 0.94),
        (.medium, 1.00),
        (.large, 1.00),
        (.xLarge, 1.12),
        (.xxLarge, 1.23),
        (.xxxLarge, 1.35),
        (.accessibility1, 1.64),
        (.accessibility2, 1.95),
        (.accessibility3, 2.31),
        (.accessibility4, 2.70),
        (.accessibility5, 3.12),
    ]

    /// Ukuran terbesar yang **masih** boleh dipakai tanpa memotong nama.
    ///
    /// `nil` berarti bahkan ukuran bawaan pun tidak muat — itu bukan "tidak
    /// ada batas", melainkan "kartu ini salah untuk nama selama-lamanya".
    public struct Fit: Equatable, Sendable {
        /// Skala terbesar yang masih muat, atau `nil` bila tak satu pun muat.
        public let largestFittingScale: Double?
        /// Ukuran terbesar yang masih muat, atau `nil` bila tak satu pun muat.
        public let largestFittingSize: TextSize?
        /// Skala yang dibutuhkan pada ukuran bawaan (`large`) — yaitu **ruang
        /// susut**: 0.823 berarti teks harus dikecilkan 18% agar muat, dan
        /// karena lantainya 0.6, nama masih terbaca. Nilai ≤ 0 atau `infinity`
        /// berarti kolomnya tidak ada, bukan "muat".
        public let requiredScaleAtDefault: Double

        /// Apakah ada setidaknya satu ukuran Dynamic Type yang memuat nama itu.
        public var fitsAtSomeSize: Bool { largestFittingScale != nil }
    }

    /// Hitung kecocokan satu nama pada satu kolom.
    ///
    /// - Parameters:
    ///   - widthAtDefault: lebar teks pada skala 1.0, dalam poin.
    ///   - columnWidth: lebar kolom tempat teks itu diletakkan, dalam poin.
    ///   - lineLimit: jumlah baris yang diizinkan.
    ///   - floor: `.minimumScaleFactor` yang dipasang di view.
    public static func fit(widthAtDefault: Double,
                           columnWidth: Double,
                           lineLimit: Int,
                           floor: Double) -> Fit {
        // Kolom selebar nol atau negatif bukan "muat" — ia kolom yang tidak ada.
        // Mengembalikan `infinity` di sini akan membuat setiap nama "muat" dan
        // gerbangnya hijau tanpa mengukur apa pun.
        guard columnWidth > 0, lineLimit > 0, widthAtDefault > 0 else {
            return Fit(largestFittingScale: nil, largestFittingSize: nil,
                       requiredScaleAtDefault: .infinity)
        }

        let capacity = columnWidth * Double(lineLimit)

        func requiredScale(at scale: Double) -> Double {
            capacity / (widthAtDefault * scale)
        }

        let atDefault = requiredScale(at: 1.0)
        var best: (size: TextSize, scale: Double)?

        // Urut dari kecil ke besar; ambil yang terbesar yang masih ≥ floor.
        for entry in dynamicTypeScales {
            if requiredScale(at: entry.scale) >= floor {
                best = (entry.size, entry.scale)
            }
        }

        return Fit(largestFittingScale: best?.scale,
                   largestFittingSize: best?.size,
                   requiredScaleAtDefault: atDefault)
    }

    /// Ukuran Dynamic Type terbesar yang **gagal** memuat nama, atau `nil` bila
    /// semuanya muat.
    ///
    /// Dipakai gerbang untuk menyebutkan kerusakannya dengan nama, bukan dengan
    /// angka: "terpotong mulai AX1" adalah kalimat yang bisa ditindaklanjuti.
    public static func firstFailingSize(widthAtDefault: Double,
                                        columnWidth: Double,
                                        lineLimit: Int,
                                        floor: Double) -> TextSize? {
        guard columnWidth > 0, lineLimit > 0, widthAtDefault > 0 else {
            return dynamicTypeScales.first?.size
        }
        let capacity = columnWidth * Double(lineLimit)
        for entry in dynamicTypeScales {
            if capacity / (widthAtDefault * entry.scale) < floor {
                return entry.size
            }
        }
        return nil
    }
}

/// Bagaimana kartu objek menyusun **gambar dan nama** pada satu ukuran teks.
///
/// **Cacat yang membuat ini ada.** Kartu objek di jam menyusun gambar 38 pt dan
/// teks dalam satu `HStack`, jadi nama selalu mendapat kolom 96 pt. Itu cukup
/// pada ukuran bawaan — dan itulah yang diukur Aturan 76, satu kali, pada 20 pt.
/// Tetapi Dynamic Type memperbesar huruf tanpa melebarkan kolom, sehingga pada
/// AX1 nama butuh susut 0.517 sementara lantainya 0.6: nama terpotong elipsis
/// tepat pada ukuran yang dipilih orang yang butuh huruf besar.
///
/// **Kenapa menyusun ulang, bukan mengecilkan lebih jauh.** Lantai
/// `.minimumScaleFactor(0.6)` ada karena teks di bawah ~60% ukuran dasarnya
/// berhenti menjadi "lebih besar" dan mulai menjadi teks kecil — memaksa nama
/// muat dengan menurunkan lantai akan mengembalikan cacatnya sebagai huruf yang
/// tidak terbaca, yang lebih buruk karena tidak terlihat sebagai cacat. Yang
/// bisa tumbuh adalah **kolomnya**: gambar dipindah ke atas nama, dan nama
/// mendapat lebar penuh kartu (142 pt).
///
/// **Kenapa ambangnya "akan terpotong", bukan daftar ukuran.** Daftar
/// (`AX1`, `AX2`, …) mengikat keputusan ke nama ukuran, dan nama itu bisa
/// bergeser bila lebar kartu, `lineLimit`, atau lantainya berubah — saat itu
/// kartu menyusun ulang terlalu cepat atau terlalu lambat tanpa ada yang
/// memberitahu. Menyusun ulang **tepat ketika** tata letak lama akan memotong
/// nama membuat keputusannya selalu mengikuti pengukuran yang sama.
public enum ObjectCardLayout {

    /// Lebar kolom nama saat gambar di samping teks: kartu 162 pt − padding
    /// 10×2 − gambar 38 pt − spacing 8 pt.
    public static let sideBySideNameColumn: Double = 96

    /// Lebar kolom nama saat gambar di atas teks: kartu 162 pt − padding 10×2.
    public static let stackedNameColumn: Double = 142

    public static let nameLineLimit = 2

    /// Jumlah baris yang **cukup** untuk nama pada ukuran teks ini.
    ///
    /// **Kenapa baris, bukan hanya lebar.** Menggeser gambar ke atas nama
    /// (kolom 96 → 142 pt) membeli ruang 48%, tetapi Dynamic Type membesarkan
    /// huruf sampai 212% (AX5 3.12× vs AX2 1.95×). Terukur pada nama terlebar
    /// (233.22 pt, lantai 0.6, kolom susunan 142 pt):
    ///
    ///     ukuran   skala   butuh kolom   di kolom 142
    ///     AX1      1.64      114.7 pt    muat (2 baris)
    ///     AX2      1.95      136.4 pt    muat (2 baris)
    ///     AX3      2.31      161.6 pt    TERPOTONG
    ///     AX5      3.12      218.3 pt    TERPOTONG
    ///
    /// Jadi menyusun ulang saja **tidak cukup** — ia hanya menunda kegagalan
    /// dari AX1 ke AX3. Yang benar-benar bertambah saat huruf membesar adalah
    /// **tinggi**, bukan lebar: kartu ada di dalam `ScrollView`, jadi baris
    /// tambahan tidak merebut ruang dari apa pun. Menahan `lineLimit` di 2
    /// sambil berharap kolom yang lebih lebar menyelamatkan nama adalah
    /// menukar satu dimensi tetap dengan dimensi lain yang juga tetap.
    public static func nameLineLimit(at size: NameOverflow.TextSize) -> Int {
        linesNeeded(at: size, columnWidth: stackedNameColumn,
                    floor: nameScaleFloor, minimum: nameLineLimit)
    }

    /// Jumlah baris minimum agar nama terlebar muat di kolom selebar
    /// `columnWidth` pada ukuran teks `size`.
    ///
    /// Dipakai bersama oleh tiga permukaan yang lebar kolomnya berbeda — kartu
    /// jam, layar Always-On, dan (lewat angkanya) panel iPhone. Satu rumus,
    /// karena tiga salinan rumus yang sama adalah tiga kesempatan berbeda
    /// pendapat. Yang berbeda antarpermukaan hanya **lebar kolom** dan
    /// **lantai skalanya**, dan keduanya parameter.
    public static func linesNeeded(at size: NameOverflow.TextSize,
                                   columnWidth: Double,
                                   floor: Double,
                                   minimum: Int = 1) -> Int {
        guard columnWidth.isFinite, columnWidth > 0,
              floor.isFinite, floor > 0 else { return minimum }
        let needed = nameWidthReference * scale(for: size) * floor / columnWidth
        guard needed.isFinite else { return minimum }
        return max(minimum, Int(needed.rounded(.up)))
    }

    /// Lebar kolom nama di layar Always-On: lebar layar jam 162 pt − padding
    /// horizontal 2×2 pt.
    public static let alwaysOnNameColumn: Double = 158

    /// Lantai skala di layar Always-On. Lebih rendah dari kartu (0.5 vs 0.6)
    /// karena layar itu memang lebih sempit dan lebih mendesak.
    public static let alwaysOnScaleFloor: Double = 0.5

    /// Jumlah baris yang cukup untuk nama di layar **Always-On**.
    ///
    /// Terukur (nama terlebar 233.22 pt pada `.title2` = 256.54 pt, kolom
    /// 158 pt, lantai 0.5):
    ///
    ///     ukuran   butuh 2 baris   hasil
    ///     AX3        148.2 pt      muat
    ///     AX4        173.2 pt      TERPOTONG
    ///     AX5        200.1 pt      TERPOTONG
    ///
    /// Layar Always-On adalah permukaan yang **paling** mungkin dipakai dengan
    /// huruf besar: pengguna yang memasang jam di pergelangan dan tidak bisa
    /// mengangkat tangan adalah pengguna yang paling butuh teks besar. Di sana
    /// nama terpotong mulai AX4 dengan `lineLimit(2)` yang tetap.
    public static func alwaysOnLineLimit(at size: NameOverflow.TextSize) -> Int {
        linesNeeded(at: size, columnWidth: alwaysOnNameColumn,
                    floor: alwaysOnScaleFloor, minimum: 2)
    }

    /// Lantai `.minimumScaleFactor` yang dipasang di view. Sama dengan yang
    /// dipakai Aturan 76 dan yang diuji `NameOverflowTests`.
    public static let nameScaleFloor: Double = 0.6

    /// Apakah nama **harus** mendapat lebar penuh kartu pada skala teks ini.
    ///
    /// - Parameter scale: skala Dynamic Type aktif (1.0 = bawaan).
    public static func stacksName(scale: Double) -> Bool {
        // Skala tak masuk akal diperlakukan sebagai "butuh lebar penuh": arah
        // kelalaian yang salah adalah menganggap ruang cukup.
        guard scale.isFinite, scale > 0 else { return true }
        let fit = NameOverflow.fit(widthAtDefault: nameWidthReference,
                                   columnWidth: sideBySideNameColumn,
                                   lineLimit: nameLineLimit,
                                   floor: nameScaleFloor)
        // Nama yang bahkan tidak muat di lebar penuh tidak diselamatkan oleh
        // susunan mana pun; menyusun ulang tetap dilakukan karena kolom lebih
        // lebar selalu lebih baik daripada kolom sempit.
        return fit.requiredScaleAtDefault / scale < nameScaleFloor
    }

    /// Lebar acuan nama terpanjang di katalog, diukur dari DejaVu Sans Bold
    /// 20 pt — angka yang sama dengan `NameOverflowTests.widestNameWidth`.
    ///
    /// Disimpan di sini sebagai konstanta, bukan dibaca dari tes: `Apps/` tidak
    /// bisa mengimpor tes, dan angka yang ditulis ulang di view adalah angka
    /// yang tidak bisa ditahan uji apa pun. Tesnya menegaskan kedua salinan itu
    /// sama.
    public static let nameWidthReference: Double = 233.22

    /// Skala Dynamic Type untuk sebuah ukuran teks, memakai tabel yang sama
    /// dengan `NameOverflow` supaya keputusan tata letak dan keputusan
    /// keterbacaan tidak bisa berbeda pendapat.
    ///
    /// Menerima `NameOverflow.TextSize`, bukan `String`: nama ukuran yang
    /// dirakit dari interpolasi adalah tautan yang tidak diperiksa compiler —
    /// `DynamicTypeSize` SwiftUI menjadi `"accessibility1"` sementara tabelnya
    /// memakai `"AX1"`, dan tautan seperti itu putus tanpa satu pun galat.
    public static func scale(for size: NameOverflow.TextSize) -> Double {
        NameOverflow.dynamicTypeScales.first { $0.size == size }?.scale
            ?? (NameOverflow.dynamicTypeScales.last?.scale ?? 1.0)
    }

    /// Apakah nama harus mendapat lebar penuh kartu pada **ukuran teks** ini.
    ///
    /// Bentuk yang dipakai view; `stacksName(scale:)` di bawah adalah bentuk
    /// yang diuji. Keduanya memakai perhitungan yang sama.
    public static func stacksName(at size: NameOverflow.TextSize) -> Bool {
        stacksName(scale: scale(for: size))
    }

    // MARK: - Panel detail iPhone (lukisan objek + nama)
    //
    // **Cacat yang membuat ini ada.** Panel detail iPhone menaruh
    // `CelestialVisualView` dan kolom nama dalam satu `HStack`, dan lukisannya
    // memakai `@ScaledMetric(relativeTo: .title2)` bertumpu pada 132 pt. Itu
    // benar untuk teks, dan salah untuk gambar: `@ScaledMetric` menaikkan
    // diameternya bersama huruf, tanpa satu pun batas atas. Terukur dengan
    // tabel skala yang sama dengan `NameOverflow.dynamicTypeScales`:
    //
    //     ukuran   skala   diameter   lebar panel 353 pt
    //     large    1.00     132.0 pt   muat
    //     AX1      1.64     216.5 pt   muat
    //     AX2      1.95     257.4 pt   muat
    //     AX3      2.31     304.9 pt   muat (kolom nama 32 pt)
    //     AX4      2.70     356.4 pt   MELEBIHI panel: kolom nama −19 pt
    //     AX5      3.12     411.8 pt   MELEBIHI panel: kolom nama −75 pt
    //
    // Pada AX4 lukisan objeknya **lebih lebar daripada baris yang memuatnya**.
    // SwiftUI tidak melaporkan itu sebagai galat: `HStack` memampatkan kolom
    // teks ke nol, nama hilang, dan yang tersisa hanya gambar besar — di
    // ukuran huruf yang justru dipilih orang yang butuh teks besar.
    //
    // **Kenapa ada batas atas, padahal di tempat lain "jangan angka tetap".**
    // Di kartu jam, gambar 38 pt tetap benar karena kartunya sendiri tetap.
    // Di sini yang berubah adalah **huruf**, dan gambar tidak perlu ikut
    // membesar tanpa batas untuk tetap terbaca: setelah beberapa kali, ia
    // berhenti menjadi informasi dan mulai menjadi penghalang. Batasnya bukan
    // angka pilihan — ia adalah sisa ruang setelah kolom nama minimum
    // dijamin, jadi ia bergerak kalau panel atau kolom minimumnya berubah.

    /// Lebar isi panel detail iPhone.
    ///
    /// **Angka ini sengaja konservatif, dan tidak diklaim tepat.** Rumusnya
    /// menganggap padding kartu 2×14 pt, sedangkan panel ini sebenarnya baris
    /// `List` tanpa kartu — jadi lebar nyatanya **lebih besar** daripada 333,
    /// bukan lebih kecil. Arah kelalaiannya aman: batas gambar jadi lebih
    /// rendah dan kolom nama lebih lebar daripada yang dimodelkan, sehingga
    /// yang terjadi di layar adalah gambar sedikit lebih kecil — bukan nama
    /// terpotong. Angka pastinya bergantung pada inset `List` bawaan iOS yang
    /// tidak bisa diukur dari Linux, jadi ia tidak ditebak ulang di sini.
    public static let detailPanelWidth: Double = 333

    /// Diameter dasar lukisan objek di panel detail, pada `.title2` bawaan.
    public static let detailVisualBaseDiameter: Double = 132

    /// Jarak antara lukisan dan kolom teks di panel detail.
    public static let detailVisualGap: Double = 16

    /// Kolom nama minimum yang masih layak untuk menyusun berdampingan.
    ///
    /// 150 pt ≈ enam huruf `.title2` selebar rata-rata, atau sekitar dua
    /// pertiga dari nama terlebar (256.54 pt). Di bawah ini nama bukan lagi
    /// "terpotong sedikit" melainkan "tidak terbaca", dan menyusun berdampingan
    /// berhenti membeli apa pun.
    public static let detailMinNameColumn: Double = 150

    /// Batas atas diameter lukisan objek di panel detail.
    ///
    /// Dihitung dari sisa ruang, bukan dipilih: panel − jarak − kolom nama
    /// minimum. 333 − 16 − 150 = **167 pt**.
    public static var detailVisualDiameterCap: Double {
        detailPanelWidth - detailVisualGap - detailMinNameColumn
    }

    /// Diameter lukisan objek pada ukuran teks `size`, **dibatasi**.
    ///
    /// Bentuk yang dipakai view. Tanpa `min` di sini, `@ScaledMetric` tetap
    /// membesar tanpa batas dan cacatnya kembali.
    public static func detailVisualDiameter(at size: NameOverflow.TextSize) -> Double {
        let raw = detailVisualBaseDiameter * scale(for: size)
        guard raw.isFinite, raw > 0 else { return detailVisualBaseDiameter }
        return min(raw, detailVisualDiameterCap)
    }

    /// Lebar teks badge keyakinan pada ukuran bawaan, terukur.
    ///
    /// 34.47 pt = "Ragu" DejaVu Sans Bold 12 pt (`.caption`):
    ///
    ///     python3 -c "from PIL import ImageFont; \
    ///       print(ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',12) \
    ///       .getlength('Ragu'))"
    ///
    /// **Bukan 31.6.** Angka itu dipakai `NameOverflowTests` sebelum ini dan
    /// 2.9 pt lebih kecil daripada font yang diklaimnya — arah kelalaian yang
    /// salah, karena badge yang lebih lebar berarti kolom nama yang lebih
    /// sempit. Tes menegaskan kedua angka itu tidak sama, supaya angka lama
    /// tidak diam-diam kembali.
    public static let detailBadgeTextWidth: Double = 34.47

    /// Padding horizontal badge (`7` pt × 2) — **14**, bukan 10.
    ///
    /// Angka 10 lebih kecil daripada font yang diklaimnya, dan arah kelalaiannya
    /// salah: badge yang lebih lebar berarti kolom nama yang lebih sempit.
    /// View memasang `.padding(.horizontal, 7)`, jadi totalnya 14 pt. Selisih
    /// 4 pt ini tidak mengubah susunan mana pun, tetapi ia membuat model dan
    /// view berbeda pendapat — persis kelas cacat yang berkas ini perbaiki.
    public static let detailBadgePadding: Double = 14

    /// Jarak nama ke badge.
    public static let detailBadgeGap: Double = 8

    /// Lantai `.minimumScaleFactor` yang dipasang panel detail.
    public static let detailNameScaleFloor: Double = 0.7

    /// `lineLimit` nama di panel detail.
    public static let detailNameLineLimit = 2

    /// Lebar acuan nama terlebar pada `.title2`: 233.22 × 22/20.
    public static let detailNameWidthReference: Double = 256.54

    /// Kolom nama yang benar-benar tersisa saat gambar **dan** badge dihitung.
    ///
    /// Badge ikut dihitung karena `.caption` juga diskalakan Dynamic Type:
    /// menahannya di lebar bawaan membuat anggarannya terlalu longgar tepat
    /// pada ukuran yang paling sempit.
    public static func detailNameColumn(at size: NameOverflow.TextSize) -> Double {
        detailPanelWidth
            - detailVisualDiameter(at: size)
            - detailVisualGap
            - (detailBadgeTextWidth * scale(for: size) + detailBadgePadding + detailBadgeGap)
    }

    /// Apakah lukisan objek harus dipindah **di atas** nama pada ukuran ini.
    ///
    /// Sama alasannya dengan kartu jam (`stacksName`): yang bertambah saat
    /// huruf membesar adalah tinggi, bukan lebar, dan panel ada di dalam
    /// `List` — baris tambahan tidak merebut ruang dari apa pun.
    public static func detailStacksVisual(at size: NameOverflow.TextSize) -> Bool {
        let fit = NameOverflow.fit(widthAtDefault: detailNameWidthReference,
                                   columnWidth: detailNameColumn(at: size),
                                   lineLimit: detailNameLineLimit,
                                   floor: detailNameScaleFloor)
        return fit.requiredScaleAtDefault / scale(for: size) < detailNameScaleFloor
    }

    /// Kolom nama yang berlaku setelah susunan dipilih.
    ///
    /// Disusun = lebar panel penuh (badge turun ke baris sendiri); berdampingan
    /// = `detailNameColumn`. Dipakai uji untuk menyatakan bahwa **setiap**
    /// ukuran muat, bukan hanya ukuran bawaan.
    public static func detailEffectiveNameColumn(at size: NameOverflow.TextSize) -> Double {
        detailStacksVisual(at: size) ? detailPanelWidth : detailNameColumn(at: size)
    }

    /// Apakah nama terlebar muat di panel ini **pada ukuran teks ini**, setelah
    /// susunan yang berlaku di ukuran itu dipilih.
    ///
    /// **Kenapa bukan `firstFailingSize`.** Fungsi itu menjawab pertanyaan yang
    /// berbeda: "pada kolom tetap ini, ukuran mana yang gagal". Panel detail
    /// tidak punya kolom tetap — kolomnya berubah bersama susunan, dan
    /// susunannya berubah bersama ukuran. Menyodorkan kolom satu ukuran ke
    /// `firstFailingSize` melaporkan kegagalan di ukuran yang justru sudah
    /// ditangani, dan gerbangnya jadi merah pada tata letak yang benar.
    public static func detailNameFits(at size: NameOverflow.TextSize) -> Bool {
        let fit = NameOverflow.fit(
            widthAtDefault: detailNameWidthReference,
            columnWidth: detailEffectiveNameColumn(at: size),
            lineLimit: detailNameLineLimit,
            floor: detailNameScaleFloor)
        guard fit.requiredScaleAtDefault.isFinite else { return false }
        return fit.requiredScaleAtDefault / scale(for: size) >= detailNameScaleFloor
    }
}
