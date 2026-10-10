import Foundation
import PointingKit

/// Pengaturan bersama jam ↔ iPhone di `UserDefaults` (ADR-020).
///
/// `@AppStorage` di kedua app membaca kunci yang sama, jadi menulis ke sini
/// langsung memperbarui layar. Perubahan **oleh pengguna** memanggil
/// `userChanged` (stempel waktu baru, lalu dikirim); perubahan yang datang
/// dari perangkat lain lewat `apply` — tanpa dikirim balik, supaya tidak
/// terjadi pantulan bolak-balik.
enum SettingsSyncStore {
    static let darkSkyKey = SkyQualityStorage.darkSkyKey
    static let hotColdKey = "hotCold.enabled"
    static let updatedAtKey = "settings.updatedAt"

    static func local(_ d: UserDefaults = .standard) -> SyncedSettings {
        SyncedSettings(darkSky: d.bool(forKey: darkSkyKey),
                       hotCold: d.object(forKey: hotColdKey) as? Bool ?? true,
                       updatedAt: Date(timeIntervalSince1970: d.double(forKey: updatedAtKey)))
    }

    /// Pengguna mengubah pengaturan di perangkat ini.
    static func userChanged(_ d: UserDefaults = .standard) -> SyncedSettings {
        d.set(Date().timeIntervalSince1970, forKey: updatedAtKey)
        return local(d)
    }

    /// Terapkan pengaturan dari perangkat lain bila lebih baru. `true` bila berubah.
    @discardableResult
    static func apply(_ incoming: SyncedSettings, _ d: UserDefaults = .standard) -> Bool {
        let mine = local(d)
        guard mine.merged(with: incoming) == incoming, incoming != mine else { return false }
        d.set(incoming.darkSky, forKey: darkSkyKey)
        d.set(incoming.hotCold, forKey: hotColdKey)
        d.set(incoming.updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
        return true
    }
}
