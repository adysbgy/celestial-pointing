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
                        raDeg: 275.10833333, decDeg: -16.17666667, magnitude: 6.00),
        // Kelompok ketiga: memperluas cakupan bentuk & menambah wakil langka.
        // M27/M57 = nebula planetari (cincin/belah ketupat), M11 = gugus
        // terbuka padat. Ketiganya objek Messier terang yang masuk akal
        // ditunjuk dengan binokuler.
        //
        // **M51 ada di sini, tapi bentuknya pindah ke `.spiralGalaxy` di
        // kelompok kelima.** Selama beberapa siklus komentar ini menjanjikan
        // "galaksi kini punya wakil berlengan (M51) selain cakram miring
        // (M31/M33)" — dan janji itu tidak pernah punya wujud: `.galaxy`
        // seluruhnya blob di titik pusat, jadi M31 dan M51 digambar
        // **identik** (diukur: 0 piksel berbeda pada fuzziness yang sama).
        // Bentuk berlengan butuh kode gambar sendiri, dan itulah yang
        // `.spiralGalaxy` tambahkan. Lihat
        // `testSpiralGalaxyHasArmsThatThePlainDiscDoesNot`.
        CelestialObject(id: "m27", name: "Nebula Dumbel",   kind: .deepSky,
                        raDeg: 299.90166667, decDeg:  22.72175000, magnitude: 7.40),
        CelestialObject(id: "m57", name: "Nebula Cincin",   kind: .deepSky,
                        raDeg: 283.39620000, decDeg:  33.02910000, magnitude: 8.80),
        CelestialObject(id: "m51", name: "Galaksi Pusaran", kind: .deepSky,
                        raDeg: 202.46957500, decDeg: 47.19525800, magnitude: 8.40),
        CelestialObject(id: "m11", name: "Gugus Bebek Liar", kind: .deepSky,
                        raDeg: 277.77500000, decDeg:  -6.26666667, magnitude: 6.30),
        // Kelompok keempat: melengkapi wakil yang ada, bukan bentuk baru.
        // M2 = gugus bola ketiga (bersama M13/M22), M35 = gugus terbuka keempat
        // (bersama M7/M44/M6). Keduanya objek Messier terang yang naik tinggi
        // di lintang Jakarta dan menambah kepadatan contoh tiap bentuk tanpa
        // memperkenalkan bentuk yang butuh kode gambar baru.
        CelestialObject(id: "m2",  name: "Gugus M2",  kind: .deepSky,
                        raDeg: 323.36208333, decDeg:  -0.82333333, magnitude: 6.50),
        CelestialObject(id: "m35", name: "Gugus M35", kind: .deepSky,
                        raDeg:  92.37333333, decDeg:  24.10666667, magnitude: 5.30),
        // Kelompok kelima: wakil kedua untuk galaksi berlengan.
        //
        // **Kenapa M101 ditambahkan padahal M51 sudah ada.** Bentuk
        // `.spiralGalaxy` baru punya satu wakil, dan satu wakil bukan pola —
        // pengguna yang hanya melihat satu galaksi berlengan tidak punya
        // cara tahu mana ciri bentuk itu dan mana kebetulan objeknya.
        // Itu alasan yang sama yang sudah mengunci aturan "minimal dua
        // wakil per bentuk" di uji; menambah bentuk tanpa memenuhinya akan
        // memerahkannya. M101 (Kincir Angin) adalah spiral menghadap penuh
        // yang paling terkenal, jadi ia pasangan yang jujur untuk M51.
        // Mag 7.86 — masih dalam jangkauan binokuler, sama seperti M51.
        CelestialObject(id: "m101", name: "Galaksi Kincir Angin", kind: .deepSky,
                        raDeg: 210.80254167, decDeg:  54.34916667, magnitude: 7.86)
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
        "m17": 0.72,   // Omega — nebula emisi, lebih sempit dari Orion
        "m27": 0.68,   // Dumbel — nebula planetari, kabut memanjang
        "m57": 0.40,   // Cincin — nebula planetari kecil & padat
        "m51": 0.92,   // Pusaran — galaksi spiral berlengan, kabut lebar
        "m11": 0.42,   // Bebek Liar — gugus terbuka padat (22′)
        "m2":  0.32,   // M2 — gugus bola, padat seperti Hercules
        "m35": 0.52,   // M35 — gugus terbuka longgar, lebih lebar dari Bebek Liar
        "m101": 0.88   // Kincir Angin — galaksi berlengan, lebar seperti Pusaran
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

    // MARK: - Seberapa memanjang siluetnya (bukan cuma seberapa lebar)

    /// Rasio sumbu **mayor : minor** siluet sebuah objek, dari id-nya.
    ///
    /// **Cacat yang ditutup tabel ini.** M27 (Dumbel) dan M57 (Cincin) sama-
    /// sama `Morphology.planetaryNebula`, dan morfologi itu menggambar
    /// **cangkang berongga yang bulat**: enam belas blob pada satu radius,
    /// tiap blob `aspect` 1.0. Akibatnya M27 — yang komentar katalognya
    /// sendiri menyebut "kabut memanjang" — terukur **rasio siluet 1.000**,
    /// lingkaran sempurna, sama persis dengan M57. Satu-satunya yang berbeda
    /// di layar adalah **skala** (siluet 108 px lawan 106 px), dan skala bukan
    /// bentuk. Dua objek katalog yang bentuknya berbeda di langit digambar
    /// identik, tanpa satu pun teks di layar yang bisa membacanya.
    ///
    /// **Kenapa parameter, bukan `case` morfologi baru.** Morfologi adalah
    /// **jenis** objek, dan M27 maupun M57 keduanya nebula planetari — itu
    /// fakta, bukan pilihan. Yang membedakan keduanya adalah **sudut
    /// pandang**: M57 dilihat hampir tepat dari arah kutubnya (1.4′ × 1.0′,
    /// jadi bulat), M27 dari samping (8.0′ × 5.7′, jadi memanjang). Menambah
    /// `case` baru berarti menyatakan dua *jenis* objek, dan tiap `case`
    /// morfologi dituntut repo ini punya warna sendiri
    /// (`testEveryMorphologyHasItsOwnColour`) serta dua wakil di katalog
    /// (`testEveryMorphologyHasMoreThanOneRepresentative`) — jadi jalan itu
    /// memaksa mengarang rona yang tidak ada di langit dan/atau menyisipkan
    /// objek katalog demi memuaskan uji. Tabel per id, seperti
    /// `fuzzinessByID`, mengukur hal yang benar tanpa keduanya.
    ///
    /// Nilai di tabel adalah **rasio yang dipakai untuk menggambar**, dan
    /// untuk M27 ia **0.60**, bukan 0.71: 0.71 adalah rasio siluet yang
    /// *terukur* pada gambar yang dihasilkan 0.60 (108 × 76 px → 0.704),
    /// karena tepi blob gradien tidak pernah setajam kotak pembatasnya.
    /// Nilai yang digambar dan nilai yang terukur karena itu berbeda, dan
    /// yang disimpan di sini adalah yang **digambar** — angka yang sama
    /// dengan yang ada di `Tools/render-visuals.py`, karena
    /// `check_deep_sky_layouts_match_the_model` membandingkan keduanya.
    ///
    /// 1.0 = bulat. Yang tidak ada di tabel dianggap **1.0**, bukan nilai
    /// tengah: siluet yang lonjong adalah **klaim bentuk**, dan
    /// memberikannya sebagai bawaan berarti setiap objek baru yang belum
    /// ditinjau tampil memanjang tanpa dasar. Kebalikan dari `fuzziness`,
    /// yang bawaannya nilai tengah justru supaya tidak mengklaim "titik".
    public static let elongationByID: [String: Double] = [
        "m27": 0.60   // Dumbel — cangkang dilihat dari samping; 0.704 terukur
    ]

    /// Seberapa memanjang siluet sebuah objek, dari id-nya.
    ///
    /// Bawaannya **1.0** (bulat) — lihat alasannya di `elongationByID`.
    public static func elongation(forObjectID id: String) -> Double {
        elongationByID[id] ?? 1.0
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
        /// Nebula planetari: cangkang gas yang **berongga di tengah** —
        /// kebalikan dari nebula emisi, yang justru paling terang di tengah.
        ///
        /// **Kenapa ini kasus sendiri, bukan `.nebula`.** M27 (Dumbel) dan
        /// M57 (Cincin) sampai siklus ini dipetakan ke `.nebula`, padahal
        /// komentar katalognya sendiri menyebutnya "nebula planetari". Dua
        /// bentuk itu berlawanan arah: nebula emisi memusat, nebula planetari
        /// berlubang. Menggambar yang kedua sebagai yang pertama bukan
        /// sekadar kurang mirip — ia menyatakan "gas mengumpul di sini" pada
        /// objek yang gasnya justru sudah ditiup keluar oleh bintang
        /// pusatnya. Nama morfologinya juga dipakai pengumuman VoiceOver,
        /// jadi yang terdengar ikut salah.
        ///
        /// Ciri yang membedakannya di layar adalah **lubang tengah**, bukan
        /// ukuran keseluruhan: cangkangnya berupa cincin, dan bagian
        /// dalamnya kosong.
        case planetaryNebula
        /// Galaksi: cakram miring dengan tonjolan inti — terlihat dari rasio
        /// sumbu elipsnya, bukan cuma dari lebarnya.
        ///
        /// **Yang ini galaksi tanpa lengan yang terbaca.** M31 dan M33
        /// tampak dari Bumi nyaris miring (inklinasi besar), sehingga
        /// lengannya memipih jadi cakram yang nyaris tak berlengan. Jadi
        /// bentuk ini bukan penyederhanaan — ia memang yang terlihat.
        /// Galaksi yang tampak dari atas (M51, M101) masuk `spiralGalaxy`.
        case galaxy
        /// Galaksi spiral **menghadap penuh**: lengan yang benar-benar
        /// terbaca, bukan cakram.
        ///
        /// **Kenapa ini kasus sendiri, bukan `.galaxy` yang diperlebar.**
        /// Komentar katalog sudah lama menjanjikan "wakil berlengan" untuk
        /// galaksi, dan `.galaxy` tidak pernah bisa memenuhinya: seluruh
        /// tata letaknya adalah tiga blob yang **semuanya di titik pusat**,
        /// jadi tidak ada satu angka pun yang bisa menggeser sesuatu ke
        /// lengan. Diukur pada fuzziness yang sama, M31 dan M51 menghasilkan
        /// **0 piksel berbeda** — dua objek katalog yang seharusnya berbeda
        /// bentuk digambar identik, dan tidak ada teks di layar yang bisa
        /// membacanya.
        ///
        /// Bedanya dari `.galaxy` **struktural, bukan skala**: jumlah blob
        /// (sepuluh lawan tiga) dan sebarannya (blob terluar di 0.53 R
        /// lawan 0.00 R). Memperlebar `.galaxy` tidak akan pernah
        /// menghasilkannya, karena lebar hanya mengubah ukuran, bukan
        /// bentuk.
        case spiralGalaxy
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
        "m17": .nebula,           // Omega — nebula emisi
        "m27": .planetaryNebula,  // Dumbel — nebula planetari bipol (lihat elongasiByID)
        "m57": .planetaryNebula,  // Cincin — nebula planetari, dilihat dari kutub
        "m51": .spiralGalaxy,     // Pusaran — galaksi spiral berlengan (menghadap penuh)
        "m11": .openCluster,      // Bebek Liar — gugus terbuka padat
        "m2":  .globularCluster,  // M2 — gugus bola padat
        "m35": .openCluster,      // M35 — gugus terbuka longgar
        "m101": .spiralGalaxy     // Kincir Angin — galaksi spiral berlengan
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
