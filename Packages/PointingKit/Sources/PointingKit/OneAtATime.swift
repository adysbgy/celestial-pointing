import Foundation
import CelestialEngine

/// "Tunjuk satu, tahu satu" (ADR-014, Docs/PRODUCT_V2_IDEA.md §2).
///
/// Jam tidak lagi menampilkan daftar "Mungkin salah satu ini". Kandidat
/// diurutkan, yang teratas tampil besar, dan Digital Crown berpindah ke
/// kandidat berikutnya **satu per satu**.
///
/// **Urutan.** Jarak dari arah tunjuk, ditambah denda kecerlangan: di langit
/// kota, dari dua benda yang sama dekatnya, yang benar-benar dilihat pengguna
/// hampir pasti yang lebih terang. Dendanya kecil (2° per magnitudo, relatif
/// terhadap kandidat paling terang) supaya arah tunjuk tetap yang utama:
/// benda yang jauh lebih dekat ke arah tangan tetap menang.
///
/// **Kejujuran.** Ini cara *menampilkan* keraguan, bukan menghapusnya.
/// Keyakinan tetap milik engine: hasil `.uncertain` tidak pernah tampil
/// sebagai "pasti", dan tetangga yang terlalu dekat untuk dibedakan oleh
/// akurasi tunjuk selalu disebut.
public struct OneAtATime: Equatable, Sendable {

    public struct Entry: Equatable, Sendable {
        public let object: CelestialObject
        /// Jarak dari arah tunjuk (derajat).
        public let separationDeg: Double
        /// Skor urut (derajat efektif; makin kecil makin mungkin).
        public let score: Double
    }

    /// Denda per magnitudo terhadap kandidat paling terang (derajat).
    public static let brightnessPenaltyDegPerMag = 2.0

    public let entries: [Entry]

    public init(candidates: [Candidate]) {
        let brightest = candidates.map(\.object.magnitude).min() ?? 0
        entries = candidates
            .map { c in
                Entry(object: c.object, separationDeg: c.separationDeg,
                      score: c.separationDeg
                        + Self.brightnessPenaltyDegPerMag * max(0, c.object.magnitude - brightest))
            }
            .sorted { $0.score < $1.score }
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    /// Kandidat pada posisi crown. Crown memutar melingkar: setelah yang
    /// terakhir, kembali ke yang pertama.
    public func entry(at crownIndex: Int) -> Entry? {
        guard !entries.isEmpty else { return nil }
        let n = entries.count
        return entries[((crownIndex % n) + n) % n]
    }

    /// Tetangga terdekat (di langit, bukan dari arah tunjuk) dari kandidat
    /// pada posisi crown, bila lebih dekat dari `withinDeg`. Inilah yang
    /// disebut di label "X juga dekat".
    public func closeNeighbour(of crownIndex: Int, withinDeg: Double) -> (object: CelestialObject, distanceDeg: Double)? {
        guard let current = entry(at: crownIndex) else { return nil }
        return entries
            .filter { $0.object.id != current.object.id }
            .map { ($0.object, Self.distanceDeg(current.object, $0.object)) }
            .filter { $0.1 <= withinDeg }
            .min { $0.1 < $1.1 }
    }

    static func distanceDeg(_ a: CelestialObject, _ b: CelestialObject) -> Double {
        SkyMath.angularSeparationDeg(EquatorialCoord(raDeg: a.raDeg, decDeg: a.decDeg),
                                     EquatorialCoord(raDeg: b.raDeg, decDeg: b.decDeg))
    }
}

/// Getaran "panas–dingin" (ADR-014, Docs/PRODUCT_V2_IDEA.md §4).
///
/// Seperti penghitung Geiger: makin dekat ke benda, ketukan makin rapat.
/// Pengguna bisa menjaga mata tetap di langit.
public enum HotCold {

    /// Di luar jarak ini tidak ada ketukan: terlalu jauh untuk berarti, dan
    /// ketukan terus-menerus hanya menguras baterai dan mengganggu.
    public static let maxDeg = 60.0

    /// Jeda antar-ketukan (detik), atau `nil` bila tidak berketuk.
    /// 60° → 1,2 dtk; 30° → ~0,7 dtk; 10° → ~0,35 dtk; ≤3° → 0,2 dtk.
    public static func tickInterval(separationDeg: Double) -> TimeInterval? {
        guard separationDeg.isFinite, separationDeg < maxDeg else { return nil }
        let t = max(0, separationDeg - 3) / (maxDeg - 3)
        return 0.2 + t * 1.0
    }

    /// 0 = dingin, 1 = panas. Untuk warna cincin.
    public static func heat(separationDeg: Double) -> Double {
        guard separationDeg.isFinite else { return 0 }
        return min(1, max(0, 1 - separationDeg / maxDeg))
    }
}
