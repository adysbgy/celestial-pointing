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
        // persegi panjang (modular), inline (teks pendek), dan **sudut**.
        //
        // **Kenapa `.accessoryCorner` ikut, padahal ia sempat tidak didesain.**
        // Sampai siklus ini keluarga ini sengaja dibiarkan jatuh ke `default`
        // — yang menampilkan satu baris teks datar tanpa label melengkung dan
        // **tanpa ikon**. Akibatnya persis kelas cacat yang sudah berulang di
        // repo ini: nama kandidat `.uncertain` terbaca sama dengan nama yang
        // sudah terkunci, karena di sudut tidak ada baris kedua dan ikon
        // adalah satu-satunya penanda yang tersedia. Yang membuatnya bertahan
        // adalah bahwa `default` **tampak** wajar — ia tidak crash, ia hanya
        // diam-diam kehilangan satu kanal.
        //
        // Sudut adalah slot complication paling menonjol di wajah jam, jadi
        // membiarkannya tanpa desain berarti permukaan yang paling sering
        // dilihat justru yang paling tidak jujur.
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
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
            // Teks pendek di sebelah waktu. Slot satu baris, jadi **tidak ada
            // ruang untuk kata tambahan** — penanda ragu karena itu masuk
            // lewat **ikon**, persis seperti keluarga lain.
            //
            // Dulu cabang ini mengembalikan `Text(digest.headline)` saja, dan
            // itu membuat satu-satunya keluarga yang tidak punya baris kedua
            // juga jadi satu-satunya yang tidak punya penanda: nama kandidat
            // `.uncertain` tampil persis seperti nama yang sudah terkunci.
            // Ikonnya diambil dari `presentedSymbolName(at:)` yang **sama**
            // dengan keluarga lain — bukan daftar ikon kedua — supaya ragu
            // (`questionmark.circle`) dan basi (`clock.badge.exclamationmark`)
            // ikut terbaca di sini tanpa aturan terpisah.
            //
            // `accessoryInline` memang menerima gambar: bentuknya "satu baris
            // teks dan gambar opsional", dan gambar disisipkan lewat
            // interpolasi `Image` di dalam `Text` (didukung watchOS 9+, sama
            // dengan ambang deployment target di `project.yml`).
            AnyView(Text("\(Image(systemName: digest.presentedSymbolName(at: Date()))) \(digest.headline)"))
        case .accessoryCircular:
            // Lingkaran: simbol keadaan + nama objek (jika ada).
            //
            // Ikon **ikut keadaan** (`presentedSymbolName`), bukan ikon tetap:
            // di pergelangan tangan inilah satu-satunya penanda yang tersedia,
            // dan tanpa itu nama kandidat `.uncertain` terbaca persis seperti
            // nama yang sudah terkunci. Lihat `carriesUncertaintyMarker`.
            //
            // Dan ikon **ikut umur** — pakai versi `at:`. Keluarga ini tidak
            // punya baris kedua, jadi `.staleMarker` tidak pernah dirender di
            // sini; tanpa bentuk yang memperhitungkan waktu, cuplikan yang
            // sudah 90 menit tetap tampil sebagai centang hijau + nama,
            // persis seperti lock yang baru saja terjadi. Lihat
            // `presentedSymbolName(at:)`.
            AnyView(Gauge(value: 1) {
                Image(systemName: digest.presentedSymbolName(at: Date()))
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
                // Versi `at:`, sama seperti lingkaran. Baris kedua di sini
                // memang sudah bisa menampilkan `.staleMarker`, tapi ikon tetap
                // kanal utama yang dibaca lebih dulu — centang hijau di sebelah
                // "hasil jam lalu" masih terbaca sebagai keberhasilan.
                // Satu aksesor untuk kedua keluarga yang punya ikon, supaya
                // tidak ada daftar ikon kedua yang bisa berbeda pendapat.
                Image(systemName: digest.presentedSymbolName(at: Date()))
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
        case .accessoryCorner:
            // Sudut: label melengkung mengelilingi kurva sudut + satu baris
            // isi. Ikon keadaan **ikut** — di sudut tidak ada baris kedua,
            // jadi ikon satu-satunya kanal penanda keraguan (Aturan 23).
            //
            // Versi `at:` dipakai, sama seperti lingkaran dan persegi panjang:
            // cuplikan yang sudah tua harus berubah ikonnya, bukan tetap
            // menampilkan centang hijau. Tanpa itu nama objek dari jam lalu
            // tampil di sudut wajah seolah hasil pengukuran sekarang.
            //
            // `widgetLabel` diisi label **keadaan**, bukan nama objek: teks
            // melengkung di sudut ruangnya paling sempit, dan nama objek yang
            // panjang akan terpotong di tengah. Yang paling penting dibaca
            // sekilas (nama + ikon) tetap di tengah; label melengkung hanya
            // memberi konteks keadaannya.
            AnyView(Gauge(value: 1) {
                Image(systemName: digest.presentedSymbolName(at: Date()))
            } currentValueLabel: {
                Text(digest.headline)
                    .font(.caption2.weight(.semibold))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetLabel {
                Text(digest.stateLabel)
            })
        default:
            // Keluarga lain (container, dsb.) belum didesain; menampilkan
            // baris utama apa adanya lebih baik daripada widget kosong.
            //
            // Ikonnya tetap disertakan karena alasan yang sama dengan inline:
            // keluarga yang tidak punya baris kedua tidak punya kanal lain
            // untuk penanda ragu, dan nama kandidat tanpa penanda terbaca
            // sebagai identitas yang pasti.
            AnyView(Text("\(Image(systemName: digest.presentedSymbolName(at: Date()))) \(digest.headline)"))
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
        // `Date()` bukan pilihan gaya: satu-satunya cara complication tahu
        // bahwa cuplikan terakhirnya sudah tua. Complication tidak menerima
        // cuplikan baru kecuali ada perubahan, jadi tanpa memeriksa
        // umur, nama objek membeku di pergelangan dan tetap tampil
        // seolah hasil pengukuran yang sedang berjalan.
        switch digest.sublineContent(at: Date()) {
        case .uncertaintyMarker:
            return TextLocalization.text(.confidenceUncertainMarker)
        case .staleMarker:
            return TextLocalization.text(.complicationStaleMarker)
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

#Preview(as: .accessoryCorner) {
    PointAndKnowComplication()
} timeline: {
    ComplicationEntry(date: .now, digest: ComplicationDigest(
        stateRaw: "lock", objectName: "Saturnus",
        objectKindRaw: "planet", isConfirmed: true, updatedAt: .now))
}