import SwiftUI
import PointingKit

/// Status apakah layar perkenalan sudah pernah dilihat.
///
/// Disimpan per-`UserDefaults` lewat `OnboardingStorage.key` — satu kunci
/// untuk jam dan iPhone. Tidak ada yang diklaim di sini: layar ini hanya
/// menjelaskan **cara pakai**, bukan hasil pengukuran, jadi tidak ada risiko
/// false confidence.
enum OnboardingStorage {
    static let key = "onboardingSeen"
}

/// Layar perkenalan "value-first": satu kartu singkat, bukan tur panjang.
///
/// **Kenapa satu kartu, bukan tur.** Pengguna membuka app di malam hari sambil
/// mengangkat pergelangan ke langit; lima layar instruksi justru menunda
/// hal yang sebenarnya dicari: "arahkan, tahu apa yang kulihat". Kartu ini
/// diketuk sekali lalu hilang, dan tidak pernah muncul lagi.
struct OnboardingView: View {

    /// Dipanggil setelah pengguna menutup kartu — pemanggil yang menyimpan
    /// status "sudah dilihat" (bukan view ini), supaya view tetap murni UI.
    var onDone: () -> Void

    /// Aturan gerak yang sama dengan layar lain, bukan ambang lokal.
    ///
    /// Sebelum ini layar perkenalan tidak membaca `reduceMotion` sama sekali.
    /// Begitu ilustrasinya berdenyut (yang memang harus — lihat komentar di
    /// pemanggilan `CelestialVisualView`), keadaan itu berubah dari "tidak
    /// relevan" menjadi "penyimpangan": pengguna yang meminta reduksi gerak
    /// akan melihat satu-satunya bintang di app ini berdenyut terus selama
    /// kartu terbuka. `MotionPolicy` yang sama dipakai jam dan iPhone, jadi
    /// tidak ada ambang kedua yang bisa berbeda pendapat.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Jam denyut. Di-reset saat berubah dari nol ke bukan-nol tidak perlu:
    /// kartu ini berumur pendek dan tidak punya `scenePhase` sendiri — layar
    /// yang menaunginya yang tahu soal itu, dan `MotionPolicy` di sana yang
    /// memutuskan. Di sini hanya satu fase dari satu titik mula.
    @State private var pulseStart = Date()

    var body: some View {
        ZStack {
            // **`AppBackdropView`, bukan `SurfacePalette.appBackground` mentah.**
            //
            // Sampai siklus ini layar perkenalan adalah satu-satunya layar
            // penuh yang menggambar gradien dua warna saja. Lima layar lain
            // memakai `appBackdrop()`, jadi app ini punya langit berbintang di
            // mana-mana **kecuali** di tempat pertama pengguna melihatnya.
            //
            // Cacatnya tidak berbunyi di gerbang mana pun: setiap sapuan
            // "apakah layar memakai latar aplikasi" melihat lima pemakaian
            // yang benar dan hijau. Yang tidak terlihat adalah ketiadaan di
            // berkas keenam. Aturan 49 sekarang menutupnya, dan aturan itu
            // **memerah pada bentuk lama** — bukan pada bentuk ini.
            //
            // `starfield: true` sama dengan layar utama: kartu ini muncul di
            // atas layar yang sudah punya langit, jadi mematikan langit di
            // sini akan membuatnya terlihat seperti potongan kertas.
            AppBackdropView()

            VStack(spacing: 18) {
                // Pahlawan prosedural, bukan ikon SF Symbol: layar perkenalan
                // adalah **pertama** yang dilihat pengguna, dan ia harus
                // memperlihatkan benda yang sebenarnya ditampilkan app —
                // titik cahaya di langit — bukan lambang pencarian generik.
                //
                // **Kenapa ini bukan klaim identitas.** Ia digambar lewat
                // jalur `CelestialVisual` yang sama dengan layar utama, tapi
                // tanpa nama dan tanpa keadaan engine: `colorIndexBV` 0 berarti
                // putih netral (bukan spektrum bintang tertentu), dan ia
                // berdiri sendiri di atas teks janji produk. Ia ilustrasi,
                // bukan hasil pengukuran — sama seperti piringan Bulan netral
                // pada kasus "fase tidak diketahui" yang sudah diuji.
                // `isConfirmed: true` di sini murni supaya tidak ada lencana
                // "?" menempel (lencana itu untuk engine yang ragu, bukan
                // untuk ilustrasi statis).
                //
                // Ukurannya tetap (bukan `@ScaledMetric`): ini citra, bukan
                // teks — Dynamic Type tidak mengubah ukuran gambar benda
                // langit di app ini. Lihat `WatchMetrics`.
                //
                // **Warna sengaja netral (baku `colorIndexBV = 0`).** Aturan
                // 24 melarang memakai `colorIndexBV` secara mentah di `Apps/`
                // — warna spektral (biru Rigel, merah Betelgeuse) adalah ciri
                // pengenal, dan lewat `drawableStarColorIndex` baru boleh
                // tampil. Di sini kita *tidak* menetapkan indeks sama sekali,
                // jadi yang dipakai adalah nilai baku 0 = putih netral. Itu
                // ilustrasi, bukan bintang tertentu — sama seperti piringan
                // Bulan netral pada kasus "fase tidak diketahui" yang sudah
                // diuji. `isConfirmed: true` pada view hanya menyembunyikan
                // lencana "?", karena lencana itu untuk engine yang ragu,
                // bukan untuk ilustrasi statis.
                // Sumber: `onboardingVisual` di bawah. Denyutnya digerbangi
                // `hasPulse` + `MotionPolicy`, sama seperti jam dan iPhone.
                onboardingVisual

                Text(TextLocalization.text(.onboardingTitle))
                    .font(.title2.bold())
                    .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                    .multilineTextAlignment(.center)

                Text(TextLocalization.text(.onboardingSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                // Janji produk, bukan instruksi teknis: ketidak-pastian ditampilkan
                // apa adanya. Ini satu-satunya tempat yang berani mengatakan
                // "mungkin tidak tahu", supaya ekspektasi pengguna jujur sejak
                // pertama kali membuka app.
                Text(TextLocalization.text(.onboardingHonesty))
                    .font(.caption)
                    .foregroundStyle(PointingTone.warning.color)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                Button(action: onDone) {
                    Text(TextLocalization.text(.onboardingStart))
                        .font(.headline)
                        // **Warna label tombol, bukan warna teks.** Label ini
                        // duduk di atas `.borderedProminent` yang ditint
                        // `PointingTone.active` — jadi latarnya aksen, bukan
                        // permukaan. Mewarnainya dengan `textPrimary` membuat
                        // teks dan latarnya sama-sama aksen, dan di mode malam
                        // keduanya merah: labelnya lenyap.
                        //
                        // `onAccent` (hitam), bukan `.white`: terukur putih
                        // hanya 3.70:1 di atas aksen biru dan 4.12:1 di atas
                        // ungu — keduanya di bawah 4.5:1, jadi putih **tidak
                        // pernah** lolos di sini. Hitam 5.68/5.09/5.25:1, dan
                        // di mode malam ia tidak memancarkan hijau/biru sama
                        // sekali. Dihitung + dijaga `SurfacePaletteTests`.
                        .foregroundStyle(SurfacePalette.active.onAccentColor)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PointingTone.active.color)
                .padding(.horizontal, 40)
                .padding(.top, 6)
            }
            .padding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TextLocalization.text(.onboardingLabel))
    }

    /// Fase denyut untuk ilustrasi — gerbangnya `hasPulse` seperti di jam.
    ///
    /// **Kenapa pembungkus `TimelineView` dipilih lewat `if`, bukan dengan
    /// mengirim fase yang `0`-nya "cukup kecil".** `Canvas` digambar ulang
    /// setiap kali nilai tangkapannya berubah; `TimelineView` 30 fps di kartu
    /// perkenalan berarti 30 gambar identik per detik untuk satu titik cahaya.
    /// Nilai `0` dari `MotionPolicy` sudah tepat nol, tapi **penyegarannya**
    /// yang membuang baterai, dan itu hanya berhenti kalau penyegarnya tidak
    /// terpasang.
    @ViewBuilder
    private var onboardingVisual: some View {
        let illustration = CelestialVisual(kind: .star, relativeSize: 0.72)
        if !reduceMotion && illustration.hasPulse {
            TimelineView(.animation(minimumInterval: MotionPolicy.pulseFrameInterval)) { _ in
                CelestialVisualView(visual: illustration,
                                    diameter: VisualImageMetrics.onboardingIllustrationDiameter,
                                    isConfirmed: true,
                                    // Gerbang `hasPulse` di ekspresi nilainya,
                                    // sama seperti jam: hanya bintang yang
                                    // berdenyut, dan jenisnya dibaca dari
                                    // model, bukan didaftar ulang di sini.
                                    pulse: illustration.hasPulse ? pulsePhase
                                                                 : MotionPolicy.staticPulsePhase)
                    .accessibilityHidden(true)
            }
        } else {
            // Diam karena diminta, bukan karena lupa.
            CelestialVisualView(visual: illustration,
                                diameter: VisualImageMetrics.onboardingIllustrationDiameter,
                                isConfirmed: true,
                                pulse: MotionPolicy.staticPulsePhase)
                .accessibilityHidden(true)
        }
    }

    /// Fase denyut dalam radian — **nol persis** saat denyut tidak boleh jalan,
    /// karena ia datang dari `MotionPolicy` dan bukan dari `sin()` lokal.
    private var pulsePhase: Double {
        MotionPolicy(reduceMotion: reduceMotion,
                     isLuminanceReduced: false,
                     isSceneActive: true)
            .pulsePhase(elapsedSeconds: Date().timeIntervalSince(pulseStart))
    }
}
