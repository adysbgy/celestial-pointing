import Foundation

/// Nama fase Bulan, untuk diucapkan VoiceOver.
///
/// **Kenapa ini ada.** Gambar prosedural Bulan menampilkan **bentuk** yang
/// berubah: sabit muda menghadap bawah, separuh, cembung, purnama. Bagi
/// pengguna yang melihat, itu informasi langsung — bukan hiasan. Bagi
/// pengguna VoiceOver, `"Bulan"` tidak mengatakan apa-apa tentang bentuknya,
/// dan `visualPanelLabel` di iPhone **sengaja** tidak mendeskripsikan gambar
/// (lihat komentarnya: "Gambar Jupiter dengan pita oranye" tidak menambah
/// informasi). Alasan itu benar untuk Jupiter — pitanya memang tidak
/// mengubah apa pun yang bisa diklaim. Alasan itu **tidak** benar untuk
/// Bulan, karena fasenya adalah data: fraksi iluminasi yang dihitung
/// engine, dan yang terlihat di layar sebagai bentuk.
///
/// Jadi yang ditutup bukan "kurang deskriptif", melainkan **satu kelas
/// informasi yang hanya bisa dilihat dan tidak bisa didengar**. Itu sama
/// bentuknya dengan kelas cacat yang sudah berulang di repo ini: gerbang
/// hijau, dan yang diukur bukan bagian yang bermasalah.
///
/// **Batasnya, dan kenapa sengaja.** Nama fase dipilih dari **ambang**, bukan
/// dari angka iluminasi yang diucapkan. Bukan karena angka lebih sulit:
/// karena tidak ada satu pun angka yang tampil di layar. Pengguna yang
/// melihat mendapat **bentuk**, jadi pengguna yang mendengar harus mendapat
/// hal yang setara — nama bentuk, bukan presisi yang tidak dimiliki tampilan.
/// Menyebut "dua puluh dua persen menyala" akan memberi yang mendengar
/// informasi **lebih** daripada yang melihat, dan itu bukan aksesibilitas,
/// itu dua versi kebenaran.
public extension CelestialVisual {

    /// Nama fase untuk diucapkan, atau `nil` bila tidak berlaku.
    ///
    /// `nil` dalam tiga keadaan, dan ketiganya sengaja:
    ///
    /// 1. **Bukan Bulan.** Planet dan bintang tidak punya fase yang terlihat
    ///    dari Bumi (Merkurius dan Venus punya, tapi tidak digambar di sini),
    ///    jadi tidak ada yang boleh diucapkan.
    /// 2. **Fraksi iluminasi tidak diketahui.** Tanpa angka, tidak ada fase
    ///    yang bisa diklaim. Mengucapkan tebakan lebih buruk daripada diam.
    /// 3. **Arah fase tidak diketahui** *dan* fasenya di antara sabit dan
    ///    cembung — di situ nama yang tersedia ("sabit"/"cembung") bergantung
    ///    pada waxing/waning, jadi `isWaxing == nil` memaksa jawaban netral.
    ///    Fase purnama dan bulan baru tidak punya masalah itu: keduanya
    ///    simetris, jadi namanya sah tanpa arah.
    /// Nama fase untuk diucapkan, atau `nil` bila tidak berlaku.
    ///
    /// `nil` dalam empat keadaan — tiga pertama diwarisi dari versi lama,
    /// yang keempat yang baru ditambahkan di sini:
    ///
    /// 1. **Bukan Bulan.** Planet dan bintang tidak punya fase yang terlihat
    ///    dari Bumi (Merkurius dan Venus punya, tapi tidak digambar di sini),
    ///    jadi tidak ada yang boleh diucapkan.
    /// 2. **Fraksi iluminasi tidak diketahui.** Tanpa angka, tidak ada fase
    ///    yang bisa diklaim. Mengucapkan tebakan lebih buruk daripada diam.
    /// 3. **Arah fase tidak diketahui** *dan* fasenya di antara sabit dan
    ///    cembung — di situ nama yang tersedia ("sabit"/"cembung") bergantung
    ///    pada waxing/waning, jadi `isWaxing == nil` memaksa jawaban netral.
    ///    Fase purnama dan bulan baru tidak punya masalah itu: keduanya
    ///    simetris, jadi namanya sah tanpa arah.
    /// 4. **Engine ragu (`isConfirmed == false`).** Fase adalah **ciri
    ///    pengenal**: bentuk sabit/cembung/purnama hanya tampil sebagai gambar,
    ///    dan pada keadaan `.uncertain` gambar memakai piringan netral (tidak
    ///    mengklaim fase) sementara badge di sebelahnya bertuliskan "Ragu".
    ///    Mata membaca gambar lebih dulu daripada badge, jadi suara tidak boleh
    ///    lebih yakin daripada gambarnya. Itulah sebabnya `spokenPhase` ikut
    ///    dibungkam saat ragu — persis seperti `spokenDeepSkyMorphology` dan
    ///    `spokenStarColor` di sebelahnya, yang sudah memakai ambang ini.
    ///    Tanpa baris ini, pengguna VoiceOver mendengar "Bulan sabit muda"
    ///    sementara pengguna yang melihat melihat piringan netral: dua keadaan
    ///    yang sama tetapi dua kebenaran berbeda.
    ///
    /// Parameter `isConfirmed` diteruskan dari view (bukan `!isStale`):
    /// ambangnya **lebih ketat** daripada "bukan sisa" — `.uncertain` punya
    /// jawaban tapi engine menyatakan diri kurang yakin, dan pada keadaan itulah
    /// pengumuman fase paling berbahaya tampil.
    func spokenPhase(isConfirmed: Bool) -> String? {
        // Ambang ini **sama** dengan `spokenDeepSkyMorphology` dan
        // `spokenStarColor`: ciri pengenal tidak boleh diucapkan saat engine
        // ragu. Ditaruh paling depan supaya tidak ada cabang di bawah yang bisa
        // bocor mengklaim fase saat ragu.
        guard isConfirmed else { return nil }
        guard kind == .moon, let fraction = illuminationFraction else { return nil }
        return TextLocalization.text(
            Self.moonPhaseText(illuminationFraction: fraction, isWaxing: isWaxing))
    }

    /// Kunci + nilai bawaan untuk fase ini — **fungsi murni**, tanpa bundle.
    ///
    /// Murni karena alasan yang sudah berulang di repo ini: `TextLocalization`
    /// mengembalikan Bahasa Indonesia di Linux (tidak ada `.lproj`), jadi
    /// menguji `spokenPhase` langsung hanya akan menguji nilai bawaan. Yang
    /// bisa diuji — dan yang memang penting — adalah **pemilihan** fasenya:
    /// ambang mana yang menang untuk fraksi berapa, dan kapan arah
    /// waxing/waning ikut menentukan.
    ///
    /// Ambangnya diambil dari tata nama fase yang lazim dipakai, dibulatkan
    /// supaya bentuknya tetap sama: 4% (bulan baru masih terlalu tipis untuk
    /// disebut sabit), 46%/54% (pita "separuh" selebar delapan persen, supaya
    /// bulan yang jelas-jelas separuh tidak disebut cembung), dan 96%
    /// (purnama).
    static func moonPhaseText(illuminationFraction fraction: Double,
                              isWaxing: Bool?) -> LocalizedText {
        let clamped = min(1, max(0, fraction))

        // Simetris: namanya sah tanpa tahu arah waxing/waning.
        if clamped < 0.04 { return .moonPhaseNew }
        if clamped > 0.96 { return .moonPhaseFull }

        // Sisanya bergantung arah. Tanpa arah, nama netral — bukan tebakan.
        if clamped < 0.46 {
            guard let waxing = isWaxing else { return .moonPhaseCrescent }
            return waxing ? .moonPhaseWaxingCrescent : .moonPhaseWaningCrescent
        }
        if clamped > 0.54 {
            guard let waxing = isWaxing else { return .moonPhaseGibbous }
            return waxing ? .moonPhaseWaxingGibbous : .moonPhaseWaningGibbous
        }
        guard let waxing = isWaxing else { return .moonPhaseQuarter }
        return waxing ? .moonPhaseFirstQuarter : .moonPhaseLastQuarter
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let moonPhaseNew = LocalizedText(key: "moon.phase.new.spoken.label",
                                            id: "Bulan baru")
    static let moonPhaseFull = LocalizedText(key: "moon.phase.full.spoken.label",
                                             id: "Bulan purnama")
    /// Nama netral saat arah waxing/waning tidak diketahui.
    static let moonPhaseCrescent = LocalizedText(key: "moon.phase.crescent.spoken.label",
                                                 id: "Bulan sabit")
    static let moonPhaseWaxingCrescent = LocalizedText(
        key: "moon.phase.waxingCrescent.spoken.label", id: "Bulan sabit muda")
    static let moonPhaseWaningCrescent = LocalizedText(
        key: "moon.phase.waningCrescent.spoken.label", id: "Bulan sabit tua")
    static let moonPhaseGibbous = LocalizedText(key: "moon.phase.gibbous.spoken.label",
                                                id: "Bulan cembung")
    static let moonPhaseWaxingGibbous = LocalizedText(
        key: "moon.phase.waxingGibbous.spoken.label", id: "Bulan cembung membesar")
    static let moonPhaseWaningGibbous = LocalizedText(
        key: "moon.phase.waningGibbous.spoken.label", id: "Bulan cembung mengecil")
    static let moonPhaseQuarter = LocalizedText(key: "moon.phase.quarter.spoken.label",
                                                id: "Bulan separuh")
    static let moonPhaseFirstQuarter = LocalizedText(
        key: "moon.phase.firstQuarter.spoken.label", id: "Bulan separuh awal")
    static let moonPhaseLastQuarter = LocalizedText(
        key: "moon.phase.lastQuarter.spoken.label", id: "Bulan separuh akhir")
}
