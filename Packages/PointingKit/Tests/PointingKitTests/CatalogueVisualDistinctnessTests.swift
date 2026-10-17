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
}
