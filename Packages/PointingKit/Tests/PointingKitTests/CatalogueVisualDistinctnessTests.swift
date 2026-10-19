import XCTest
@testable import PointingKit
import CelestialEngine

/// Setiap bintang di katalog harus tetap **terbedakan secara visual**.
///
/// **Apa yang dijaga, dan kenapa ini bukan kosmetik.** Titik bintang di layar
/// hanya membawa dua sinyal identitas: warna (dari indeks B−V lewat
/// `CelestialVisual.starColorIndex`) dan ukuran (dari magnitudo lewat
/// `relativeSize`). Dua bintang yang kebetulan punya **B−V dan magnitudo yang
/// sama** tidak bisa dibedakan oleh warna maupun ukuran — saat engine ragu dan
/// hanya terang yang tampil, keduanya bahkan menghilang menjadi titik abu
/// identik. Itu persis kelas "false confidence" yang PRD larang: layar tidak
/// bisa mengatakan mana yang sedang ditunjuk.
///
/// STATUS.md (progres 17 Okt 2026, baris ~647) mencatat celah ini secara
/// jujur sebagai *"celah yang belum ditutup dan belum relevan untuk katalog
/// sekarang"* — karena pasangan B−V identik di katalog (sirius/vega,
/// hadar/spica, fomalhaut/deneb) semuanya punya magnitudo berbeda. Uji ini
/// yang mengunci bahwa pernyataan itu tetap benar saat katalog bertambah:
/// menambah bintang baru yang kebetulan meniru B−V **dan** magnitudo bintang
/// yang sudah ada akan memerah di sini, bukan diam-diam menciptakan pasangan
/// tak-terbedakan.
///
/// **Kenapa di `PointingKit`, bukan di `CelestialEngine`.** Indeks B−V hidup di
/// `CelestialVisual` (lapisan visual, teruji di Linux), sementara magnitudo
/// hidup di `Catalogue.brightStars`. Keduanya harus dibandingkan di satu
/// tempat; lapisan visual adalah tempat yang benar, dan `Catalogue` sudah
/// diimpor lintas-paket oleh uji-uji tetangga (lihat `NightVisualTests`).
final class CatalogueVisualDistinctnessTests: XCTestCase {

    /// Tidak ada dua bintang katalog yang punya B−V **dan** magnitudo sama.
    ///
    /// Epsilon untuk B−V sengaja longgar (0,05): perbedaan kelas spektral
    /// sekecil itu sudah terlihat sebagai warna berbeda di layar (lihat
    /// `StarColorSpeech.starColorText`, yang memotong di −0,10 / 0,25 / 0,95 /
    /// 1,50 — semua selisih di atas 0,10 berarti label warna berbeda). Magnitudo
    /// dibandingkan persis (akurasi berkas), karena satu kelipatan magnitudo
    /// adalah satu langkah ukuran titik yang nyata.
    func testNoTwoStarsShareBothColorIndexAndMagnitude() {
        let epsilon: Double = 0.05
        let stars = Catalogue.brightStars

        var collisions: [(String, String)] = []
        for i in 0..<stars.count {
            for j in (i + 1)..<stars.count {
                let a = stars[i], b = stars[j]
                guard let bvA = CelestialVisual.starColorIndex[a.id],
                      let bvB = CelestialVisual.starColorIndex[b.id] else {
                    // Bintang tanpa entri B−V memanggil warna "tidak ada
                    // klaim" (NaN) — ia sudah tidak bisa mengklaim warna apa
                    // pun, jadi ia tidak ikut membentuk pasangan tak-terbedakan.
                    continue
                }
                let sameColor = abs(bvA - bvB) <= epsilon
                let sameMagnitude = a.magnitude == b.magnitude
                if sameColor && sameMagnitude {
                    collisions.append((a.id, b.id))
                }
            }
        }

        XCTAssertTrue(collisions.isEmpty,
                      "bintang tak-terbedakan secara visual: \(collisions)")
    }

    /// **Non-vakuositas.** Kontrol negatif: pasangan B−V identik yang memang
    /// ada di katalog (sirius/vega, hadar/spica) harus **berbeda magnitudo**,
    /// supaya uji di atas tidak lulus hanya karena ia lupa membandingkan
    /// magnitudo. Kalau baris ini gagal, itu berarti seluruh pasangan B−V
    /// identik ternyata juga sama magnitudonya — dan uji utama di atas baru
    /// saja kehilangan satu dari dua syaratnya.
    func testKnownColorTwinsStillDifferInMagnitude() {
        let twins: [(String, String)] = [
            ("sirius", "vega"),     // B−V 0,00 / 0,00
            ("hadar", "spica"),     // B−V −0,23 / −0,23
            ("fomalhaut", "deneb")  // B−V 0,09 / 0,09
        ]
        for (x, y) in twins {
            let mx = Catalogue.brightStars.first { $0.id == x }!.magnitude
            let my = Catalogue.brightStars.first { $0.id == y }!.magnitude
            XCTAssertNotEqual(mx, my,
                             "\(x)/\(y) B−V sama tapi magnitudo harus beda, " +
                             "supaya masih terbedakan ukuran titik")
        }
    }

    // MARK: - Objek langit dalam: tabrakan sinyal yang tidak terlihat

    /// Tiga sinyal yang menentukan gambar objek langit dalam.
    ///
    /// Semuanya dibaca dari **tabel katalog**, dan tidak satu pun tahu apa
    /// objeknya — itu yang membuatnya mungkin kebetulan sama:
    ///
    ///   * `morphology` → susunan blob (`VisualFrame.deepSky`)
    ///   * `fuzziness`  → seberapa lebar blob itu
    ///   * `elongation` → rasio sumbu siluet (hanya `.planetaryNebula`)
    ///
    /// Warna **tidak** ikut menjadi sinyal pembeda: `deepSkyColour(for:)`
    /// bergantung pada morfologi saja, jadi dua objek ber-morfologi sama
    /// selalu berwarna sama. Yang tersisa untuk membedakan mereka hanyalah
    /// ketiga angka di atas — dan kalau ketiganya sama, **tidak ada** satu
    /// pun di layar yang bisa dibedakan.
    private func deepSkySignature(_ object: CelestialObject) -> String {
        let morphology = DeepSkyCatalogue.morphology(forObjectID: object.id)
        let fuzziness = DeepSkyCatalogue.fuzziness(forObjectID: object.id)
        let elongation = DeepSkyCatalogue.elongation(forObjectID: object.id)
        return "morphology=\(morphology.map { String(describing: $0) } ?? "nil") "
             + "fuzziness=\(String(format: "%.4f", fuzziness)) "
             + String(format: "elongation=%.4f", elongation)
    }

    /// **Fakta terukur (19 Okt 2026) yang dikunci, bukan disembunyikan.**
    ///
    /// Pasangan `m7` (Gugus Ptolemy) dan `m41` (Gugus M41) di katalog **saat
    /// ini** bertabrakan di ketiga sinyal: sama-sama `.openCluster`,
    /// `fuzziness` 0,50, dan elongasi bawaan 1,0. `VisualFrame.deepSky` lalu
    /// menghasilkan tujuh blob dengan offset, setengah-lebar, dan opasitas
    /// yang **sama persis** — diukur lewat port render yang dipakai gerbang
    /// piksel: 7 blob identik, pada morfologi yang juga memberi warna yang
    /// sama. Artinya di layar, saat engine menunjuk M41, gambarnya = gambar
    /// M7; seluruh teks lain bisa benar sementara gambar milik benda lain.
    /// Itu kelas "gambar lebih yakin daripada teksnya" yang dilarang PRD.
    ///
    /// Dua jalan perbaikan yang **salah** dan sengaja tidak diambil:
    ///
    ///   1. Menurunkan `fuzziness` m41 ke 0,44 "memisahkan" penanda di atas
    ///      kertas, tetapi render nyatanya hanya berubah ~7% piksel (delta
    ///      kanal maks ~0,09) — tak terbaca mata pada kartu jam 38 pt. Itu
    ///      hijau palsu: uji lulus, pengguna tetap tak beda.
    ///   2. Menuntut "tidak ada pasangan yang tabrakan" memerah hari ini —
    ///      lalu melonggarkan entri tabel supaya hijau. Sama salahnya.
    ///
    /// Uji ini oleh karena itu **tidak** menuntut tabrakan hilang; ia menuntut
    /// *fakta* tabrakan itu tercatat dan *penanda* memang bekerja (uji
    /// non-vakuositas di bawah). Perbaikan yang jujur adalah **struktural**
    /// (misal elongasi/konsentrasi yang berlaku untuk gugus terbuka, atau
    /// bentuk yang berbeda), dan saat itu tiba, uji ini yang mengunci bahwa
    /// perbaikan itu benar-benar memisahkan sinyal — bukan cuma mencolek
    /// angka. Melaporkan begini, bukan hijau palsu, adalah agar siklus
    /// berikutnya tidak mengulang cacat "uji lulus padahal gambar sama".
    func testDeepSkyClusterPairCollisionIsRecordedNotHidden() {
        let m7 = DeepSkyCatalogue.objects.first { $0.id == "m7" }!
        let m41 = DeepSkyCatalogue.objects.first { $0.id == "m41" }!
        XCTAssertEqual(DeepSkyCatalogue.morphology(forObjectID: m7.id),
                       DeepSkyCatalogue.morphology(forObjectID: m41.id),
                       "prasyarat: keduanya gugus terbuka")
        XCTAssertEqual(deepSkySignature(m7), deepSkySignature(m41),
                       "tabrakan m7/m41 berubah — kalau ini gagal, perbaikinya " +
                       "harus memisahkan gambar, bukan cuma nilai tabel")
    }

    /// **Non-vakuositas penanda.** Kalau `deepSkySignature` mengembalikan satu
    /// nilai untuk semua objek (misal selalu jatuh ke bawaan), uji di atas
    /// lulus tanpa menangkap apa pun. Uji ini menuntut penanda benar-benar
    /// membaca ketiga sinyal: tiga pasangan yang **memang** berbeda bentuk
    /// harus punya penanda berbeda.
    func testDeepSkySignatureMarkerActuallySeparatesShapes() {
        let pleiades = DeepSkyCatalogue.objects.first { $0.id == "m45" }!  // gugus terbuka
        let hercules = DeepSkyCatalogue.objects.first { $0.id == "m13" }!  // gugus bola
        let andromeda = DeepSkyCatalogue.objects.first { $0.id == "m31" }! // galaksi
        XCTAssertNotEqual(deepSkySignature(pleiades), deepSkySignature(hercules),
                          "morfologi berbeda tapi penanda identik")
        XCTAssertNotEqual(deepSkySignature(pleiades), deepSkySignature(andromeda),
                          "galaksi dan gugus terbuka harus terbedakan")
        XCTAssertNotEqual(deepSkySignature(andromeda), deepSkySignature(hercules))
    }

    /// **Non-vakuositas sinyal elongasi.** M27/M57 sama-sama nebula planetari;
    /// satu-satunya pembeda di tabel adalah elongasi (0,60 vs 1,0). Kalau
    /// penanda mengabaikan elongasi, dua objek ini jadi kembar dan uji bentuk
    /// di atas cuma terhindar karena `fuzziness`-nya kebetulan berbeda.
    func testDeepSkySignatureMarkerReadsElongation() {
        let dumbell = DeepSkyCatalogue.objects.first { $0.id == "m27" }!
        let ring = DeepSkyCatalogue.objects.first { $0.id == "m57" }!
        XCTAssertEqual(DeepSkyCatalogue.morphology(forObjectID: "m27"),
                       DeepSkyCatalogue.morphology(forObjectID: "m57"),
                       "prasyarat: keduanya nebula planetari")
        XCTAssertNotEqual(DeepSkyCatalogue.elongation(forObjectID: "m27"),
                          DeepSkyCatalogue.elongation(forObjectID: "m57"),
                          "prasyarat: elongasi memang berbeda di katalog")
        XCTAssertTrue(deepSkySignature(dumbell).contains("elongation=0.6000"),
                      "penanda tidak membaca elongasi: \(deepSkySignature(dumbell))")
        XCTAssertNotEqual(deepSkySignature(dumbell), deepSkySignature(ring))
    }
}
