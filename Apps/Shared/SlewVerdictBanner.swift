import SwiftUI
import CelestialEngine
import PointingKit

/// Baris putusan GoTo — **mengapa teleskop boleh atau tidak boleh bergerak**.
///
/// **Kenapa ada, padahal mesinnya sudah lama benar.** `SlewPlanner` menghitung
/// putusan keselamatan sejak FASE 3, dan `PointingController.slewDecision(date:)`
/// menyambungkannya ke engine yang berjalan. Yang hilang bukan perhitungannya,
/// melainkan **jalurnya ke layar**: `slewDecision` nol pemanggil di seluruh
/// `Apps/`. Akibatnya satu-satunya aturan keras PRD yang menyangkut keselamatan
/// alat — "POINT → OBJECT ID → SAFE GOTO" — tidak punya wajah.
///
/// Yang paling berbahaya bukan ketiadaan baris ini, melainkan **penyamarataan**
/// yang ia sebabkan: tanpa kalimat, penolakan karena `sunProximity` (melindungi
/// peralatan dan mata dari cahaya Matahari) terlihat persis sama dengan
/// penolakan karena `lowConfidence` (soal ketelitian) — yaitu sama-sama tidak
/// terlihat.
///
/// **Kenapa `nil` berarti tidak ada apa-apa, bukan "aman".** Sama alasannya
/// dengan `Resolution.searchHint`: putusan ini adalah penjelasan atas sebuah
/// **masalah**. Kalau ia juga bisa berbunyi saat GoTo aman, setiap pemanggil
/// harus ingat memeriksa keadaan sebelum menampilkannya — dan satu tempat yang
/// lupa akan menuliskan "ditolak" di sebelah GoTo yang justru berjalan. Dengan
/// `nil` sebagai satu-satunya jawaban untuk "aman", dua keadaan itu tidak bisa
/// muncul bersamaan.
///
/// **Batasnya.** Tampilan ini hanya meneruskan kalimat yang **sudah** diputuskan
/// `SlewPlanner`; ia tidak bisa melunakkan penolakan menjadi izin, dan tidak
/// memutuskan apa pun sendiri.
struct SlewVerdictBanner: View {

    /// Kalimat putusan dalam bahasa aktif; `nil` bila GoTo aman atau belum ada
    /// jawaban. Diambil dari `SlewDecision.verdictText` (teruji di Linux), bukan
    /// dirangkai di sini.
    let verdict: String?

    /// Padding kartu; jam sempit, iPhone lega.
    var padding: CGFloat = 8

    var body: some View {
        if let verdict {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    // Simbolnya hiasan: kalimat di sebelahnya sudah menyebut
                    // sebabnya. Tanpa baris ini VoiceOver mengucapkan nama
                    // berkas SF Symbol-nya.
                    .accessibilityHidden(true)
                Text(verdict)
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(PointingTone.warning.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .surfaceCard(level: .raised, radius: 10)
            // Satu elemen: kalimatnya satu pengumuman utuh. Peringatan
            // keselamatan yang terpecah jadi tiga item yang harus diusap satu
            // per satu justru lebih mudah terlewat.
            .accessibilityElement(children: .combine)
        }
    }
}
