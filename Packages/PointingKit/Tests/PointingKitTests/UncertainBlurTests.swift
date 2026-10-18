import XCTest
@testable import PointingKit

/// Gerbang: **keraguan oleh bentuk**, bukan hanya oleh lencana.
///
/// `CelestialVisualView` sudah menahan ciri pengenal saat engine ragu
/// (`drawable(isConfirmed:)`, Aturan 50/51). Yang tersisa setelah ciri itu
/// hilang adalah bingkai kosong yang **masih berbentuk benda langit pasti**:
/// cakram penuh, kabut bermorfologi netral. Lencana tanda tanya duduk di
/// sudut, dan mata membaca bentuk lebih dulu daripada lencana.
///
/// Siklus ini menambahkan samaran (blur) pada gambar saat engine belum pasti.
/// Uji di bawah menahan **keputusan siapa yang disamarkan** — satu-satunya
/// bagian dari jalur itu yang bisa dieksekusi di Linux, karena `rasterize` dan
/// filter blur sendiri hidup di `Apps/`.
final class UncertainBlurTests: XCTestCase {

    /// Jenis yang **hanya** dibedakan oleh cirinya adalah jenis yang boleh
    /// disamarkan. Bukan daftar tangan: himpunannya dibaca dari model.
    func testOnlyFeatureBearingKindsAreBlurred() {
        XCTAssertTrue(UncertainBlur.allows(.planet),
                      "planet ragu tanpa samaran tetap tampil sebagai planet pasti")
        XCTAssertTrue(UncertainBlur.allows(.deepSky),
                      "langit-dalam ragu tanpa samaran tetap tampil sebagai kabut tajam")
    }

    /// **Kontrol negatif yang paling penting.** Sabit Bulan adalah fakta
    /// tanggal, bukan identitas: `check_moon_phase_survives_uncertainty`
    /// menuntut sabit ragu identik piksel dengan sabit yakin. Memblur piringan
    /// Bulan memerahkan gerbang itu, jadi Bulan wajib tetap tajam.
    func testTheMoonPhaseIsNotBlurred() {
        XCTAssertFalse(UncertainBlur.allows(.moon),
                       "fase Bulan bertahan saat ragu (check_moon_phase_survives_uncertainty); memblurnya menghapus fakta yang sah")
    }

    /// Bintang dan Matahari sudah disamarkan warna, dan pada 38 pt blur hanya
    /// menghapusnya. Ini juga mengunci bahwa `rasterize` tidak masuk ke jalur
    /// gambar yang tidak membutuhkannya.
    func testStarsAndSunStaySharp() {
        XCTAssertFalse(UncertainBlur.allows(.star))
        XCTAssertFalse(UncertainBlur.allows(.sun))
    }

    /// Setiap kasus `CelestialVisual.Kind` wajib **diputuskan**, salah satu
    /// arah. Tanpa ini, kasus baru jatuh ke "tidak disamarkan" secara diam-
    /// diam — keputusan yang tidak pernah diambil, dan tidak ada yang tahu
    /// apakah itu disengaja.
    func testEveryVisualKindIsDecided() {
        let kinds: [CelestialVisual.Kind] = [.planet, .moon, .star, .sun, .deepSky]
        // Non-vakuositas: sapuan yang tidak menemukan kasus apa pun lulus
        // semua pengecekan di bawah tanpa memeriksa satu keputusan.
        XCTAssertFalse(kinds.isEmpty)
        for kind in kinds {
            let decided = UncertainBlur.eligible.contains(kind)
                || UncertainBlur.deliberatelySharp.contains(kind)
            XCTAssertTrue(decided,
                          "\(kind) tidak diputuskan: apakah gambarnya disamarkan saat engine ragu?")
        }
        // Dan keputusannya tidak boleh dua-duanya sekaligus — itu berarti
        // himpunannya saling bertentangan dan `allows` hanya menjawab satu.
        XCTAssertTrue(UncertainBlur.eligible.isDisjoint(with: UncertainBlur.deliberatelySharp),
                      "\(UncertainBlur.eligible.intersection(UncertainBlur.deliberatelySharp)) diputuskan dua arah sekaligus")
    }

    /// Himpunan keputusannya persis sama dengan lima kasus yang ada — daftar
    /// yang menyebut kasus yang tidak ada akan terus "hijau" untuk kasus yang
    /// sudah dihapus, kelas yang sama dengan `ObservedState.roles`.
    func testDecisionsMentionOnlyRealKinds() {
        let real: Set<String> = ["planet", "moon", "star", "sun", "deepSky"]
        let decided = Set(UncertainBlur.eligible.map(\.rawValue))
            .union(UncertainBlur.deliberatelySharp.map(\.rawValue))
        XCTAssertEqual(decided, real,
                       "keputusan samaran menyebut kasus yang tidak ada: \(decided.subtracting(real)) "
                       + "/ tidak memutuskan kasus nyata: \(real.subtracting(decided))")
    }
}
