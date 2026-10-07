import Foundation

/// Bentuk objek langit dalam, untuk diucapkan VoiceOver.
///
/// **Kenapa ini ada.** Gambar prosedural objek langit dalam sekarang
/// menampilkan **bentuk** yang berbeda per jenis: galaksi sebagai cakram
/// miring berinti, gugus bola sebagai inti padat, gugus terbuka sebagai
/// bintik-bintik tersebar, nebula sebagai kabut. Bagi pengguna yang melihat,
/// itu informasi langsung — bukan hiasan.
///
/// Bagi pengguna VoiceOver, tidak satu pun dari itu terdengar. Yang paling
/// tajam: **"Gugus Ptolemy" dan "Gugus Hercules" diumumkan dengan kalimat
/// yang sama persis** — nama, "objek langit jauh", magnitudo. Padahal yang
/// pertama gugus terbuka dan yang kedua gugus bola, dan di layar keduanya
/// kini digambar berbeda. Jenisnya (`ObjectKind.deepSky`) tidak membedakan
/// mereka, jadi pengumuman yang ada kehilangan satu kelas informasi yang
/// hanya bisa dilihat.
///
/// Ini bentuk yang sama dengan `spokenPhase` untuk Bulan, dan alasannya sama:
/// fase Bulan dan morfologi objek langit dalam adalah **data**, bukan
/// deskripsi hiasan. Karena itu aturannya juga sama — hanya bentuk yang
/// benar-benar ditampilkan yang diucapkan, dan yang tidak diketahui tidak
/// ditebak.
///
/// **Kenapa bukan sekadar mendeskripsikan gambarnya.** `visualPanelLabel`
/// sengaja tidak pernah menceritakan gambar (lihat komentarnya: "Gambar
/// Jupiter dengan pita oranye" tidak menambah informasi). Alasan itu tetap
/// benar untuk planet: pita Jupiter tidak mengubah apa pun yang bisa
/// diklaim. Ia **tidak** benar di sini, karena bentuknya berbeda antar objek
/// di katalog yang sama.
///
/// **Batasnya, dan trade-off yang disengaja.** Untuk objek yang namanya
/// sudah menyebut jenisnya ("Galaksi Andromeda"), kata morfologinya jadi
/// sedikit berulang saat diucapkan. Itu dibiarkan, bukan karena tidak
/// terasa, tapi karena alternatifnya — memeriksa apakah nama pada bahasa
/// aktif sudah memuat kata jenisnya — berarti mencocokkan teks yang
/// dilokalisasi, dan itu rapuh persis pada bahasa yang belum ada
/// terjemahannya. Pengulangan kecil lebih baik daripada aturan yang bisa
/// diam-diam salah.
public extension CelestialVisual {

    /// Nama bentuk untuk diucapkan, atau `nil` bila tidak berlaku.
    ///
    /// `nil` dalam tiga keadaan, dan ketiganya sengaja:
    ///
    /// 1. **Bukan objek langit dalam.** Planet, Bulan, dan bintang punya
    ///    bentuk yang sudah ditentukan jenisnya; morfologi tidak berlaku.
    /// 2. **Bentuknya tidak diketahui.** Ini yang penting: `objectID` yang
    ///    tidak ada di katalog mengembalikan `nil` (lihat
    ///    `DeepSkyCatalogue.morphology(forObjectID:)`), dan di situ tidak ada
    ///    satu pun bentuk yang boleh diklaim. Mengucapkan tebakan lebih buruk
    ///    daripada diam — sama seperti fase Bulan yang tidak diketahui.
    /// 3. **Engine belum yakin.** Bentuk adalah ciri pengenal, jadi ia hanya
    ///    boleh diklaim saat `isConfirmed`. Parameter itu diteruskan dari
    ///    pemanggil karena `CelestialVisual` sendiri tidak menyimpan
    ///    keyakinan — ia hanya tahu objeknya apa.
    ///
    /// Keadaan 2 dan 3 membuat pengucapannya **cocok dengan gambarnya**:
    /// gambar memakai kabut netral saat bentuknya tidak diketahui *atau* saat
    /// engine ragu (`drawableMorphology`), dan pengumuman tidak menyebut
    /// bentuk apa pun. Tanpa keadaan 3, pengguna VoiceOver akan mendengar
    /// "galaksi" di sebelah badge "Ragu" yang justru tidak menggambarnya.
    func spokenDeepSkyMorphology(isConfirmed: Bool) -> String? {
        guard kind == .deepSky,
              let id = objectID,
              let morphology = DeepSkyCatalogue.drawableMorphology(forObjectID: id,
                                                                   isConfirmed: isConfirmed) else {
            return nil
        }
        return TextLocalization.text(Self.deepSkyMorphologyText(morphology))
    }

    /// Kunci + nilai bawaan untuk sebuah morfologi — **fungsi murni**.
    ///
    /// Murni karena alasan yang sama dengan `moonPhaseText`: `TextLocalization`
    /// mengembalikan Bahasa Indonesia di Linux (tidak ada `.lproj`), jadi
    /// menguji `spokenDeepSkyMorphology` langsung hanya akan menguji nilai
    /// bawaan. Yang bisa diuji — dan yang memang penting — adalah
    /// **pemetaan** morfologi ke teksnya: setiap jenis punya kata sendiri,
    /// dan tidak ada dua jenis yang berbagi kata.
    static func deepSkyMorphologyText(_ morphology: DeepSkyCatalogue.Morphology) -> LocalizedText {
        switch morphology {
        case .nebula:          return .deepSkyMorphologyNebula
        case .planetaryNebula: return .deepSkyMorphologyPlanetaryNebula
        case .galaxy:          return .deepSkyMorphologyGalaxy
        case .spiralGalaxy:    return .deepSkyMorphologySpiralGalaxy
        case .openCluster:     return .deepSkyMorphologyOpenCluster
        case .globularCluster: return .deepSkyMorphologyGlobularCluster
        }
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let deepSkyMorphologyNebula = LocalizedText(
        key: "deepSky.morphology.nebula.spoken.label", id: "nebula")
    /// **Kenapa kata ini bukan sekadar "nebula".** Nebula planetari memakai
    /// kata sendiri karena bentuknya berlawanan: nebula emisi memusat,
    /// nebula planetari berongga. Dua objek yang berbagi satu kata untuk dua
    /// gambar yang bertolak belakang adalah cacat yang sama dengan yang
    /// berkas ini ada untuk menutup — bedanya kali ini ada di telinga, bukan
    /// di mata.
    static let deepSkyMorphologyPlanetaryNebula = LocalizedText(
        key: "deepSky.morphology.planetaryNebula.spoken.label", id: "nebula planetari")
    static let deepSkyMorphologyGalaxy = LocalizedText(
        key: "deepSky.morphology.galaxy.spoken.label", id: "galaksi")
    /// **Kenapa galaksi berlengan butuh kata sendiri.** Sama persis dengan
    /// alasan `planetaryNebula` di atas, dan kali ini yang bertolak belakang
    /// bukan bentuk gas melainkan **sudut pandang**: `.galaxy` menggambar
    /// cakram miring yang lengannya memipih, `.spiralGalaxy` menggambar
    /// lengannya. Bagi pengguna VoiceOver, satu kata "galaksi" untuk
    /// keduanya berarti M31 dan M51 diumumkan dengan kalimat yang sama —
    /// padahal justru beda itu yang sekarang bisa dilihat.
    ///
    /// Kata generiknya ("galaksi") tetap dipakai `.galaxy`, bukan diganti
    /// jadi "galaksi miring": untuk cakram yang lengannya tidak terbaca,
    /// kata umumnya **benar** — dan memberi nama sudut pandang akan
    /// mengklaim sesuatu yang gambarnya sendiri tidak tampilkan.
    static let deepSkyMorphologySpiralGalaxy = LocalizedText(
        key: "deepSky.morphology.spiralGalaxy.spoken.label", id: "galaksi spiral")
    static let deepSkyMorphologyOpenCluster = LocalizedText(
        key: "deepSky.morphology.openCluster.spoken.label", id: "gugus terbuka")
    static let deepSkyMorphologyGlobularCluster = LocalizedText(
        key: "deepSky.morphology.globularCluster.spoken.label", id: "gugus bola")
}
