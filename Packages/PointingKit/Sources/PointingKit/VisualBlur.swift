import Foundation

/// Apakah gambar benda langit boleh **memuat dirinya sendiri** menjadi
/// salinan kabur (blur) — jenis objek yang perlu samar untuk menyatakan
/// keraguan dengan bentuk, bukan dengan lencana kecil di sudutnya.
///
/// **Kenapa keputusan ini ada di model, bukan di view.** Bentuknya sepele,
/// tetapi akibatnya tidak: ia memasukkan `rasterize` + filter blur ke dalam
/// jalur gambar, dan jalur itu hidup di `Apps/` yang **tidak pernah dibangun**
/// `swift-test.sh` di Linux. Kalau daftarnya ditulis di view, menambahkan
/// satu kasus ke sana (atau menghapusnya) tidak bisa diukur di sini sama
/// sekali. Di sini ia satu fungsi yang ditahan `UncertainBlurTests`.
///
/// **Kenapa `.planet` dan `.deepSky` saja.** Dua jenis inilah yang di layar
/// **hanya** dibedakan oleh cirinya: pita Jupiter, cincin Saturnus, lengan
/// spiral, inti gugus. Saat engine ragu, view sudah menahan ciri itu — tetapi
/// yang tersisa adalah *bingkai kosong* yang masih berbentuk benda langit
/// pasti (cakram penuh, kabut tajam). Samaran (blur) menambahkan satu sinyal
/// lagi yang tidak bisa dibaca sebagai identitas: bentuknya sendiri menjadi
/// ragu.
///
/// - `.moon` **tidak**: fase Bulan datang dari tanggal, bukan dari tabel
///   berindeks id, jadi sabit tetap sah saat engine ragu.
///   `check_moon_phase_survives_uncertainty` menuntut sabit "ragu" identik
///   piksel demi piksel dengan sabit "yakin". Memblur piringan Bulan akan
///   memerahkan gerbang itu — dan gerbangnya benar.
/// - `.star` dan `.sun` **tidak**: keduanya sudah disamarkan oleh warna
///   (warna "tidak mengklaim" saat ragu), dan pada ukuran 38 pt di jam,
///   blur pada titik 3–10 piksel hanya membuatnya **hilang** — itu
///   menghapus kehadiran objek, bukan menyatakan keraguan. Ada juga efek
///   samping yang berdiri sendiri: `rasterize` membuat frame fokus sendiri,
///   dan sulit dipercaya bahwa berbagi dua lapisan fokus identik tidak
///   menggeser anti-aliasing glow.
public enum UncertainBlur {

    /// Jenis visual yang boleh memblur dirinya saat engine belum pasti.
    ///
    /// **Satu sumber**, bukan `switch` di view: view hanya menanyakan
    /// `UncertainBlur.allows(visual.kind)`. Setiap kasus yang ditambahkan ke
    /// `CelestialVisual.Kind` kelak wajib diputuskan di sini — dan
    /// `UncertainBlurTests.testEveryVisualKindIsDecided` menuntut keputusan
    /// itu ada (daftar boleh "tidak", tetapi harus tertulis).
    public static let eligible: Set<CelestialVisual.Kind> = [.planet, .deepSky]

    /// Jenis yang **sengaja** tidak disamarkan, beserta alasan yang bisa
    /// dibaca kembali. Bukan daftar bungkam: `testEveryVisualKindIsDecided`
    /// menuntut setiap kasus `Kind` muncul di salah satu dari dua himpunan.
    public static let deliberatelySharp: Set<CelestialVisual.Kind> = [.moon, .star, .sun]

    /// Apakah jenis ini boleh disamarkan saat engine belum pasti.
    public static func allows(_ kind: CelestialVisual.Kind) -> Bool {
        eligible.contains(kind)
    }
}
