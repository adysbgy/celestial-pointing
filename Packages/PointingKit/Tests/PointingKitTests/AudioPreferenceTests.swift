import XCTest
@testable import PointingKit

/// Uji `AudioPreference` — keputusan "bunyi menyala atau tidak" yang dulu
/// tinggal di `Apps/Shared/AudioCue.swift` tanpa satu pun gerbang.
final class AudioPreferenceTests: XCTestCase {

    /// Saklar yang dimatikan pengguna **wajib** dihormati.
    ///
    /// **Koreksi riwayat (22 Okt 2026).** Versi pertama docstring ini menulis
    /// bahwa uji ini "menangkap cacat yang terukur di `sapu-buta-apps.py`":
    /// mengganti badan `AudioCue.isOn` menjadi `return true` lolos seluruh
    /// gerbang. Itu tidak benar — `PreferenceDefaultsTests` sudah menangkap
    /// bentuk itu, dan yang membuat klaim itu lahir adalah alat sapuannya,
    /// yang hanya menjalankan dua dari tiga gerbang.
    ///
    /// Yang **benar-benar** tidak terjaga oleh apa pun sebelum modul ini:
    /// membalik nilai di dalam cabang, sehingga kunci kosong berarti **mati**
    /// padahal model menyatakan nyala. Bentuk itu tidak meninggalkan jejak di
    /// teks — hanya perilakunya yang salah, dan hanya uji yang menjalankannya
    /// yang bisa melihatnya. Uji ini menjalankannya.
    func testStoredFalseIsRespected() {
        XCTAssertFalse(AudioPreference.isEnabled(stored: false),
                       "saklar pengguna dimatikan, tapi bunyi tetap dianggap nyala")
    }

    /// Saklar yang dinyalakan pengguna dihormati apa adanya.
    func testStoredTrueIsRespected() {
        XCTAssertTrue(AudioPreference.isEnabled(stored: true))
    }

    /// Belum pernah diset = nyala.
    ///
    /// Default ini sengaja, bukan kebetulan: bunyi kunci adalah saluran
    /// aksesibilitas, dan default mati membuat saluran itu tidak pernah
    /// ditemukan orang yang paling membutuhkannya.
    func testUnsetFallsBackToEnabled() {
        XCTAssertTrue(AudioPreference.isEnabled(stored: nil),
                      "kunci belum pernah diset harus berarti nyala, bukan mati")
        XCTAssertEqual(AudioPreference.isEnabled(stored: nil),
                       AudioPreference.defaultEnabled)
    }

    /// Ketiga keadaan tersimpan menghasilkan **tiga** hasil berbeda-beda
    /// yang mungkin — dan yang penting: tidak ada dua keadaan yang runtuh
    /// menjadi satu.
    ///
    /// Uji ini menjaga sifat yang membuat `Bool?` dipakai sebagai parameter:
    /// kalau `nil` dan `false` sama-sama menghasilkan `false`, "belum diset"
    /// tidak bisa dibedakan dari "dimatikan", dan default nyala hilang tanpa
    /// ada yang memintanya.
    func testUnsetIsDistinguishableFromOff() {
        XCTAssertNotEqual(AudioPreference.isEnabled(stored: nil),
                          AudioPreference.isEnabled(stored: false),
                          "belum diset dan dimatikan menghasilkan nilai sama — "
                          + "default nyala tidak bisa dibedakan dari saklar mati")
    }

    /// Sapuan: setiap nilai `Bool?` yang mungkin menghasilkan jawaban, dan
    /// hanya `false` tersimpan yang menghasilkan mati.
    ///
    /// Ditulis sebagai sapuan, bukan tiga asersi, supaya kasus baru (kalau
    /// tipe parameternya kelak melebar) tidak bisa lolos hanya karena tidak
    /// ada yang menyebutnya.
    func testEveryStoredValueDecides() {
        for stored in [nil, true, false] as [Bool?] {
            let hasil = AudioPreference.isEnabled(stored: stored)
            let diharapkan = stored ?? AudioPreference.defaultEnabled
            XCTAssertEqual(hasil, diharapkan,
                           "stored=\(String(describing: stored)) salah diputuskan")
        }
    }
}
