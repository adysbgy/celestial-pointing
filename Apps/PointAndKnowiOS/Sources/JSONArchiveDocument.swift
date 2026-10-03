import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Berkas JSON yang dibagikan lewat `ShareLink`.
///
/// **Kenapa bukan `String` langsung.** `ShareLink(item: String)` membagikan teks
/// mentah tanpa identitas berkas: di lembar berbagi ia muncul sebagai "Teks"
/// tanpa akhiran `.json`, dan penerimanya tidak bisa membukanya sebagai dataset.
/// Nama berkas dari `suggestedFilename` (stempel waktu UTC) yang sudah ditulis
/// dan diuji di `PointingKit` jadi tidak pernah terpakai — dua ekspor bisa
/// bertabrakan, dan berkas yang tersimpan ke Files tidak dikenali sebagai JSON.
///
/// Membungkusnya sebagai `FileRepresentation` membuat berkasnya benar-benar
/// ditulis ke disk dengan nama itu, lalu diserahkan ke lembar berbagi.
struct JSONArchiveDocument: Transferable {

    /// Nama berkas tujuan, termasuk akhiran `.json`.
    let filename: String
    /// Isi berkas.
    let data: Data

    init(filename: String, data: Data) {
        self.filename = filename
        self.data = data
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { document in
            // `FileRepresentation` menuntut berkas nyata di disk. Tulis ke
            // direktori sementara dengan nama yang sudah ditentukan pemanggil,
            // lalu serahkan URL-nya — sistem yang menyalin ke tujuan.
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(document.filename)
            try document.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
