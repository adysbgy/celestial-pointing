import Foundation

/// Apa yang **boleh** digambar layar redup (Always-On) untuk objek terkunci.
///
/// **Kenapa keputusan ini ada di `PointingKit`, bukan di view.** Sampai siklus
/// ini `ReducedLuminanceView` adalah satu-satunya permukaan yang menampilkan
/// objek terkunci **tanpa gambar sama sekali** — hanya nama dan keadaan sebagai
/// teks. Aturan yang sudah menjaga empat permukaan lain (kartu jam, panel
/// iPhone, complication, onboarding) tidak sampai ke sini, karena keputusannya
/// tidak pernah dinyatakan sebagai nilai yang bisa diuji. Yang tersisa hanyalah
/// ingatan orang yang sedang menulis view — dan justru inilah kelas cacat yang
/// paling sering terbukti di repo ini: keputusan yang "hidup di kepala" tidak
/// punya penjaga.
///
/// Begitu gambar masuk ke layar redup, **satu** pertanyaan identitas ikut
/// masuk: bolehkah gambar itu menampilkan ciri pengenalnya (cincin Saturnus,
/// pita Jupiter, bentuk galaksi)? Pertanyaan itu sudah punya satu jawaban di
/// tiga tempat lain (`CelestialVisual.Palette.drawable`,
/// `drawableStarColorIndex`, `DeepSkyCatalogue.drawableMorphology`), dan
/// jawabannya sama di ketiganya: **ciri hanya boleh tampil saat engine yakin.**
/// Layar redup tidak boleh menjadi tempat keempat yang menjawabnya sendiri,
/// karena di situlah perbedaannya paling berbahaya — layar ini sengaja miskin
/// konteks (tanpa badge keyakinan, tanpa panel peringatan, tanpa baris kedua),
/// jadi gambar yang lebih yakin daripada teksnya tidak punya apa pun di
/// sebelahnya untuk membantahnya.
///
/// **Yang TIDAK diklaim.** Ini bukan penilaian baru atas keyakinan engine:
/// `isConfirmed` datang dari pemanggil (di app: `PointingEngine`, yang
/// menurunkannya lewat `PointingSnapshot.confirmsIdentity`). Yang diklaim di
/// sini hanya **pemetaan** keyakinan → rencana gambar, supaya tidak ada satu
/// pun view yang menulis ulang aturannya.
///
/// **Kenapa saat ragu digambar apa-apa sama sekali.** Sampai siklus ini
/// `plan` mengembalikan `.candidate(visual)` saat ragu, dengan alasan bahwa
/// bola netral masih memberi satu hal yang tidak diberikan kata "Ragu":
/// *ada* sesuatu di arah itu. Alasan itu gugur diukur — visual tidak pernah
/// bernama. Layar redup tidak punya badge keyakinan dan tidak punya baris
/// kedua: yang tersisa di sebelah gambar hanyalah nama objek berkurung ragu
/// (`shortLabel`) dan lencana tanda tanya, keduanya **lebih kecil** dari
/// gambar. Jadi wajah pertama yang dibaca pengamat pada jam redup adalah bola
/// yang bentuknya adalah klaim identitas dengan keyakinan penuh; tanda tanya
/// menempel padanya sebagai koreksi, bukan sebagai bingkai. Semua permukaan
/// lain (`Palette.drawable`, `drawableStarColorIndex`,
/// `DeepSkyCatalogue.drawableMorphology`) menjawab pertanyaan yang sama dengan
/// "jangan tampilkan cirinya"; yang paling konsisten dengan PRD ("uncertainty
/// > false confidence") adalah **tidak menampilkan gambar sama sekali**.
///
/// **Yang hilang dan yang tidak hilang.** `.none` tidak membuat layar redup
/// buta: nama objek, keadaan keyakinan, dan status tetap dirender sebagai
/// teks di sebelahnya. Yang hilang hanya gambar. Gambar penuh tetap ada di
/// kartu jam dan panel iPhone, di mana keyakinan punya tempat untuk ditulis.
public enum ReducedLuminanceVisual: Equatable, Sendable {

    /// Rencana gambar untuk layar redup.
    public enum Plan: Equatable, Sendable {
        /// Tidak ada yang digambar: tidak ada objek yang berlaku, **atau**
        /// identitasnya belum dikunci engine.
        ///
        /// Bukan "gambar generik": visual tanpa nama akan menampilkan benda yang
        /// tidak ditentukan engine, dan itu klaim yang dilarang PRD. Layar redup
        /// tanpa gambar tetap menampilkan keadaannya ("Mencari") sebagai teks.
        case none
        /// Gambar **dengan** ciri pengenalnya — engine sudah yakin.
        case identifiable(CelestialVisual)
    }

    /// Rencana gambar untuk objek yang sedang ditampilkan di layar redup.
    ///
    /// - Parameters:
    ///   - visual: model gambar objek yang berlaku, atau `nil` bila tidak ada
    ///     objek yang ditampilkan.
    ///   - isConfirmed: apakah engine sudah mengunci identitasnya. Saat
    ///     `false`, hasilnya `.none` — gambar samar termasuk klaim yang terlalu
    ///     kuat untuk layar yang tidak punya tempat menulis keraguan ini.
    public static func plan(visual: CelestialVisual?,
                            isConfirmed: Bool) -> Plan {
        guard let visual, isConfirmed else { return .none }
        return .identifiable(visual)
    }

    /// Apakah layar redup boleh menganimasikan gambarnya.
    ///
    /// **Selalu `false` saat layar redup**, dan itu bukan pilihan tampilan:
    /// watchOS hanya menyegarkan layar redup sekali per detik, jadi
    /// `TimelineView` 30 fps di sana membakar baterai untuk frame yang tidak
    /// pernah terlihat mulus. Fungsinya ada supaya layar redup terikat pada
    /// kebijakan yang **sama** (`MotionPolicy`) dengan layar penuh, bukan punya
    /// aturan gerak sendiri yang bisa berbeda diam-diam.
    ///
    /// - Parameter policy: kebijakan gerak dari pemanggil (di app: dibangun
    ///   dengan `isLuminanceReduced: true`).
    public static func allowsMotion(policy: MotionPolicy) -> Bool {
        policy.allowsContinuousMotion
    }
}
