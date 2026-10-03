import XCTest
@testable import CelestialEngine

/// Uji anti-false-lock.
///
/// Ini janji keselamatan utama PRD: engine boleh ragu, tapi TIDAK BOLEH
/// mengklaim pasti saat kandidat ambigu. Kalau uji di file ini merah,
/// fitur tidak boleh dirilis — apa pun kata metrik lain.
final class ConfidenceTests: XCTestCase {

    private func candidate(_ id: String, separationDeg: Double) -> Candidate {
        Candidate(
            object: CelestialObject(id: id, name: id, kind: .star,
                                    raDeg: 0, decDeg: 0, magnitude: 1.0),
            separationDeg: separationDeg
        )
    }

    private let policy = ConfidencePolicy() // sigma 10° -> ambiguitas 20°, HIGH ≤ 10°

    // MARK: - Kasus dasar

    func testNoCandidatesIsLow() {
        let intent = ConfidenceModel.evaluate(candidates: [], coneDeg: 20, policy: policy)
        XCTAssertEqual(intent.level, .low)
        XCTAssertNil(intent.best)
    }

    func testBestOutsideConeIsLow() {
        let intent = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 25)], coneDeg: 20, policy: policy
        )
        XCTAssertEqual(intent.level, .low)
        XCTAssertNil(intent.best)
    }

    func testCloseBestWithNoNeighbourIsHigh() {
        let intent = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 3)],
            coneDeg: 20, nearestNeighbourDeg: nil, policy: policy
        )
        XCTAssertEqual(intent.level, .high)
        XCTAssertEqual(intent.best?.id, "a")
    }

    // MARK: - Aturan anti-false-lock

    /// Kandidat terbaik dekat, TAPI ada kandidat lain dalam radius ambiguitas
    /// -> tidak boleh HIGH.
    func testCloseBestWithNearbyNeighbourIsNotHigh() {
        let intent = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 1), candidate("b", separationDeg: 5)],
            coneDeg: 20, nearestNeighbourDeg: 5.0, policy: policy // 5° < 20° ambiguitas
        )
        XCTAssertEqual(intent.level, .medium)
        XCTAssertEqual(intent.best?.id, "a", "tetap laporkan tebakan terbaik")
        XCTAssertEqual(intent.candidates.count, 2, "kandidat lain harus ikut dilaporkan")
    }

    /// Kandidat terbaik dekat dan tetangganya jauh -> boleh HIGH.
    func testCloseBestWithFarNeighbourIsHigh() {
        let intent = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 1), candidate("b", separationDeg: 15)],
            coneDeg: 20, nearestNeighbourDeg: 40.0, policy: policy
        )
        XCTAssertEqual(intent.level, .high)
    }

    /// Ambang ambiguitas bersifat inklusif: tetangga yang persis di ambang
    /// masih dianggap ambigu (arah aman), yang lebih jauh baru boleh HIGH.
    func testAmbiguityThresholdIsInclusive() {
        let atThreshold = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 1)],
            coneDeg: 20, nearestNeighbourDeg: policy.ambiguityDeg, policy: policy
        )
        XCTAssertEqual(atThreshold.level, .medium, "tepat di ambang masih ambigu")

        let beyond = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 1)],
            coneDeg: 20, nearestNeighbourDeg: policy.ambiguityDeg + 0.001, policy: policy
        )
        XCTAssertEqual(beyond.level, .high)
    }

    /// Kandidat terbaik di antara ambang HIGH dan tepi kerucut -> MEDIUM.
    func testBestBetweenHighThresholdAndConeIsMedium() {
        let intent = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: policy.maxSeparationDeg + 1)],
            coneDeg: 20, nearestNeighbourDeg: nil, policy: policy
        )
        XCTAssertEqual(intent.level, .medium)
        XCTAssertEqual(intent.best?.id, "a")
    }

    // MARK: - Sigma

    /// Sigma pointing yang lebih besar harus membuat engine LEBIH pelit
    /// memberi HIGH, bukan lebih royal. Ini yang membuat kalibrasi
    /// Experiment 1 bermakna.
    func testLargerSigmaMakesHighRarer() {
        let strict = ConfidencePolicy(pointingSigmaDeg: 5)
        let loose = ConfidencePolicy(pointingSigmaDeg: 20)

        // Kandidat 7° dari arah tunjuk, tanpa tetangga.
        let candidates = [candidate("a", separationDeg: 7)]
        let coneDeg = 60.0

        XCTAssertEqual(
            ConfidenceModel.evaluate(candidates: candidates, coneDeg: coneDeg,
                                     nearestNeighbourDeg: nil, policy: strict).level,
            .medium, "sigma 5° -> ambang HIGH 5°, kandidat 7° belum boleh HIGH"
        )
        XCTAssertEqual(
            ConfidenceModel.evaluate(candidates: candidates, coneDeg: coneDeg,
                                     nearestNeighbourDeg: nil, policy: loose).level,
            .high, "sigma 20° -> ambang HIGH 20°, kandidat 7° boleh HIGH"
        )
    }

    func testPolicyDerivedThresholds() {
        let policy = ConfidencePolicy(pointingSigmaDeg: 4, ambiguitySigma: 2, maxSeparationSigma: 1.5)
        XCTAssertEqual(policy.maxSeparationDeg, 6)
        XCTAssertEqual(policy.ambiguityDeg, 8)
    }

    // MARK: - Kebetulan pemanggilan

    /// Kandidat yang datang tidak terurut tidak boleh mengubah keputusan.
    func testUnsortedInputDoesNotChangeVerdict() {
        let ordered = ConfidenceModel.evaluate(
            candidates: [candidate("a", separationDeg: 1), candidate("b", separationDeg: 9)],
            coneDeg: 20, nearestNeighbourDeg: 40, policy: policy
        )
        let shuffled = ConfidenceModel.evaluate(
            candidates: [candidate("b", separationDeg: 9), candidate("a", separationDeg: 1)],
            coneDeg: 20, nearestNeighbourDeg: 40, policy: policy
        )
        XCTAssertEqual(ordered.level, shuffled.level)
        XCTAssertEqual(ordered.best?.id, shuffled.best?.id)
    }
}
