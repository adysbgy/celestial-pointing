import XCTest
import CelestialEngine
@testable import PointingKit

/// Daftar target harus memakai magnitudo **nyata**, bukan magnitudo terserah.
///
/// **Kenapa uji ini ada.** `availableTargets` menyusun daftar target yang
/// dipakai kalibrasi dan Experiment 1, lalu mengurutkannya "terang dulu —
/// itu yang paling mudah ditunjuk". Untuk bintang, magnitudo yang dipakai
/// adalah magnitudo katalog (nyata). Untuk benda tata surya, yang dipakai
/// adalah `EphemerisBody.typicalBrightestMagnitude` — sebuah **konstanta
/// teoretis**: magnitudo paling terang yang pernah mungkin, bukan magnitudo
/// malam ini.
///
/// Itu bukan sekadar kurang tepat, melainkan klaim yang salah arahnya.
/// Mars berayun antara -2.9 (oposisi) dan +1.8 (konjungsi); Merkurius antara
/// -1.9 dan +5. Jadi pada malam Mars redup, daftar tetap menaruhnya **di
/// atas** bintang yang benar-benar lebih terang, dan menyajikannya sebagai
/// "paling mudah ditunjuk" — padahal engine akan menolak menguncinya karena
/// `tooFaint`. Pengguna ditunjukkan target yang tidak bisa dikunci, tanpa
/// satu pun teks yang membantahnya. Itu persis kebohongan yang dilarang PRD:
/// uncertainty > false confidence.
///
/// Yang membuat cacat ini tidak terlihat: magnitudo konstanta itu **masuk
/// akal**. Daftarnya tidak pernah tampak rusak — urutannya saja yang salah,
/// dan urutan tidak punya kolom tempat kesalahannya bisa dibaca.
final class PlanetTargetMagnitudeHonestyTests: XCTestCase {

    private let jakarta = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)
    private var epoch: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 15
        c.hour = 22; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func resolver() -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: VisibilityPolicy(),
                         ephemeris: AstronomyKitEphemeris())
    }

    /// Magnitudo **nyata** sebuah benda menurut efemeris, untuk dibandingkan.
    private func actualMagnitude(_ body: EphemerisBody,
                                 at date: Date) -> Double? {
        try? resolver().ephemeris?.apparent(body, at: date, from: jakarta).magnitude
    }

    /// Setiap target benda tata surya harus membawa magnitudo efemerisnya
    /// **sendiri**, bukan konstanta "paling terang yang pernah mungkin".
    ///
    /// Ambang 1.0 magnitudo sengaja longgar: tujuannya bukan menuntut
    /// kecocokan persis dengan satu sampel efemeris (implementasi bebas
    /// menentukan caranya), melainkan menuntut bahwa nilainya **berasal dari
    /// malam ini**. Konstanta teoretis untuk Mars (-2.9) dan Merkurius (-1.9)
    /// menyimpang jauh lebih dari 1.0 pada sebagian besar malam.
    func testSolarSystemTargetsCarryTheirRealMagnitude() {
        let date = epoch
        let targets = resolver().availableTargets(observer: jakarta,
                                                  date: date,
                                                  aboveHorizonOnly: true)
        let solarBodies = Set(EphemerisBody.pointableBodies.map(\.rawValue))
        let moving = targets.filter { solarBodies.contains($0.id) }

        XCTAssertFalse(moving.isEmpty,
                       "harus ada benda tata surya di atas horizon untuk diuji")

        for target in moving {
            guard let body = EphemerisBody(rawValue: target.id),
                  let actual = actualMagnitude(body, at: date) else { continue }
            XCTAssertEqual(target.magnitude, actual, accuracy: 1.0,
                           "target \(target.id) memakai magnitudo \(target.magnitude), "
                           + "padahal efemeris malam ini menghitung \(actual)")
            // Bukti bahwa nilainya bukan lagi konstanta teoretis.
            XCTAssertNotEqual(target.magnitude,
                              body.typicalBrightestMagnitude, accuracy: 0.001,
                              "target \(target.id) masih memakai magnitudo terserah "
                              + "\(body.typicalBrightestMagnitude)")
        }
    }

    /// Bukti bahwa perbaikan ini mengubah sesuatu yang nyata: untuk
    /// setidaknya satu benda tata surya, magnitudo efemerisnya **berbeda**
    /// dari konstanta teoretisnya.
    ///
    /// Tanpa uji ini, `testSolarSystemTargetsCarryTheirRealMagnitude` bisa
    /// hijau karena kebetulan: kalau semua planet malam ini sedang berada
    /// persis di magnitudo terbaiknya, memakai konstanta pun lulus — dan
    /// cacatnya kembali tanpa ada yang memerah. Uji ini mengunci bahwa
    /// selisihnya memang ada.
    func testSomeBodyDeviatesFromItsTypicalMagnitude() {
        var deviations = 0
        for day in stride(from: 0.0, through: 400.0, by: 20.0) {
            let date = epoch.addingTimeInterval(day * 86400)
            for body in EphemerisBody.pointableBodies where body != .moon {
                guard let actual = actualMagnitude(body, at: date) else { continue }
                if abs(actual - body.typicalBrightestMagnitude) > 1.0 {
                    deviations += 1
                }
            }
        }
        XCTAssertGreaterThan(deviations, 0,
                             "pasti ada malam di mana magnitudo nyata planet "
                             + "menyimpang dari magnitudo terserahnya")
    }
}
