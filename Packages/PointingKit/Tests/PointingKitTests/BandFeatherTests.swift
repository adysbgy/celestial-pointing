import XCTest
@testable import PointingKit

/// Uji `CelestialVisual.bandFeatherWeight`.
///
/// **Cacat yang ditutup uji ini.** Pita Jupiter digambar sebagai poligon warna
/// **rata** yang bersambung, jadi batas antar pita adalah langkah satu piksel.
/// Diukur pada port Python (render 200 px, ss=2, di dalam piringan): lompatan
/// terang terbesar **132.32/255**, sementara median langkah antar piksel
/// bersebelahan **0.93/255** — 142×. Pada ukuran yang benar-benar dikirim ke
/// jam (76 px) lompatannya masih **83.63/255** terhadap median 2.00. Di mata itu
/// terbaca sebagai pita isolasi yang ditempel.
///
/// **Kenapa ujinya di sini, bukan hanya di gerbang piksel.** Gerbang piksel
/// mengukur port Python. Yang dikirim ke jam adalah view SwiftUI, dan view
/// punya cara gagalnya sendiri: ia bisa berhenti memanggil pelembutan ini, atau
/// memanggilnya dengan lebar yang ditulis ulang alih-alih dibaca dari model.
/// Uji ini mengunci **bentuk kurvanya**, sehingga angkanya tidak bisa digeser
/// tanpa ada yang tahu.
///
/// **Yang TIDAK diklaim.** Ini bukan model atmosfer: tidak ada hamburan,
/// tidak ada tinggi skala, tidak ada ketergantungan panjang gelombang. Yang
/// diuji hanya bahwa langkah warna di batas pita hilang.
final class BandFeatherTests: XCTestCase {

    /// Di tengah pita tidak ada pencampuran sama sekali.
    ///
    /// Kalau ini gagal, pita kehilangan nada aslinya dan gerbang
    /// keterpisahan pita (`check_band_separation`) akan mengukur angka yang
    /// berbeda dari yang dulu.
    func testBandCentreIsUntouched() {
        XCTAssertEqual(CelestialVisual.bandFeatherWeight(atFraction: 0.5), 0.0,
                       accuracy: 1e-12)
        XCTAssertEqual(CelestialVisual.bandFeatherWeight(atFraction: 0.0), 0.5,
                       accuracy: 1e-12)
        XCTAssertEqual(CelestialVisual.bandFeatherWeight(atFraction: 1.0), 0.5,
                       accuracy: 1e-12)
    }

    /// Tepat di batas dua pita, kedua sisi menyumbang **sama besar**.
    ///
    /// Inilah yang menghapus langkahnya. Kalau satu sisi lebih berat, batasnya
    /// hanya bergeser, bukan melembut.
    func testSharedEdgeIsSymmetricAcrossNeighbours() {
        let topEdge = CelestialVisual.bandFeatherWeight(atFraction: 0.0)
        let bottomEdge = CelestialVisual.bandFeatherWeight(atFraction: 1.0)
        XCTAssertEqual(topEdge, bottomEdge, accuracy: 1e-12)
        XCTAssertEqual(topEdge, 0.5, accuracy: 1e-12,
                       "di batas pita, tetangga harus menyumbang separuh")
    }

    /// Kurvanya monoton: makin ke tengah, makin kecil pencampurannya.
    ///
    /// Tanpa monotonisitas, pelembutan bisa menghasilkan pita yang lebih
    /// tajam di suatu tempat daripada tanpa pelembutan — persis kebalikan
    /// dari yang dijanjikan.
    func testFeatherDecaysMonotonicallyTowardTheCentre() {
        var previous = Double.infinity
        for step in 0...10 {
            let t = Double(step) / 10.0 * 0.5   // 0 … 0.5 (tepi atas → tengah)
            let weight = CelestialVisual.bandFeatherWeight(atFraction: t)
            XCTAssertLessThanOrEqual(weight, previous + 1e-12,
                                     "berat tidak boleh naik menjauh dari tepi (t=\(t))")
            previous = weight
        }
        XCTAssertEqual(previous, 0.0, accuracy: 1e-12)
    }

    /// Lebar nol berarti tidak ada pelembutan — dan itu harus aman.
    ///
    /// `guard width > 0` ada karena pembagian dengan nol akan menghasilkan
    /// `NaN`, dan `NaN` yang masuk ke `Color(red:green:blue:)` membuat
    /// gambarnya hilang tanpa pesan apa pun.
    func testZeroWidthDisablesFeatheringInsteadOfProducingNaN() {
        for t in [0.0, 0.5, 1.0] {
            let weight = CelestialVisual.bandFeatherWeight(atFraction: t, width: 0)
            XCTAssertEqual(weight, 0.0, accuracy: 1e-12)
            XCTAssertFalse(weight.isNaN)
        }
    }

    /// Nilai `t` di luar 0…1 dijepit, bukan diekstrapolasi.
    ///
    /// Piksel di luar pita bisa ikut tersentuh karena pembulatan koordinat.
    /// Ekstrapolasi akan memberi berat **negatif** di sana, dan warna negatif
    /// memotong ke hitam — garis gelap tipis di batas pita, cacat yang lebih
    /// buruk daripada yang sedang diperbaiki.
    func testOutOfRangeFractionsAreClamped() {
        XCTAssertEqual(CelestialVisual.bandFeatherWeight(atFraction: -0.5), 0.5,
                       accuracy: 1e-12)
        XCTAssertEqual(CelestialVisual.bandFeatherWeight(atFraction: 1.5), 0.5,
                       accuracy: 1e-12)
    }

    /// Lebar pelembutan harus cukup besar untuk menutupi satu piksel pada
    /// ukuran terkecil yang dipakai, tetapi tidak sampai menghapus pitanya.
    ///
    /// Pada kartu jam 38 pt, satu pita tingginya ≈ 2/7 × 38 ≈ 10.9 pt. Dengan
    /// lebar 0.18, zona transisinya ≈ 2 pt di tiap tepi — cukup untuk
    /// melembutkan satu-dua piksel retina, dan masih menyisakan ≈ 60% tinggi
    /// pita yang memakai nada murni.
    func testFeatherWidthLeavesMostOfEachBandAtItsOwnTone() {
        let width = CelestialVisual.bandFeatherFraction
        XCTAssertGreaterThan(width, 0.0)
        XCTAssertLessThan(width, 0.5, "dua tepi tidak boleh bertemu di tengah pita")
        // Bagian yang tetap bernada murni.
        let pure = 1.0 - 2.0 * width
        XCTAssertGreaterThan(pure, 0.5,
                             "lebih dari separuh tiap pita harus tetap bernada aslinya")
    }

    /// **Kurva yang digambar view harus kurva model, di seluruh pita.**
    ///
    /// **Cacat yang ditutup uji ini, dan ia nyata.** Versi pertama unit ini
    /// menyusun gradien pita **tiga titik** di view: berat 0.5 di tepi atas,
    /// nol di tengah, 0.5 di tepi bawah. Port Python memakai **dataran**: 0.5
    /// di tepi, nol pada 18%, nol sampai tepi seberang. Keduanya menyebut
    /// konstanta yang sama (`bandFeatherFraction = 0.18`), jadi
    /// `check_port_matches_swift_constants` hijau — ia membandingkan
    /// **konstanta**, dan konstanta itu memang sama. Yang berbeda bentuk
    /// kurvanya, dan bentuk kurva tidak dibandingkan apa pun.
    ///
    /// Akibatnya bukan kosmetik: dengan segitiga, separuh nada tetangga
    /// merembes sampai ke pusat pita, jadi pita tidak lagi punya nadanya
    /// sendiri di mana pun selain garis tengah. Keterpisahan pita yang diukur
    /// `check_jupiter_bands_read_as_separate_stripes` (0.2125) hanya berlaku
    /// untuk port, bukan untuk gambar yang dikirim ke jam.
    ///
    /// **Kenapa 201 sampel, bukan empat titik.** Titik-titik `bandFeatherStops`
    /// dibandingkan dengan fungsinya tepat di lokasinya sendiri akan lulus
    /// bahkan kalau bagian di antaranya salah — dan bagian di antaranya justru
    /// yang membedakan segitiga dari dataran.
    func testStopsReproduceTheCurveEverywhereNotJustAtTheirOwnLocations() {
        for step in 0...200 {
            let t = Double(step) / 200.0
            let fromCurve = CelestialVisual.bandFeatherWeight(atFraction: t)
            let fromStops = CelestialVisual.bandFeatherWeightFromStops(atFraction: t)
            XCTAssertEqual(fromStops, fromCurve, accuracy: 1e-12,
                           "kurva gradien menyimpang dari model pada t=\(t)")
        }
        // Kontrol prasyarat: kurvanya memang **bukan** segitiga. Tanpa ini,
        // uji di atas akan lulus pada segitiga juga kalau fungsinya kebetulan
        // ikut diubah jadi segitiga — dan yang dijaga adalah selisih keduanya,
        // bukan keberadaan salah satunya.
        //
        // **Titik ujinya t=0.25, bukan t=0.5.** Di tengah pita kedua bentuk
        // bertemu di nol — segitiga selebar pita dan dataran sama-sama
        // bernilai nol di sana, jadi membandingkan di t=0.5 akan lulus pada
        // keduanya dan tidak membedakan apa pun. Yang membedakan justru
        // seperempat pita: segitiga masih 0.25, dataran sudah nol.
        func triangle(_ t: Double) -> Double {
            0.5 * max(0.0, 1.0 - 2.0 * min(t, 1.0 - t))
        }
        XCTAssertEqual(triangle(0.5), 0.0, accuracy: 1e-12,
                       "prasyarat: segitiga dan dataran memang bertemu di tengah")
        XCTAssertGreaterThan(abs(CelestialVisual.bandFeatherWeight(atFraction: 0.25)
                                 - triangle(0.25)), 0.2,
                             "kurvanya harus dataran, bukan segitiga selebar pita")
        // Dan selisihnya harus muncul di **seluruh** zona transisi, bukan satu
        // titik yang kebetulan berbeda.
        var maxGap = 0.0
        for step in 0...200 {
            let t = Double(step) / 200.0
            maxGap = max(maxGap, abs(CelestialVisual.bandFeatherWeight(atFraction: t)
                                     - triangle(t)))
        }
        XCTAssertGreaterThan(maxGap, 0.2,
                             "kurva model harus terpisah jelas dari segitiga")
    }

    /// Gradien harus **berbentuk V**: turun dari tepi atas ke dataran, datar di
    /// tengah, lalu naik lagi ke tepi bawah.
    ///
    /// **Kenapa bukan monoton turun.** Versi pertama uji ini menuntut berat
    /// tidak pernah naik, dan ia merah pada kode yang benar: kurvanya memang
    /// **cermin**, 0.5 → 0 → 0 → 0.5, karena kedua tepi pita bertemu nada
    /// tetangganya masing-masing. Yang berbahaya bukan kenaikan itu, melainkan
    /// **lokasi** yang tidak naik ketat: gradien SwiftUI menginterpolasi
    /// menurut urutan lokasi, jadi dua titik berlokasi sama atau berbalik
    /// membuat warna pita tetangga muncul lagi di tengah pita ini.
    func testStopsAreOrderedAndVShaped() {
        let stops = CelestialVisual.bandFeatherStops()
        XCTAssertEqual(stops.count, 4, "dataran butuh dua titik, plus dua tepi")
        for index in 1..<stops.count {
            XCTAssertGreaterThan(stops[index].location, stops[index - 1].location,
                                 "lokasi titik harus naik ketat")
        }
        // Turun menuju dataran...
        for index in 1..<2 {
            XCTAssertLessThanOrEqual(stops[index].weight, stops[index - 1].weight + 1e-12,
                                     "berat harus turun dari tepi ke dataran")
        }
        // ...datar di tengah...
        XCTAssertEqual(stops[1].weight, stops[2].weight, accuracy: 1e-12,
                       "dataran harus benar-benar rata")
        // ...lalu naik lagi ke tepi bawah.
        XCTAssertGreaterThanOrEqual(stops[3].weight, stops[2].weight - 1e-12,
                                    "berat harus naik lagi ke tepi bawah")
        XCTAssertEqual(stops.first?.location ?? -1, 0.0, accuracy: 1e-12)
        XCTAssertEqual(stops.last?.location ?? -1, 1.0, accuracy: 1e-12)
        XCTAssertEqual(stops.first?.weight ?? -1, 0.5, accuracy: 1e-12)
        XCTAssertEqual(stops.last?.weight ?? -1, 0.5, accuracy: 1e-12)
        XCTAssertEqual(stops[1].weight, 0.0, accuracy: 1e-12)
        XCTAssertEqual(stops[2].weight, 0.0, accuracy: 1e-12)
        // Kedua tepi harus simetris: pita tidak boleh lebih condong ke satu
        // tetangga, karena itu berarti nada pita ini bergeser ke salah satunya.
        XCTAssertEqual(stops.first?.weight ?? -1, stops.last?.weight ?? -2,
                       accuracy: 1e-12, "kedua tepi harus sama berat")
    }

    /// Lebar di luar rentang yang sah mengembalikan kurva **tanpa** pelembutan.
    ///
    /// Dua kasus berbeda dan keduanya harus aman: `0` (pelembutan dimatikan)
    /// dan `≥ 0.5` (dua tepi bertemu, kurva berhenti berupa dataran). Yang
    /// **tidak** boleh terjadi adalah kurva terlipat: berat negatif
    /// menghasilkan warna negatif, dan warna negatif memotong ke hitam —
    /// garis gelap di batas pita, lebih buruk daripada cacat aslinya.
    func testStopsRefuseToFoldWhenWidthIsTooLarge() {
        for width in [0.0, 0.5, 0.7, -0.2] {
            let stops = CelestialVisual.bandFeatherStops(width: width)
            XCTAssertEqual(stops.count, 2,
                           "lebar \(width) harus jatuh ke kurva datar, bukan dilipat")
            for stop in stops {
                XCTAssertEqual(stop.weight, 0.0, accuracy: 1e-12)
                XCTAssertFalse(stop.weight.isNaN)
            }
            for step in 0...20 {
                let t = Double(step) / 20.0
                XCTAssertEqual(CelestialVisual.bandFeatherWeightFromStops(
                                   atFraction: t, width: width), 0.0, accuracy: 1e-12)
            }
        }
    }
}
