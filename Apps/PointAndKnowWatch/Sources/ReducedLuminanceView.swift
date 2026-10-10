import SwiftUI
import CelestialEngine
import PointingKit

/// Versi **sederhana + kontras tinggi** untuk layar redup (Always-On).
///
/// Kenapa perlu terpisah, bukan sekadar "redupkan warna saja": saat
/// `isLuminanceReduced` aktif, layar watchOS diredupkan oleh sistem dan
/// **sebagian gestur diabaikan**. Layar interaktif yang bergantung pada
/// swipe/ketukan tidak bisa diandalkan — dan layar yang penuh teks halus
/// (angka 10pt, abu-abu sekunder) praktis tak terbaca. Karena itu yang tampil
/// di sini hanya dua hal yang benar-benar harus terbaca sekilas:
/// **nama objek** dan **keadaannya**, dalam huruf besar warna terang. Tidak ada
/// animasi, tidak ada detail halus, tidak ada tombol.
///
/// Isinya **hanya** informasi yang sudah berlaku — sama seperti `PointingView`.
/// Kalau keadaan tidak punya jawaban, tidak ada nama yang dikarang; hanya status
/// "Arahkan"/"Mencari" yang tampil. Objek sisa tetap ditandai, karena di layar
/// sekilas tanpa panel peringatan yang biasa, objek lama tanpa penanda akan
/// terbaca sebagai hasil pengukuran sekarang.
struct ReducedLuminanceView: View {

    @ObservedObject var engine: PointingEngine
    /// Petunjuk arah yang sedang berlaku (ADR-018). Saat lengan menunjuk
    /// langit layar justru redup, jadi panah dan jaraknya harus ada di sini —
    /// dulu layar ini hanya bertuliskan keadaan ("Siap", "Menunjuk").
    var hint: GuideHint? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                if let hint, engine.displayedObject == nil {
                    Image(systemName: "location.north.fill")
                        .font(.largeTitle)
                        .rotationEffect(.degrees(hint.arrowDeg))
                        .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                        .accessibilityHidden(true)
                    Text(verbatim: WatchHomeText.degrees(hint.separationDeg))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                    Text(WatchHomeText.guideTitle(hint.name))
                        .font(.footnote)
                        .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                        .multilineTextAlignment(.center)
                }
                // Nama objek: satu-satunya informasi yang paling mungkin dicari
                // pengamat saat layar redup.
                if let object = engine.displayedObject {
                    // **Penanda ragu menempel pada nama, bukan di bawahnya.**
                    //
                    // Layar ini tidak punya badge keyakinan seperti layar
                    // penuh, jadi tanpa penanda eksplisit nama kandidat
                    // tampil sebagai huruf terbesar di layar -- dan itu
                    // terbaca sebagai temuan, bukan sebagai kandidat.
                    // `shortLabel` di bawah memang berbeda dari `lock`,
                    // tetapi ukurannya lebih kecil dan tidak menempel pada
                    // nama, sehingga tidak menundo proporsi hierarki.
                    //
                    // Bentuknya `confidence.uncertain.marker` -- frasa yang
                    // **sama** dengan yang dipakai complication. Dua
                    // permukaan, satu kunci: katalog kedua hanya akan
                    // menghasilkan dua ejaan untuk fakta yang sama.
                    if engine.carriesUncertaintyMarker {
                        Text(TextLocalization.text(.confidenceUncertainMarker))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                    }
                    Text(object.name)
                        // Nama = informasi utama, jadi `title2` (besar & tebal).
                        // Bukan `.system(size: 20)`: angka tetap mengabaikan
                        // Dynamic Type, jadi pengguna yang memperbesar teks tetap
                        // membaca nama besar yang sama kecilnya dengan label
                        // di bawahnya — persis hierarki yang dibalik.
                        .font(.title2.bold())
                        .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    // Penanda sisa dipertahankan: di layar redup tidak ada
                    // ruang untuk panel peringatan, tapi klaim tanpa dasar
                    // yang dilarang PRD tidak boleh lebih lemah hanya karena
                    // layarnya lebih sederhana.
                    if engine.isDisplayingStaleObject {
                        // Bukan literal `"sisa"`, dan bukan kebetulan:
                        // katalog menerjemahkan satu kata itu sebagai
                        // `"left"` — yang dalam Bahasa Inggris terbaca
                        // sebagai arah atau sisa jumlah, bukan sebagai
                        // "dari pandangan sebelumnya". Di layar redup
                        // tidak ada panel peringatan yang memberi konteks,
                        // jadi kata itu sendirian memberi tahu pengguna
                        // bahwa yang tampil adalah hasil lama.
                        //
                        // Bentuk **pendek** dipakai karena ruangnya satu
                        // baris; kalimat penuh `staleNote` tidak muat.
                        // Yang diucapkan memakai kunci yang sama persis —
                        // satu kunci, dua panjang, bukan dua terjemahan.
                        Text(ObjectSpeech.staleShortNote)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                    }
                }

                // Status: dua kata, kontras tinggi. Warna **primary**, bukan
                // tone keadaan — di layar redup watchOS menahan sebagian
                // kromatik, dan warna status yang paling cepat hilang adalah
                // cyan/hijau di atas latar gelap. Kontras tekstual selalu
                // menang di sini.
                Text(engine.snapshot.state.shortLabel)
                    .font(.headline)
                    .foregroundStyle(SurfacePalette.active.textPrimaryColor)

                // Peringatan **keselamatan** — satu-satunya penolakan yang
                // lolos ke layar redup.
                //
                // **Kenapa ini ada di layar yang sengaja miskin.** Sisa layar
                // ini hanya memuat yang tidak boleh terlewat. Kalau sebuah
                // nama objek terkunci tampil di sini tanpa tanda bahwa
                // teleskop **menolak bergerak**, pengguna membaca "berhasil"
                // dari layar yang justru sedang menyembunyikan bahaya — dan
                // bahaya itu (cahaya Matahari ke lensa) adalah satu-satunya
                // yang bisa merusak alat atau mata. Bahaya mutu ("terlalu
                // redup") tetap tidak masuk: ia mengecewakan, bukan
                // berbahaya, dan pengguna bisa mengetahuinya begitu mengangkat
                // pergelangan.
                //
                // Kalimatnya datang dari `SlewDecision.safetyWarningText`
                // (teruji di Linux) — ambangnya memakai `isSafety` yang sama
                // dengan warna peringatan di layar penuh, jadi kedua layar
                // tidak bisa berbeda pendapat soal mana yang bahaya.
                if let warning = engine.slewVerdict?.safetyWarningText {
                    HStack(alignment: .top, spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(warning)
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Hanya tampil saat sensor mati — pesan yang benar-benar mengubah
                // perilaku, bukan angka pelengkap.
                if let note = motionNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(SurfacePalette.active.textPrimaryColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
        }
        .appBackground()
        .forceDarkScheme()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reducedAccessibilityLabel)
    }

    /// Label layar redup untuk VoiceOver.
    ///
    /// Sengaja pendek: saat layar redup, pembaca layar berjalan lebih lambat,
    /// dan pengumuman panjang justru menutupi informasi yang paling penting.
    /// Penanda sisa tetap ikut diucapkan — di layar redup yang satu-satunya
    /// jalan membedakan "baru diukur" dari "sisa".
    ///
    /// **Tapi bentuknya bukan "sisa".** Di layar satu kata sudah cukup karena
    /// ada panel peringatan di bawahnya yang memberi konteks; di VoiceOver
    /// tidak ada panel itu, dan "sisa" sendirian terdengar seperti pecahan
    /// kalimat — "…LK · sisa" bukan "…LK · sisa pandangan sebelumnya". Satu
    /// kunci, dua panjang: `staleShort` untuk suara, `stale` untuk layar penuh.
    private var reducedAccessibilityLabel: String {
        var parts: [String] = []
        // Penanda ragu ikut diucapkan **sebelum** nama, bukan sesudahnya.
        //
        // Urutannya penting: nama kandidat adalah kata yang paling mungkin
        // diartikan sebagai temuan, jadi penandanya harus terdengar lebih dulu.
        // Meletakkannya sesudah nama menghasilkan "Vega. Belum pasti" — di
        // mana klausa kedua terdengar seperti koreksi, bukan syarat.
        //
        // Frasa yang diucapkan sama persis dengan yang ditampilkan: satu
        // kunci untuk dua medianya.
        if engine.carriesUncertaintyMarker {
            parts.append(TextLocalization.text(.confidenceUncertainMarker))
        }
        if let object = engine.displayedObject {
            parts.append(object.name)
        }
        parts.append(engine.snapshot.state.shortLabel)
        // Peringatan keselamatan ikut diucapkan: ia alasan teleskop tidak
        // bergerak, dan layar redup yang membacakan nama objek tanpa alasan
        // itu terdengar seperti keberhasilan.
        if let warning = engine.slewVerdict?.safetyWarningText {
            parts.append(warning)
        }
        if engine.isDisplayingStaleObject {
            // Aksesor yang sama dengan baris di atasnya (line 60), supaya
            // dua pemanggilan ke kunci yang sama tidak bisa berbeda bentuk.
            parts.append(ObjectSpeech.staleShortNote)
        }
        return parts.joined(separator: ". ")
    }

    private var motionNote: String? { engine.sensorNote }
}

/// Pembungkus yang memilih tampilan berdasarkan `isLuminanceReduced`.
///
/// Dipisah dari `PointingView` supaya keputusan "layar mana yang dipakai"
/// ada di **satu** tempat, dan `PointingView` tetap bisa dirender penuh saat
/// layar normal.
///
/// **Animasi dihentikan saat redup** dengan cara yang tidak bisa dilanggar
/// tanpa disengaja: cabang `reduced` tidak memuat `.animation`,
/// `withAnimation`, maupun keadaan yang bertransisi. Saat layar redup, watchOS
/// hanya menyegarkan sekali per detik, jadi animasi apa pun di sana hanya
/// menghabiskan baterai tanpa pernah terlihat mulus. Menaruh keputusan ini di
/// pembungkus (bukan di tiap layar) membuat penambahan animasi di cabang
/// reduksi harus dilakukan secara eksplisit.
struct NightAwareContainer<Content: View, Reduced: View>: View {

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @ViewBuilder let content: () -> Content
    @ViewBuilder let reduced: () -> Reduced

    var body: some View {
        if isLuminanceReduced {
            reduced()
        } else {
            content()
        }
    }
}