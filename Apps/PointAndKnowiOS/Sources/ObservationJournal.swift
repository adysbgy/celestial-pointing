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
