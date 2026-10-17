import XCTest
@testable import PointingKit

/// Keraguan tidak boleh lebih terang daripada jawaban.
///
/// **Cacat yang diuji di sini, dan bagaimana ia ditemukan.** Aturan PRD
/// "saat ragu tampilkan visual **samar**" selama ini hanya dijaga pada
/// **bentuk**: `DeepSkyCatalogue.drawableMorphology` mengembalikan `nil` saat
/// engine belum pasti, jadi ciri pengenal (cangkang, lengan spiral, inti
/// gugus) tidak digambar. Yang tidak pernah diukur adalah **terangnya**.
///
/// Diukur pada model (`VisualFrame.deepSky`), pada fuzziness yang sama (0.8),
/// sebagai luas elips × opasitas puncak tiap blob:
///
///     morfologi            blob    terang terpancar
///     (ragu: nil)             3        1.197   <-- paling terang
///     nebula                  3        1.197
///     planetaryNebula        24        0.827
///     globularCluster        13        0.510
///     spiralGalaxy           12        0.392
///     galaxy                  3        0.368
///     openCluster             7        0.149
///
/// Kabut "tidak tahu" adalah benda **paling terang dan paling luas** dari
/// seluruh katalog langit dalam — 3,3× galaksi, 8× gugus terbuka. Di layar
/// itu berarti: satu-satunya keadaan yang tidak berhak mengklaim apa pun
/// justru yang paling menarik mata. Mata membaca gambar lebih dulu daripada
/// badge "Ragu" di sebelahnya, jadi urutannya terbalik dari yang diminta PRD.
///
/// **Kenapa uji model, bukan gerbang PNG.** Gerbang PNG (`check-visuals.py`)
/// mengukur satu ukuran dan satu supersampling; invariannya harus bertahan di
/// setiap ukuran kartu, dan yang menentukan terang di layar adalah geometri
/// blob — bukan hasil rasterisasinya. Uji ini mengukur geometrinya langsung,
/// jadi ia ikut merah di `swift test` tanpa Docker gambar.
final class UncertainDeepSkyIsNotTheLoudestTests: XCTestCase {

    /// Terang terpancar sebuah geometri: luas elips × opasitas puncaknya.
    ///
    /// Ini **bukan** kecerahan puncak. Puncak kabut netral (0.55) memang lebih
    /// rendah daripada puncak galaksi, jadi mengukur puncak saja akan
    /// menyatakan semuanya baik-baik saja sementara luasnya 3× lebih besar.
    /// Yang menentukan seberapa "menarik mata" di layar adalah jumlah cahaya,
    /// bukan tinggi satu piksel di tengahnya.
    private func emittedLight(_ geometry: VisualFrame.NebulaGeometry) -> Double {
        geometry.blobs.reduce(0) { total, blob in
            total + Double.pi * blob.halfWidth * blob.halfHeight * blob.opacity
        }
    }

    /// Kabut ragu **tidak boleh** memancarkan lebih banyak cahaya daripada
    /// morfologi mana pun yang boleh diklaim.
    ///
    /// Daftar morfologinya diambil dari `allCases`, bukan ditulis tangan:
    /// bentuk yang ditambahkan belakangan adalah yang paling mudah lupa
    /// diperiksa, dan daftar tangan akan tertinggal separuh.
    func testUncertainFogIsDimmerThanEveryClaimedMorphology() {
        // Fuzziness katalog yang benar-benar dipakai: M57 0.40, M27 0.68,
        // galaksi 0.6–0.8. Diuji di seluruh rentang supaya perbaikan yang
        // hanya benar pada satu nilai tidak lolos.
        for fuzziness in [0.0, 0.4, 0.6, 0.8, 1.0] {
            let uncertain = VisualFrame.deepSky(morphology: nil,
                                                fuzziness: fuzziness)
            let uncertainLight = emittedLight(uncertain)

            for morphology in DeepSkyCatalogue.Morphology.allCases {
                let claimed = VisualFrame.deepSky(morphology: morphology,
                                                  fuzziness: fuzziness)
                let claimedLight = emittedLight(claimed)
                XCTAssertLessThan(
                    uncertainLight, claimedLight,
                    "pada fuzziness \(fuzziness), kabut RAGU memancarkan "
                    + "\(String(format: "%.3f", uncertainLight)) sementara "
                    + "\(morphology.rawValue) hanya "
                    + "\(String(format: "%.3f", claimedLight)) — keraguan "
                    + "tampil lebih terang daripada jawaban, dan mata membaca "
                    + "gambar sebelum badge \"Ragu\"")
            }
        }
    }

    /// Jarak terangnya harus **terbaca**, bukan sekadar "kurang 0.001".
    ///
    /// Tanpa ambang, perbaikan yang menyusutkan kabut seperseribu akan hijau
    /// sementara di layar keduanya tetap sama terang. Ambangnya 0.9×: kabut
    /// ragu wajib paling sedikit 10% lebih redup daripada morfologi paling
    /// redup yang diklaim.
    ///
    /// **Kenapa 10%, bukan 50%.** Kabut netral tetap harus **terlihat** —
    /// objek yang tidak digambar sama sekali terbaca sebagai "tidak ada objek
    /// di sini", bukan sebagai "ada sesuatu, tapi belum pasti". 10% cukup
    /// untuk membuatnya lebih redup dari jawaban mana pun tanpa membuatnya
    /// menghilang.
    func testUncertainFogIsNoticeablyDimmerNotJustMarginally() {
        for fuzziness in [0.4, 0.8, 1.0] {
            let uncertainLight = emittedLight(
                VisualFrame.deepSky(morphology: nil, fuzziness: fuzziness))
            let dimmestClaimed = DeepSkyCatalogue.Morphology.allCases
                .map { emittedLight(VisualFrame.deepSky(morphology: $0,
                                                        fuzziness: fuzziness)) }
                .min() ?? 0
            XCTAssertLessThanOrEqual(
                uncertainLight, dimmestClaimed * 0.9,
                "pada fuzziness \(fuzziness) kabut ragu hanya "
                + "\(String(format: "%.1f%%", 100 * (1 - uncertainLight / dimmestClaimed)))"
                + " lebih redup daripada morfologi paling redup — di layar "
                + "keduanya terbaca sama terang")
        }
    }

    /// Kabut ragu **tidak boleh hilang**: ia masih harus punya blob.
    ///
    /// Ini sisi sebaliknya dari uji di atas, dan ia ada karena "redupkan
    /// sampai tidak terlihat" akan memenuhi keduanya sekaligus. Objek yang
    /// tidak digambar sama sekali terbaca sebagai "tidak ada objek di sini",
    /// bukan sebagai "ada sesuatu, tapi engine belum pasti" — dan yang
    /// pertama adalah klaim yang lebih kuat daripada yang kedua.
    func testUncertainFogStillExists() {
        for fuzziness in [0.0, 0.5, 1.0] {
            let uncertain = VisualFrame.deepSky(morphology: nil,
                                                fuzziness: fuzziness)
            XCTAssertFalse(uncertain.blobs.isEmpty,
                           "kabut ragu harus tetap ada, bukan kosong")
            XCTAssertGreaterThan(emittedLight(uncertain), 0,
                                 "kabut ragu harus tetap terlihat, bukan nol")
        }
    }

    /// Morfologi yang diklaim **tidak berubah** oleh perbaikan ini.
    ///
    /// Perbaikan yang menurunkan terang kabut ragu dengan mengubah tata letak
    /// bersama akan ikut mengubah galaksi, nebula, dan gugus — dan setiap
    /// gerbang gambar yang mengukur bentuknya akan tetap hijau karena
    /// keduanya bergerak bersama. Uji ini menahan sisi itu: hanya jalur `nil`
    /// yang boleh berubah.
    func testClaimedMorphologiesKeepTheirLight() {
        // Nilai acuan diukur dari kode sebelum perbaikan. Kalau angka ini
        // berubah, perubahan tata letak memang disengaja — dan saat itu
        // nilainya harus diperbarui bersama alasan yang tertulis, bukan
        // dilonggarkan diam-diam.
        let expected: [DeepSkyCatalogue.Morphology: Double] = [
            .nebula: 1.197,
            .planetaryNebula: 0.827,
            .galaxy: 0.368,
            .spiralGalaxy: 0.392,
            .openCluster: 0.149,
            .globularCluster: 0.510
        ]
        for (morphology, light) in expected {
            let actual = emittedLight(VisualFrame.deepSky(morphology: morphology,
                                                          fuzziness: 0.8))
            XCTAssertEqual(actual, light, accuracy: 0.02,
                           "\(morphology.rawValue) berubah terang: "
                           + "\(String(format: "%.3f", actual)) vs acuan "
                           + "\(String(format: "%.3f", light)) — perbaikan "
                           + "kabut ragu tidak boleh menyentuh morfologi "
                           + "yang diklaim")
        }
    }
}
