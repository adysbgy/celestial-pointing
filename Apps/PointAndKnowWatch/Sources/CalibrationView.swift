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
    @State private var statusMessage = CalibrationText.initialStatus

    /// Pesan status terakhir yang **sudah diumumkan** ke VoiceOver.
    ///
    /// Tanpa ini, menekan "Catat" kelihatan berhasil: haptic boleh berbunyi,
    /// teks berubah — tapi pengguna yang tidak melihat layar tidak pernah
    /// diberi tahu apakah acuan tercatat atau ditolak. Itu kelas kesalahan
    /// yang sama dengan "kegagalan diam": yang membuat berbahaya justru
    /// tidak adanya apa pun yang keliru.
    @State private var announcedStatus: String?

    var body: some View {
        NightAwareContainer {
            calibrationContent
        } reduced: {
            // Saat layar redup, alur kalibrasi tidak bisa dijalankan (gestur
            // diabaikan sistem), dan layar ini memang tidak punya apa pun yang
            // harus terbaca sekilas selain nama objek & status. Karena itu
            // tampilan jam yang dipakai — bukan versi khusus kedua.
            ReducedLuminanceView(engine: engine)
        }
    }

    private var calibrationContent: some View {
        // `TimelineView` menyegarkan layar tiap 30 detik — bukan untuk
        // menggambar, tapi supaya daftar acuan dihitung ulang saat sudah
        // basi karena **waktu**. Bintang bergerak ~15°/jam, jadi daftar yang
        // dibiarkan sepuluh menit meleset ~2,5° dan bisa menawarkan bintang
        // yang sudah terbenam; tanpa penyegaran berkala, pengguna mencatat
        // sampel hantu yang membalik offset kalibrasi tanpa terlihat.
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if session?.isReferenceListStale == true {
                        staleBanner
                    }
                    phaseCard
                    referenceList
                    actions
                    Text(statusMessage)
                        // Semantic, bukan `.system(size: 11)`. Angka tetap
                        // mengabaikan Dynamic Type, jadi di layar 42mm teks
                        // 11pt ini tidak bisa membesar sama sekali — dan kalibrasi
                        // justru layar yang paling sering dipakai pengguna yang
                        // perlu glasses di lapangan.
                        .font(.footnote)
                        .foregroundStyle(Color.nightAwareSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(TextLocalization.text(.calibrationStatusPrefix,
                                                                  statusMessage))
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle(TextLocalization.text(.calibrationTitle))
            .onAppear { ensureSession() }
            // Daftar acuan bergantung pada lokasi: lokasi sungguhan tiba beberapa
            // detik setelah layar ini dibuka, dan bintang yang tampak "di atas
            // horizon" di tempat lama bisa sudah terbenam di tempat sebenarnya.
            // Daftar yang salah tempat tampak sama normalnya dengan yang benar,
            // jadi perhitungan ulang dipaksa setiap lokasi berubah.
            .onChange(of: engine.location) { _, _ in
                session?.refreshReferenceTargets()
            }
            // Penyegaran berkala: tiap tik, kalau daftar sudah basi (lokasi
            // berubah *atau* waktunya lewat), hitung ulang sebelum pengguna
            // memilih acuan.
            .onChange(of: timeline.date) { _, _ in
                if session?.isReferenceListStale == true {
                    session?.refreshReferenceTargets()
                }
            }
            // Umumkan **hasil setiap aksi**, bukan hanya perubahan keadaan engine.
            //
            // Layar ini tidak punya `.onChange(of: engine.snapshot.state)` seperti
            // `PointingView`, jadi tanpa baris ini tidak ada satu pun umpan balik
            // yang sampai ke VoiceOver sama sekali. `announcedStatus` menjaga
            // pengumuman tetap pada perubahan: `onChange` sudah tidak memicu saat
            // nilai sama, tapi pesan "Belum siap dipakai" bisa muncul berkali-kali
            // untuk satu masalah yang sama.
            .onChange(of: statusMessage) { _, newMessage in
                guard announcedStatus != newMessage else { return }
                announcedStatus = newMessage
                AccessibilityNotification.Announcement(newMessage).post()
            }
        }
    }

    /// Peringatan bahwa daftar acuan dihitung untuk langit yang sudah lewat.
    ///
    /// Daftar memang disegarkan otomatis tiap 30 detik, tapi saat layar baru
    /// dibuka lokasi sungguhan belum tiba — jadi ada jendela singkat di mana
    /// daftar masih dari tempat/langit lama. Banner ini memberi tahu, bukan
    /// diam, supaya pengguna tahu daftarnya belum boleh dipakai mentah.
    private var staleBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(CalibrationText.staleBanner)
                .font(.caption2)
        }
        .foregroundStyle(PointingTone.warning.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CalibrationText.staleBannerHint)
    }

    // MARK: - Kartu tahap

    private var phaseCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: phaseSymbol)
                    .foregroundStyle(phaseTone.color)
                Text(phaseLabel)
                    .font(.headline)
                    .foregroundStyle(phaseTone.color)
            }
            if let flow = session?.flow {
            // **Jumlah acuan berbeda, bukan jumlah ketukan.** Ini bukan
            // kerapian: kalau kartu menampilkan "3 acuan" sementara tahapnya
            // masih "Mengumpulkan acuan", pengguna menyimpulkan tombolnya
            // rusak — padahal pengukurannya memang tidak bertambah, karena
            // satu arah yang sama diukur berulang.
            Text(TextLocalization.text(.calibrationSamplesRecorded,
                                      Int64(flow.distinctReferenceCount)))
                .font(.caption)
                .foregroundStyle(Color.nightAwareSecondary)
            // Pengulangan tidak pernah disembunyikan. Yang ditampilkan adalah
            // accessor dari alur, bukan hitungan yang dihitung view: ada dua
            // angka yang sama-sama masuk akal di sini (bintang yang diulang vs
            // ketukan yang terbuang) dan view tidak punya cara memilih yang
            // benar. Hitungan di atas ("3 acuan") dan hitungan di sini saling
            // meniadakan: 3 + 1 bukan jumlah ketukan yang benar-benar terjadi.
            if let hint = flow.repetitionHint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(PointingTone.warning.color)
            }
            if let calibration = flow.calibration {
                Text(CalibrationText.offsetDisplay(degrees: calibration.yawOffsetDeg))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.nightAwareSecondary)
                    if let spread = calibration.residualSpreadDeg {
                        let maxSpread = session?.flow.maxResidualSpreadDeg ?? 3
                        Text(CalibrationText.spreadDisplay(spreadDeg: spread,
                                                           maxDeg: maxSpread))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(spread <= maxSpread
                                             ? PointingTone.success.color
                                             : PointingTone.warning.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WatchMetrics.cardPadding)
        // **Permukaan dari token, bukan campuran nada.** Dulu baris ini
        // `.background(phaseTone.color.opacity(0.12))`: warna nada dicampur ke
        // latar di view, dan hasilnya tidak pernah dihitung siapa pun. Di mode
        // malam campuran itu menaikkan latar ke merah ~0.154 sementara teksnya
        // berwarna nada yang sama — `.neutral` (merah 0.94) jatuh ke 4.32:1,
        // di bawah ambang 4.5 yang brief nyatakan. Karena teksnya juga warna
        // nada, tidak ada gerbang yang menyala: katalog benar, `shortLabel`
        // benar, dan yang redup hanya warnanya.
        //
        // `surfaceCard` memakai `surface1` yang sudah diuji kontrasnya terhadap
        // semua nada (`TonePaletteTests`), jadi kartu ini tidak bisa lagi
        // membangun latarnya sendiri. Identitas tahap tetap dibawa ikon dan
        // label di atasnya, yang memakai warna nada teruji — bukan latar.
        .surfaceCard(level: .card, radius: WatchMetrics.cornerRadius)
        // Satu elemen: tahap, jumlah acuan, offset, dan sebaran adalah satu
        // pengumuman. Tanpa penggabungan, VoiceOver membaca empat item
        // terpisah yang harus diusap satu per satu. Teksnya dari
        // `PointingKit` (teruji di Linux), bukan ditulis di sini — kalau
        // kalimatnya salah, ujinya yang merah, bukan layar.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(session?.flow.spokenPhaseSummary
                            ?? TextLocalization.text(.calibrationNotStarted))
    }

    // MARK: - Daftar acuan

    private var referenceList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(TextLocalization.text(.calibrationReferenceHeading))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nightAwareSecondary)

            if let targets = session?.referenceTargets, !targets.isEmpty {
                ForEach(targets) { target in
                    Button {
                        capture(target)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(PointingTone.active.color)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(target.name)
                                    .font(.subheadline.weight(.medium))
                                Text(CalibrationText.captureAltitudeDisplay(
                                                altitudeDeg: target.direction.altitudeDeg))
                                    .font(.caption2)
                                    .foregroundStyle(Color.nightAwareSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.caption)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    // Label tombol, bukan isi tombol mentah.
                    //
                    // `accessibilityHidden` di dua ikon itu wajib: tanpa itu
                    // VoiceOver membacakan "bintang, plus lingkaran, Sirius,
                    // 40 derajat tinggi, plus lingkaran" — ikon dekoratif ikut
                    // diucapkan sebagai kata. Label di sini juga menyebut
                    // **aksinya** ("Catat … sebagai acuan"), karena ada
                    // tombol lain di layar ini yang juga mencatat — tanpa
                    // perbedaan itu keduanya terdengar sama.
                    .accessibilityLabel(target.spokenCaptureLabel)
                }
            } else {
                Text(TextLocalization.text(.calibrationNoVisibleReference))
                    .font(.footnote)
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
                Label(TextLocalization.text(.calibrationCaptureNearestLabel),
                      systemImage: "dot.scope")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            // `.accessibilityLabel`, bukan `.accessibilityHint`: hint hanya
            // dibaca setelah pengguna menahan tombol, jadi aksi ini — yang
            // satu-satunya jalan mencatat tanpa memilih bintang — harus
            // ikut terlihat di nama tombolnya sendiri. Label juga menyebut
            // bahwa ia memakai arah yang sedang ditunjuk, karena ada
            // tombol lain di layar ini yang juga mencatat acuan.
            .accessibilityLabel(TextLocalization.text(.calibrationCaptureNearestHint))

            HStack(spacing: 4) {
                Button(TextLocalization.text(.calibrationApplyLabel)) { apply() }
                    .font(.caption.weight(.semibold))
                    .disabled(!(session?.flow.isReady ?? false))
                    // Keadaan tombol ikut diucapkan. Tanpa ini tombol yang
                    // mati terdengar persis sama dengan yang hidup — dan
                    // "Pakai" yang ditolak karena sebaran terlalu lebar
                    // adalah hasil yang paling mudah disalahartikan.
                    .accessibilityLabel(session?.flow.spokenApplyButtonLabel
                                        ?? TextLocalization.text(.calibrationApplyNotReadyHint))
                Button(TextLocalization.text(.calibrationResetLabel)) { reset() }
                    .font(.caption.weight(.semibold))
                    .disabled((session?.flow.samples.isEmpty ?? true))
                    .accessibilityLabel(TextLocalization.text(.calibrationResetHint))
            }

            if let policy = session?.suggestedConfidencePolicy {
                Text(TextLocalization.text(.calibrationDisplaySuggestedSigma,
                                                policy.pointingSigmaDeg))
                    .font(.caption2)
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
            statusMessage = CalibrationText.alreadyInstalled(offsetDeg: calibration.yawOffsetDeg)
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
            statusMessage = CalibrationText.notReadyStatus
            return
        }
        engine.apply(calibration: calibration)
        // Kirim hasil kalibrasi ke iPhone: sigma ini yang menyetel ambang
        // keyakinan di sisi sana.
        link.send(calibration: calibration)
        statusMessage = CalibrationText.installed(
            offsetDeg: calibration.yawOffsetDeg,
            spreadDeg: calibration.residualSpreadDeg ?? .nan)
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
        statusMessage = CalibrationText.resetStatus
    }

    // MARK: - Tampilan tahap

    private var phaseLabel: String {
        (session?.flow.phase ?? .idle).displayName
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
        // Nada tahap adalah milik model, bukan view: ia dipakai untuk teks dan
        // ikon kartu, dan peta itu harus bisa diuji di Linux. Lihat
        // `CalibrationPhase.tone` untuk alasan lengkapnya.
        (session?.flow.phase ?? .idle).tone
    }
}
