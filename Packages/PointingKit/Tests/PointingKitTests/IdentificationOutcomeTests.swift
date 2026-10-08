import XCTest
@testable import PointingKit
@testable import CelestialEngine

final class IdentificationOutcomeTests: XCTestCase {

    private let sirius = CelestialObject(id: "sirius", name: "Sirius", kind: .star,
                                         raDeg: 101.29, decDeg: -16.72, magnitude: -1.46)
    private let canopus = CelestialObject(id: "canopus", name: "Canopus", kind: .star,
                                          raDeg: 95.99, decDeg: -52.70, magnitude: -0.74)
    private let procyon = CelestialObject(id: "procyon", name: "Procyon", kind: .star,
                                          raDeg: 114.83, decDeg: 5.22, magnitude: 0.34)
    private let rigel = CelestialObject(id: "rigel", name: "Rigel", kind: .star,
                                        raDeg: 78.63, decDeg: -8.20, magnitude: 0.13)

    private func snapshot(_ state: PointingState, _ level: ConfidenceLevel = .high,
                          best: CelestialObject? = nil, candidates: [CelestialObject] = []) -> PointingSnapshot {
        PointingSnapshot(state: state,
                         intent: CelestialIntent(level: level, best: best,
                                                 candidates: candidates.map { Candidate(object: $0, separationDeg: 1) }))
    }

    func testStatesMapToTheThreeProductOutcomes() {
        XCTAssertEqual(IdentificationOutcome.from(PointingSnapshot(state: .idle)), .holdSteady)
        XCTAssertEqual(IdentificationOutcome.from(PointingSnapshot(state: .pointing)), .holdSteady)
        XCTAssertEqual(IdentificationOutcome.from(PointingSnapshot(state: .unavailable)), .unavailable)
        XCTAssertEqual(IdentificationOutcome.from(PointingSnapshot(state: .searching)), .notSure)
        XCTAssertEqual(IdentificationOutcome.from(snapshot(.lock, best: sirius, candidates: [sirius])),
                       .single(sirius))
        XCTAssertEqual(IdentificationOutcome.from(snapshot(.uncertain, .medium, best: sirius,
                                                           candidates: [sirius, procyon])),
                       .possibleMatches([sirius, procyon]))
    }

    /// Lock tanpa objek tidak boleh berubah menjadi jawaban kosong.
    func testLockWithoutObjectIsNotSure() {
        XCTAssertEqual(IdentificationOutcome.from(snapshot(.lock, best: nil)), .notSure)
    }

    /// Kandidat dibatasi tiga, dan yang terbaik selalu ikut walau tidak ada
    /// di daftar kandidat.
    func testPossibleMatchesCappedAndIncludeBest() {
        let o = IdentificationOutcome.from(snapshot(.uncertain, .medium, best: rigel,
                                                    candidates: [sirius, canopus, procyon]))
        XCTAssertEqual(o, .possibleMatches([rigel, sirius, canopus]))
        XCTAssertEqual(o.confirmable.count, 3)
    }

    func testOnlyAnswersAreConfirmable() {
        XCTAssertTrue(IdentificationOutcome.notSure.confirmable.isEmpty)
        XCTAssertTrue(IdentificationOutcome.holdSteady.confirmable.isEmpty)
        XCTAssertEqual(IdentificationOutcome.single(sirius).confirmable, [sirius])
    }

    func testDefaultPolicyIsProvisionalUntilMeasured() {
        XCTAssertTrue(ConfidencePolicy().isProvisional)
        XCTAssertFalse(ConfidencePolicy.measured(pointingSigmaDeg: 4, ambiguitySigma: 2,
                                                 maxSeparationSigma: 1).isProvisional)
    }
}
