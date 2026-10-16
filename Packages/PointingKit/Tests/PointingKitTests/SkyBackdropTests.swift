import XCTest
import CelestialEngine
@testable import PointingKit

/// Menguji **batas** latar berbintang: ia boleh mempercantik, tapi tidak
/// boleh pernah terbaca sebagai hasil pengenalan.
///
/// **Kenapa uji ini ditulis lebih dulu.** `SkyBackdrop` adalah hiasan, dan
/// hiasan adalah tempat paling mudah untuk menyelundupkan klaim yang tidak
/// diuji: tidak ada teks di layar yang menyebut titik-titik ini, jadi satu-
/// satunya yang bisa membuktikan mereka tidak berbohong adalah uji. Dua
/// janji di bawah — ukuran dan warna — bukan preferensi estetika; keduanya
/// adalah batas kejujuran yang sama dengan yang berlaku pada benda yang
/// dikenali.
final class SkyBackdropTests: XCTestCase {

    // MARK: - Batas ukuran: hiasan tidak boleh sebesar benda terkecil

    /// Setiap titik latar **lebih kecil** dari titik bintang paling redup
    /// yang bisa dikenali engine.
    ///
    /// Cacat yang ditutup uji ini: kalau titik latar boleh sebesar bintang
    /// terkecil, mata tidak punya cara membedakan "tekstur langit" dari
    /// "benda yang baru saja dikunci" — dan tidak ada teks di layar yang
    /// meluruskannya. Katalog tahu benda paling redupnya (Polaris, mag
    /// 1.98), jadi batasnya diukur terhadap katalog, bukan diketik.
    func testEverySpeckIsSmallerThanTheDimmestIdentifiableStar() {
        let limit = SkyBackdrop.maximumSpeckRadius
        let dimmestSize = Catalogue.brightStars
            .map { CelestialVisual.sizeFromMagnitude($0.magnitude) }
            .min() ?? 0

        XCTAssertLessThan(limit, dimmestSize,
            "Titik latar harus lebih kecil dari bintang paling redup yang "
            + "bisa dikenali, kalau tidak ia terbaca sebagai hasil pengenalan.")

        for speck in SkyBackdrop.specks(size: .init(width: 400, height: 400)) {
            XCTAssertLessThanOrEqual(speck.radius, limit,
                "Ada titik latar yang melewati batas ukuran.")
            XCTAssertGreaterThan(speck.radius, 0,
                "Titik beradius nol sudah menghilang, jadi tidak usah digambar.")
        }
    }

    /// Batas ukuran punya **jarak** yang terukur, bukan cuma lebih kecil.
    ///
    /// Kenapa ini uji tersendiri: selisih 0.0001 secara teknis memenuhi uji
    /// di atas, tapi di layar dua titik itu sama besar — janji "ini hiasan"
    /// lalu hanya hidup di niatnya. Jaraknya harus bisa dilihat.
    func testTheSizeLimitLeavesAVisibleGap() {
        let dimmestSize = Catalogue.brightStars
            .map { CelestialVisual.sizeFromMagnitude($0.magnitude) }
            .min() ?? 0
        XCTAssertLessThan(SkyBackdrop.maximumSpeckRadius, dimmestSize * 0.8,
            "Jarak antara hiasan dan benda terkecil terlalu kecil untuk "
            + "terlihat sebagai dua kelas yang berbeda.")
    }

    // MARK: - Batas warna: hiasan tidak boleh punya ciri pengenal

    /// Titik latar **akromatik** — tidak boleh punya warna spektral.
    ///
    /// Cacat yang ditutup uji ini: warna spektral adalah ciri pengenal yang
    /// sama kuatnya dengan cincin Saturnus. Titik latar berwarna merah akan
    /// terbaca "Betelgeuse" oleh mata yang sudah dilatih aplikasi ini,
    /// padahal tidak ada satu pun perhitungan yang menghasilkan warna itu.
    func testSpecksCarryNoSpectralColor() {
        // Model tidak menyimpan warna sama sekali — itu disengaja. Yang
        // diuji di sini adalah bahwa warna yang dipakai lapisan view
        // (`neutralStarBody`) memang tidak mengklaim kelas spektral apa pun.
        let neutral = CelestialVisual.neutralStarBody
        XCTAssertEqual(neutral.red, neutral.green, accuracy: 0.0001,
            "Warna latar punya rona; rona adalah ciri pengenal.")
        XCTAssertEqual(neutral.green, neutral.blue, accuracy: 0.0001,
            "Warna latar punya rona; rona adalah ciri pengenal.")
    }

    /// Mode malam memetakan terang latar lewat jalur **yang sama** dengan
    /// benda, bukan jalur sendiri.
    ///
    /// Kenapa ini penting: aturan mode malam hanya berguna kalau tidak ada
    /// jalan keluar dari sana. Titik hiasan yang tetap putih akan menghemat
    /// rhodopsin di semua tempat kecuali ratusan titik kecil yang justru
    /// paling sulit diperiksa.
    func testNightModeRoutesBackdropThroughTheSameMapping() {
        let day = 0.8
        let night = SkyBackdrop.nightBrightness(day)
        let viaNight = NightVisual.surface(
            CelestialVisual.RGBComponents(red: day, green: day, blue: day))

        XCTAssertEqual(night, viaNight.red, accuracy: 0.0001,
            "Terang malam latar harus lahir dari NightVisual.surface, bukan "
            + "dari pemetaan sendiri.")
        XCTAssertGreaterThanOrEqual(night, NightVisual.floorBrightness,
            "Titik yang lebih redup dari lantai akan menghilang di latar merah.")
    }

    // MARK: - Deterministik

    /// Langit yang sama untuk input yang sama.
    ///
    /// Cacat yang ditutup uji ini: kalau posisinya acak per proses, setiap
    /// kali SwiftUI mengevaluasi ulang `body` seluruh langit bergeser —
    /// kedip yang tidak bisa dijelaskan, dan tidak bisa diuji.
    func testTheSameSizeAndSeedYieldTheSameSky() {
        let first = SkyBackdrop.specks(size: .init(width: 360, height: 360))
        let second = SkyBackdrop.specks(size: .init(width: 360, height: 360))
        XCTAssertEqual(first.count, second.count, "Jumlah titik tidak stabil.")
        XCTAssertEqual(first, second, "Langit bergeser antara dua render.")
    }

    /// Seed yang berbeda menghasilkan langit yang berbeda.
    ///
    /// Pelengkap uji di atas: deterministik boleh saja berarti "selalu
    /// mengembalikan hal yang sama tanpa peduli seed" — cacat yang tidak
    /// akan ditangkap uji sebelumnya.
    func testDifferentSeedsYieldDifferentSkies() {
        let a = SkyBackdrop.specks(size: .init(width: 360, height: 360), seed: 1)
        let b = SkyBackdrop.specks(size: .init(width: 360, height: 360), seed: 2)
        XCTAssertNotEqual(a, b, "Seed diabaikan: dua seed memberi langit sama.")
    }

    /// Bidang lebih luas menambah titik, bukan menggeser yang sudah ada.
    ///
    /// Kenapa ini uji, bukan catatan: potongan pembangkit per titik
    /// (`seed + index * konstanta`) dipilih tepat agar titik yang sudah ada
    /// tetap di tempatnya saat layar membesar. Tanpa uji ini, seseorang
    /// bisa menyederhanakan pembangkitnya menjadi satu aliran panjang dan
    /// seluruh langit akan berpindah setiap kali ukuran berubah.
    func testAGrowingFieldAddsSpecksWithoutMovingTheExistingOnes() {
        let small = SkyBackdrop.specks(size: .init(width: 300, height: 300))
        let large = SkyBackdrop.specks(size: .init(width: 600, height: 600))

        XCTAssertGreaterThan(large.count, small.count,
            "Bidang lebih luas harus punya lebih banyak titik.")
        for (index, speck) in small.enumerated() {
            XCTAssertEqual(speck.x, large[index].x, accuracy: 0.0001,
                "Titik ke-\(index) berpindah saat bidang membesar.")
            XCTAssertEqual(speck.y, large[index].y, accuracy: 0.0001,
                "Titik ke-\(index) berpindah saat bidang membesar.")
        }
    }

    // MARK: - Kelayakan gambar

    /// Semua titik berada di dalam bidang.
    ///
    /// Kalau ada yang keluar, ia tidak akan terlihat — dan lapisan view
    /// akan menggambar kerja yang sia-sia.
    func testSpecksStayInsideTheField() {
        for speck in SkyBackdrop.specks(size: .init(width: 500, height: 300)) {
            XCTAssertGreaterThanOrEqual(speck.x, 0)
            XCTAssertLessThanOrEqual(speck.x, 1)
            XCTAssertGreaterThanOrEqual(speck.y, 0)
            XCTAssertLessThanOrEqual(speck.y, 1)
            XCTAssertGreaterThan(speck.brightness, 0)
            XCTAssertLessThanOrEqual(speck.brightness, 1)
        }
    }

    /// Titik-titik **tidak** boleh saling menyambung.
    ///
    /// Cacat yang ditutup uji ini, ditemukan dengan mengukur: koordinat
    /// sebuah titik pernah muncul lagi sebagai koordinat titik berikutnya
    /// (`y` titik ke-n == `x` titik ke-n+1 secara persis). Langitnya lalu
    /// berbentuk untaian diagonal, mata membacanya sebagai pola, dan pola
    /// pada latar mengundang pengguna mencari arti di situ — padahal tidak
    /// ada arti apa pun. Itu kebalikan dari tujuan lapisan ini.
    func testConsecutiveSpecksDoNotChainCoordinates() {
        let specks = SkyBackdrop.specks(size: .init(width: 400, height: 400))
        for index in 1..<specks.count {
            XCTAssertNotEqual(specks[index].x, specks[index - 1].y,
                "Titik ke-\(index) menyambung ke titik sebelumnya: latar "
                + "berbentuk untaian, bukan langit.")
            XCTAssertNotEqual(specks[index].x, specks[index - 1].x,
                "Dua titik berturutan punya x yang sama persis.")
        }
    }

    /// Bidang nol tidak menghasilkan apa-apa, dan tidak menumbangkan apa pun.
    ///
    /// Kasus tepi yang nyata: `GeometryReader` memberi ukuran 0 sebelum
    /// tata letak selesai. Mengembalikan titik di situ akan menggambar di
    /// tempat yang salah.
    func testAnEmptyFieldProducesNothing() {
        XCTAssertTrue(SkyBackdrop.specks(size: .init(width: 0, height: 0)).isEmpty)
    }

    /// Jumlah titik masuk akal untuk ukuran jam sungguhan.
    ///
    /// Bukan uji keindahan, melainkan pagar: kalau kepadatannya keliru satu
    /// satuan, jam akan mendapat ratusan titik atau dua titik, dan dua-duanya
    /// terlihat rusak tanpa ada yang bisa menunjuk angkanya.
    func testSpeckCountIsInASaneRangeForAWatchScreen() {
        let watch = SkyBackdrop.specks(size: .init(width: 198, height: 242))
        XCTAssertGreaterThan(watch.count, 10,
            "Langit jam terlalu sepi untuk terbaca sebagai langit.")
        XCTAssertLessThan(watch.count, 400,
            "Terlalu banyak titik: ini menjadi derau, bukan atmosfer.")
    }
}
