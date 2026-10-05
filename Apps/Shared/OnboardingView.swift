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

    var body: some View {
        ZStack {
            SurfacePalette.appBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(SurfacePalette.active.accentGradient)
                    .accessibilityHidden(true)

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
}
