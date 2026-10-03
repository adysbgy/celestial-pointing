import SwiftUI
import CelestialEngine
import PointingKit

/// Layar utama: arahkan jam ke langit, lihat apa yang dikenali engine.
///
/// Seluruh isi layar berasal dari `snapshot.state` dan `snapshot.intent` — tidak
/// ada keadaan yang dikarang di UI. Konsekuensinya penting: kalau engine ragu,
/// layar ikut terlihat ragu, dan kalau sensor mati layar **tidak** menyisakan
/// jawaban lama.
struct PointingView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var link: WatchLinkService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    statusCard
                    // Ditampilkan selama ada objek — termasuk saat keadaannya
                    // sudah tidak punya jawaban lagi. Di situlah
                    // `isDisplayingStaleObject` berbunyi: objek dari pandangan
                    // sebelumnya ditampilkan **dengan peringatan**, bukan
                    // disembunyikan (menyembunyikannya membuat jam berkedip
                    // tiap kali pergelangan bergerak sedikit).
                    if let object = engine.displayedObject {
                        ObjectDetailView(object: object,
                                         level: engine.snapshot.intent?.level,
                                         isStale: engine.isDisplayingStaleObject)
                    }
                    if let note = motion.unavailableReason ?? engine.sensorNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(PointingTone.danger.color)
                            .multilineTextAlignment(.center)
                    }
                    // Peringatan ini harus muncul tepat saat lokasinya BUKAN
                    // hasil pengukuran. Dibandingkan lewat `isFallback`, bukan
                    // lewat string `source` apa adanya: string itu bisa berubah
                    // di `LocationProvider` tanpa ada yang ingat memeriksanya,
                    // dan perbandingan mentah akan **membalik** peringatan ini
                    // diam-diam — memperingatkan justru saat lokasi sungguhan.
                    if engine.location.isFallback {
                        Text("Lokasi: \(engine.location.label)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    linkRow
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Point & Know")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SkyContextView(engine: engine)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        CalibrationView(engine: engine, motion: motion, link: link)
                    } label: {
                        Image(systemName: engine.snapshot.isCalibrated
                              ? "scope"
                              : "exclamationmark.circle")
                            .foregroundStyle(engine.snapshot.isCalibrated
                                             ? PointingTone.success.color
                                             : PointingTone.warning.color)
                    }
                }
            }
        }
    }

    // MARK: - Kartu keadaan

    private var statusCard: some View {
        let state = engine.snapshot.state
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: state.symbolName)
                    .foregroundStyle(state.tone.color)
                Text(state.shortLabel)
                    .font(.system(size: WatchMetrics.statusSize, weight: .semibold))
                    .foregroundStyle(state.tone.color)
            }
            Text(state.guidance)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let rate = engine.snapshot.angularRateDegPerSec {
                Text(String(format: "%.0f°/dtk", rate))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(rate > 8 ? PointingTone.warning.color : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(WatchMetrics.cardPadding)
        .background(state.tone.color.opacity(0.12), in: .rect(cornerRadius: WatchMetrics.cornerRadius))
    }

    // MARK: - Baris tautan iPhone

    private var linkRow: some View {
        HStack(spacing: 4) {
            Image(systemName: link.isReachable ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash")
                .font(.system(size: 10))
            Text(link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau")
                .font(.system(size: 10))
            if link.sendFailureCount > 0 {
                Text("· \(link.sendFailureCount) gagal")
                    .font(.system(size: 10))
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// Detail objek yang dikenali.
///
/// `isStale` ditampilkan sebagai peringatan: objek yang tersisa dari pandangan
/// sebelumnya **tidak** boleh tampak seperti hasil pengukuran sekarang.
struct ObjectDetailView: View {

    let object: CelestialObject
    let level: ConfidenceLevel?
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(object.name)
                    .font(.system(size: WatchMetrics.titleSize, weight: .bold))
                Spacer(minLength: 2)
                // Badge keyakinan hanya untuk jawaban yang berlaku sekarang.
                // Pada objek sisa, menampilkan "Yakin" di sebelahnya akan
                // terbaca sebagai klaim keyakinan atas pengukuran sekarang —
                // persis false confidence yang dilarang PRD.
                if let level, !isStale {
                    Text(level.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(level.tone.color.opacity(0.2),
                                    in: .capsule)
                        .foregroundStyle(level.tone.color)
                }
            }
            Text(kindLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            if isStale {
                Text("Sisa pandangan sebelumnya — bukan hasil sekarang")
                    .font(.system(size: 10))
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WatchMetrics.cardPadding)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: WatchMetrics.cornerRadius))
    }

    private var kindLine: String {
        var parts = [kindLabel]
        parts.append(String(format: "mag %.2f", object.magnitude))
        if object.kind == .star {
            parts.append(String(format: "RA %.1f° Dec %+.1f°", object.raDeg, object.decDeg))
        }
        return parts.joined(separator: " · ")
    }

    private var kindLabel: String {
        switch object.kind {
        case .star: return "Bintang"
        case .moon: return "Bulan"
        case .planet: return "Planet"
        case .deepSky: return "Objek langit dalam"
        case .sun: return "Matahari"
        }
    }
}

/// Layar kepercayaan pengukuran: apa yang engine ketahui tentang ketelitiannya
/// sendiri. Ini yang membuat "aku tidak tahu" bisa dibedakan dari "tidak ada
/// objek di sana".
struct SkyContextView: View {

    @ObservedObject var engine: PointingEngine

    var body: some View {
        List {
            if let context = engine.skyContext {
                row("Langit", context.isDark ? "Gelap" : "Terang")
                row("Matahari", String(format: "%.0f°", context.sunAltitudeDeg))
                if let moonAlt = context.moonAltitudeDeg {
                    row("Bulan", String(format: "%.0f°", moonAlt))
                }
                if let fraction = context.moonIlluminationFraction {
                    row("Fase Bulan", String(format: "%.0f%%", fraction * 100))
                }
            } else {
                Text("Konteks langit belum dihitung.")
            }
            Section("Ketelitian") {
                row("Kalibrasi", engine.snapshot.isCalibrated ? "Sudah" : "Belum")
                if let pointing = engine.pointing {
                    row("Azimut", String(format: "%.1f°", pointing.azimuthDeg))
                    row("Ketinggian", String(format: "%.1f°", pointing.altitudeDeg))
                }
                row("Lokasi", engine.location.label)
                row("Asal lokasi", engine.location.source)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }
}
