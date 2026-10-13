import Foundation
import CelestialEngine

/// Bentuk **layar** dari target yang akan dikirim ke mount.
///
/// **Kenapa berkas ini ada, bukan dirangkai di dalam view.** Baris koordinat
/// di layar serah-terima teleskop adalah satu-satunya tempat pengguna bisa
/// melihat **bentuk apa** yang benar-benar akan sampai ke motor: RA/Dek untuk
/// mount ekuatorial, Alt/Az untuk mount alt-az. Selama baris itu dirakit di
/// dalam `body` SwiftUI, tidak ada satu pun uji yang bisa menyatakan bahwa
/// bentuknya benar — `Apps/` tidak bisa diuji di Linux, dan `check-visuals.py`
/// tidak menggambar baris ini. Yang tersisa cuma dua pilihan: mempercayai
/// matanya, atau memindahkannya ke sini.
///
/// **Yang TIDAK diklaim.** Fungsi ini hanya memformat; ia tidak memutuskan
/// sumbu mana yang dipakai, tidak menghitung koordinat, dan tidak pernah
/// menyentuh perangkat. Keputusan sumbu dan isi koordinat datang dari
/// `TelescopeBridge` (teruji di `TelescopeBridgeTests`); di sini hanya bentuk
/// tampilannya, supaya yang tampil tidak bisa berbeda dari yang dikirim.
public enum TelescopeDisplay {

    /// Jumlah angka di belakang koma pada baris koordinat.
    ///
    /// Empat, bukan satu seperti `object.display.coordinates`: baris itu
    /// menggambarkan **objek** (cukup untuk dikenali), sedangkan baris ini
    /// menggambarkan **perintah** — ia harus cukup rinci untuk memeriksa
    /// apakah yang dikirim memang yang dimaksud. Empat desimal ≈ 0,0001°,
    /// di bawah ketelitian mekanis mount mana pun, jadi angka di layar tidak
    /// pernah lebih halus daripada yang bisa dieksekusi alat.
    static let fractionDigits = 4

    /// Baris koordinat untuk sebuah target mount.
    ///
    /// Bentuknya dibaca dari `MountTarget` itu sendiri, bukan dari kemampuan
    /// mount yang dihitung kedua kalinya: kalau `TelescopeBridge` memutuskan
    /// sesuatu yang berbeda dari yang kita kira, yang tercetak adalah apa yang
    /// **benar-benar** akan dikirim.
    public static func coordinateLine(for target: MountTarget) -> String {
        switch target {
        case .equatorial(let coord, _):
            // Deklinasi bertanda (bisa negatif di selatan khatulistiwa), jadi
            // tandanya dicetak lewat `signedDegrees` — bukan oleh pemanggil.
            return TextLocalization.text(
                .telescopeCoordinateEquatorial,
                NumberFormat.degrees(coord.raDeg, fractionDigits: fractionDigits),
                NumberFormat.signedDegrees(coord.decDeg, fractionDigits: fractionDigits))
        case .horizontal(let coord):
            // Alt-az tidak bertanda: ketinggian di bawah horizon sudah ditolak
            // gerbang sebelum sampai ke sini, dan azimut selalu 0…360.
            return TextLocalization.text(
                .telescopeCoordinateHorizontal,
                NumberFormat.degrees(coord.altitudeDeg, fractionDigits: fractionDigits),
                NumberFormat.degrees(coord.azimuthDeg, fractionDigits: fractionDigits))
        }
    }
}
