import CelestialEngine

/// Kalimat yang diucapkan VoiceOver untuk **layar redup** (Always-On).
///
/// **Mengapa dirakit di sini, bukan di `ReducedLuminanceView`.** Label itu
/// sebelumnya hidup sebagai properti `private` di dalam view, di `Apps/` —
/// berkas yang tidak ikut terbangun di Linux. Urutan katanya adalah janji
/// produk (penanda ragu harus terdengar **sebelum** nama, karena nama kandidat
/// adalah kata yang paling mudah dibaca sebagai temuan), dan janji itu tidak
/// bisa diperiksa satu gerbang pun di sana.
///
/// **Cacat yang ditutup.** Layar redup menampilkan satu baris catatan sensor
/// saat gerak tidak tersedia ("Data gerak tidak tersedia."), tetapi labelnya
/// tidak pernah menyebutnya. Bagi pengguna VoiceOver, layar yang membeku
/// terbaca sebagai keberhasilan. `safetyWarning` sudah ikut diucapkan dengan
/// alasan yang sama; catatan sensor terlewat.
///
/// **Batas yang dijaga.** Setiap bagian hanya muncul bila baris yang
/// bersangkutan memang tampil:
///
/// - `objectName` `nil` (tidak ada objek yang ditampilkan) berarti **tidak ada
///   nama yang dikarang** — hanya status.
/// - Penanda ragu ikut hanya bila ada nama. Penanda sendirian tanpa nama yang
///   disyaratkannya adalah sinyal tanpa isi.
///
/// Pemisahnya selalu `". "`, sama dengan yang sudah dipakai layar redup, supaya
/// pembaca layar berhenti di antara bagian — bukan menyambungnya jadi satu
/// kalimat panjang.
public enum ReducedLuminanceLabel {

    /// Susun label VoiceOver layar redup, dalam urutan yang sama dengan
    /// urutan baris di layar.
    ///
    /// - Parameters:
    ///   - isUncertain: engine belum yakin; penanda ragu diucapkan **sebelum**
    ///     nama.
    ///   - objectName: nama yang tampil, atau `nil` bila tidak ada objek.
    ///   - stateLabel: kata keadaan ("Terkunci", "Mencari", …).
    ///   - safetyWarning: alasan teleskop menolak bergerak, bila ada.
    ///   - sensorNote: catatan sensor yang tampil di layar, bila ada.
    ///   - isStale: objek yang tampil berasal dari pandangan sebelumnya.
    public static func text(isUncertain: Bool,
                            objectName: String?,
                            stateLabel: String,
                            safetyWarning: String?,
                            sensorNote: String?,
                            isStale: Bool) -> String {
        var parts: [String] = []
        if isUncertain, objectName != nil {
            parts.append(TextLocalization.text(.confidenceUncertainMarker))
        }
        if let objectName {
            parts.append(objectName)
        }
        parts.append(stateLabel)
        if let safetyWarning {
            parts.append(safetyWarning)
        }
        // Catatan sensor adalah alasan jam tidak menanggapi gerakan. Tanpa
        // kalimat ini, pembaca layar mendengar nama dan status tanpa tahu
        // bahwa sensornya mati — keberhasilan yang membeku.
        if let sensorNote {
            parts.append(sensorNote)
        }
        if isStale {
            parts.append(ObjectSpeech.staleShortNote)
        }
        return parts.joined(separator: ". ")
    }
}
