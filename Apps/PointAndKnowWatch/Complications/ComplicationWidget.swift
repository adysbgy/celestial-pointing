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
/// kita cukup beri satu entri; app memicu reload lewat
/// `PointingEngine.complicationReload` (lihat `recordComplicationIfChanged`).
/// Panggilan itu **wajib**: menulis berkas snapshot tidak membuat watchOS
/// menggambar ulang apa pun, jadi tanpa reload complication membaca sekali lalu
/// membeku di objek pertama selamanya.
@main
struct PointAndKnowComplication: Widget {

    private let kind = "PointAndKnowComplication"

    var body: some WidgetConfiguration {
        // `StaticConfiguration` butuh label argumen `provider:` — closure
        // timeline tanpa label dibaca sebagai trailing closure, yang tidak
        // ada di initializer ini.
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
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

    /// Dipasang sekali, sebelum entri timeline apa pun diminta.
    ///
    /// **Kenapa bridge dipasang di sini, padahal tidak ada di
    /// `LocalizationBridge.swift` milik app.** Complication adalah target
    /// terpisah yang tidak menarik berkas app mana pun, dan ia berjalan di
    /// proses sendiri. `ComplicationDigest.headline` membaca
    /// `PointingState.shortLabel`, dan baris kedua membaca
    /// `objectKind.displayName` — keduanya teks yang **dihasilkan di
    /// PointingKit** lewat `TextLocalization`, jadi tanpa bridge semuanya
    /// jatuh ke nilai bawaan Bahasa Indonesia.
    ///
    /// Dulu katalog pun tidak ikut ke bundel ini (lihat `project.yml`), jadi
    /// kedua sisi sama-sama tidak ada: tanpa katalog, `Bundle` tidak punya
    /// apa-apa untuk dibaca. Sekarang katalog ikut (lihat `project.yml`),
    /// dan bridge di sini yang membacanya.
    ///
    /// Dipasang di `init()` provider — satu titik yang dijamin berjalan
    /// sebelum `body` dirender, dan tidak bergantung pada lifecycle app.
    init() {
        ComplicationLocalization.install()
    }

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
///
/// **Kenapa `AnyView`.** `WidgetFamily` punya banyak kasus (termasuk yang akan
/// datang), dan tiap kasus menghasilkan tipe `some View` berbeda —
/// `Text` untuk inline, `Gauge` untuk circular, `HStack` untuk rectangular.
/// Tanpa pembungkus tunggal, `switch` gagal dengan "branches have mismatching
/// types". `AnyView` di sini mengubah pertanyaan tipe menjadi pertanyaan
/// `@ViewBuilder` — dan biayanya sepele untuk tiga tampilan sekecil ini.
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
    private func content(for digest: ComplicationDigest) -> AnyView {
        switch family {
        case .accessoryInline:
            // Teks pendek di sebelah waktu. Slot satu baris, jadi tidak ada
            // ruang untuk kata tambahan — penanda ragu masuk lewat ikon di
            // keluarga lain.
            AnyView(Text(digest.headline))
        case .accessoryCircular:
            // Lingkaran: simbol keadaan + nama objek (jika ada).
            //
            // Ikon **ikut keadaan** (`presentedSymbolName`), bukan ikon tetap:
            // di pergelangan tangan inilah satu-satunya penanda yang tersedia,
            // dan tanpa itu nama kandidat `.uncertain` terbaca persis seperti
            // nama yang sudah terkunci. Lihat `carriesUncertaintyMarker`.
            AnyView(Gauge(value: 1) {
                Image(systemName: digest.presentedSymbolName)
            } currentValueLabel: {
                Text(digest.headline)
                    // Semantik, bukan `.system(size: 11)`. Lingkaran
                    // complication adalah ruang terkecil di seluruh app —
                    // justru di situ teks paling perlu bisa membesar mengikuti
                    // Dynamic Type, dan ukuran tetap mengabaikannya sama
                    // sekali. `.caption2` + semibold mempertahankan beratnya
                    // sambil menyerahkan ukurannya ke sistem.
                    .font(.caption2.weight(.semibold))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular))
        case .accessoryRectangular:
            // Persegi panjang: simbol + nama + jenis.
            AnyView(HStack(spacing: 4) {
                Image(systemName: digest.presentedSymbolName)
                    .font(.headline)
                VStack(alignment: .leading, spacing: 0) {
                    Text(digest.headline)
                        .font(.headline)
                    // Baris kedua sudah punya ruang, jadi penanda ragu tampil
                    // sebagai **kata**, bukan hanya ikon. Ini yang membuat
                    // keadaan ragu terbaca tanpa perlu mengermat ke ikon —
                    // persis seperti badge di app jam dan iPhone.
                    if let subline = subline(for: digest) {
                        Text(subline)
                            .font(.caption2)
                    }
                }
            }
            .widgetCurvesContent())
        default:
            // Keluarga lain (corner, container, dll.) belum didesain; menampilkan
            // baris utama apa adanya lebih baik daripada widget kosong.
            AnyView(Text(digest.headline))
        }
    }

    /// Baris kedua untuk keluarga persegi panjang.
    ///
    /// **Prioritasnya diputuskan di model, bukan di sini.** `sublineContent`
    /// sudah menimbang penanda ragu di atas jenis benda, dan itu teruji di
    /// Linux. View ini hanya menerjemahkan keputusannya menjadi teks, lewat
    /// `TextLocalization` supaya kata yang tampil berasal dari katalog.
    ///
    /// Kalau urutan ini ditulis ulang sebagai dua `if` terpisah di sini, ia
    /// tidak akan bisa diuji — WidgetKit tidak ada di Linux — dan tepat di
    /// keadaan ragu baris kedua akan kembali menampilkan jenis benda.
    private func subline(for digest: ComplicationDigest) -> String? {
        switch digest.sublineContent {
        case .uncertaintyMarker:
            return TextLocalization.text(.confidenceUncertainMarker)
        case .objectKind:
            return digest.objectKind?.displayName
        case .none:
            return nil
        }
    }

    /// Tampilan saat belum ada data sama sekali.
    private var fallback: AnyView {
        switch family {
        case .accessoryInline:
            AnyView(Text("Point & Know"))
        case .accessoryCircular:
            AnyView(Image(systemName: "scope").font(.headline))
        case .accessoryRectangular:
            AnyView(Label("Point & Know", systemImage: "scope"))
        default:
            AnyView(Text("Point & Know"))
        }
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