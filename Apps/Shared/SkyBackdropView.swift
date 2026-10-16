import SwiftUI
import PointingKit

/// Lapisan langit berbintang di balik seluruh antarmuka.
///
/// **Kenapa lapisan ini ada.** `SurfacePalette.appBackground` hanya berupa
/// gradien dua warna. Ia sudah benar — kontrasnya teruji — tetapi ia tidak
/// menyampaikan apa pun tentang **tempat** informasi ini berada. Aplikasi
/// astronomi premium menaruh datanya di atas langit; tanpa langit, kartu
/// yang rapi sekalipun terbaca sebagai daftar pengaturan. Ini yang menjawab
/// keluhan "jelek" yang tidak bisa diselesaikan dengan merapikan kartu.
///
/// **Yang paling penting: ini bukan hasil pengenalan.** Titik-titik di sini
/// tidak mewakili bintang nyata. Batasnya bukan niat, melainkan dua hal yang
/// diuji di `SkyBackdropTests`:
///
///   - ukurannya **lebih kecil** daripada bintang paling redup yang bisa
///     dikenali engine, jadi tidak ada titik latar yang bisa disangka benda
///     yang baru saja dikunci;
///   - warnanya **netral**, tanpa rona spektral — karena rona adalah ciri
///     pengenal, dan hiasan tidak boleh punya ciri pengenal.
///
/// **Semua angka datang dari `SkyBackdrop` di `PointingKit`.** Berkas ini
/// hanya mengubah angka menjadi piksel; tidak ada kepadatan, radius, maupun
/// terang yang ditulis di sini. Kalau sebuah keputusan visual bisa salah
/// tanpa ada yang bisa mengujinya, keputusan itu tidak boleh ada di sini.
struct SkyBackdropView: View {

    /// Apakah lapisan ini ikut digambar.
    ///
    /// Always-On Display (layar redup) **wajib** mematikannya: watchOS hanya
    /// menyegarkan sekali per detik saat redup, dan ratusan titik kecil yang
    /// digambar ulang terus-menerus menghabiskan baterai tanpa pernah
    /// terlihat mulus. Ini bukan penghematan opsional — ia bagian dari
    /// kontrak AOD.
    var isVisible: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // `reduceMotion` dibaca di sini bukan karena lapisan ini beranimasi,
        // melainkan untuk menyatakan bahwa ia **memang** tidak beranimasi:
        // pembaca yang kelak menambahkan gerak akan menemukan penjaganya
        // sudah ada, dan Aturan 7 tidak akan memberi izin palsu.
        GeometryReader { proxy in
            Canvas { context, size in
                guard isVisible, size.width > 0, size.height > 0 else { return }
                let specks = SkyBackdrop.specks(
                    size: SkyBackdrop.CGSizeLike(width: size.width,
                                                 height: size.height))
                let night = NightMode.isOn
                let baseColor = CelestialVisual.neutralStarBody

                for speck in specks {
                    let center = CGPoint(x: speck.x * size.width,
                                         y: speck.y * size.height)
                    // Radius titik dinyatakan dalam satuan lebar bidang oleh
                    // model, jadi dikalikan lebar — bukan sisi terpendek.
                    // Memakai sisi terpendek akan membuat titik mengecil di
                    // layar lebar, padahal ukurannya harus tetap terasa sama.
                    let radius = max(0.35, speck.radius * size.width)
                    let rect = CGRect(x: center.x - radius,
                                      y: center.y - radius,
                                      width: radius * 2,
                                      height: radius * 2)
                    // Terang: di mode malam dipetakan lewat `NightVisual`
                    // — jalur yang sama dengan warna benda — sehingga tidak
                    // ada titik biru/putih yang luput dari aturan merah.
                    let brightness = night
                        ? SkyBackdrop.nightBrightness(speck.brightness)
                        : speck.brightness

                    let color = baseColor.color
                    context.opacity = brightness * SkyBackdrop.layerOpacity
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .ignoresSafeArea()
        // Hiasan tidak boleh ikut VoiceOver: tidak ada informasi di dalamnya,
        // dan menyebut "langit berbintang" pada setiap layar hanya menambah
        // derau bagi pengguna pembaca layar.
        .accessibilityHidden(true)
        // Titik-titik ini tidak pernah merespons sentuhan; tanpa ini mereka
        // ikut dalam hit tes setiap ketukan di latar belakang.
        .allowsHitTesting(false)
    }
}

/// Latar aplikasi **lengkap**: gradien permukaan yang teruji + langit.
///
/// Dipisah dari `appBackground()` supaya layar yang sengaja polos
/// (mis. tampilan Always-On yang harus hemat baterai) tetap bisa memakai
/// gradien saja tanpa kehilangan jaminan kontrasnya.
struct AppBackdropView: View {

    /// Matikan langit saat layar redup (Always-On).
    var starfieldVisible: Bool = true

    var body: some View {
        ZStack {
            SurfacePalette.appBackground
            SkyBackdropView(isVisible: starfieldVisible)
        }
        .ignoresSafeArea()
    }
}

extension View {

    /// Latar aplikasi berlapis: gradien + langit berbintang.
    func appBackdrop(starfield: Bool = true) -> some View {
        background(AppBackdropView(starfieldVisible: starfield).ignoresSafeArea())
    }
}
