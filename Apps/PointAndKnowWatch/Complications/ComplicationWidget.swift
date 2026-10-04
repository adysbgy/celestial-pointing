import SwiftUI
import WidgetKit

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

/// Entri timeline — cuma membungkus snapshot yang dibaca dari store.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: ComplicationSnapshot?
}

/// Penyedia timeline: baca snapshot terakhir dari store bersama.
struct ComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), snapshot: ComplicationStore.shared.read())
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date(), snapshot: ComplicationStore.shared.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = ComplicationEntry(date: Date(), snapshot: ComplicationStore.shared.read())
        // Satu entrik yang berlaku terus sampai app meminta reload. Kita tidak
        // bisa memprediksi kapan objek berikutnya terkunci, jadi tidak ada
        // entri masa depan — app yang memicu `reloadAllTimelines()`.
        completion(Timeline(entries: [entry], policy: .never))
    }
}

/// Tampilan complication, per keluarga.
struct ComplicationView: View {
    let entry: ComplicationEntry

    var body: some View {
        // `accessoryWidgetGroup` menangani mask keluarga; di dalamnya kita
        // beralih berdasarkan keluarga yang aktif. Baik ada jawaban maupun
        // tidak, kita pakai `content(for:)` yang membaca snapshot — bedanya
        // hanya string yang diambil (`headline` vs nama objek).
        if let snap = entry.snapshot {
            content(for: snap)
        } else {
            fallback
        }
    }

    /// Konten per keluarga. `widgetFamily` dari environment menentukan bentuk.
    @ViewBuilder
    private func content(for snap: ComplicationSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            // Teks pendek di sebelah waktu.
            Text(snap.headline)
        case .accessoryCircular:
            // Lingkaran: simbol keadaan + nama objek (jika ada).
            Gauge(value: 1) {
                Image(systemName: symbol(for: snap))
            } currentValueLabel: {
                Text(snap.objectName ?? snap.shortLabelFallback)
                    .font(.system(size: 11, weight: .semibold))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            // Persegi panjang: simbol + nama + jenis.
            HStack(spacing: 4) {
                Image(systemName: symbol(for: snap))
                    .font(.headline)
                VStack(alignment: .leading, spacing: 0) {
                    Text(snap.objectName ?? snap.shortLabelFallback)
                        .font(.headline)
                    if let kind = snap.objectKindDisplay {
                        Text(kind)
                            .font(.caption2)
                    }
                }
            }
            .widgetCurvesContent()
        @unknown default:
            Text(snap.headline)
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
    private func symbol(for snap: ComplicationSnapshot) -> String {
        PointingState(rawValue: snap.stateRaw)?.symbolName ?? "scope"
    }

    @Environment(\.widgetFamily) private var family
}

private extension ComplicationSnapshot {
    /// Label keadaan bila tidak ada objek (fallback nama).
    var shortLabelFallback: String {
        PointingState(rawValue: stateRaw)?.shortLabel ?? "Point & Know"
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, snapshot: ComplicationSnapshot(
        stateRaw: "lock", objectName: "Sirius",
        objectKindDisplay: "Bintang", confirmed: true, updatedAt: .now))
}

#Preview(as: .accessoryRectangular) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, snapshot: ComplicationSnapshot(
        stateRaw: "lock", objectName: "Jupiter",
        objectKindDisplay: "Planet", confirmed: true, updatedAt: .now))
}

#Preview(as: .accessoryInline) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, snapshot: ComplicationSnapshot(
        stateRaw: "searching", objectName: nil,
        objectKindDisplay: nil, confirmed: false, updatedAt: .now))
}
