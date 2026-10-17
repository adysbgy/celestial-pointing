import Foundation

/// Apakah animasi boleh berjalan — **satu aturan** untuk denyut kontinu dan
/// transisi sesaat.
///
/// **Kenapa ini ada di `PointingKit`, bukan di view.** Dua alasan yang saling
/// menguatkan:
///
/// 1. **Tidak bisa diuji di lapisan lain.** `accessibilityReduceMotion` dan
///    `isLuminanceReduced` hanya ada di SwiftUI, dan `Canvas`/`TimelineView`
///    tidak bisa dibangun di Linux. Kalau aturan ini tinggal di view, satu-
///   -satunya penjaganya adalah ingatan orang yang sedang menulis — persis
///    yang sudah terbukti gagal untuk Dynamic Type, `.system(size:)`, dan
///    font semantik.
/// 2. **Dua bentuk gerak, satu alasan.** "Gerak berulang tanpa akhir"
///    (denyut glow) dan "gerak sekali lalu berhenti" (pop saat kunci) punya
///    implementasi berbeda di SwiftUI — satu `TimelineView`, satu
///    `withAnimation` — tapi **jawaban accessibility-nya sama**: kalau
///    pengguna minta reduksi gerak, keduanya harus berhenti. Menghentikannya
///    di dua tempat berarti dua tempat yang bisa berbeda pendapat, dan
///    keduanya terlihat benar secara terpisah.
///
/// **Yang bukan bagian dari aturan ini.** `isSceneActive` hanya berlaku untuk
/// denyut: layar tidak aktif bukan alasan-accessibility, cuma alasan-baterai.
/// Pop saat kunci dipicu aksi pengguna yang sedang menatap, jadi layar harus
/// aktif saat itu terjadi — tapi pop tetap boleh jalan di layar yang normal.
/// Kalau keduanya memakai ambang yang sama, pop ikut hilang setiap kali app
/// kehilangan fokus, dan umpan balik "kunci berhasil" ikut hilang.
public struct MotionPolicy: Equatable, Sendable {

    /// Pengguna meminta pengurangan gerak (Settings > Accessibility).
    public var reduceMotion: Bool
    /// Layar redup Always-On.
    public var isLuminanceReduced: Bool
    /// Scene sedang aktif (terlihat di layar).
    public var isSceneActive: Bool

    public init(reduceMotion: Bool,
                isLuminanceReduced: Bool,
                isSceneActive: Bool) {
        self.reduceMotion = reduceMotion
        self.isLuminanceReduced = isLuminanceReduced
        self.isSceneActive = isSceneActive
    }

    /// Denyut berulang (glow bintang) boleh berjalan.
    ///
    /// Tidak boleh kalau pengguna meminta reduksi gerak, karena denyut tidak
    /// pernah benar-benar berhenti — ia berulang terus selama layar menyala,
    /// yang persis yang diminta untuk dihentikan.
    ///
    /// Layar tidak aktif ikut mematikan: denyut di latar belakang hanya
    /// membebani baterai tanpa pernah terlihat. Ini **alasan baterai**, bukan
    /// accessibility, dan itu sebabnya ia tidak ikut masuk ambang transisi.
    public var allowsContinuousMotion: Bool {
        !reduceMotion && !isLuminanceReduced && isSceneActive
    }

    /// Transisi sesaat (pop saat kunci) boleh berjalan.
    ///
    /// Hanya dua hal yang boleh menghentikannya, dan layar tidak aktif bukan
    /// salah satunya: transisi dipicu aksi pengguna, jadi saat transisi
    /// berjalan layarnya aktif.
    public var allowsTransitions: Bool {
        !reduceMotion && !isLuminanceReduced
    }

    /// Laju denyut, dalam radian per detik.
    ///
    /// Angka tunggal yang di sini supaya "seberapa cepat berdenyut" punya satu
    /// jawaban. Nilai bakunya **bukan** di view, karena perubahan laju di view
    /// tidak akan pernah bisa diuji di Linux.
    public static let pulseRateRadiansPerSecond: Double = 1.1

    /// Fase yang dikirim ke **gambar statis** — ilustrasi, bukan pandangan.
    ///
    /// **Kenapa ini ada, padahal nilainya nol.** Tiga pemanggil
    /// `CelestialVisualView` di `Apps/` memutuskan denyut dengan cara yang sama
    /// persis, dan dua di antaranya menulis keputusan itu satu kali per
    /// cabang. Pemanggil ketiga — ilustrasi onboarding — tidak menulis
    /// `pulse:` sama sekali, jadi ia menerima nilai baku `0` **tanpa
    /// keputusan**. Ilustrasinya adalah bintang, dan bintang satu-satunya jenis
    /// yang berdenyut menurut `CelestialVisual.hasPulse`; hasilnya, layar
    /// pertama yang dilihat pengguna adalah satu-satunya tempat glow bintang
    /// diam.
    ///
    /// **Kenapa di sini, bukan di gerbang sapu.** Aturan 40 menuntut setiap
    /// pemanggil menyebut fase yang dikirimnya, dan itu cukup untuk membuat
    /// kelalaian terlihat. Yang tidak bisa dijawab gerbang teks: **nilai apa**
    /// yang benar untuk gambar statis. Menulis `0` di setiap layar berarti
    /// keputusan yang sama ditulis tiga kali, dan nilai yang berbeda di antara
    /// ketiganya tidak akan terdeteksi — gambar yang sama bisa tampak berbeda
    /// di onboarding dan di layar redup tanpa satu pun uji berbunyi.
    ///
    /// Nilainya **identik** dengan `pulsePhase` saat gerak ditolak, dan itu
    /// dijaga uji, bukan hanya dikomentari.
    public static let staticPulsePhase: Double = 0

    /// Fase denyut untuk waktu yang sudah lewat, dalam radian.
    ///
    /// Mengembalikan **tepat nol** saat gerak kontinu tidak boleh berjalan,
    /// bukan amplitude kecil. Bolak-balik kecil itu kelihatan seperti pilihan:
    /// view membaca `sin(0) = 0`, jadi optiknya diam — tapi nilainya tidak nol,
    /// pemeriksaan mana pun yang berburu "apakah denyutnya benar-benar mati"
    /// akan melihat angka yang bergerak. Satu nilai, satu arti.
    ///
    /// - Parameter elapsedSeconds: waktu sejak denyut dimulai. Nilai
    ///   negatif dijepit ke nol supaya jam yang belum dimulai tidak berdenyut
    ///   ke belakang.
    public func pulsePhase(elapsedSeconds: Double) -> Double {
        guard allowsContinuousMotion else { return 0 }
        return max(0, elapsedSeconds) * Self.pulseRateRadiansPerSecond
    }

    /// Bentuk gerak untuk pop saat objek terkunci: dua tahap, satu angka.
    ///
    /// **Kenapa ini pindah ke sini.** Angka yang sama — `response: 0.42`,
    /// `dampingFraction: 0.82`, dan jeda `0.08` untuk tahap kedua — ditulis
    /// **empat kali** di dua aplikasi:
    ///
    ///     Apps/PointAndKnowWatch/Sources/PointingView.swift:564,568
    ///     Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift:851,855
    ///
    /// Kedua pasang itu tidak bisa saling melihat. Brief meminta "token tema
    /// dipakai Watch + iPhone", tetapi yang lebih mendesak: pop saat kunci
    /// adalah **umpan balik bahwa identifikasi berhasil**. Kalau jam dan iPhone
    /// memantul dengan bentuk berbeda, keduanya tetap "terlihat benar" sendiri-
    /// sendiri, dan tidak ada satu pun uji atau gerbang di Linux yang bisa
    /// membandingkannya — `Apps/` tidak pernah dibangun di sini.
    ///
    /// **Kenapa dua tahap, bukan satu.** Tahap pertama menaikkan skala sedikit
    /// di atas 1 sambil memunculkan opacity; tahap kedua menurunkannya kembali
    /// ke 1. Kalau keduanya dijalankan bersamaan, skala hanya berhenti di 1.04
    /// dan tidak pernah kembali — objek terkunci tampak 4% lebih besar
    /// selamanya. Jedanya yang membuat "memantul" terjadi.
    ///
    /// **Yang TIDAK diklaim.** Angka-angka ini **tidak** diukur dari rasa
    /// Apple; ia angka yang sudah dipakai repo ini dan di sini hanya
    /// dijadikan satu. Yang dibuktikan uji adalah bahwa keduanya **berbeda
    /// tahap** dan bahwa tahap kedua memang kembali ke 1 — bukan bahwa 0.42
    /// detik terasa paling enak.
    public struct LockArrival: Equatable, Sendable {

        /// Lama tahap pertama, detik.
        public static let responseSeconds: Double = 0.42
        /// Redaman pegas. Di bawah 1 berarti memantul sedikit lalu tenang.
        public static let dampingFraction: Double = 0.82
        /// Skala puncak tahap pertama — sedikit di atas 1 supaya terlihat
        /// "muncul", bukan sekadar memudar.
        public static let peakScale: Double = 1.04
        /// Skala akhir. **Wajib 1**: objek yang terkunci harus berhenti pada
        /// ukuran yang sama dengan objek yang tidak pernah beranimasi.
        public static let settledScale: Double = 1
        /// Jeda sebelum tahap kedua mulai, detik.
        public static let settleDelaySeconds: Double = 0.08

        /// Apakah tahap kedua benar-benar mengembalikan skala ke keadaan diam.
        ///
        /// Ditulis sebagai fungsi supaya bisa diuji: nilai `peakScale` yang
        /// sama dengan `settledScale` akan membuat pop tidak terlihat, dan
        /// `settledScale` selain 1 akan meninggalkan objek pada ukuran yang
        /// salah selamanya.
        public static var settlesBackToRest: Bool {
            settledScale == 1 && peakScale > settledScale
        }
    }
}