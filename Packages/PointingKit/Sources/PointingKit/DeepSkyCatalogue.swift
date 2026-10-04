import Foundation
import CelestialEngine

/// Objek langit dalam (nebula, galaksi, gugus) untuk katalog produksi.
///
/// **Kenapa berkas ini ada.** Seluruh jalur visual objek langit dalam sudah
/// lengkap dan teruji jauh sebelum berkas ini: `CelestialVisual.Kind.deepSky`
/// ada, `VisualFrame.nebula(fuzziness:)` menghitung geometrinya, `NightVisual`
/// punya aksen `deepSky`, `ObjectKind.deepSky` punya label & pengucapan, dan
/// `CelestialVisualView.drawDeepSky` menggambarnya. Resolver pun sudah menulis
/// `for object in catalogue where object.kind == .star || object.kind == .deepSky`
/// — jadi ia **sudah siap** menerima objek langit dalam.
///
/// Tapi tidak ada satu pun katalog yang berisi objek ber-`kind: .deepSky`.
/// Akibatnya `drawDeepSky` tidak pernah berjalan di aplikasi mana pun: satu-
/// satunya yang pernah membangun `CelestialVisual(kind: .deepSky)` adalah uji.
/// Ini kelas cacat yang sama dengan yang sudah berulang di repo ini —
/// **semuanya benar secara terpisah, yang hilang adalah jalur yang
/// menghubungkannya** — dan tidak bisa dilihat dari layar, karena tidak ada
/// yang tampil untuk dilihat.
///
/// Yang menjaganya sekarang ada di uji: `DeepSkyCatalogueTests` menuntut
/// setiap objek di sini punya entri `fuzziness`, dan `EngineFactoryTests`
/// menuntut katalog produksi benar-benar memuatnya.
public enum DeepSkyCatalogue {

    /// Objek langit dalam, koordinat J2000 (derajat).
    ///
    /// `magnitude` adalah magnitudo **terintegrasi** (seluruh nebula digabung),
    /// bukan magnitudo titik seperti bintang. Karena itu ukuran gambarnya
    /// **tidak** diturunkan dari angka ini (lihat `CelestialVisual.init`):
    /// nebula mag 4 tidak "sebesar" bintang mag 4 — ia menyebar, bukan
    /// mengumpul. Yang membedakan bentuknya adalah `fuzziness`, bukan
    /// magnitudo.
    ///
    /// Enam objek dipilih yang paling dikenal dan paling terang, supaya
    /// pengguna mata telanjang atau binokuler benar-benar bisa menemukannya —
    /// menawarkan target yang tidak terlihat hanya menghasilkan penunjukan
    /// yang menyesatkan.
    public static let objects: [CelestialObject] = [
        CelestialObject(id: "m45", name: "Pleiades",       kind: .deepSky,
                        raDeg:  56.75000000, decDeg:  24.11670000, magnitude: 1.60),
        CelestialObject(id: "m31", name: "Galaksi Andromeda", kind: .deepSky,
                        raDeg:  10.68470833, decDeg:  41.26875000, magnitude: 3.44),
        CelestialObject(id: "m7",  name: "Gugus Ptolemy",  kind: .deepSky,
                        raDeg: 268.45000000, decDeg: -34.81670000, magnitude: 3.30),
        CelestialObject(id: "m42", name: "Nebula Orion",   kind: .deepSky,
                        raDeg:  83.82208333, decDeg:  -5.39111111, magnitude: 4.00),
        CelestialObject(id: "m13", name: "Gugus Hercules", kind: .deepSky,
                        raDeg: 250.42329167, decDeg:  36.46130556, magnitude: 5.80),
        CelestialObject(id: "m8",  name: "Nebula Laguna",  kind: .deepSky,
                        raDeg: 270.90000000, decDeg: -24.38330000, magnitude: 6.00)
    ]

    /// Seberapa "menyebar" tiap objek (0 = titik, 1 = kabut paling lebar).
    ///
    /// **Kenapa ini tabel per id, bukan satu angka untuk semua.** Kalau semua
    /// nebula memakai `fuzziness` yang sama, seluruh kelas objek ini tampil
    /// sebagai satu bentuk yang identik — pengguna tidak bisa membedakan
    /// nebula dari gugus dari galaksi, dan yang paling halus: tidak ada satu
    /// teks di layar yang bisa membacanya. Galaksi Andromeda (lebar, samar)
    /// dan gugus bola Hercules (padat, kecil) adalah dua bentuk yang paling
    /// berbeda; menyamakannya menghapus informasi yang justru membedakan
    /// kelas objek ini dari bintang.
    ///
    /// Sengaja `internal` (bukan `private`) supaya uji bisa menegakkan bahwa
    /// **setiap** objek di katalog punya entri. Tanpa uji itu, menambah objek
    /// baru akan memberinya nilai bawaan yang tampak sah padahal bentuknya
    /// tidak dipilih — kelas cacat yang sama dengan tabel warna bintang.
    static let fuzzinessByID: [String: Double] = [
        "m45": 0.55,   // Pleiades — gugus terbuka + kabut pantulan tipis
        "m31": 1.00,   // Andromeda — galaksi, paling lebar & paling samar
        "m7":  0.50,   // Ptolemy — gugus terbuka, longgar
        "m42": 0.90,   // Orion — nebula emisi, besar
        "m13": 0.35,   // Hercules — gugus bola, padat
        "m8":  0.80    // Laguna — nebula emisi
    ]

    /// Seberapa menyebar sebuah objek langit dalam, dari id-nya.
    ///
    /// Id yang tidak ada di tabel mengembalikan nilai tengah (0.6), bukan 0:
    /// nol berarti "titik", dan menggambar nebula yang tidak dikenal sebagai
    /// titik membuatnya tampak seperti bintang — klaim bentuk yang tidak
    /// dimiliki objeknya. Nilai tengah tidak mengklaim bentuk tertentu.
    public static func fuzziness(forObjectID id: String) -> Double {
        fuzzinessByID[id] ?? 0.6
    }
}
