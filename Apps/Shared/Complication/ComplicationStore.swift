import Foundation
import CelestialEngine
import PointingKit

/// Penyimpan antara app jam dan **complication** (WidgetKit).

/// **Kenapa ini perlu.** Complication watchOS berjalan di proses **terpisah**
/// dari app jam — ia tidak bisa membaca `@StateObject` engine, tidak bisa
/// memanggil `PointingEngine`, dan tidak punya akses ke layar apa pun. Satu-
/// satunya cara ia tahu "objek terakhir yang terkunci" adalah lewat berkas
/// yang dibagi. Karena itu app jam **menulis** snapshot ringkas setiap kali
/// keadaan berubah, dan complication **membaca**nya saat watchOS meminta
/// entri timeline.

/// **Kenapa App Group + fallback.** Berbagi antar-proses di watchOS butuh
/// App Group (`containerURL(forSecurityApplicationGroupIdentifier:)`). Tapi
/// CI membangun **tanpa tanda tangan** (`CODE_SIGNING_ALLOWED=NO`), dan di
/// situ container App Group mengembalikan `nil`. Kalau kita mengandalkan
/// container itu tanpa cadangan, complication akan diam di setiap build CI
/// (dan di Simulator tanpa entitas) — persis "kegagalan diam" yang dilarang
/// PRD. Makanya ada fallback ke direktori cache: penyimpanan tetap jalan
/// (sekadar tidak terbaca complication saat belum ada App Group yang
/// diaktifkan di profil), dan yang penting **kompilasi & tes lolos** tanpa
/// sertifikat.

/// Snapshot yang dibagikan — hanya teks & enum, bukan objek engine.

/// Sengaja `Codable` & `Sendable`: complication hanya butuh string untuk
/// dirender, dan menyalin struct engine ke sini berarti dua sumber nama.
/// Nama & jenis sudah dihitung di app (pakai `ObjectKindLabels` yang sama),
/// jadi complication tidak perlu tahu `PointingKit` sama sekali.
public struct ComplicationSnapshot: Codable, Sendable {
    /// Keadaan engine (`PointingState` rawValue — `String, Codable`).
    public var stateRaw: String
    /// Nama objek terkunci, bila ada.
    public var objectName: String?
    /// Jenis objek (Bintang/Planet/…), bila ada.
    public var objectKindDisplay: String?
    /// Apakah gambar/identitas dikonfirmasi (bukan `.uncertain`).
    public var confirmed: Bool
    /// Kapan snapshot ini ditulis.
    public var updatedAt: Date

    public init(stateRaw: String,
                objectName: String?,
                objectKindDisplay: String?,
                confirmed: Bool,
                updatedAt: Date) {
        self.stateRaw = stateRaw
        self.objectName = objectName
        self.objectKindDisplay = objectKindDisplay
        self.confirmed = confirmed
        self.updatedAt = updatedAt
    }

    /// Baris utama untuk complication: nama objek bila terkunci, atau label
    /// keadaan bila tidak.
    public var headline: String {
        if let name = objectName, (stateRaw == PointingState.lock.rawValue
                                    || (stateRaw == PointingState.uncertain.rawValue && confirmed)) {
            return name
        }
        return PointingState(rawValue: stateRaw)?.shortLabel ?? "Point & Know"
    }

    /// Apakah snapshot ini berisi hasil pengenalan yang patut ditampilkan.
    public var hasAnswer: Bool {
        stateRaw == PointingState.lock.rawValue
            || stateRaw == PointingState.uncertain.rawValue
    }
}

/// Satu-satunya tempat baca/tulis berkas complication.
///
/// `shared` dipakai app jam (tulis) dan complication (baca). Menuliskannya di
/// satu kelas berarti app dan extension tidak bisa berbeda pendapat tentang
/// nama berkas & lokasi container.
public final class ComplicationStore {

    public static let shared = ComplicationStore()

    /// Nama berkas — identik di app dan extension.
    static let fileName = "complication-snapshot.json"
    /// App Group bersama. Harus diaktifkan di profil provisi untuk benar-benar
    /// terbagi; tanpa itu, `containerURL` mengembalikan `nil` dan kita pakai
    /// fallback cache.
    static let appGroupID = "group.dev.celestial.pointandknow"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// URL tempat menyimpan. App Group bila tersedia, else cache app.
    ///
    /// Dua lokasi ini **berbeda** saat App Group belum aktif, jadi di situ
    /// complication (jika ia punya App Group) tidak akan melihat tulisan app
    /// (yang jatuh ke cache). Itu bukan bug diam-diam: di perangkat nyata
    /// dengan App Group diaktifkan, keduanya sama. Fallback hanya menjaga
    /// agar penyimpanan tidak crash saat tidak ada container.
    private var storeURL: URL {
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            return group.appendingPathComponent(Self.fileName)
        }
        let cache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cache.appendingPathComponent(Self.fileName)
    }

    /// Tulis snapshot. Aman dipanggil dari main actor; pemanggil sudah
    /// membatasi ke transisi keadaan, jadi ini tidak terjadi 20×/dtk.
    public func record(_ snapshot: ComplicationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        // Tulis ke file sementara lalu pindahkan: menimpa berkas langsung bisa
        // meninggalkan berkas rusak bila app dihentikan tengah tulis.
        let url = storeURL
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent("\(Self.fileName).tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            try fileManager.replaceItem(at: url, withItemAt: tmp)
        } catch {
            // Kegagalan tulis complication bukan alasan menghentikan engine.
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Baca snapshot terakhir. `nil` bila belum pernah ditulis.
    public func read() -> ComplicationSnapshot? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? JSONDecoder().decode(ComplicationSnapshot.self, from: data)
    }
}
