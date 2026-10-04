import SwiftUI
import CelestialEngine
import PointingKit

/// Alur kalibrasi di jam.
///
/// Prinsip yang dipegang layar ini: kalibrasi tidak boleh "kelihatan selesai"
/// sebelum sebarannya benar-benar terukur. Karena itu tombol pakai tetap mati
/// selama `CalibrationSession` belum menyatakan siap — memasang kalibrasi
/// setengah matang lebih berbahaya daripada tidak mengkalibrasi, karena
/// offsetnya bisa membalik jawaban engine tanpa terlihat.
struct CalibrationView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var link: WatchLinkService

    @State private var session: CalibrationSession?
    @State private var statusMessage = "Tunjuk bintang acuan, lalu tekan Catat."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                phaseCard
                referenceList
                actions
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nightAwareSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle("Kalibrasi")
        .onAppear { ensureSession() }
        // Daftar acuan bergantung pada lokasi: lokasi sungguhan tiba beberapa
        // detik setelah layar ini dibuka, dan bintang yang tampak "di atas
        // horizon" di tempat lama bisa sudah terbenam di tempat sebenarnya.
        // Daftar yang salah tempat tampak sama normalnya dengan yang benar,
        // jadi perhitungan ulang dipaksa setiap lokasi berubah.
        .onChange(of: engine.location) { _, _ in
            session?.refreshReferenceTargets()
        }
    }

    // MARK: - Kartu tahap

    private var phaseCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: phaseSymbol)
                    .foregroundStyle(phaseTone.color)
                Text(phaseLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(phaseTone.color)
            }
            if let flow = session?.flow {
            Text("\(flow.samples.count) acuan tercatat")
                .font(.system(size: 11))
                .foregroundStyle(Color.nightAwareSecondary)
            if let calibration = flow.calibration {
                Text(String(format: "Offset %.1f°", calibration.yawOffsetDeg))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.nightAwareSecondary)
                    if let spread = calibration.residualSpreadDeg {
                        Text(String(format: "Sebaran %.1f° (maks %.1f°)",
                                    spread, session?.flow.maxResidualSpreadDeg ?? 3))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(spread <= (session?.flow.maxResidualSpreadDeg ?? 3)
                                             ? PointingTone.success.color
                                             : PointingTone.warning.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WatchMetrics.cardPadding)
        .background(phaseTone.color.opacity(0.12), in: .rect(cornerRadius: WatchMetrics.cornerRadius))
    }

    // MARK: - Daftar acuan

    private var referenceList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Acuan di atas horizon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.nightAwareSecondary)

            if let targets = session?.referenceTargets, !targets.isEmpty {
                ForEach(targets) { target in
                    Button {
                        capture(target)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PointingTone.active.color)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(target.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(String(format: "%.0f° tinggi", target.direction.altitudeDeg))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.nightAwareSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Tidak ada acuan yang terlihat sekarang. Acuan bawaan adalah bintang terang; tunggu sampai salah satunya terbit.")
                    .font(.system(size: 11))
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
    }

    // MARK: - Tombol

    private var actions: some View {
        VStack(spacing: 4) {
            Button {
                captureNearest()
            } label: {
                Label("Catat yang ditunjuk", systemImage: "dot.scope")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 4) {
                Button("Pakai") { apply() }
                    .font(.system(size: 12))
                    .disabled(!(session?.flow.isReady ?? false))
                Button("Ulang") { reset() }
                    .font(.system(size: 12))
                    .disabled((session?.flow.samples.isEmpty ?? true))
            }

            if let policy = session?.suggestedConfidencePolicy {
                Text(String(format: "Ambang keyakinan usulan: σ %.1f°", policy.pointingSigmaDeg))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nightAwareSecondary)
            }
        }
    }

    // MARK: - Aksi

    private func ensureSession() {
        if session == nil {
            session = CalibrationSession(controller: engine.controller)
        }
        session?.refreshReferenceTargets()
        if let calibration = engine.controller.calibration as PointingCalibration?,
           calibration.sampleCount > 0, session?.flow.samples.isEmpty == true {
            statusMessage = "Kalibrasi sudah terpasang: offset "
                + String(format: "%.1f°", calibration.yawOffsetDeg) + "."
        }
    }

    private func capture(_ target: PointingTarget) {
        guard let session else { return }
        let step = session.capture(objectID: target.id)
        statusMessage = step.message
        // Tidak ada yang dipasang ke controller di sini: mencatat acuan hanya
        // menambah sampel ke alur, bukan mengubah kalibrasi yang berlaku.
        // (Dulu baris ini memanggil `engine.apply(calibration:)` dengan
        // kalibrasi yang sedang berlaku — yang hanya mereset perata orientasi
        // dan menghentikan alur tanpa mengubah apa pun.)
    }

    private func captureNearest() {
        guard let session else { return }
        let step = session.captureNearest()
        statusMessage = step.message
    }

    private func apply() {
        guard let session else { return }
        guard let calibration = session.applyIfReady() else {
            statusMessage = "Belum siap dipakai: sebarannya masih terlalu lebar."
            return
        }
        engine.apply(calibration: calibration)
        // Kirim hasil kalibrasi ke iPhone: sigma ini yang menyetel ambang
        // keyakinan di sisi sana.
        link.send(calibration: calibration)
        statusMessage = String(format: "Terpasang. Offset %.1f°, sebaran %.1f°.",
                               calibration.yawOffsetDeg,
                               calibration.residualSpreadDeg ?? .nan)
    }

    private func reset() {
        session?.reset()
        // `CalibrationSession` menyentuh controller, bukan engine. Kalau
        // cuplikan engine tidak disegarkan di sini, layar jam tetap membaca
        // `isCalibrated == true` dari cuplikan lama: ikon "scope" dan baris
        // "Kalibrasi: Sudah" terus mengklaim kalibrasi terpasang padahal
        // offsetnya sudah dibuang. Pengguna lalu mempercayai arah tunjuk yang
        // sebenarnya belum terkalibrasi — persis klaim tanpa dasar yang
        // dilarang PRD. `apply()` sudah menyegarkan lewat engine; `reset()`
        // harus lewat jalur yang sama, bukan diam-diam melewatinya.
        engine.apply(calibration: .none)
        statusMessage = "Kalibrasi dihapus. Mulai dari awal."
    }

    // MARK: - Tampilan tahap

    private var phaseLabel: String {
        switch session?.flow.phase ?? .idle {
        case .idle: return "Belum ada acuan"
        case .collecting: return "Mengumpulkan"
        case .ready: return "Siap dipakai"
        case .applied: return "Sudah dipakai"
        }
    }

    private var phaseSymbol: String {
        switch session?.flow.phase ?? .idle {
        case .idle: return "circle.dashed"
        case .collecting: return "ellipsis.circle"
        case .ready: return "checkmark.seal"
        case .applied: return "checkmark.seal.fill"
        }
    }

    private var phaseTone: PointingTone {
        switch session?.flow.phase ?? .idle {
        case .idle: return .neutral
        case .collecting: return .active
        case .ready, .applied: return .success
        }
    }
}
