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

    // Jarak di jam lebih rapat: 40 pt inset tombol memakan hampir separuh
    // layar 40 mm.
    #if os(watchOS)
    private static let spacing: CGFloat = 10
    private static let buttonInset: CGFloat = 8
    private static let outerPadding: CGFloat = 4
    #else
    private static let spacing: CGFloat = 18
    private static let buttonInset: CGFloat = 40
    private static let outerPadding: CGFloat = 16
    #endif

    var body: some View {
        ZStack {
            SurfacePalette.appBackground
                .ignoresSafeArea()

            // Bergulir, bukan dipadatkan: di jam 40–49 mm tumpukan ini lebih
            // tinggi dari layar, dan tanpa ScrollView SwiftUI memotong judul
            // dan isi jadi "Point your w…" (terlihat di Ultra 3). Setiap teks
            // juga diizinkan tumbuh vertikal (`fixedSize`) dan judul boleh
            // mengecil sedikit sebelum membungkus.
            ScrollView {
            VStack(spacing: Self.spacing) {
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
                CelestialVisualView(
                    visual: CelestialVisual(kind: .star, relativeSize: 0.72),
                    diameter: 64,
                    isConfirmed: true)
                    .accessibilityHidden(true)

                Text(TextLocalization.text(.onboardingTitle))
                    .font(.title2.bold())
                    .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(TextLocalization.text(.onboardingSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280)

                // Janji produk, bukan instruksi teknis: ketidak-pastian ditampilkan
                // apa adanya. Ini satu-satunya tempat yang berani mengatakan
                // "mungkin tidak tahu", supaya ekspektasi pengguna jujur sejak
                // pertama kali membuka app.
                Text(TextLocalization.text(.onboardingHonesty))
                    .font(.caption)
                    .foregroundStyle(PointingTone.warning.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 280)

                Button(action: onDone) {
                    Text(TextLocalization.text(.onboardingStart))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PointingTone.active.color)
                .padding(.horizontal, Self.buttonInset)
                .padding(.top, 6)
            }
            .padding(Self.outerPadding)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TextLocalization.text(.onboardingLabel))
    }
}
