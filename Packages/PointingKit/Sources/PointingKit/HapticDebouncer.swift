import Foundation
import CelestialEngine

/// Peredam getaran (ADR-022).
///
/// **Masalah lapangan (Ady, 10 Okt 2026).** "Kalau sudah terkunci di Deneb,
/// kenapa jam masih bergetar seolah masih mencari bintang lain?" Getaran
/// dipicu **setiap kali** keadaan masuk ke `lock` atau `uncertain`. Dengan
/// lengan terangkat, gerak kecil memantulkan keadaan lock → pointing → lock
/// berkali-kali, jadi getaran "ketemu" berbunyi lagi dan lagi untuk bintang
/// yang **sama**, dan getaran "ragu" ikut berselang-seling.
///
/// Aturannya:
/// - "Ketemu" hanya untuk benda **baru**, atau benda yang sama setelah kunci
///   benar-benar hilang cukup lama (`relockQuietSeconds`).
/// - "Ragu" paling sering sekali per `uncertainQuietSeconds`, dan tidak
///   pernah sesaat setelah "ketemu" (itu hanya kunci yang goyah, bukan berita).
/// - Peristiwa lain (sensor hilang, kembali ke idle) tidak diredam.
public struct HapticDebouncer: Sendable {
    public var relockQuietSeconds: TimeInterval = 8
    public var uncertainQuietSeconds: TimeInterval = 6

    private var celebratedObjectID: String?
    private var lastLockSeen: Date?
    private var lastUncertainPlayed: Date?

    public init() {}

    public mutating func filter(_ events: [HapticEvent], state: PointingState,
                                objectID: String?, at now: Date) -> [HapticEvent] {
        defer { if state == .lock { lastLockSeen = now } }
        return events.filter { event in
            switch event {
            case .lockSucceeded:
                let sameObject = objectID != nil && objectID == celebratedObjectID
                let recentlyLocked = lastLockSeen.map { now.timeIntervalSince($0) < relockQuietSeconds } ?? false
                if sameObject && recentlyLocked { return false }
                celebratedObjectID = objectID
                return true
            case .uncertain:
                if let seen = lastLockSeen, now.timeIntervalSince(seen) < uncertainQuietSeconds { return false }
                if let played = lastUncertainPlayed, now.timeIntervalSince(played) < uncertainQuietSeconds { return false }
                lastUncertainPlayed = now
                return true
            default:
                return true
            }
        }
    }

    public mutating func reset() {
        celebratedObjectID = nil
        lastLockSeen = nil
        lastUncertainPlayed = nil
    }
}
