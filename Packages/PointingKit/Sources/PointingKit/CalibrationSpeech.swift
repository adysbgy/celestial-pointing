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
    /// **Hitungan yang diucapkan adalah jumlah acuan BERBEDA**, bukan jumlah
    /// ketukan — sama seperti yang tampil di layar, dan untuk alasan yang lebih
    /// penting di sini: pengumuman inilah satu-satunya umpan balik pengguna
    /// yang tidak melihat layar. Kalau kartu tahap masih "Mengumpulkan acuan"
    /// sementara pengumuman tetap berbunyi "3 acuan tercatat", yang
    /// tidak melihat layar diberi tahu bahwa pengukurannya **tidak**
    /// bertambah — persis cacat yang paling sulit diperbaiki karena tidak ada
    /// yang salah secara terpisah.
    ///
    /// Angka diucapkan lengkap ("2.4 derajat"), bukan "2.4°": derajat adalah
    /// singkatan visual yang tidak terbaca sebagai kata.
    var spokenPhaseSummary: String {
        var parts = [CalibrationText.spokenPhasePrefix(phase.spokenName)]
        parts.append(CalibrationText.spokenSamplesRecorded(distinctReferenceCount))
        // Pengulangan ikut diucapkan **beserta artinya**: tanpa ini,
        // pengumuman tetap terasa tidak bertambah tanpa alasan yang bisa
        // didengar. `spokenRepeatedReference` menyatakan akibatnya, bukan
        // sekadar mengulang kata "sudah tercatat".
        if let repeated = repeatedReferenceIDs.first,
           distinctReferenceCount < minimumSamples {
            parts.append(CalibrationText.spokenRepeatedReference(
                name: repeatedDisplayName(ofObjectID: repeated)))
        }
        if let offset = calibration?.yawOffsetDeg {
            parts.append(CalibrationText.spokenOffset(degrees: offset))
        }
        if let spread = calibration?.residualSpreadDeg {
            parts.append(CalibrationText.spokenSpread(spreadDeg: spread,
                                                      maxDeg: maxResidualSpreadDeg))
        }
        return parts.joined(separator: " ")
    }

    /// Nama tampilan acuan untuk pengumuman — sumber yang sama dengan pesan
    /// di layar, supaya suara dan layar tidak bisa menyebut bintang berbeda.
    private func repeatedDisplayName(ofObjectID id: String) -> String {
        referenceObjects.first { $0.id == id }?.name ?? id
    }

    /// Label tombol "Pakai" — **menyertakan keadaan tombolnya**.
    ///
    /// Ini poin yang mudah terlewat: `.disabled` adalah sifat visual, dan
    /// VoiceOver membacanya sebagai "redup" pada sebagian pembaca layar. Kalau
    /// label tidak berubah, tombol yang ditolak karena sebaran terlalu lebar
    /// terdengar **persis sama** dengan tombol yang bisa dipakai — padahal itu
    /// hasil yang paling mudah disalahartikan di seluruh alur ini.
    var spokenApplyButtonLabel: String {
        isReady ? CalibrationText.spokenApplyReady
                : CalibrationText.spokenApplyNotReady
    }
}

public extension CalibrationPhase {

    /// Nama tahap untuk **layar** — frasa pendek yang enak dibaca.
    ///
    /// Satu sumber dengan `spokenName`: dulu keduanya literal di tempat
    /// berbeda, jadi satu perubahan bisa membuat layar dan suara menyebut
    /// tahap yang berbeda untuk keadaan yang sama.
    var displayName: String {
        switch self {
        case .idle:       return TextLocalization.text(.calibrationPhaseIdleLabel)
        case .collecting: return TextLocalization.text(.calibrationPhaseCollectingLabel)
        case .ready:      return TextLocalization.text(.calibrationPhaseReadyLabel)
        case .applied:    return TextLocalization.text(.calibrationPhaseAppliedLabel)
        }
    }

    /// Nama tahap untuk diucapkan.
    ///
    /// Untuk suara, kalimat penuh lebih jelas tanpa simbol; nilainya kini
    /// sama dengan label layar karena keduanya membaca katalog yang sama.
    var spokenName: String { displayName }
}

public extension PointingTarget {

    /// Label tombol acuan untuk VoiceOver.
    ///
    /// Menyebut **aksinya** ("Catat … sebagai acuan"), bukan hanya nama
    /// bintang: di layar ini ada tombol lain yang juga mencatat, jadi tanpa
    /// perbedaan itu keduanya terdengar sama. Dan "tinggi" diucapkan sebagai
    /// "derajat tinggi", karena "40° tinggi" bukan kalimat.
    var spokenCaptureLabel: String {
        CalibrationText.spokenCaptureLabel(name: name,
                                           altitudeDeg: direction.altitudeDeg)
    }
}