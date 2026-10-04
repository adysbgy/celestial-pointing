import SwiftUI
import WidgetKit
import CelestialEngine
import PointingKit

/// Complication watchOS: tampilkan objek terkunci terakhir / keadaan engine
/// tanpa membuka app.
///
/// **Kenapa WidgetKit, bukan ClockKit.** watchOS 11 hanya menerima
/// complication lewat WidgetKit (SwiftUI `Widget`). Complication berjalan di
/// proses **terpisah** dari app jam, jadi ia tidak membaca engine langsung —
/// ia membaca `ComplicationStore.shared.read()` (berkas yang dibagi app).
///
/// **Kenapa timeline statis + reload.** Kita tidak tahu kapan pengguna
/// mengunci, jadi entri tunggal berlaku "selamanya" (sampai app memanggil
/// `WidgetCenter.shared.reloadAllTimelines()` saat snapshot berubah). Di sini
/// kita cukup beri satu entri; app memicu reload lewat `ComplicationStore`
/// (lihat `PointingEngine.recordComplicationIfChanged`).
@main
struct PointAndKnowComplication: Widget {

    private let kind = "PointAndKnowComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind) { entry in
            ComplicationView(entry: entry)
        } timelineProvider: {
            ComplicationProvider()
        }
        .configurationDisplayName("Point & Know")
        .description("Objek terakhir yang dikenali, tanpa membuka app.")
        // Keluarga yang didukung jam tangan: lingkaran (wajah utama),
        // persegi panjang (modular), dan inline (teks pendek).
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

/// Entri timeline — cuma membungkus ringkasan yang dibaca dari store.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let digest: ComplicationDigest?
}

/// Penyedia timeline: baca ringkasan terakhir dari store bersama.
struct ComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), digest: ComplicationStore.shared.read())
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date(), digest: ComplicationStore.shared.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), digest: ComplicationStore.shared.read())
        // Satu entri yang berlaku terus sampai app meminta reload. Kita tidak
        // bisa memprediksi kapan objek berikutnya terkunci, jadi tidak ada
        // entri masa depan — app yang memicu `reloadAllTimelines()`.
        completion(Timeline(entries: [entry], policy: .never))
    }
}

/// Tampilan complication, per keluarga.
struct ComplicationView: View {
    let entry: ComplicationEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let digest = entry.digest {
            content(for: digest)
        } else {
            fallback
        }
    }

    /// Konten per keluarga. `widgetFamily` dari environment menentukan bentuk.
    @ViewBuilder
    private func content(for digest: ComplicationDigest) -> some View {
        switch family {
        case .accessoryInline:
            // Teks pendek di sebelah waktu.
            Text(digest.headline)
        case .accessoryCircular:
            // Lingkaran: simbol keadaan + nama objek (jika ada).
            Gauge(value: 1) {
                Image(systemName: symbol(for: digest))
            } currentValueLabel: {
                Text(digest.headline)
                    .font(.system(size: 11, weight: .semibold))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            // Persegi panjang: simbol + nama + jenis.
            HStack(spacing: 4) {
                Image(systemName: symbol(for: digest))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 0) {
                    Text(digest.headline)
                        .font(.headline)
                    if let kind = digest.objectKind?.displayName {
                        Text(kind)
                            .font(.caption2)
                    }
                }
            }
            .widgetCurvesContent()
        @unknown default:
            Text(digest.headline)
        }
    }

    /// Tampilan saat belum ada data sama sekali.
    private var fallback: some View {
        switch family {
        case .accessoryInline:
            Text("Point & Know")
        case .accessoryCircular:
            Image(systemName: "scope")
                .font(.headline)
        default:
            Label("Point & Know", systemImage: "scope")
        }
    }

    /// Simbol SF sesuai keadaan.
    private func symbol(for digest: ComplicationDigest) -> String {
        digest.state?.symbolName ?? "scope"
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, digest: ComplicationDigest(
        stateRaw: "lock", objectName: "Sirius",
        objectKindRaw: "star", isConfirmed: true, updatedAt: .now))
}

#Preview(as: .accessoryRectangular) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, digest: ComplicationDigest(
        stateRaw: "lock", objectName: "Jupiter",
        objectKindRaw: "planet", isConfirmed: true, updatedAt: .now))
}

#Preview(as: .accessoryInline) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, digest: ComplicationDigest(
        stateRaw: "searching", objectName: nil,
        objectKindRaw: nil, isConfirmed: false, updatedAt: .now))
}