import XCTest
@testable import PointingKit

/// Katalog **wajib** memuat Bahasa Indonesia untuk setiap kunci yang lahir di
/// paket.
///
/// **Cacat yang akan ditangkap berkas ini.** `sensor.motion.failed` satu-satunya
/// kunci `sensor.*` yang tidak punya entri `id` di `Localizable.xcstrings`. Di
/// perangkat berbahasa Indonesia, kunci itu jatuh ke nilai bawaan
/// `LocalizedText.id` ("Sensor gerak berhenti: %@") — jadi kalimatnya **tampak
/// benar**, dan itulah sebabnya cacat ini tidak pernah terlihat. Yang tidak
/// benar adalah bentuk `localizations`-nya: katalog menyatakan kunci itu
/// punya terjemahan Inggris dan **tidak** punya teks Indonesia, padahal
/// `sourceLanguage` katalog adalah `id`. Xcode memperlakukannya sebagai
/// terjemahan **tidak lengkap** untuk bahasa sumber, dan yang terlihat di
/// Editor katalog adalah `en` ditempel di kolom `id` — sementara nilai yang
/// benar-benar dipakai saat berjalan datang dari berkas Swift, bukan katalog.
///
/// **Kenapa satu kunci bisa lolos tanpa gerbang.** Aturan 6 memeriksa
/// **paritas kunci** (ada/tidak ada), bukan **kelengkapan bahasa**; Aturan 4
/// menyapu literal di `Apps/`; Aturan 29 menyapu literal di parameter
/// `String`. Tidak satu pun membaca isi `localizations` sebuah kunci yang
/// sudah ada. Kelasnya sama dengan cacat-cacat lain di repo ini: kuncinya ada,
/// jadi semua gerbang yang memeriksa keberadaan lulus.
///
/// **Kenapa `id` wajib untuk kunci paket, padahal docstring
/// `ObjectDisplayNameTests` bilang tidak.** Dua aturan berbeda, dan bedanya
/// bisa diperiksa: nama objek langit dibangun **satu kali** di
/// `LocalizedText.id` dan katalognya hanya perlu `en`. Untuk kunci paket biasa
/// nilai bawaannya juga ada di `LocalizedText.id` — tetapi kuncinya dipakai
/// **di kedua app lewat dua jalur berbeda** (`TextLocalization` di paket, dan
/// `Text(LocalizedStringKey)` di view), dan jalur kedua **tidak pernah
/// membaca `LocalizedText.id`**: ia membaca katalog. Tanpa entri `id`, dua
/// jalur itu bisa berbeda pendapat tentang Bahasa Indonesia — hanya katalog
/// yang mengikat keduanya.
final class CatalogIndonesianCoverageTests: XCTestCase {

    /// Setiap kunci yang dideklarasikan di paket harus punya entri `id`.
    func testEveryPackageKeyHasAnIndonesianEntry() throws {
        let catalog = try XCTUnwrap(Self.catalogStrings(),
                                    "Localizable.xcstrings tidak terbaca")
        let keys = LocalizedText.allKeys.map(\.rawValue)
        XCTAssertGreaterThan(keys.count, 300,
                             "cakupan berkas ini menyusut — kunci paket lebih "
                             + "sedikit dari sebelumnya")

        var tanpaIndonesia: [String] = []
        for key in keys {
            guard let entry = catalog[key] else { continue }  // Aturan 6 sudah menjaga ini
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            guard let unit = localizations["id"]?["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String,
                  !value.isEmpty else {
                tanpaIndonesia.append(key)
                continue
            }
        }

        XCTAssertTrue(tanpaIndonesia.isEmpty,
                      "\(tanpaIndonesia.count) kunci paket tanpa teks Indonesia di "
                      + "katalog: \(tanpaIndonesia.sorted().joined(separator: ", "))")
    }

    /// Nilai `id` di katalog harus **sama** dengan nilai bawaan di paket.
    ///
    /// Bukan hiasan: dua salinan yang boleh berbeda berarti perangkat
    /// berbahasa Indonesia dan pengujian Linux membaca kalimat yang berbeda,
    /// dan yang lolos LULUS adalah yang di Linux. Uji ini memaksa keduanya
    /// satu teks.
    func testCatalogIndonesianMatchesThePackageDefault() throws {
        let catalog = try XCTUnwrap(Self.catalogStrings(),
                                    "Localizable.xcstrings tidak terbaca")
        var berbeda: [String] = []
        for key in LocalizedText.allKeys where !key.indonesian.isEmpty {
            guard let entry = catalog[key.rawValue],
                  let localizations = entry["localizations"] as? [String: [String: Any]],
                  let unit = localizations["id"]?["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else { continue }
            if value != key.indonesian {
                berbeda.append("\(key.rawValue): katalog=\(value) paket=\(key.indonesian)")
            }
        }
        XCTAssertTrue(berbeda.isEmpty,
                      "nilai Indonesia di katalog dan di paket menyimpang:\n"
                      + berbeda.joined(separator: "\n"))
    }

    private static func catalogStrings() -> [String: [String: Any]]? {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            let candidate = dir
                .appendingPathComponent("Apps/Shared/Resources/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path),
               let data = try? Data(contentsOf: candidate),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let strings = root["strings"] as? [String: [String: Any]] {
                return strings
            }
        }
        return nil
    }
}
