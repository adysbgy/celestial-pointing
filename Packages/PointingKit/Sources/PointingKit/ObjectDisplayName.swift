import CelestialEngine

/// Nama objek untuk **layar**, dalam bahasa aktif — termasuk jalur yang lolos
/// dari `BodyName` dan `DisplayLabel`.
///
/// **Kenapa berkas ini ada, padahal dua berkas itu sudah melokalkan nama.**
/// Keduanya melokalkan nama yang **dihitung saat render dari id**:
/// `BodyName.text(_:)` untuk benda tata surya, `DisplayLabel.objectName` untuk
/// bintang & objek langit dalam. Yang belum punya penjaga adalah jalur yang
/// paling tua dan paling langsung: `CelestialObject.name` — field yang diisi
/// **resolver** saat ia mengenali objek (`EphemerisBody.displayName` untuk
/// benda tata surya, `Catalogue.brightStars[..].name` untuk bintang), lalu
/// dibaca apa adanya oleh lima permukaan:
///
///     PointingView             Text(object.name)      — kartu utama
///     ReducedLuminanceView     teks always-on
///     DiagnosticsView          baris objek
///     ObjectDetailView         judul panel rincian
///     ComplicationDigest       headline komplikasi
///
/// **Bentuk kegagalannya berbeda dari dua berkas itu, dan itulah alasan berkas
/// ini berdiri sendiri.** Kalau `DisplayLabel` salah, hasilnya salah **di semua
/// bahasa sekaligus** (nama Indonesia di layar Inggris) dan ada satu titik yang
/// bisa dijaga. Kalau `CelestialObject.name` yang tidak dilokalkan, hasilnya
/// salah **hanya untuk pembaca non-Indonesia** — dan itu justru kasus yang
/// paling jarang dibuka di mesin pengembang, jadi ia bertahan lama. Penjaganya
/// cuma bisa satu: accessor di bawah, dipakai kelima pemanggil itu.
///
/// **Kenapa tidak menambah `localizedName` di `CelestialObject`.** Model itu
/// hidup di paket yang tidak boleh tahu apa pun soal `Bundle`: ia dipakai di
/// Linux, diserialisasi ke berkas hasil eksperimen, dan dibandingkan dengan
/// fixture JPL. Terjemahan di sana juga akan membuat dataset yang tersimpan
/// memuat **label beku** — kelas cacat yang sudah pernah dibayar repo ini
/// (label harus dihitung saat render). Jadi terjemahan dihitung di sini,
/// di lapisan app.
///
/// **Yang tidak diklaim.** Accessor ini tidak memvalidasi bahwa terjemahan di
/// katalog **benar**; hanya bahwa katanya ada, tidak kosong, dan bukan
/// pengenal mentah. Nama yang tidak punya entri katalog dikembalikan apa
/// adanya — mengarang nama dari id dilarang di repo ini.
public enum ObjectDisplayName {

    /// Nama untuk ditampilkan, dalam bahasa aktif.
    ///
    /// Urutan pencarian:
    ///
    /// 1. Kunci benda tata surya (`object.body.<nama>`) — kalau nama yang
    ///    dipasang engine adalah nama sebuah benda tata surya. Inilah yang
    ///    membuat `"Saturnus"` menjadi `"Saturn"` tanpa menyentuh pemanggil.
    /// 2. Kunci nama penuh (`object.name.<pengenal>`) — untuk nama yang
    ///    dipasang engine sebagai **kalimat jadi**, mis. `"Bulan Purnama"`.
    /// 3. Tidak ada keduanya -> nama asli dari engine.
    ///
    /// **Kenapa urutannya begitu, dan kenapa bukan "lokalkan kata pertama".**
    /// Melokalkan kata pertama `"Bulan Purnama"` menghasilkan `"Moon Purnama"`:
    /// separuh baris tampak benar, dan justru karena itu tidak ada yang
    /// mencarinya. Nama yang tidak punya kunci sendiri dikembalikan **utuh** —
    /// salah dalam satu bahasa, tapi konsisten dan bisa dilaporkan.
    public static func text(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return name }

        if let body = bodyMatching(trimmed) {
            let declaration = self.declaration(for: body)
            let localized = TextLocalization.text(declaration)
            // `TextLocalization.text` sudah menolak hasil kosong dan nama kunci,
            // jadi perbandingan ini hanya melewatkan hasil yang benar-benar ada.
            if localized != body.displayName { return localized }
        }

        return TextLocalization.text(
            LocalizedText(key: catalogKey(forName: trimmed), id: trimmed)
        )
    }

    /// Nama objek apa pun untuk layar, dengan **nama engine** bila tidak ada
    /// terjemahannya. Tidak pernah kosong, tidak pernah nama kunci.
    public static func text(of object: CelestialObject) -> String {
        text(object.name)
    }

    /// Deklarasi `LocalizedText` untuk nama engine ini.
    ///
    /// Dipakai juga oleh komplikasi, yang butuh `LocalizedText` (bukan
    /// `String`) supaya bahasa bisa diselesaikan di proses widget — lihat
    /// `ComplicationLocalization`.
    public static func declaration(for object: CelestialObject) -> LocalizedText {
        if let body = bodyMatching(object.name) {
            return declaration(for: body)
        }
        return LocalizedText(key: catalogKey(forName: object.name), id: object.name)
    }

    /// Nama benda tata surya yang cocok dengan nama engine ini, bila ada.
    ///
    /// Nama yang tidak cocok **tidak** ditebak: `"Bulan Purnama"` bukan
    /// `"Bulan"`, dan menebaknya akan menampilkan frasa yang lebih panjang
    /// sebagai satu kata benda di layar.
    static func bodyMatching(_ name: String) -> EphemerisBody? {
        EphemerisBody.allCases.first { $0.displayName == name }
    }

    static func declaration(for body: EphemerisBody) -> LocalizedText {
        BodyName.declaration(for: body)
    }

    /// Kunci katalog untuk nama objek yang dipasang engine.
    ///
    /// Dibentuk dari **pengenal**, bukan dari kalimatnya: `"Nebula Orion"`
    /// menjadi `object.name.nebulaOrion`, dan `"Barnard's Star"` menjadi
    /// `object.name.barnardsStar`. Kalau kalimatnya sendiri yang jadi kunci,
    /// kuncinya akan memuat spasi — dan kunci berspasi membuat
    /// `TextLocalization` tidak lagi bisa membedakan "kunci tidak ada" dari
    /// "terjemahan yang kebetulan berbunyi sama dengan pengenalnya".
    public static func catalogKey(forName name: String) -> String {
        "object.name." + identifier(forName: name)
    }

    /// Kunci yang **mungkin** dipakai: satu per nama yang dirakit engine, dan
    /// yang namanya **perlu diterjemahkan**.
    ///
    /// **Kenapa daftar ini ada, padahal kuncinya sudah dihitung dari nama.**
    /// Gerbang Aturan 19 menuntut setiap kunci katalog dirujuk oleh **literal**
    /// di kode yang dikirim — dan `catalogKey(forName:)` membangun kunci saat
    /// jalan, jadi baris yang ditambahkan bersamanya dilaporkan sebagai yatim
    /// dan membuat CI merah. Bentuk yang sama sudah dipakai
    /// `BodyName.catalogKey(for:)`: kunci ditulis lengkap di kode, bukan
    /// disusun.
    ///
    /// **Kenapa bintang tidak ada di sini.** Dua puluh lima bintang di
    /// `Catalogue.brightStars` punya nama baku yang sama di dua bahasa —
    /// `Sirius`, `Vega`, `Betelgeuse` — jadi baris katalog untuk mereka akan
    /// mengklaim menerjemahkan sesuatu yang tidak berubah, dan
    /// `testPhraseNamesAssembledByTheEngineAlsoHaveRows` sudah menahan
    /// perubahan itu. Yang di sini adalah nama yang **berbeda** antar bahasa:
    /// sembilan bendera tata surya, dan delapan belas objek langit dalam yang
    /// namanya frasa Indonesia.
    ///
    /// **Yang membuat daftar ini tidak bisa basi.**
    /// `testDeclaredKeyListMatchesTheEngineCataloguesExactly` membandingkannya
    /// dua arah dengan kunci yang dihitung dari katalog engine: nama yang
    /// berubah atau objek yang dibuang membuat uji itu merah, bukan membuat
    /// daftarnya diam-diam salah.
    public static let catalogueKeys: [String] = [
        "object.name.matahari",
        "object.name.bulan",
        "object.name.merkurius",
        "object.name.venus",
        "object.name.mars",
        "object.name.jupiter",
        "object.name.saturnus",
        "object.name.uranus",
        "object.name.neptunus",
        "object.name.pleiades",
        "object.name.galaksiAndromeda",
        "object.name.gugusPtolemy",
        "object.name.nebulaOrion",
        "object.name.gugusHercules",
        "object.name.nebulaLaguna",
        "object.name.gugusSarangLebah",
        "object.name.galaksiTriangulum",
        "object.name.gugusSagitarius",
        "object.name.gugusKupuKupu",
        "object.name.nebulaOmega",
        "object.name.nebulaDumbel",
        "object.name.nebulaCincin",
        "object.name.galaksiPusaran",
        "object.name.gugusBebekLiar",
        "object.name.gugusM2",
        "object.name.gugusM35",
        "object.name.galaksiKincirAngin"
    ]

    /// Pengenal stabil untuk sebuah nama: tanpa spasi, tanpa tanda baca, kata
    /// pertama huruf kecil dan sisanya huruf besar.
    ///
    /// **Apostrof itu bagian dari kata, bukan pemisah kata.** `"Barnard's"`
    /// harus menjadi **satu** kata (`barnards`), sama seperti `"Barnards"`.
    /// Kalau apostrof diperlakukan seperti spasi, dua orang yang menulis benda
    /// yang sama dengan ejaan berbeda menghasilkan **dua kunci katalog** — dan
    /// salah satunya akan selalu kosong, sehingga namanya kembali Bahasa
    /// Indonesia tanpa ada yang menyadarinya. `"Kupu-kupu"` sebaliknya: tanda
    /// hubung memang memisahkan, dan kuncinya `gugusKupuKupu`.
    ///
    /// Kata yang tidak memuat huruf dibuang (`"51 Pegasi b"` -> `pegasiB`):
    /// pengenal yang dimulai angka pada kunci ber-titik terlihat seperti versi
    /// lain dari kunci yang sama, dan tidak ada yang bisa membedakannya saat
    /// membaca katalog.
    public static func identifier(forName name: String) -> String {
        let joined = name.lowercased().map { character -> Character in
            if character.isLetter || character.isNumber { return character }
            return Self.wordJoiningCharacters.contains(character) ? character : " "
        }
        let separated: [String] = String(joined)
            .split(separator: " ")
            .map { String($0.filter { $0.isLetter || $0.isNumber }) }
        var words = separated.filter { $0.contains { $0.isLetter } }
        guard !words.isEmpty else { return "unknown" }
        let head = words.removeFirst()
        return head + words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Tanda baca yang **menyambung** dua bagian kata, bukan memisahkannya.
    ///
    /// Sengaja sempit: hanya apostrof (lurus dan miring). Menambahkan titik di
    /// sini akan membuat `"M31."` dan `"M31"` kunci yang sama — benar untuk
    /// singkatan, tapi juga membuat `"Sirius A.B."` menyatu dengan
    /// `"Sirius A. B."`, dan perbedaan itu tidak bisa dipulihkan saat membaca
    /// katalog.
    private static let wordJoiningCharacters: Set<Character> = ["'", "\u{2019}"]
}

public extension CelestialObject {
    /// Nama objek ini untuk layar, dalam bahasa aktif.
    ///
    /// Accessor, bukan field: pemanggil yang lupa melokalkan tetap mendapat
    /// nama engine (perilaku lama), bukan nama kosong.
    var localizedName: String {
        ObjectDisplayName.text(name)
    }
}
