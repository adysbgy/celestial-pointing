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
/// **Kenapa sekarang menerima `SlewDecision`, bukan `String?`.** Versi pertama
/// mengambil kalimatnya saja. Itu cukup untuk memisahkan **teks** dua kelas
/// bahaya, tapi tidak untuk memisahkan **bobotnya**: view menggambar keduanya
/// dengan warna peringatan yang sama dan ikon yang sama, sehingga pemisahan
/// berhenti tepat di titik yang paling menentukan — pengguna yang membaca
/// sekilas. Dengan menerima putusannya utuh, warna dan ikon datang dari
/// `SlewDecision.verdictTone`/`verdictSymbolName` (teruji di Linux), dan kedua
/// permukaan — jam dan iPhone — tidak bisa lagi berbeda pendapat soal mana yang
/// bahaya dan mana yang sekadar mutu.
///
/// **Kenapa ikon tidak boleh ikut disederhanakan.** Di Mode Malam seluruh palet
/// nada menyempit jadi satu merah (`TonePalette.night`), jadi warna berhenti
/// membedakan — itu sudah dicatat sebagai konsekuensi yang diterima. Yang tetap
/// membedakan adalah **ikon**. Kalau ikonnya sama, pembeda terakhir hilang
/// tepat di mode yang paling sering dipakai saat mengamati langit.
///
/// **Kenapa `nil` berarti tidak ada apa-apa, bukan "aman".** Sama alasannya
/// dengan `Resolution.searchHint`: putusan ini adalah penjelasan atas sebuah
/// **masalah**. Kalau ia juga bisa berbunyi saat GoTo aman, setiap pemanggil
/// harus ingat memeriksa keadaan sebelum menampilkannya — dan satu tempat yang
/// lupa akan menuliskan "ditolak" di sebelah GoTo yang justru berjalan. Dengan
/// `nil` sebagai satu-satunya jawaban untuk "aman", dua keadaan itu tidak bisa
/// muncul bersamaan.
///
/// **Batasnya.** Tampilan ini hanya meneruskan putusan yang **sudah** dihitung
/// `SlewPlanner`; ia tidak bisa melunakkan penolakan menjadi izin, dan tidak
/// memutuskan apa pun sendiri.
struct SlewVerdictBanner: View {

    /// Putusan GoTo; `nil` bila belum ada jawaban. Bahkan saat aman view ini
    /// tidak menampilkan apa-apa, karena `verdictText` mengembalikan `nil`.
    let decision: SlewDecision?

    /// Padding kartu; jam sempit, iPhone lega.
    var padding: CGFloat = 8

    var body: some View {
        // Dibaca sekali supaya `verdictText` dan `verdictTone` tidak bisa
        // memutuskan dari sumber yang berbeda.
        if let decision, let text = decision.verdictText {
            let tone = decision.verdictTone
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: decision.verdictSymbolName)
                    .font(.caption2)
                    // Simbolnya hiasan: kalimat di sebelahnya sudah menyebut
                    // sebabnya. Tanpa baris ini VoiceOver mengucapkan nama
                    // berkas SF Symbol-nya.
                    .accessibilityHidden(true)
                Text(text)
                    .font(.caption2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(tone.color)
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
