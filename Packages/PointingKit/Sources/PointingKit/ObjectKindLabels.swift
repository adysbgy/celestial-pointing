import Foundation
import CelestialEngine

/// Label jenis benda — **satu sumber** untuk jam, iPhone, dan complication.
///
/// **Kenapa berkas ini pindah ke sini, dan bukan tetap di `Apps/`.** Label ini
/// (`"Bintang"`, `"Objek langit dalam"`, …) adalah teks yang tampil di
/// sidebar panel detail iPhone, di baris "Jenis" panel jam, dan di baris kedua
/// complication rectangular. Semuanya dibaca pengguna, dan semuanya **hanya
/// punya Bahasa Indonesia** selama label itu ditulis sebagai string biasa.
///
/// Yang membuatnya bisa lolos dari setiap gerbang ada di bentuknya, bukan di
/// kebetulan. Aturan 4 (`./swift-ui-lint.sh`) menyapu literal
/// `Text("...")`/Button/Label/accessibilityLabel — dan `return "Bintang"`
/// di dalam `switch` **tidak pernah menjadi salah satu dari itu**. Jadi
/// berkas itu dilaporkan bersih sementara sepuluh label yang tampil di layar
/// tidak punya satu pun padanan bahasa Inggris. Aturan 6 menutup kunci yang
/// *dideklarasikan di paket*, jadi ia juga tidak melihat teks yang memang
/// hidup di app.
///
/// Dua jalur itu sama-sama benar, dan keduanya mengukur bagian yang tidak
/// bermasalah — persis bentuk "hijau yang tidak hijau" yang sudah tiga kali
/// muncul di repo ini.
///
/// Memindahkannya ke paket menutup kelasnya, bukan satu berkas:
///
/// - **Bisa diuji di Linux.** `swift test` tidak pernah bisa membangun
///   `Apps/`, jadi selama label ini di sana, ia tidak punya satu pun penjaga.
/// - **Kunci katalog bisa dijangkau.** `LocalizedText.allKeys` adalah sumber
///   untuk aturan 6, jadi menambah kunci di sini membuat katalog wajib
///   ikut memuatnya — dan menghapusnya dari `allKeys` jadi merah.
/// - **Satu sumber untuk tiga layar.** Complication berjalan di proses
///   terpisah dan tidak menarik `Apps/` sama sekali; ia hanya bisa membaca
///   label kalau label itu datang dari paket.
public extension ObjectKind {

    /// Nama jenis untuk ditampilkan ke pengguna.
    ///
    /// Lewat `TextLocalization` dengan alasan yang sama seperti
    /// `ConfidenceLevel.displayName`: teks ini tampil di beberapa layar
    /// sekaligus, berasal dari switch, dan tidak pernah melewati literal yang
    /// bisa dijangkau aturan 4.
    var displayName: String { TextLocalization.text(displayText) }

    /// Kunci + nilai bawaan untuk nama jenis ini.
    var displayText: LocalizedText {
        switch self {
        case .star:    return .kindStarLabel
        case .planet:  return .kindPlanetLabel
        case .moon:    return .kindMoonLabel
        case .sun:     return .kindSunLabel
        case .deepSky: return .kindDeepSkyLabel
        }
    }

    /// Label jenis untuk **diucapkan** (VoiceOver).
    ///
    /// Bedanya dengan `displayName` bukan terjemahan: `"Objek langit dalam"`
    /// adalah frasa majemuk yang terdengar janggal saat diucapkan, jadi
    /// pengucapannya ditulis eksplisit sebagai `"objek langit jauh"`.
    ///
    /// Sengaja **tidak** memakai `displayName` yang sudah dilokalisasi. Yang
    /// diucapkan adalah bentuk yang **terasa** benar di telinga; memakai
    /// bentuk tampilan membuat kalimat terucap "object deep sky, magnitude
    /// 1.6" yang tidak pernah diucapkan siapa pun.
    var spokenName: String { TextLocalization.text(spokenText) }

    /// Kunci + nilai bawaan untuk pengucapan jenis ini.
    var spokenText: LocalizedText {
        switch self {
        case .deepSky: return .kindDeepSkySpoken
        case .star:    return .kindStarSpoken
        case .planet:  return .kindPlanetSpoken
        case .moon:    return .kindMoonSpoken
        case .sun:     return .kindSunSpoken
        }
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    // MARK: Nama jenis (tampilan)

    static let kindStarLabel = LocalizedText(key: "object.kind.star.display.label",
                                              id: "Bintang")
    static let kindPlanetLabel = LocalizedText(key: "object.kind.planet.display.label",
                                                id: "Planet")
    static let kindMoonLabel = LocalizedText(key: "object.kind.moon.display.label",
                                              id: "Bulan")
    static let kindSunLabel = LocalizedText(key: "object.kind.sun.display.label",
                                             id: "Matahari")
    static let kindDeepSkyLabel = LocalizedText(key: "object.kind.deepSky.display.label",
                                                 id: "Objek langit dalam")

    // MARK: Nama jenis (pengucapan)

    static let kindStarSpoken = LocalizedText(key: "object.kind.star.spoken.label",
                                               id: "bintang")
    static let kindPlanetSpoken = LocalizedText(key: "object.kind.planet.spoken.label",
                                                 id: "planet")
    static let kindMoonSpoken = LocalizedText(key: "object.kind.moon.spoken.label",
                                               id: "bulan")
    static let kindSunSpoken = LocalizedText(key: "object.kind.sun.spoken.label",
                                              id: "matahari")
    static let kindDeepSkySpoken = LocalizedText(key: "object.kind.deepSky.spoken.label",
                                                  id: "objek langit jauh")
}