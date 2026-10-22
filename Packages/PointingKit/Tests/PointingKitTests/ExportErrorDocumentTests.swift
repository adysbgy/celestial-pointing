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
}
