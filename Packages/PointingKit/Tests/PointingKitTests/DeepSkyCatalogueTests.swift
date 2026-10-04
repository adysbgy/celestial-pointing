import XCTest
import CelestialEngine
@testable import PointingKit

/// Katalog objek langit dalam.
///
/// **Kelas cacat yang dijaga di sini:** seluruh jalur visual objek langit
/// dalam (`CelestialVisual.Kind.deepSky`, `VisualFrame.nebula`, aksen
/// `NightVisual.deepSky`, label `ObjectKind.deepSky`, `drawDeepSky`) sudah ada
/// dan teruji — tapi tidak ada satu pun katalog yang memuat objek
/// ber-`kind: .deepSky`. Jadi `drawDeepSky` tidak pernah berjalan di aplikasi
/// mana pun; satu-satunya yang pernah membangunnya adalah uji.
///
/// Cacat itu tidak bisa dilihat dari layar (tidak ada yang tampil untuk
/// dilihat) dan tidak menyalakan gerbang mana pun (semua bagian benar secara
/// terpisah). Yang menutupnya adalah uji yang menuntut **jalur**-nya ada,
/// bukan bagian-bagiannya.
final class DeepSkyCatalogueTests: XCTestCase {

    // MARK: - Paritas tabel: setiap objek punya bentuk

    /// Setiap objek di katalog harus punya entri `fuzziness`.
    ///
    /// Tanpa uji ini, menambah nebula baru akan memberinya nilai bawaan yang
    /// **tampak sah** padahal bentuknya tidak dipilih — persis kelas cacat
    /// yang sudah terjadi pada tabel warna bintang. Uji itu menuntut
    /// penambahan katalog menyentuh tabelnya; ini yang setara untuk bentuk.
    func testEveryDeepSkyObjectHasAFuzzinessEntry() {
        XCTAssertFalse(DeepSkyCatalogue.objects.isEmpty,
                       "katalog objek langit dalam kosong: jalur visualnya tidak akan pernah berjalan")
        for object in DeepSkyCatalogue.objects {
            XCTAssertNotNil(DeepSkyCatalogue.fuzzinessByID[object.id],
                            "\(object.id) belum punya entri fuzziness — bentuknya akan memakai nilai bawaan yang tampak sah")
        }
    }

    /// Tidak ada entri yatim: setiap kunci tabel harus milik objek yang ada.
    ///
    /// Kebalikannya juga penting. Entri yang tertinggal setelah objeknya
    /// dihapus membuat tabel perlahan menunjuk id yang tidak ada lagi, dan
    /// tidak ada yang bisa melihatnya.
    func testNoFuzzinessEntryIsOrphaned() {
        let ids = Set(DeepSkyCatalogue.objects.map(\.id))
        for key in DeepSkyCatalogue.fuzzinessByID.keys {
            XCTAssertTrue(ids.contains(key),
                          "entri fuzziness '\(key)' tidak punya objeknya")
        }
    }

    /// Setiap objek harus ber-`kind: .deepSky`.
    ///
    /// Kalau ada yang salah jenis, ia akan tampil sebagai bintang (dengan
    /// glow & spike) atau planet — klaim bentuk yang salah, tanpa satu teks
    /// pun di layar yang bisa membacanya.
    func testEveryEntryIsADeepSkyObject() {
        for object in DeepSkyCatalogue.objects {
            XCTAssertEqual(object.kind, .deepSky, "\(object.id) bukan objek langit dalam")
        }
    }

    // MARK: - Morfologi: bentuk apa, bukan cuma seberapa lebar

    /// Setiap objek harus punya entri morfologi.
    ///
    /// `fuzziness` hanya mengatur **lebar**; tanpa morfologi, galaksi, gugus
    /// terbuka, dan gugus bola digambar dengan bentuk yang sama persis. Uji
    /// ini menuntut setiap objek menyatakan bentuknya — supaya menambah
    /// objek baru tidak memberinya bentuk bawaan yang tampak sah padahal
    /// tidak dipilih.
    func testEveryDeepSkyObjectHasAMorphologyEntry() {
        for object in DeepSkyCatalogue.objects {
            XCTAssertNotNil(DeepSkyCatalogue.morphologyByID[object.id],
                            "\(object.id) belum punya morfologi — bentuknya akan menebak")
        }
    }

    /// Tidak ada entri morfologi yang yatim.
    func testNoMorphologyEntryIsOrphaned() {
        let ids = Set(DeepSkyCatalogue.objects.map(\.id))
        for key in DeepSkyCatalogue.morphologyByID.keys {
            XCTAssertTrue(ids.contains(key),
                          "entri morfologi '\(key)' tidak punya objeknya")
        }
    }

    /// Id tak dikenal **tidak** menebak bentuk.
    ///
    /// Ini beda penting dengan `fuzziness`, yang boleh jatuh ke nilai tengah:
    /// lebar yang tidak diketahui tidak mengklaim apa pun, sedangkan setiap
    /// morfologi menyatakan "ini galaksi" atau "ini gugus bola". Menebak
    /// salah satunya adalah klaim identitas yang keliru — persis yang
    /// dilarang PRD. Jadi `nil`, dan lapisan gambar memakai kabut netral.
    func testUnknownIDHasNoMorphologyRatherThanGuessing() {
        XCTAssertNil(DeepSkyCatalogue.morphology(forObjectID: "bukan-objek-nyata"),
                     "id tak dikenal harus mengembalikan nil, bukan bentuk bawaan")
    }

    /// Katalog produksi harus memakai **lebih dari satu** morfologi.
    ///
    /// Kalau semua objek kebetulan satu bentuk, uji per-objek di atas tetap
    /// hijau sementara kelas cacatnya kembali: layar menampilkan bentuk yang
    /// sama untuk semua. Ini yang mengunci niatnya.
    func testCatalogueUsesMoreThanOneMorphology() {
        let shapes = Set(DeepSkyCatalogue.objects.compactMap {
            DeepSkyCatalogue.morphology(forObjectID: $0.id)
        })
        XCTAssertGreaterThan(shapes.count, 1,
                             "seluruh katalog memakai satu bentuk — semua objek akan tampil identik")
    }

    /// Setiap morfologi yang dideklarasikan **benar-benar dipakai**.
    ///
    /// Menambah `case` baru ke `Morphology` tanpa memetakannya ke objek mana
    /// pun berarti bentuk itu tidak pernah digambar — jalur mati yang tidak
    /// bisa dilihat dari layar. Daftarnya diambil dari `allCases`, jadi
    /// penambahan `case` langsung menuntut objeknya.
    func testEveryMorphologyIsUsedByTheCatalogue() {
        let used = Set(DeepSkyCatalogue.objects.compactMap {
            DeepSkyCatalogue.morphology(forObjectID: $0.id)
        })
        for morphology in DeepSkyCatalogue.Morphology.allCases {
            XCTAssertTrue(used.contains(morphology),
                          "morfologi \(morphology) tidak dipakai objek mana pun — bentuknya tidak akan pernah tampil")
        }
    }

    /// Id harus unik: dua objek ber-id sama membuat yang satu menutupi yang
    /// lain di `Dictionary`/`first(where:)`, dan arah yang dilaporkan bisa
    /// milik objek yang salah.
    func testIdentifiersAreUnique() {
        let ids = DeepSkyCatalogue.objects.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ada id objek langit dalam yang duplikat")
    }

    // MARK: - Bentuk berbeda, bukan satu bentuk untuk semua

    /// `fuzziness` harus benar-benar membedakan objek.
    ///
    /// Kalau seluruh kelas memakai satu angka, nebula, gugus, dan galaksi
    /// tampil sebagai bentuk yang sama — pengguna kehilangan satu-satunya
    /// informasi yang membedakan mereka, dan itu tidak terlihat dari teks.
    /// Galaksi Andromeda (lebar, samar) dan gugus bola Hercules (padat, kecil)
    /// adalah pasangan yang paling jelas berbeda.
    func testFuzzinessActuallyDistinguishesObjects() {
        let values = DeepSkyCatalogue.objects.map {
            DeepSkyCatalogue.fuzziness(forObjectID: $0.id)
        }
        XCTAssertGreaterThan(Set(values).count, 1,
                             "semua objek langit dalam memakai fuzziness yang sama: bentuknya tidak bisa dibedakan")
    }

    /// Setiap nilai harus di dalam rentang yang `VisualFrame.nebula` definisikan.
    ///
    /// Di luar 0…1, `nebula(fuzziness:)` menjepitnya — jadi angkanya tampak
    /// dihormati padahal tidak. Lebih baik uji ini yang merah.
    func testFuzzinessValuesAreInRange() {
        for object in DeepSkyCatalogue.objects {
            let value = DeepSkyCatalogue.fuzziness(forObjectID: object.id)
            XCTAssertGreaterThanOrEqual(value, 0, "\(object.id) fuzziness < 0")
            XCTAssertLessThanOrEqual(value, 1, "\(object.id) fuzziness > 1")
        }
    }

    /// Id yang tidak dikenal mengembalikan nilai tengah, **bukan nol**.
    ///
    /// Nol berarti "titik": nebula yang tidak dikenal akan digambar seperti
    /// bintang. Nilai tengah tidak mengklaim bentuk tertentu — sama dengan
    /// `colorIndex(forStarID:)` yang mengembalikan 0 (putih netral) untuk
    /// bintang yang tidak dikenal, bukan warna karangan.
    func testUnknownIDFallsBackToNeutralNotPoint() {
        let fallback = DeepSkyCatalogue.fuzziness(forObjectID: "tidak-ada")
        XCTAssertGreaterThan(fallback, 0,
                             "nilai bawaan 0 membuat nebula tak dikenal digambar sebagai titik (seperti bintang)")
        XCTAssertLessThanOrEqual(fallback, 1)
    }

    // MARK: - Jalur: katalog produksi benar-benar memuatnya

    /// **Uji yang paling penting di berkas ini.** Katalog produksi harus
    /// benar-benar memuat objek langit dalam.
    ///
    /// Semua uji di atas bisa hijau sementara aplikasi tetap tidak pernah
    /// menggambar satu nebula pun — kalau katalognya tidak pernah digabungkan.
    /// Inilah cacat yang sebenarnya: bagian-bagiannya benar, jalurnya tidak
    /// pernah disambungkan. Uji ini menyambungkannya dan menguncinya.
    func testProductionCatalogueContainsDeepSkyObjects() {
        let deepSky = EngineFactory.productionCatalogue.filter { $0.kind == .deepSky }
        XCTAssertEqual(deepSky.count, DeepSkyCatalogue.objects.count,
                       "katalog produksi tidak memuat objek langit dalam")
        XCTAssertGreaterThan(EngineFactory.productionCatalogue.count,
                             Catalogue.brightStars.count,
                             "katalog produksi sama dengan katalog bintang: tidak ada yang ditambahkan")
    }

    /// Resolver yang dirakit pabrik harus benar-benar menawarkan objek langit
    /// dalam — bukan hanya memuatnya di katalog.
    ///
    /// Ini menutup celah terakhir: katalog bisa benar sementara penyaring di
    /// `availableTargets`/`diagnose` membuang objeknya sebelum sampai ke UI.
    /// Tanpa efemeris pun (katalog saja), objeknya harus muncul.
    func testProductionResolverOffersDeepSkyTargets() {
        let resolver = EngineFactory.makeResolver(includeSolarSystem: false)
        let targets = resolver.availableTargets(
            observer: Observer(latitudeDeg: -6.2, longitudeDeg: 106.8),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            aboveHorizonOnly: false
        )
        let offered = targets.filter { $0.kind == .deepSky }
        XCTAssertEqual(offered.count, DeepSkyCatalogue.objects.count,
                       "resolver produksi tidak menawarkan objek langit dalam: jalur visualnya tetap mati")
    }

    /// Objek langit dalam harus bisa sampai ke **visual** dengan bentuknya
    /// sendiri — bukan hanya sampai ke daftar target.
    ///
    /// Menyambungkan dua ujung: objek dari katalog → `CelestialVisual` →
    /// `fuzziness` yang benar. Kalau salah satu sambungan lepas, yang tampil
    /// di layar adalah bentuk bawaan untuk semua objek, dan tidak ada yang
    /// bisa membacanya.
    func testDeepSkyTargetReachesVisualWithItsOwnShape() {
        for object in DeepSkyCatalogue.objects {
            let visual = CelestialVisual(object: object)
            XCTAssertEqual(visual.kind, .deepSky, "\(object.id) tidak menghasilkan visual langit dalam")
            XCTAssertEqual(visual.fuzziness,
                           DeepSkyCatalogue.fuzziness(forObjectID: object.id),
                           accuracy: 1e-12,
                           "\(object.id) tampil dengan bentuk yang bukan miliknya")
        }
    }

    // MARK: - Kalibrasi: objek langit dalam bukan acuan

    /// Objek langit dalam tidak boleh ditawarkan sebagai acuan kalibrasi.
    ///
    /// Kebenaran kalibrasi diambil dari posisi katalog, dan posisi objek
    /// langit dalam juga ada di katalog — jadi menyaringnya **bukan** soal
    /// posisi. Yang salah adalah bahwa objek ini **tidak punya tepi**:
    /// pengguna tidak bisa tahu bagian mana dari kabut Orion yang sedang ia
    /// tunjuk, jadi sampelnya jauh lebih berisik daripada bintang. Sampel
    /// berisik melebarkan `residualSpreadDeg` dan membuat kalibrasi terlihat
    /// lebih buruk daripada sesungguhnya — atau, lebih buruk lagi, terlihat
    /// "siap" dengan offset yang salah.
    ///
    /// Uji ini **tidak vacuous**: ia lebih dulu membuktikan bahwa pada waktu
    /// yang dipakai, objek langit dalam memang di atas horizon — jadi tanpa
    /// penyaring jenis, ia benar-benar akan lolos ke daftar acuan.
    func testDeepSkyObjectsAreNeverOfferedAsCalibrationReferences() {
        let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
        let star = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                   raDeg: 101.28715533, decDeg: -16.71611586, magnitude: -1.46)
        let nebula = CelestialObject(id: "m42", name: "Nebula Orion", kind: .deepSky,
                                     raDeg: 83.82208333, decDeg: -5.39111111, magnitude: 4.0)
        let resolver = PointingResolver(catalogue: [star, nebula], policy: .permissive)

        // Cari waktu ketika nebula benar-benar tinggi di langit.
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var when: Date?
        for hour in 0..<48 {
            let candidate = base.addingTimeInterval(Double(hour) * 3600)
            let altitude = resolver.horizontal(ofObjectID: "m42", observer: observer,
                                               date: candidate)?.altitudeDeg ?? -90
            if altitude > 20 { when = candidate; break }
        }
        guard let date = when else {
            return XCTFail("tidak menemukan waktu ketika M42 di atas horizon — uji tidak bisa membuktikan apa pun")
        }

        // Buktikan dulu bahwa nebula memang akan lolos penyaring horizon.
        let offered = resolver.availableTargets(observer: observer, date: date)
        XCTAssertTrue(offered.contains { $0.id == "m42" },
                      "nebula tidak di atas horizon pada waktu uji: uji jadi vacuous")

        let controller = PointingController(resolver: resolver, observer: observer,
                                            config: PointingControllerConfig(coneDeg: 5))
        let session = CalibrationSession(controller: controller,
                                         flow: CalibrationFlow(referenceObjects: [star, nebula]))
        session.refreshReferenceTargets(date: date)

        XCTAssertFalse(session.referenceTargets.contains { $0.kind == .deepSky },
                       "objek langit dalam ditawarkan sebagai acuan kalibrasi")
    }
}
