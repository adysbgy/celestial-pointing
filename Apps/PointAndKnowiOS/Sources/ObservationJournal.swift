import Foundation
import CelestialEngine
import PointingKit

/// Jurnal pengamatan tersimpan (ADR-019): "Simpan Pengamatan" di kartu
/// Penemuan. Disimpan di perangkat (UserDefaults, JSON) — tidak dikirim ke
/// mana pun.
@MainActor
final class ObservationJournal: ObservableObject {
    struct JournalEntry: Codable, Identifiable, Equatable {
        var id = UUID()
        var objectID: String
        var name: String
        var kind: String
        var date: Date
        var latitudeDeg: Double
        var longitudeDeg: Double
        /// Disimpan otomatis dari konfirmasi di jam (ADR-020).
        var fromWatch: Bool? = nil
        /// Id pesan jam — mencegah konfirmasi yang sama tersimpan dua kali
        /// (langsung lalu dari antrean).
        var sourceMessageID: UInt64? = nil
    }

    static let storageKey = "journal.v1"
    @Published private(set) var entries: [JournalEntry] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded.sorted { $0.date > $1.date }
        }
    }

    /// Pernah disimpan sebelumnya? Menentukan "PENEMUAN PERTAMA".
    func contains(objectID: String) -> Bool { entries.contains { $0.objectID == objectID } }

    func save(_ object: CelestialObject, at date: Date, observer: Observer) {
        entries.insert(JournalEntry(objectID: object.id, name: object.name, kind: object.kind.rawValue, date: date,
                             latitudeDeg: observer.latitudeDeg, longitudeDeg: observer.longitudeDeg), at: 0)
        persist()
    }

    /// Konfirmasi "Ya, itu dia" di jam → Jurnal, otomatis (ADR-020).
    func saveFromWatch(_ message: LiveMessage, resolver: PointingResolver, observer: Observer) {
        guard let id = message.objectID,
              !entries.contains(where: { $0.sourceMessageID == message.id && $0.fromWatch == true }),
              let object = resolver.object(forID: id, observer: observer, date: message.sentAt) else { return }
        entries.insert(JournalEntry(objectID: id, name: object.name, kind: object.kind.rawValue,
                                    date: message.sentAt, latitudeDeg: observer.latitudeDeg,
                                    longitudeDeg: observer.longitudeDeg, fromWatch: true,
                                    sourceMessageID: message.id), at: 0)
        entries.sort { $0.date > $1.date }
        persist()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
