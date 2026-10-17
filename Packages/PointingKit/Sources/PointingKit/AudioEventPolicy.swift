import Foundation

/// Peristiwa mana yang boleh **berbunyi** — satu keputusan, di tempat yang
/// bisa diuji.
///
/// **Kenapa ini ada di `PointingKit`, bukan di badan `AudioCueEngine.play` di
/// `Apps/Shared/AudioCue.swift`.**
///
/// Badan itu dulu berbunyi seperti ini:
///
///     guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }
///
/// Satu baris, dan ia memutuskan **politik** yang PRD tetapkan: hanya
/// perpindahan ke `.lockSucceeded` yang boleh terdengar sebagai berhasil.
/// Peristiwa lain — terutama `.uncertain` — tidak boleh. Bunyi saat engine
/// ragu adalah false confidence yang berwujud suara: pengguna yang tidak
/// melihat layar (tepat pengguna yang audio ini untuknya) hanya punya telinga
/// untuk menilai, jadi bunyi yang sama untuk "berhasil" dan "ragu"
/// menghapus makna kata berhasil itu sendiri.
///
/// Masalahnya kelas yang sama dengan `NightPaletteSelector`: berkas itu ada di
/// `Apps/`, yang **tidak pernah dibangun** `./swift-test.sh` di Linux dan tidak
/// punya uji. Diukur (salinan utuh, proses baru, ke-45 aturan UI dijalankan):
///
///     guard ... events.contains(.lockSucceeded) ...        ->  HIJAU
///     guard ... .lockSucceeded || .uncertain ...           ->  HIJAU  (buta)
///     guard AudioCue.isOn                                  ->  HIJAU  (buta)
///     return                                               ->  HIJAU  (buta)
///
/// Empat keadaan, nol yang berbunyi. Yang paling sunyi bukan yang terakhir
/// (yang hanya membuat bunyi hilang) melainkan yang kedua: engine ragu
/// berbunyi **persis** seperti engine yakin, dan tidak ada yang bisa
/// membantahnya dari dalam app.
///
/// Karena itu pemilihan peristiwanya dipindah ke fungsi murni di sini, yang
/// punya uji, dan `Apps/` hanya meneruskan daftar peristiwanya. `Apps/` tidak
/// bisa lagi mengarang pemilihan itu tanpa menulis ulang fungsi ini —
/// dan fungsi ini diuji di Linux.
///
/// **Batas yang diakui.** Fungsi ini tidak tahu apakah audio diaktifkan
/// pengguna; saklar `AudioCue.isOn` tetap di `Apps/` karena ia `UserDefaults`,
/// sama seperti `NightMode.isOn`. Yang dipindah adalah pemilihan
/// **peristiwa**, bukan sumber keadaannya.
public enum AudioEventPolicy {

    /// Peristiwa yang boleh berbunyi.
    ///
    /// Hanya `.lockSucceeded`, dan itu sengaja satu-satunya: setiap peristiwa
    /// lain adalah keadaan yang **belum** berhasil, dan bunyi untuknya akan
    /// terdengar seperti berhasil kepada pengguna yang tidak melihat layar.
    /// Daftar ini adalah sumber kebenaran; jangan disalin ke `Apps/`.
    public static let audibleEvents: Set<HapticEvent> = [.lockSucceeded]

    /// Apakah sekumpulan peristiwa harus dibunyikan.
    ///
    /// - Parameter events: peristiwa yang dikirim engine pada satu pembaruan.
    ///   Boleh kosong — engine memang mengirim daftar kosong saat tidak ada
    ///   perpindahan keadaan, dan itu bukan bunyi.
    /// - Parameter isAudioEnabled: saklar pengguna. Dibutuhkan terpisah, bukan
    ///   dibaca di sini, supaya `AudioEventPolicy` tetap fungsi murni yang
    ///   bisa diuji di Linux tanpa `UserDefaults`.
    ///
    /// Mengembalikan `true` **hanya** bila audio diaktifkan **dan** daftar
    /// itu memuat setidaknya satu peristiwa audible. Peristiwa ragu di
    /// dalamnya tidak membatalkan `lockSucceeded` yang hadir bersamanya —
    /// yang dinilai adalah apakah ada alasan untuk berbunyi, bukan apakah
    /// daftarnya murni.
    public static func shouldPlay(events: [HapticEvent],
                                  isAudioEnabled: Bool) -> Bool {
        guard isAudioEnabled else { return false }
        return events.contains(where: { audibleEvents.contains($0) })
    }

    /// Apakah satu peristiwa boleh berbunyi.
    ///
    /// Dipakai `Apps/` bila ia perlu menilai peristiwa satu per satu; bentuk
    /// himpunannya lebih mudah ditinjau daripada `if event == .lockSucceeded`
    /// yang tersebar di view.
    public static func isAudible(_ event: HapticEvent) -> Bool {
        audibleEvents.contains(event)
    }
}
