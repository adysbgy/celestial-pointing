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

    /// **Tabrakan m7/m41 — sekarang terpisah lewat susunan bintangnya.**
    ///
    /// Pasangan `m7` (Gugus Ptolemy) dan `m41` (Gugus M41) bertabrakan di
    /// **seluruh** sinyal bentuk lain: sama `.openCluster`, sama `fuzziness`
    /// 0,50, elongasi bawaan 1,0, dan warna ikut morfologi sehingga juga
    /// sama. Sebelum siklus ini `VisualFrame.deepSky` menghasilkan tujuh blob
    /// dengan offset, setengah-lebar, dan opasitas **sama persis** — di layar,
    /// saat engine menunjuk M41 gambarnya milik M7.
    ///
    /// Perbaikannya **bukan** mengubah angka tabel:
    ///
    ///   1. Menurunkan `fuzziness` m41 ke 0,44 hanya mengubah lebar tiap blob,
    ///      bukan letaknya: render berubah ~7% piksel dengan delta kanal
    ///      ~0,09 — tak terbaca pada kartu jam 38 pt. Hijau palsu.
    ///   2. Memipihkan siluet lewat `elongation` **tidak dipakai**: M7 dan
    ///      M41 sama-sama nyaris bulat, jadi memipihkan salah satunya berarti
    ///      mengarang bentuk demi lulus uji.
    ///
    /// Yang dipakai adalah derajat kebebasan yang nyata: **arah sebaran**
    /// bintang (`scatterRotated`). Memutar susunan tidak mengubah jumlah,
    /// ukuran, sebaran, maupun opasitas satu blob pun — hanya arahnya.
    ///
    /// Uji ini menuntut dua hal sekaligus, karena memenuhi satu saja
    /// menghasilkan cacat lain:
    ///
    ///   1. geometri `deepSky` untuk kedua id **benar-benar berbeda**; dan
    ///   2. `objectID: nil` tetap **persis** susunan bawaan — kalau tidak,
    ///      objek yang belum masuk katalog ikut berpindah tanpa dasar, dan
    ///      kabut netral saat engine ragu kehilangan acuannya.
    func testOpenClusterPairRendersDistinctArrangements() {
        let m7 = DeepSkyCatalogue.objects.first { $0.id == "m7" }!
        let m41 = DeepSkyCatalogue.objects.first { $0.id == "m41" }!
        XCTAssertEqual(DeepSkyCatalogue.morphology(forObjectID: m7.id),
                       DeepSkyCatalogue.morphology(forObjectID: m41.id),
                       "prasyarat: keduanya gugus terbuka")
        XCTAssertEqual(deepSkySignature(m7), deepSkySignature(m41),
                       "prasyarat: sinyal tabelnya memang masih bertabrakan — " +
                       "kalau ini gagal, uji di bawah jadi tidak membuktikan apa-apa")

        func geometry(_ id: String?, fuzziness: Double = 0.5) -> [Double] {
            let resolved = fuzziness
            let frame = VisualFrame.deepSky(morphology: .openCluster,
                                            fuzziness: resolved,
                                            objectID: id)
            return frame.blobs.flatMap { [$0.offsetX, $0.offsetY,
                                          $0.halfWidth, $0.halfHeight, $0.opacity] }
        }

        let layout7 = geometry("m7")
        let layout41 = geometry("m41")
        XCTAssertEqual(layout7.count, 35, "prasyarat: tujuh blob × lima angka")

        // (1) Kedua objek tidak lagi digambar sama. Toleransinya jauh di atas
        // galat titik-mengambang, dan jauh di bawah pergeseran sudut terkecil
        // yang mungkin dari pemetaan (1/3600 putaran ≈ 0,0017 rad).
        let shift = zip(layout7, layout41).map { abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(shift, 0.01,
                             "m7 dan m41 masih digambar identik (selisih maks \(shift)) — " +
                             "gambar di layar akan milik benda lain")

        // (2) Tanpa id, susunannya harus tepat susunan bawaan: `nil` bukan
        // sekadar "sudut 0, kalau kebetulan".
        let noID = geometry(nil)
        let emptyID = geometry("")
        XCTAssertEqual(noID.count, emptyID.count)
        XCTAssertEqual(zip(noID, emptyID).map { abs($0 - $1) }.max() ?? 1, 0,
                       accuracy: 1e-12,
                       "objectID kosong harus menghasilkan susunan bawaan")

        // (3) Deterministik: id yang sama, dipanggil ulang, susunan sama.
        // Tanpa ini `hashValue` bisa menyelinap dan gambar berubah tiap
        // proses.
        let again = geometry("m7")
        XCTAssertEqual(again.count, layout7.count)
        XCTAssertEqual(Array(again.enumerated()).map { abs($0.element - layout7[$0.offset]) }.max() ?? 1,
                       0, accuracy: 1e-12,
                       "susunan m7 tidak stabil antar pemanggilan")
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
