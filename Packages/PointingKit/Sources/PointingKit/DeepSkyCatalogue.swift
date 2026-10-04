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
    ///
    /// **Kenapa kemudian ditambah menjadi sebelas.** Enam objek pertama
    /// memberi **satu** galaksi dan **satu** gugus bola; dengan begitu dua
    /// bentuk di katalog hanya terlihat sekali, dan pengguna tidak punya
    /// pembanding untuk tahu mana yang khas dan mana yang kebetulan. Lima
    /// objek berikutnya menambah satu galaksi lagi (M33), satu gugus bola
    /// lagi (M22), dan dua gugus terbuka (M44, M6) — sehingga tiap bentuk
    /// punya setidaknya dua wakil, dan perbedaan antar-bentuk bisa dibaca
    /// dari layar, bukan hanya dari label. Semuanya masih objek terang
    /// (mag ≤ 6) yang terlihat dengan mata telanjang atau binokuler.
    ///
    /// Koordinatnya J2000 dari data publik (epoch 2000.0), bukan karangan:
    /// objek langit dalam tidak punya satu titik terang untuk dikoreksi,
    /// jadi posisi yang salah tetap tampak benar di layar dan hanya muncul
    /// di tempat yang keliru — `testEveryObjectRisesAboveTheHorizonForTheTargetLatitude`
    /// yang menutupnya, bukan mata.
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
                        raDeg: 270.90000000, decDeg: -24.38330000, magnitude: 6.00),
        // Kelompok kedua: satu wakil lagi untuk tiap bentuk.
        CelestialObject(id: "m44", name: "Gugus Sarang Lebah", kind: .deepSky,
                        raDeg: 130.10000000, decDeg:  19.98333333, magnitude: 3.70),
        CelestialObject(id: "m33", name: "Galaksi Triangulum", kind: .deepSky,
                        raDeg:  23.45841667, decDeg:  30.66019444, magnitude: 5.72),
        CelestialObject(id: "m22", name: "Gugus Sagitarius", kind: .deepSky,
                        raDeg: 279.09975000, decDeg: -23.90475000, magnitude: 5.10),
        CelestialObject(id: "m6",  name: "Gugus Kupu-kupu", kind: .deepSky,
                        raDeg: 265.02500000, decDeg: -32.21666667, magnitude: 4.20),
        CelestialObject(id: "m17", name: "Nebula Omega",   kind: .deepSky,
                        raDeg: 275.10833333, decDeg: -16.17666667, magnitude: 6.00)
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
        "m8":  0.80,   // Laguna — nebula emisi
        "m44": 0.45,   // Sarang Lebah — gugus terbuka paling lebar (95′)
        "m33": 0.95,   // Triangulum — galaksi, lebih lebar dari Andromeda
        "m22": 0.30,   // Sagitarius — gugus bola, lebih longgar dari Hercules
        "m6":  0.48,   // Kupu-kupu — gugus terbuka, lebih kecil dari Ptolemy
        "m17": 0.72    // Omega — nebula emisi, lebih sempit dari Orion
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

    // MARK: - Bentuk: apa objeknya, bukan cuma seberapa lebar

    /// Morfologi — **jenis** objek langit dalam.
    ///
    /// **Kenapa `fuzziness` saja tidak cukup.** `fuzziness` hanya mengatur
    /// **seberapa lebar** kabutnya; semua objek langit dalam tetap digambar
    /// dengan tiga blob yang sama. Di katalog produksi itu berarti galaksi
    /// spiral, gugus terbuka, dan gugus bola tampil sebagai **satu bentuk
    /// yang persis sama** — pengguna tidak bisa membedakan satu dari yang
    /// lain, dan yang paling halus: tidak ada satu teks di layar yang bisa
    /// membacanya. PRD melarang menampilkan visual yang mengklaim identitas
    /// yang tidak dimiliki objek; gambar yang **sama untuk semua** adalah
    /// bentuk klaim yang paling sulit terlihat, karena tidak ada yang salah
    /// untuk dilihat.
    ///
    /// Tabelnya per id, sama seperti `fuzzinessByID`, supaya menambah objek
    /// baru tidak memberinya bentuk bawaan yang tampak sah padahal tidak
    /// dipilih — kelas cacat yang sama dengan tabel warna bintang.
    public enum Morphology: String, Equatable, Sendable, CaseIterable {
        /// Nebula emisi/pantulan: kabut asimetris yang menyebar.
        case nebula
        /// Galaksi: cakram miring dengan tonjolan inti — terlihat dari rasio
        /// sumbu elipsnya, bukan cuma dari lebarnya.
        case galaxy
        /// Gugus terbuka: bintang-bintang tersebar **jarang**, tanpa inti.
        case openCluster
        /// Gugus bola: inti padat dengan bintang yang mengerumun rapat.
        case globularCluster
    }

    /// Bentuk tiap objek, per id.
    ///
    /// Dipisah dari `fuzzinessByID` dan bukan digabung ke dalamnya, karena
    /// keduanya menjawab pertanyaan berbeda ("seberapa lebar" vs "bentuk
    /// apa") dan punya **gagal-bawaan** yang berbeda: lebar boleh jatuh ke
    /// nilai tengah, sedangkan bentuk **tidak boleh menebak**. Lihat
    /// `morphology(forObjectID:)`.
    static let morphologyByID: [String: Morphology] = [
        "m45": .openCluster,      // Pleiades — gugus terbuka
        "m31": .galaxy,           // Andromeda — galaksi
        "m7":  .openCluster,      // Ptolemy — gugus terbuka
        "m42": .nebula,           // Orion — nebula emisi
        "m13": .globularCluster,  // Hercules — gugus bola
        "m8":  .nebula,           // Laguna — nebula emisi
        "m44": .openCluster,      // Sarang Lebah — gugus terbuka
        "m33": .galaxy,           // Triangulum — galaksi
        "m22": .globularCluster,  // Sagitarius — gugus bola
        "m6":  .openCluster,      // Kupu-kupu — gugus terbuka
        "m17": .nebula            // Omega — nebula emisi
    ]

    /// Bentuk sebuah objek langit dalam, dari id-nya.
    ///
    /// **Kenapa jatuh ke `nil`, bukan ke bentuk bawaan.** Untuk `fuzziness`,
    /// nilai tengah (0.6) masuk akal: lebar yang tidak diketahui tetap tidak
    /// mengklaim apa pun. Bentuk tidak punya "nilai tengah" — setiap pilihan
    /// menyatakan "ini galaksi" atau "ini gugus bola". Menebak salah satunya
    /// adalah klaim identitas yang keliru, persis yang dilarang PRD. Jadi
    /// id yang tidak dikenal mengembalikan `nil`, dan lapisan gambar lalu
    /// memakai bentuk netral yang **tidak** menyatakan salah satu jenis.
    public static func morphology(forObjectID id: String) -> Morphology? {
        morphologyByID[id]
    }

    /// Bentuk yang boleh **digambar** untuk sebuah objek, mengingat
    /// keyakinan engine saat ini.
    ///
    /// **Kenapa ini fungsi, bukan `morphology(...)` langsung di view.**
    /// Bentuk adalah **ciri pengenal**: gugus bola yang berinti padat adalah
    /// penanda yang sama meyakinkannya dengan cincin Saturnus, dan galaksi
    /// berpalung adalah penanda seperti pita Jupiter. Aturan yang sudah
    /// berlaku untuk planet — saat engine belum pasti, hanya warna yang
    /// boleh tampil, cirinya tidak — karena itu harus berlaku juga di sini,
    /// dengan cara yang **sama**: satu tempat, diuji di Linux.
    ///
    /// Bahayanya konkret dan sudah pernah terjadi di repo ini: badge di
    /// sebelah gambar bisa bertuliskan "Ragu", sementara gambar di sebelahnya
    /// memperlihatkan bentuk galaksi yang khas. Mata membaca gambar lebih
    /// dulu daripada badge, jadi gambar yang lebih yakin daripada teksnya
    /// adalah klaim identitas yang justru dilarang PRD.
    ///
    /// Saat `isConfirmed == false` hasilnya `nil` — bentuk **netral**, bukan
    /// bentuk objeknya, dan bukan bentuk objek lain. Nama `nil` di sini
    /// berarti "tidak ada bentuk yang boleh diklaim", bukan "tidak tahu".
    public static func drawableMorphology(forObjectID id: String,
                                          isConfirmed: Bool) -> Morphology? {
        guard isConfirmed else { return nil }
        return morphology(forObjectID: id)
    }
}
