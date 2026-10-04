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

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Nama objek: satu-satunya informasi yang paling mungkin dicari
                // pengamat saat layar redup.
                if let object = engine.displayedObject {
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
                        Text("sisa")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reducedAccessibilityLabel)
    }

    /// Label layar redup untuk VoiceOver.
    ///
    /// Sengaja pendek: saat layar redup, pembaca layar berjalan lebih lambat,
    /// dan pengumuman panjang justru menutupi informasi yang paling penting.
    /// Penanda sisa tetap ikut diucapkan — di layar redup yang satu-satunya
    /// jalan membedakan "baru diukur" dari "sisa".
    private var reducedAccessibilityLabel: String {
        var parts: [String] = []
        if let object = engine.displayedObject {
            parts.append(object.name)
        }
        parts.append(engine.snapshot.state.shortLabel)
        if engine.isDisplayingStaleObject {
            parts.append("sisa pandangan sebelumnya")
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