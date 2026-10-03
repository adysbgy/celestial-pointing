import Foundation

/// Model keyakinan. Prinsip PRD: uncertainty > false confidence.
public enum ConfidenceModel {

    /// Evaluasi kandidat -> CelestialIntent.
    /// - coneDeg: setengah sudut kerucut pointing (derajat).
    public static func evaluate(candidates: [Candidate], coneDeg: Double) -> CelestialIntent {
        guard let best = candidates.first else {
            return CelestialIntent(level: .low, best: nil, candidates: [])
        }
        let second = candidates.count > 1 ? candidates[1] : nil
        let tight = coneDeg * 0.4

        if best.separationDeg <= tight {
            if let s = second, (s.separationDeg - best.separationDeg) < 3.0 {
                // Dua kandidat berdekatan -> jangan mengklaim pasti.
                return CelestialIntent(level: .medium, best: best.object,
                                       candidates: Array(candidates.prefix(3)))
            }
            return CelestialIntent(level: .high, best: best.object, candidates: [best])
        }

        if best.separationDeg <= coneDeg {
            return CelestialIntent(level: .medium, best: best.object,
                                   candidates: Array(candidates.prefix(3)))
        }

        return CelestialIntent(level: .low, best: nil, candidates: [])
    }
}
