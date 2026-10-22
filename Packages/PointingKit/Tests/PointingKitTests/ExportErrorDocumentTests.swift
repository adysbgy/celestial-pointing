import XCTest
import CelestialEngine
@testable import PointingKit

/// Ekspor gagal-encode wajib tetap menghasilkan **JSON yang sah**.
///
/// **Cacat yang ditangkap berkas ini.** Dua jalur ekspor
/// (`Experiment1View.exportDocument` dan `DiagnosticsView.exportDocument`)
/// membangun berkas pengganti saat encoding gagal dengan **menggabung string**:
///
///     let message = "{\"error\": \"gagal meng-encode dataset: \(error.localizedDescription)\"}"
///
/// Itu bukan JSON. `error.localizedDescription` berasal dari sistem dan boleh
/// memuat tanda kutip — misalnya pesan `NSCocoaErrorDomain` yang menyebut nama
/// berkas bertanda kutip, atau pesan `EncodingError` yang menyertakan path
/// ber-kutip. Satu kutip saja membuat berkasnya **tidak sah sebagai JSON**,
/// padahal namanya `experiment1-….json` dan isinya dibuka penerima sebagai
/// dataset. Kerusakannya senyap: berkasnya ada, ukurannya wajar, dan baru
/// ketahuan saat dibuka.
///
/// **Kenapa diuji di PointingKit.** Penggabungan string itu tinggal di badan
/// view, yang tidak bisa dijalankan di Linux. Yang bisa diuji adalah
/// penggantinya: satu fungsi murni yang membangun berkas galat, dan hasilnya
/// harus **lolos `JSONSerialization`** untuk pesan yang mengandung kutip,
/// garis miring terbalik, dan baris baru. Aturan 90 (`swift-ui-lint.sh`)
/// kemudian mengukur bahwa view benar-benar memakai fungsi ini dan tidak
/// kembali menggabung string.
final class ExportErrorDocumentTests: XCTestCase {

    /// Pesan galat yang benar-benar bisa muncul: kutip, garis miring terbalik,
    /// baris baru, dan karakter non-ASCII.
    private let hostileMessages = [
        "gagal meng-encode dataset: file \"experiment1.json\" tidak terbaca",
        "gagal meng-encode riwayat keyakinan: path C:\\Users\\observer\\trace.json",
        "gagal meng-encode dataset: baris pertama\nbaris kedua",
        "gagal meng-encode dataset: nilai tak terhingga (∞) pada sigma",
        "gagal meng-encode dataset: {kurung kurawal} dan [kurung siku]",
        "gagal meng-encode dataset: kutip tunggal 'x' dan kutip ganda \"y\""
    ]

    /// Berkas galat harus **JSON sah** untuk setiap pesan, dan pesannya harus
    /// **kembali utuh** setelah dibaca — bukan dipotong di kutip pertama.
    func testErrorDocumentIsValidJSONForHostileMessages() throws {
        for message in hostileMessages {
            let data = ExportErrorDocument.data(message: message)

            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                XCTFail("berkas galat bukan objek JSON untuk pesan: \(message)")
                continue
            }

            XCTAssertEqual(dictionary["error"] as? String, message,
                           "pesan galat berubah saat ditulis sebagai JSON")
            XCTAssertEqual(dictionary.count, 1,
                           "berkas galat hanya boleh memuat satu kunci `error`")
        }
    }

    /// Isi berkas galat harus **bisa dibaca sebagai teks UTF-8**. Berkas yang
    /// tidak terbaca sama saja dengan berkas kosong bagi penerimanya.
    func testErrorDocumentIsUTF8() {
        let data = ExportErrorDocument.data(message: "gagal meng-encode dataset: ∞")
        XCTAssertNotNil(String(data: data, encoding: .utf8))
    }

    /// Berkas galat **tidak boleh** bisa dibaca sebagai dataset sungguhan.
    /// Kalau `DatasetArchive.decode` menerimanya, penerima akan mengira ia
    /// mendapat dataset kosong yang sah — persis kesalahan yang ingin dicegah.
    func testErrorDocumentIsNotDecodableAsDataset() {
        let data = ExportErrorDocument.data(message: "gagal meng-encode dataset")
        XCTAssertThrowsError(try DatasetArchive.decode(data)) { error in
            XCTAssertFalse(error is ExportErrorDocument.Failure,
                           "galat decode tidak boleh berasal dari pembuat dokumen galat")
        }
    }

    /// Berkas galat **tidak boleh** bisa dibaca sebagai riwayat keyakinan.
    func testErrorDocumentIsNotDecodableAsTrace() {
        let data = ExportErrorDocument.data(message: "gagal meng-encode riwayat")
        XCTAssertThrowsError(try ConfidenceTraceArchive.decode(data))
    }

    /// Nama berkas galat tetap memakai akhiran `.json` supaya penerima bisa
    /// membukanya, dan tetap membawa stempel waktu pemanggil.
    func testErrorDocumentKeepsCallerFilename() {
        let name = "experiment1-20260101-000000Z.json"
        XCTAssertEqual(ExportErrorDocument.filename(like: name), name)
    }

    /// Pesan kosong pun harus menghasilkan JSON sah — bukan `{"error": }`.
    func testEmptyMessageStillValidJSON() throws {
        let data = ExportErrorDocument.data(message: "")
        let object = try JSONSerialization.jsonObject(with: data)
        XCTAssertEqual((object as? [String: Any])?["error"] as? String, "")
    }

    // ── Jalur cadangan `escapedFallback` ──────────────────────────────────
    //
    // `data(message:)` memakai `JSONSerialization`, dan jalur cadangannya
    // **tidak bisa dicapai** dari sana: `[String: String]` selalu bisa
    // diserialisasi. Kalau jalur itu tidak diuji sama sekali, komentar
    // "tidak ada cabang yang menghasilkan berkas tidak sah" hanya klaim —
    // dan cabang yang tak teruji adalah tempat cacat berikutnya bersembunyi.
    // Jadi peng-escape-nya diuji **langsung**, dan hasilnya dibungkus jadi
    // JSON lalu dibaca balik.

    /// Peng-escape harus menghasilkan literal JSON yang sah dan **bolak-balik
    /// utuh** untuk pesan yang memuat kutip, garis miring terbalik, dan baris
    /// baru sekaligus.
    func testFallbackEscaperProducesValidJSONForHostileMessages() throws {
        for message in hostileMessages {
            let literal = "{\"error\": \"\(ExportErrorDocument.escapedFallback(message))\"}"
            let data = Data(literal.utf8)

            let object = try JSONSerialization.jsonObject(with: data)
            XCTAssertEqual((object as? [String: Any])?["error"] as? String, message,
                           "pesan berubah saat lewat jalur cadangan: \(message)")
        }
    }

    /// **Urutan escape adalah inti cacatnya.** Garis miring terbalik wajib
    /// di-escape **sebelum** kutip. Kalau dibalik, garis miring yang baru
    /// ditambahkan untuk kutip ikut ter-escape lagi dan pesannya berlipat:
    /// `"` → `\"` → `\\\"` yang terbaca balik sebagai `\"`.
    ///
    /// Pesan di bawah memuat keduanya bersebelahan, jadi urutan yang salah
    /// tidak bisa lolos diam-diam.
    func testFallbackEscaperEscapesBackslashBeforeQuote() throws {
        let message = #"path \"kuot\" di C:\Users\observer"#
        let literal = "{\"error\": \"\(ExportErrorDocument.escapedFallback(message))\"}"
        let object = try JSONSerialization.jsonObject(with: Data(literal.utf8))
        XCTAssertEqual((object as? [String: Any])?["error"] as? String, message)
    }

    /// Baris baru **harus** menjadi `\n`, bukan baris baru sungguhan: JSON
    /// tidak mengizinkan baris baru mentah di dalam string, dan berkas yang
    /// memuatnya ditolak pembaca — persis kegagalan yang ingin dicegah.
    func testFallbackEscaperRejectsRawNewline() {
        let escaped = ExportErrorDocument.escapedFallback("baris satu\nbaris dua")
        XCTAssertFalse(escaped.contains("\n"), "baris baru mentah lolos ke literal JSON")
        XCTAssertTrue(escaped.contains("\\n"), "baris baru tidak di-escape menjadi \\n")
    }
}
