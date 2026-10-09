import SwiftUI
import CelestialEngine
import PointingKit

/// Kalender fenomena di jam (ADR-015): daftar → rincian → "Pandu ke sana".
///
/// Dibuka sebagai sheet dari layar utama. Memilih "Pandu ke sana" memasang
/// fenomena itu di `SkyGuideModel` dan menutup sheet; layar utama lalu
/// memandu dengan cincin + getaran panas–dingin ke sasarannya.
struct PhenomenaView: View {
    @ObservedObject var guide: SkyGuideModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(guide.phenomena) { p in
                NavigationLink {
                    PhenomenonDetailView(phenomenon: p, guide: guide) { dismiss() }
                } label: {
                    PhenomenonRow(phenomenon: p)
                }
            }
            .navigationTitle(PhenomenonText.sectionTitle)
        }
    }
}

struct PhenomenonRow: View {
    let phenomenon: Phenomenon

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: phenomenon.kind.symbol)
                .foregroundStyle(phenomenon.visibleHere ? PointingTone.active.color : Color.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(PhenomenonText.title(phenomenon))
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(PhenomenonText.when(phenomenon.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !phenomenon.visibleHere {
                    Text(PhenomenonText.visibility(phenomenon))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PhenomenonDetailView: View {
    let phenomenon: Phenomenon
    @ObservedObject var guide: SkyGuideModel
    let onGuide: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: phenomenon.kind.symbol)
                    .font(.title)
                    .foregroundStyle(PointingTone.active.color)
                    .accessibilityHidden(true)
                Text(PhenomenonText.title(phenomenon))
                    .font(.headline)
                Text(PhenomenonText.when(phenomenon.date))
                    .font(.footnote)
                if let detail = PhenomenonText.detail(phenomenon) {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                Label(PhenomenonText.visibility(phenomenon),
                      systemImage: phenomenon.visibilitySymbol)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if phenomenon.requiresSolarFilter {
                    Label(PhenomenonText.solarFilter, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(PointingTone.warning.color)
                } else if phenomenon.isGuidable {
                    if guide.direction(of: phenomenon) != nil {
                        Button {
                            guide.pin(phenomenon)
                            onGuide()
                        } label: {
                            Label(PhenomenonText.guideThere, systemImage: "location.north.line.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    } else {
                        Text(PhenomenonText.notUpYet(PhenomenonText.targetName(phenomenon)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
        }
        .fontDesign(.rounded)
    }
}

extension Phenomenon.Kind {
    var symbol: String {
        switch self {
        case .conjunction: return "circle.circle"
        case .lunarEclipse: return "moon.circle"
        case .solarEclipse: return "sun.max.trianglebadge.exclamationmark"
        case .meteorShower: return "sparkles"
        case .fullMoon: return "moon.fill"
        case .elongation: return "sunset"
        }
    }
}
