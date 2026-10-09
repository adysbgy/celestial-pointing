import Foundation
import CelestialEngine

/// Baris mentah untuk layar pengembang "Kenapa belum yakin?" (ADR-011).
///
/// Sengaja teknis dan tidak diterjemahkan: layar ini untuk difoto dari jam
/// sungguhan saat log perangkat tidak terjangkau, lalu dibaca pengembang.
public enum WhyNotSureReport {

    public struct Row: Equatable, Identifiable, Sendable {
        public let id: String
        public let value: String
    }

    public static func rows(snapshot: PointingSnapshot,
                            frame: AttitudeReferenceFrame,
                            locationIsFallback: Bool,
                            sunAltitudeDeg: Double?,
                            visibleCount: Int,
                            nearest: GuideHint?) -> [Row] {
        func n(_ v: Double) -> String { NumberFormat.decimal(v, fractionDigits: 0) }
        let p = snapshot.calibratedPointing
        return [
            Row(id: "state", value: snapshot.state.rawValue),
            Row(id: "hint", value: snapshot.searchHint?.rawValue ?? "–"),
            Row(id: "frame", value: frame.rawValue),
            Row(id: "heading", value: frame.hasAbsoluteHeading ? "north" : "arbitrary"),
            Row(id: "calibrated", value: snapshot.isCalibrated ? "yes" : "no"),
            Row(id: "aim", value: snapshot.aim.rawValue),
            Row(id: "location", value: locationIsFallback ? "fallback" : "device"),
            Row(id: "sun alt", value: sunAltitudeDeg.map { n($0) + "°" } ?? "–"),
            Row(id: "visible", value: String(visibleCount)),
            Row(id: "pointing", value: p.map { "alt " + n($0.altitudeDeg) + "° az " + n($0.azimuthDeg) + "°" } ?? "–"),
            Row(id: "rate", value: snapshot.angularRateDegPerSec.map { n($0) + "°/s" } ?? "–"),
            Row(id: "nearest", value: nearest.map { $0.name + " " + n($0.separationDeg) + "°" } ?? "–"),
        ]
    }
}
