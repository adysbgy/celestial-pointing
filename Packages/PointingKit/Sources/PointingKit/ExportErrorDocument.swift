import Foundation

/// Berkas pengganti yang dibagikan saat encoding dataset gagal.
///
/// **Kenapa ini ada.** Ekspor `Experiment 1` dan ekspor riwayat keyakinan
/// sama-sama bisa gagal encode. Dulu kedua view membangun berkas penggantinya
/// dengan **menggabung string**:
///
///     let message = "{\"error\": \"gagal meng-encode dataset: \(error.localizedDescription)\"}"
///
/// `error.localizedDescription` datang dari sistem dan boleh memuat tanda
/// kutip, garis miring terbalik, atau baris baru. Satu kutip saja membuat
/// berkas `.json` itu **tidak sah**, padahal namanya tetap
/// `experiment1-….json` dan penerimanya membukanya sebagai dataset. Kerusakan
/// seperti itu tidak berbunyi: berkasnya ada, ukurannya wajar, dan baru
/// ketahuan saat dibuka.
///
/// Karena itu pembentukan berkas ini dipindah ke satu fungsi murni yang
/// memakai `JSONSerialization` — jalur yang sama dengan pembaca di sisi
/// penerima. Hasilnya diuji `ExportErrorDocumentTests` untuk pesan yang
/// memang memuat kutip dan karakter kendali.
public enum ExportErrorDocument {

    /// Galat yang dilempar saat pembuat dokumen ini sendiri gagal — praktis
    /// tidak terjadi (`JSONSerialization` menerima string apa pun), tapi
    /// kegagalan itu tidak boleh diam-diam menghasilkan berkas kosong.
    public struct Failure: Error, CustomStringConvertible {
        public let underlying: Error
        public var description: String {
            "ExportErrorDocument gagal membangun berkas galat: \(underlying)"
        }
    }

    /// Bangun isi berkas galat sebagai JSON sah: satu objek `{"error": …}`.
    ///
    /// **Kenapa `JSONSerialization`, bukan `JSONEncoder`.** Yang perlu ditulis
    /// hanya satu pasangan kunci–nilai; struct `Codable` satu bidang untuk itu
    /// menambah tipe yang harus ikut diuji. Yang penting bukan pemilihan
    /// API-nya, melainkan bahwa **tidak ada satu pun jalur** yang menggabung
    /// string JSON dengan tangan.
    ///
    /// `prettyPrinted` dan `sortedKeys` dipakai supaya berkasnya terbaca
    /// manusia saat dibuka di Files — isinya pesan kesalahan, dan pesan
    /// kesalahan yang terbaca satu baris panjang lebih sulit dilaporkan.
    public static func data(message: String) -> Data {
        let object: [String: String] = ["error": message]
        guard let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            // Jalan keluar yang tetap sah.
            //
            // **Ini tidak pernah jalan.** `[String: String]` selalu bisa
            // diserialisasi — `Swift.String` selalu Unicode yang sah, jadi
            // `JSONSerialization` tidak punya alasan menolaknya. Cabang ini
            // tetap ada supaya `data(message:)` **tidak punya** jalur yang
            // mengembalikan `Data()` kosong; berkas kosong adalah bentuk
            // kegagalan senyap yang justru ingin dicegah.
            //
            // Karena tidak bisa dicapai lewat `data(message:)`, peng-escape-nya
            // diuji langsung (`escapedFallback`) — kalau tidak, kalimat "tidak
            // ada cabang yang menghasilkan berkas tidak sah" hanya klaim.
            return Data("{\"error\": \"\(escapedFallback(message))\"}".utf8)
        }
        return data
    }

    /// Escape satu string supaya aman dipakai di dalam literal JSON.
    ///
    /// Dipakai hanya oleh jalur cadangan `data(message:)`, yang tidak bisa
    /// dicapai di produksi. Ia `internal` (bukan `private`) supaya bisa diuji
    /// langsung — cabang yang tidak bisa dicapai tapi tidak diuji adalah klaim,
    /// bukan jaminan.
    ///
    /// Urutannya penting: **garis miring terbalik lebih dulu**, lalu yang lain.
    /// Kalau kutip di-escape lebih dulu, garis miring yang baru ditambahkan
    /// untuk kutip itu akan ikut di-escape lagi dan hasilnya berlipat.
    static func escapedFallback(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Nama berkas untuk dokumen galat.
    ///
    /// Nama dari pemanggil dipertahankan apa adanya: akhiran `.json` dan
    /// stempel waktunya sudah diputuskan di satu tempat
    /// (`DatasetArchive.suggestedFilename` / `ConfidenceTraceArchive`), dan
    /// berkas galat tidak boleh punya penamaan sendiri — dua skema nama untuk
    /// satu jenis berkas akan membuat ekspor saling menimpa.
    public static func filename(like name: String) -> String {
        name
    }
}
