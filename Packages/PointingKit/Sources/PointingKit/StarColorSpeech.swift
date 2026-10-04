import Foundation

/// Warna spektral bintang, untuk diucapkan VoiceOver.
///
/// **Kenapa ini ada.** Gambar prosedural bintang menampilkan **warna**
/// (biru pada Rigel, merah pada Betelgeuse, putih-biru pada Sirius) — itu
/// data nyata dari indeks B−V katalog, bukan hiasan. Bagi pengguna yang
/// melihat, warna itu informasi langsung. Bagi pengguna VoiceOver,
/// `"bintang Sirius"` tidak mengatakan apa pun soal warna, padahal warna
/// adalah salah satu atribut yang justru dipakai UI untuk membedakan
/// bintang — sama seperti fase Bulan dan bentuk objek langit dalam yang
/// sudah punya jalur ucapan sendiri.
///
/// Ini kategori yang sama persis dengan `MoonPhaseSpeech` dan
/// `DeepSkySpeech`: satu kelas informasi yang **hanya bisa dilihat dan tidak
/// bisa didengar**. Gerbang hijau, dan yang diukur bukan bagian yang
/// bermasalah.
///
/// **Kenapa bukan sekadar mendeskripsikan gambarnya.** `visualPanelLabel`
/// sengaja tidak menceritakan gambar planet (lihat catatannya: "Gambar
/// Jupiter dengan pita oranye" tidak menambah informasi). Alasan itu tetap
/// benar untuk planet: pitanya tidak mengubah apa pun yang bisa diklaim. Ia
/// **tidak** benar di sini, karena warna bintang adalah *atribut spektral*
/// yang berbeda per bintang di katalog yang sama — Rigel dan Betelgeuse
/// sama-sama "bintang" di ucapan jenisnya, tapi di layar keduanya digambar
/// biru vs merah. Tanpa ini, "Rigel" dan "Betelgeuse" terdengar sama
/// persis padahal warna mereka adalah salah satu hal pertama yang dilihat
/// mata telanjang.
///
/// **Batasnya, dan trade-off yang disengaja.** Warna diucapkan dari *pita*
/// indeks B−V, bukan dari angka mentahnya. Bukan karena angka lebih sulit:
/// karena tidak ada satu pun angka yang tampil di layar. Pengguna yang
/// melihat mendapat **warna**, jadi pengguna yang mendengar harus mendapat
/// hal yang setara — nama warna, bukan presisi "B−V −0.03" yang tidak
/// dimiliki tampilan. Menyebut angka akan memberi yang mendengar informasi
/// *lebih* daripada yang melihat, dan itu bukan aksesibilitas, itu dua
/// versi kebenaran.
public extension CelestialVisual {

    /// Warna spektral untuk diucapkan, atau `nil` bila tidak berlaku.
    ///
    /// `nil` dalam satu keadaan, dan itu sengaja: **bukan bintang.** Planet,
    /// Bulan, Matahari, dan objek langit dalam punya warna di gambar, tapi
    /// warna itu adalah sifat *render*, bukan klaim spektral — dan tidak ada
    /// satu pun yang boleh diucapkan sebagai "warna spektral bintang".
    ///
    /// Untuk bintang, warna selalu ada (indeks B−V-nya, yang sudah dipakai
    /// UI untuk mewarnai titiknya), jadi pengembaliannya tidak pernah `nil`
    /// di sini — persis seperti `spokenPhase` yang tidak pernah `nil` untuk
    /// Bulan yang tahu fraksinya.
    var spokenStarColor: String? {
        guard kind == .star else { return nil }
        return TextLocalization.text(Self.starColorText(colorIndexBV))
    }

    /// Kunci + nilai bawaan untuk indeks B−V — **fungsi murni**, tanpa bundle.
    ///
    /// Murni karena alasan yang sudah berulang di repo ini:
    /// `TextLocalization` mengembalikan Bahasa Indonesia di Linux (tidak ada
    /// `.lproj`), jadi menguji `spokenStarColor` langsung hanya akan menguji
    /// nilai bawaan. Yang bisa diuji — dan yang memang penting — adalah
    /// **pemetaan** indeks B−V ke pita warnanya: setiap bintang di katalog
    /// jatuh ke pita yang benar, dan batas antar-pita tidak meleset.
    ///
    /// Pita diambil dari kelas spektral nyata, dibulatkan supaya tetap sama
    /// dengan yang dilihat mata: biru (B ke awal A, B−V ≤ −0,10), putih
    /// kebiruan (A ke awal F, −0,10 … 0,25), kuning (F ke awal K, 0,25 …
    /// 0,95), jingga (K, 0,95 … 1,50), merah (M, > 1,50). Sirius (B−V 0,00)
    /// jatuh ke putih kebiruan, Betelgeuse (1,85) ke merah, Rigel (−0,03) ke
    /// biru — persis yang ditunjukkan gambar.
    static func starColorText(_ colorIndexBV: Double) -> LocalizedText {
        if colorIndexBV <= -0.10 { return .starColorBlue }
        if colorIndexBV <= 0.25 { return .starColorWhiteBlue }
        if colorIndexBV <= 0.95 { return .starColorYellow }
        if colorIndexBV <= 1.50 { return .starColorOrange }
        return .starColorRed
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    static let starColorBlue = LocalizedText(key: "star.color.blue.spoken.label",
                                             id: "biru")
    static let starColorWhiteBlue = LocalizedText(
        key: "star.color.whiteBlue.spoken.label", id: "putih kebiruan")
    static let starColorYellow = LocalizedText(key: "star.color.yellow.spoken.label",
                                               id: "kuning")
    static let starColorOrange = LocalizedText(key: "star.color.orange.spoken.label",
                                               id: "jingga")
    static let starColorRed = LocalizedText(key: "star.color.red.spoken.label",
                                            id: "merah")
}
