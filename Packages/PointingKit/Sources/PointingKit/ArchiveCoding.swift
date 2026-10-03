import Foundation

/// Format waktu untuk arsip dataset.
///
/// **Kenapa bukan `.iso8601` bawaan.** Strategi bawaan membuang pecahan detik.
/// Untuk rekaman pointing itu merugikan dua kali: urutan percobaan bisa
/// bertukar saat dua percobaan jatuh pada detik yang sama, dan waktu yang
/// hilang tidak terlihat di berkas. Arsip eksperimen harus menyimpan waktu apa
/// adanya — kalau tidak, yang dianalisis bukan lagi data yang direkam.
enum ArchiveDateCoding {
    /// Penulis: selalu dengan pecahan detik.
    static let writer: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Pembaca: menerima bentuk dengan maupun tanpa pecahan detik, supaya
    /// arsip lama (yang ditulis dengan `.iso8601` bawaan) tetap terbaca.
    static func date(from text: String) -> Date? {
        if let date = writer.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }
}

extension JSONEncoder {
    /// Pengekod arsip dataset: waktu UTC dengan pecahan detik, keluaran rapi.
    static func pointingArchive() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ArchiveDateCoding.writer.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    /// Penyahkod pasangan `JSONEncoder.pointingArchive()`.
    static func pointingArchive() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = ArchiveDateCoding.date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "waktu ISO8601 tidak bisa dibaca: \(text)"
                )
            }
            return date
        }
        return decoder
    }
}
