import Foundation
import CelestialEngine

/// Teks **yang diucapkan** untuk alur kalibrasi — satu sumber, teruji di
/// Linux.
///
/// **Kenapa berkas ini ada, dan kenapa bukan di `Apps/`.** Semua kalimat di
/// bawah adalah *janji produk*: "Pakai" hanya hidup kalau sebaran cukup
/// sempit, tombol acuan hanya hidup kalau ada target, angka diucapkan dengan
/// satuannya. Semuanya bisa salah **tanpa ada satu pun bagian UI yang keliru**
/// — kalau label lupa menyebut tahap, layar tetap menampilkan "Siap
/// dipakai" dengan hijau, dan pengguna yang tidak melihat layar tidak punya
/// jalan apa pun untuk mengetahuinya. Itu kelas kesalahan yang sama dengan
/// "objek sisa tampil sebagai hasil sekarang": UI yang tampak benar sambil
/// menyembunyikan apa yang sebenarnya berlaku.
///
/// Konsekuensinya sama seperti `PointingPresentation`: teks yang diucapkan
/// diletakkan di `PointingKit`, bukan di berkas view yang hanya bisa dibaca
/// di macOS. View tinggal memanggilnya.
public extension CalibrationFlow {

    /// Label kartu tahap untuk VoiceOver.
    ///
    /// Stage, sample count, offset, dan sebaran adalah **satu** pengumuman,
    /// bukan empat. Dan tahap tetap ikut disebut karena itulah yang menentukan
    /// apakah tombol "Pakai" boleh ditekan — pengguna tidak bisa menebak itu
    /// dari angka sebaran saja.
    ///
    /// Angka diucapkan lengkap ("2.4 derajat"), bukan "2.4°": derajat adalah
    /// singkatan visual yang tidak terbaca sebagai kata.
    var spokenPhaseSummary: String {
        var parts = ["Tahap: \(phase.spokenName)."]
        parts.append("\(samples.count) acuan tercatat.")
        if let offset = calibration?.yawOffsetDeg {
            parts.append(String(format: "Offset %.1f derajat.", offset))
        }
        if let spread = calibration?.residualSpreadDeg {
            parts.append(String(format: "Sebaran %.1f derajat, batas %.1f derajat.",
                                spread, maxResidualSpreadDeg))
        }
        return parts.joined(separator: " ")
    }

    /// Label tombol "Pakai" — **menyertakan keadaan tombolnya**.
    ///
    /// Ini poin yang mudah terlewat: `.disabled` adalah sifat visual, dan
    /// VoiceOver membacanya sebagai "redup" pada sebagian pembaca layar. Kalau
    /// label tidak berubah, tombol yang ditolak karena sebaran terlalu lebar
    /// terdengar **persis sama** dengan tombol yang bisa dipakai — padahal itu
    /// hasil yang paling mudah disalahartikan di seluruh alur ini.
    var spokenApplyButtonLabel: String {
        isReady ? "Pakai kalibrasi ini" : "Pakai kalibrasi, belum bisa dipakai"
    }
}

public extension CalibrationPhase {

    /// Nama tahap untuk diucapkan.
    ///
    /// Beda dari label `phaseLabel` di view yang berupa kata/frasa singkat
    /// ("Siap dipakai"). Untuk layar, frasa pendek lebih enak dibaca; untuk
    /// suara, kalimat penuh lebih jelas tanpa simbol.
    var spokenName: String {
        switch self {
        case .idle:      return "Belum ada acuan"
        case .collecting: return "Mengumpulkan acuan"
        case .ready:     return "Siap dipakai"
        case .applied:   return "Sudah dipakai"
        }
    }
}

public extension PointingTarget {

    /// Label tombol acuan untuk VoiceOver.
    ///
    /// Menyebut **aksinya** ("Catat … sebagai acuan"), bukan hanya nama
    /// bintang: di layar ini ada tombol lain yang juga mencatat, jadi tanpa
    /// perbedaan itu keduanya terdengar sama. Dan "tinggi" diucapkan sebagai
    /// "derajat tinggi", karena "40° tinggi" bukan kalimat.
    var spokenCaptureLabel: String {
        "Catat \(name) sebagai acuan, "
            + String(format: "%.0f derajat tinggi.", direction.altitudeDeg)
    }
}