import SwiftUI
import Charts
import CelestialEngine
import PointingKit

/// Akar app iPhone.
///
/// iPhone tidak menunjuk; ia **mengukur dan menjelaskan**. Karena itu dua tab:
/// diagnostik (apa yang terjadi, dan mengapa engine ragu) dan Experiment 1
/// (mengumpulkan data yang menjawab apakah akurasi Watch cukup).
@main
struct PointAndKnowiOSApp: App {

    @StateObject private var engine = PointingEngine()
    @StateObject private var motion = MotionLogger()
    @StateObject private var location = LocationProvider()
    @StateObject private var link = PhoneLinkService()
    @StateObject private var trace = ConfidenceTraceStore()

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, motion: motion, location: location, link: link, trace: trace)
        }
    }
}

struct RootView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    @Environment(\.scenePhase) private var scenePhase

    /// Preferensi mode malam — **satu untuk seluruh app**, bukan per-tab.
    /// `TabView` menahan semua tab tetap hidup, jadi menaruhnya di akar
    /// berarti paletnya berubah serentak di Diagnostik, Experiment 1, dan
    /// Tautan. Kuncinya sama dengan app jam (lihat `NightModeStorage.key`).
    @AppStorage(NightModeStorage.key) private var nightMode = false
    /// Apakah layar perkenalan sudah pernah dilihat (per-device, sekali).
    @AppStorage(OnboardingStorage.key) private var onboardingSeen = false
    /// Pemutar bunyi opsional saat kunci — aksesibilitas multi-modal (iPhone
    /// tidak punya Taptic Engine, jadi bunyi menggantikan getaran di sini).
    private let audioCue = AudioCueEngine()

    var body: some View {
        TabView {
            DiagnosticsView(engine: engine, motion: motion, location: location, link: link, trace: trace)
                .tabItem { Label("Diagnostik", systemImage: "chart.xyaxis.line") }
            Experiment1View(engine: engine, link: link)
                .tabItem { Label("Experiment 1", systemImage: "target") }
            LinkView(link: link, trace: trace)
                .tabItem { Label("Tautan", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
        // Perkenalan sekali pakai: satu kartu, bukan tur panjang. Dibungkus
        // sheet supaya layar utama (dan hasil pengukuran) tetap hidup di
        // belakang — menutupnya tidak mereset alur.
        .sheet(isPresented: .init(
            get: { !onboardingSeen },
            set: { seen in onboardingSeen = seen })) {
            OnboardingView(onDone: { onboardingSeen = true })
        }
        // Palet merah murni saat malam, berlaku untuk **seluruh** tab.
        .preferredColorScheme(nightMode ? .dark : nil)
        .onAppear { start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: start()
            case .inactive, .background: stop()
            @unknown default: stop()
            }
        }
    }

    /// Sensor, lokasi, dan alur adalah milik **app**, bukan milik satu tab.
    ///
    /// **Kenapa tidak di `onAppear` tiap tab.** `TabView` menahan semua tabnya
    /// tetap hidup: membuka tab lain tidak mematikan tab sebelumnya. Kalau tiap
    /// tab menyalakan sensornya sendiri, keduanya menyetel `motion.onUpdate` pada
    /// `MotionLogger` yang **sama** — yang terakhir menang — dan `onDisappear`
    /// salah satu tab akan memanggil `engine.stop()` untuk alur yang dipakai tab
    /// lain. Gejalanya halus dan menyesatkan: layar tetap tampak hidup sementara
    /// sensor sudah mati, atau riwayat keyakinan diam-diam berhenti terisi.
    /// Menaruh siklus hidupnya di akar membuat ia berjalan tepat sekali untuk
    /// seluruh umur app.
    private func start() {
        // Keputusan yang dikirim jam direkam ke riwayat keyakinan yang sama
        // dengan sampel iPhone; `fromWatch` membedakan asal-usulnya.
        //
        // Tanpa penyambungan ini, `onMessage` tidak pernah dipanggil dan
        // bagian "Sampel dari jam" di layar Tautan akan selalu nol — layar
        // yang tampak baik-baik saja sambil menyembunyikan bahwa datanya
        // tidak pernah masuk. Jam tidak mengirim jarak kandidat, jadi
        // `ratioToSigma` sampel ini memang kosong; itu ditampilkan apa
        // adanya, bukan diisi angka karangan.
        link.onMessage = { message in trace.record(message: message) }
        link.activate()

        // Setiap sampel masuk ke engine **dan** ke riwayat keyakinan.
        // Penyambungannya ada di sini, bukan di tiap tab, karena hanya ada
        // satu `MotionLogger` yang dibagi kedua tab.
        motion.onUpdate = { update in
            engine.ingest(update)
            trace.record(snapshot: update.snapshot,
                         sigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        }
        // iPhone tidak punya Taptic Engine.
        engine.haptics = nil
        // Bunyi pendek saat kunci: saluran multi-modal bagi pengguna yang
        // tidak melihat layar. Mirror pola haptic di jam.
        let cue = audioCue
        engine.audioCue = { events in cue.play(events) }
        motion.start(controller: engine.controller)
        engine.setSensorAvailable(motion.isAvailable)
        location.start()
        engine.bind(location: location)
    }

    private func stop() {
        motion.stop()
        engine.stop()
        location.stop()
    }
}

/// Pembungkus `ObservableObject` untuk `ConfidenceTrace`, supaya perubahan
/// (sampel baru) memicu render grafik.
@MainActor
final class ConfidenceTraceStore: ObservableObject {
    @Published private(set) var trace = ConfidenceTrace()
    /// Jumlah sampel — dipublikasikan terpisah supaya `objectWillChange`
    /// benar-benar terpicu (kelas `ConfidenceTrace` bukan ObservableObject).
    @Published private(set) var count = 0

    func record(snapshot: PointingSnapshot, sigmaDeg: Double, nearestNeighbourDeg: Double? = nil) {
        // `nearestNeighbourDeg` tidak diisi dari sini: cuplikan sudah membawa
        // angka yang dipakai engine untuk memutuskan ambiguitas, dan
        // `ConfidenceTrace` membacanya dari sana. Satu tempat saja yang tahu
        // dari mana angka itu berasal.
        trace.record(snapshot: snapshot,
                     sigmaDeg: sigmaDeg,
                     nearestNeighbourDeg: nearestNeighbourDeg)
        count = trace.samples.count
    }

    func record(message: PointingLinkMessage) {
        trace.record(message: message)
        count = trace.samples.count
    }

    func reset() {
        trace.reset()
        count = 0
    }

    /// Nyalakan/jeda perekaman.
    ///
    /// **Lewat store, bukan binding langsung ke `trace.trace.isRecording`.**
    /// `ConfidenceTrace` bukan `ObservableObject`, jadi menulis propertinya dari
    /// binding tidak memicu render: saklarnya bisa tampak tidak menanggapi
    /// ketukan. Melewati `@Published` di sini membuat setiap perubahan
    /// dipublikasikan.
    func setRecording(_ isRecording: Bool) {
        trace.isRecording = isRecording
        count = trace.samples.count
    }

    /// Apakah sampel yang datang sedang disimpan.
    var isRecording: Bool { trace.isRecording }

    var samples: [ConfidenceSample] { trace.samples }
}

// MARK: - Diagnostik

/// Grafik keyakinan + penjelasan mengapa engine ragu.
///
/// Yang digambar sengaja **rasio terhadap sigma**, bukan derajat. Ambang
/// keyakinan dinyatakan dalam kelipatan sigma pointing, jadi derajat mentah
/// tidak bisa dibaca: 5° berarti "sangat dekat" pada sigma 10° dan "jauh" pada
/// sigma 1°. Menggambar derajat akan membuat pengguna menyimpulkan hal yang
/// salah tentang ambangnya.
struct DiagnosticsView: View {

    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    /// Preferensi mode malam. Menulis ke kunci yang **sama** dengan `RootView`
    /// (`NightModeStorage.key`), jadi saklar ini dan palet seluruh app tidak
    /// bisa berbeda pendapat — keduanya membaca `UserDefaults` yang sama.
    @AppStorage(NightModeStorage.key) private var nightMode = false
    /// Bunyi saat kunci, disimpan ke `UserDefaults` lewat `AudioCueStorage`.
    /// Satu preferensi untuk seluruh app, sama seperti mode malam.
    @AppStorage(AudioCueStorage.key) private var audioCueEnabled = true

    /// Fase denyut glow untuk gambar bintang.
    ///
    /// Berhenti saat scene tidak aktif: denyut yang jalan di latar belakang
    /// hanya membebani baterai tanpa pernah terlihat. `TimelineView` sendiri
    /// sudah berhenti saat scene tidak aktif, tapi jamnya di sini supaya
    /// nilainya tidak melompat saat app kembali dibuka — denyut yang melompat
    /// terbaca sebagai kedipan, bukan denyut.
    @State private var pulseStart = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var pulsePhase: Double {
        guard scenePhase == .active else { return 0 }
        return Date().timeIntervalSince(pulseStart) * 1.1
    }

    /// Saat app kembali aktif, jam denyut di-set ulang **sekali**.
    ///
    /// Tanpa ini, `pulseStart` tetap menunjuk waktu app terakhir aktif, jadi
    /// denyut melompat maju beberapa detik dalam satu frame — dan lompatan itu
    /// terlihat seperti kedipan, bukan denyut. Efeknya persis kebalikan dari
    /// yang diinginkan: denyut yang lembut menenangkan, denyut yang melompat
    /// memberi tahu pengguna ada yang salah.
    private func resyncPulse() {
        pulseStart = Date()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Sekarang") {
                    row("Keadaan", engine.snapshot.state.shortLabel)
                    row("Kalibrasi", engine.snapshot.isCalibrated ? "Sudah" : "Belum")
                    if let rate = engine.snapshot.angularRateDegPerSec {
                        row("Laju pergelangan", String(format: "%.1f°/dtk", rate))
                            // "0.5°/dtk" terbaca oleh mata, tidak oleh suara.
                            // Yang diucapkan bentuk katanya — angkanya sama,
                            // jadi tidak ada versi kedua yang bisa menyimpang.
                            .accessibilityLabel(RowSpeech.spokenRow(
                                title: "Laju pergelangan",
                                spokenValue: RowSpeech.spokenRate(rate)))
                    }
                    if let object = engine.displayedObject {
                        // Sama seperti di jam: objek sisa harus terlihat sebagai
                        // sisa. Baris ini berada di bagian "Sekarang", jadi
                        // tanpa penanda ia terbaca sebagai hasil pengukuran
                        // sekarang.
                        row(engine.isDisplayingStaleObject ? "Objek (sisa)" : "Objek",
                            engine.isDisplayingStaleObject
                                ? "\(object.name) — bukan hasil sekarang"
                                : object.name)
                        // Panel besar: di iPhone ada ruang untuk gambar penuh,
                        // dan justru di tempat pengguna memeriksa "apakah ini
                        // benar?" picture lebih cepat dibaca daripada teks.
                        //
                        // Disamar penuh saat engine ragu: `isConfirmed` memakai
                        // predikat yang sama dengan badge keyakinan, jadi gambar
                        // tidak pernah lebih yakin daripada teksnya.
                        // Animasi halus saat kunci baru tiba (lihat komentar di
                        // `LockArrival` / `ObjectDetailView` di app jam): pop
                        // memudar + sedikit membesar lewat spring, dipicu oleh
                        // token yang **naik**, bukan oleh `state == .lock`, dan
                        // tidak diputar ulang saat kunci dilepas (objek jadi
                        // sisa). `TimelineView` di bawah menyegarkan 30×/detik,
                        // jadi pop dijaga `.onChange` agar hanya berjalan sekali
                        // per kedatangan, bukan per frame.
                        if let visual = engine.visualForDisplayedObject {
                            LockArrivalPanel(visual: visual,
                                             object: object,
                                             isStale: engine.isDisplayingStaleObject,
                                             // **Bukan** `!isStale`: selama
                                             // `.uncertain` engine punya
                                             // kandidat tapi menyatakan diri
                                             // kurang yakin. Menurunkan
                                             // `isConfirmed` dari `!isStale`
                                             // meloloskan seluruh ciri
                                             // pengenal tepat saat badge
                                             // bertuliskan "Ragu".
                                             isConfirmed: engine.confirmsDisplayedIdentity,
                                             lockArrivalToken: engine.lockArrival?.token,
                                             pulse: pulsePhase)
                        }
                    }
                    if let pointing = engine.pointing {
                        row("Arah", String(format: "%.1f° / %.1f°",
                                           pointing.altitudeDeg, pointing.azimuthDeg))
                    }
                    row("Sigma dipakai", String(format: "%.1f°",
                                                engine.controller.resolver.confidencePolicy.pointingSigmaDeg))
                }

                Section("Keyakinan") {
                    if trace.samples.isEmpty {
                        Text("Belum ada sampel. Angkat iPhone dan arahkan ke langit.")
                            .foregroundStyle(Color.nightAwareSecondary)
                    } else {
                        confidenceChart
                        Text(trace.trace.diagnosis(
                            policy: engine.controller.resolver.confidencePolicy))
                            .font(.footnote)
                    }
                }

                Section("Sensor & lokasi") {
                    row("Device motion", motion.isAvailable ? "Ada" : "Tidak ada")
                    row("Sampel", "\(motion.sampleCount)")
                    row("Lokasi", location.effectiveLocation.label)
                    row("Asal lokasi", location.effectiveLocation.source)
                    if let reason = motion.unavailableReason {
                        Text(reason).foregroundStyle(PointingTone.danger.color)
                    }
                    // Penolakan izin lokasi (atau kegagalan pengambilan) harus
                    // terlihat, bukan diam: engine tetap jalan dengan lokasi
                    // darurat (Jakarta), tapi langit dihitung untuk tempat yang
                    // salah. `note` `nil` saat normal, jadi tidak pernah
                    // memunculkan pesan menakutkan saat segalanya beres.
                    if let note = location.note {
                        Text(note).foregroundStyle(PointingTone.warning.color)
                    }
                }

                Section("Kontrol") {
                    Toggle("Mode Malam (merah)", isOn: $nightMode)
                    Toggle("Bunyi saat kunci", isOn: $audioCueEnabled)
                    Toggle("Rekam keyakinan", isOn: Binding(
                        get: { trace.isRecording },
                        set: { trace.setRecording($0) }))
                    Button("Kosongkan riwayat") { trace.reset() }
                        // Riwayat kosong **atau** perekaman dijeda: tombol yang
                        // tampak siap menghapus padahal tidak ada yang disimpan
                        // lagi hanya membuat pengguna mengira riwayatnya masih
                        // terkumpul. Keadaannya ditampilkan apa adanya.
                        .disabled(trace.samples.isEmpty || !trace.isRecording)
                }

                Section {
                    ShareLink(item: exportDocument,
                              preview: SharePreview("Riwayat keyakinan")) {
                        Label("Ekspor dataset (JSON)", systemImage: "square.and.arrow.up")
                    }
                    .disabled(trace.samples.isEmpty)
                } header: {
                    Text("Ekspor")
                } footer: {
                    Text("Berkas ini memuat lokasi, kalibrasi, dan sigma yang berlaku saat merekam — tanpa itu, jarak kandidat dalam derajat tidak bisa ditafsirkan kembali.")
                }
            }
            .navigationTitle("Diagnostik")
            // Sembunyikan latar `List` bawaan supaya gradien aplikasi
            // (`#0A0A0F`/`#121216`) terlihat di balik kartu, bukan chrome
            // sistem yang menutupinya. Kartu tetap memakai `surfaceCard`.
            .scrollContentBackground(.hidden)
            // Set ulang denyut tepat saat app aktif lagi.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { resyncPulse() }
            }
            // Siklus hidup sensor, lokasi, dan alur **tidak** ada di sini:
            // ketiganya dibagi dengan tab Experiment 1, dan `TabView` menahan
            // kedua tab tetap hidup. Siklus hidupnya ada di `RootView`, tempat
            // ia berjalan tepat sekali untuk seluruh app.
        }
        .appBackground()
        .forceDarkScheme()
    }

    /// Rasio terhadap sigma. Garis ambang digambar dari kebijakan yang **sedang
    /// dipakai**, bukan angka tetap, supaya grafiknya tetap benar setelah
    /// ambangnya diperketat.
    private var confidenceChart: some View {
        let policy = engine.controller.resolver.confidencePolicy
        let points = trace.samples.enumerated().compactMap { index, sample -> (Int, Double)? in
            sample.ratioToSigma.map { (index, $0) }
        }

        return VStack(alignment: .leading, spacing: 4) {
            if points.isEmpty {
                Text("Sampel ada, tapi belum ada jarak kandidat yang terukur.")
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            } else {
                Chart {
                    ForEach(points, id: \.0) { index, ratio in
                        LineMark(x: .value("Sampel", index), y: .value("σ", ratio))
                            .foregroundStyle(PointingTone.active.color)
                    }
                    RuleMark(y: .value("Ambang yakin", policy.maxSeparationSigma))
                        .lineStyle(StrokeStyle(dash: [4, 3]))
                        .foregroundStyle(PointingTone.success.color)
                        .annotation(position: .top, alignment: .leading) {
                            Text("batas yakin").font(.caption2)
                        }
                    RuleMark(y: .value("Ambang ambigu", policy.ambiguitySigma))
                        .lineStyle(StrokeStyle(dash: [2, 4]))
                        .foregroundStyle(PointingTone.warning.color)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("batas ambigu").font(.caption2)
                        }
                }
                .chartYAxisLabel("jarak kandidat / σ")
                .frame(height: 180)
            }

            HStack(spacing: 12) {
                legend("Yakin", .success)
                legend("Ragu", .warning)
                legend("Tidak tahu", .danger)
            }
            .font(.caption2)
        }
    }

    private func legend(_ label: String, _ tone: PointingTone) -> some View {
        HStack(spacing: 3) {
            Circle().fill(tone.color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    /// Isi berkas ekspor: riwayat keyakinan **beserta konteks yang berlaku saat
    /// merekam**. Kalau encoding gagal, yang dibagikan adalah pesan kesalahan di
    /// dalam berkas — bukan berkas kosong yang tampak seperti dataset valid.
    /// Nama berkasnya memakai stempel waktu UTC dari `ConfidenceTraceArchive`.
    private var exportDocument: JSONArchiveDocument {
        let filename = ConfidenceTraceArchive.suggestedFilename()
        let export = ConfidenceTraceArchive.export(
            from: trace.trace,
            location: engine.location,
            calibration: engine.controller.calibration,
            confidenceSigmaDeg: engine.controller.resolver.confidencePolicy.pointingSigmaDeg)
        do {
            let data = try ConfidenceTraceArchive.encode(export)
            return JSONArchiveDocument(filename: filename, data: data)
        } catch {
            let message = "{\"error\": \"gagal meng-encode riwayat keyakinan: \(error.localizedDescription)\"}"
            return JSONArchiveDocument(filename: filename, data: Data(message.utf8))
        }
    }

    /// Baris detail teknis: nilai monospaced + sekunder.
    ///
    /// Monospaced bukan gaya — angka RA/Dec yang rata kanan adalah bentuk
    /// yang membuat dua kolom angka bisa dibandingkan sekilas, dan
    /// `disclosure` ini dipakai untuk membandingkan.
    ///
    /// `static` karena dipakai juga oleh `LockArrivalPanel` (nested type),
    /// yang tidak bisa memanggil instance method `DiagnosticsView`. Murni:
    /// hanya memakai `SurfacePalette` static + argumennya, jadi aman lepas
    /// dari instance.
    static func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
            Spacer(minLength: 12)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
        }
        .font(.footnote)
        // Sama seperti `row`: judul dan nilai adalah satu pengumuman. Baris
        // ini justru lebih rawan — isinya RA/Dec/Id, yaitu pengenal yang
        // diucapkan tanpa judulnya terdengar seperti deretan karakter.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Color.nightAwareSecondary)
        }
        // Satu pengumuman, bukan dua elemen tanpa hubungan. Kalimatnya dari
        // `RowSpeech` (PointingKit) — sumber yang **sama** dengan `LinkView`
        // dan `SkyContextView`, supaya tiga `row` yang identik tidak punya
        // tiga versi aturan pengumuman.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }

    /// Panel detail besar (iPhone): gambar prosedural + nama + jenis, dengan
    /// animasi "muncul" halus saat kunci baru tiba.
    ///
    /// Dipisah dari `DiagnosticsView` supaya status animasi (`@State`
    /// `appearScale`/`appearOpacity`) punya masa hidup sendiri dan tidak ikut
    /// dirender ulang oleh `TimelineView` 30 Hz yang hanya bertugas
    /// menyegarkan denyut glow bintang. Kalau pop ditaruh di atas
    /// `TimelineView`, ia diputar ulang tiap frame.
    ///
    /// **Kenapa pop dipicu oleh `lockArrivalToken` yang naik, bukan `state ==
    /// .lock`.** Pada iPhone `snapshot` diperbarui terus (sampel sensor +
    /// observer), dan `state` tetap `.lock` selama kunci bertahan — memakai
    /// keadaan membuat panel berkedip terus-menerus. `LockArrivalGate` sudah
    /// menyaring itu: token hanya naik saat ada **kedatangan kunci baru** dengan
    /// objek yang berlaku sekarang, dan kembali `nil` saat kunci dilepas.
    /// `.onChange` di bawah memainkan pop **sekali**, dan mengabaikan saat
    /// token jadi `nil` — kita tidak merayakan jawaban yang sudah tidak berlaku
    /// (kelas false confidence yang dilarang PRD).
    struct LockArrivalPanel: View {

        let visual: CelestialVisual
        let object: CelestialObject
        let isStale: Bool
        /// Apakah gambar boleh mengklaim identitas — ambang **lebih ketat**
        /// daripada `!isStale` (lihat `PointingSnapshot.confirmsIdentity`).
        let isConfirmed: Bool
        let lockArrivalToken: Int?
        let pulse: Double

        @State private var appearScale: CGFloat = 1
        @State private var appearOpacity: Double = 1

        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                HStack(alignment: .center, spacing: 16) {
                    CelestialVisualView(visual: visual,
                                         diameter: 132,
                                         // Bukan `!isStale`: `.uncertain`
                                         // bukan sisa, tapi engine kurang
                                         // yakin — gambar tidak boleh lebih
                                         // yakin daripada badge "Ragu" di
                                         // sebelahnya.
                                         isConfirmed: isConfirmed,
                                         pulse: pulse)
                    // Nama + jenis digabung jadi satu pengumuman VoiceOver,
                    // dengan penanda **sisa** ikut terbawa — tanpa itu, objek
                    // basi terdengar persis seperti hasil pengukuran sekarang.
                    VStack(alignment: .leading, spacing: 4) {
                        // Nama = informasi utama: paling besar.
                        Text(object.name)
                            .font(.title2.bold())
                        Text(object.kind.displayName)
                            .font(.subheadline)
                            .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // **Detail teknis disembunyikan di balik Disclosure.**
                        // RA/Dec/mag adalah alat verifikasi, bukan yang dicari
                        // saat mengarahkan jam. Menampilkannya di samping nama
                        // membuat lima angka bersaing dengan satu jawaban.
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 2) {
                                // Setiap baris teknis diberi label terucap
                                // sendiri. Tanpa itu yang diucapkan adalah
                                // "101.2871°" — angka tanpa konteks apa yang
                                // diukur, persis di baris yang isinya
                                // pengenal. Presisinya mengikuti tampilan,
                                // supaya suara dan layar tidak menyebut dua
                                // angka berbeda untuk nilai yang sama.
                                DiagnosticsView.detailRow("Magnitudo", String(format: "%.2f", object.magnitude))
                                if object.kind == .star {
                                    DiagnosticsView.detailRow("RA", String(format: "%.4f°", object.raDeg))
                                        .accessibilityLabel(RowSpeech.label(
                                            title: "RA",
                                            value: RowSpeech.spokenDegrees(object.raDeg, precision: 4)))
                                    DiagnosticsView.detailRow("Dec", String(format: "%+.4f°", object.decDeg))
                                        .accessibilityLabel(RowSpeech.label(
                                            title: "Dec",
                                            value: RowSpeech.spokenDegrees(object.decDeg, precision: 4)))
                                }
                                DiagnosticsView.detailRow("Id katalog", object.id)
                            }
                            .padding(.top, 4)
                        } label: {
                            Text("Detail teknikal")
                                .font(.footnote)
                                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                        }
                        .tint(SurfacePalette.active.textSecondaryColor)
                    }
                    .accessibilityElement(children: .contain)
                    // Label ini hanya untuk bagian **atas**; grup dan disclosure
                    // di bawahnya tetap elemen terpisah supaya bisa dibuka.
                    .accessibilityLabel(DiagnosticsView.visualPanelLabel(
                        object: object,
                        stale: isStale,
                        includeTechnicalDetails: false))
                }
            }
            .padding(.vertical, 6)
            // Pop "muncul" saat kunci baru: sedikit membesar lalu kembali,
            // plus opasitas penuh. Penampilan yang diwujudkan di sini hanya
            // sebagai umpan balik visual halus — tidak mengubah satu pun
            // klaim teks/identitas.
            .scaleEffect(appearScale)
            .opacity(appearOpacity)
            .onChange(of: lockArrivalToken) { oldToken, newToken in
                guard let new = newToken, new != oldToken else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    appearScale = 1.04
                    appearOpacity = 1
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.08)) {
                    appearScale = 1
                }
            }
            // Hanya bagian **atas** panel yang digabung, bukan seluruhnya.
            .accessibilityElement(children: .contain)
        }
    }

    /// Label panel gambar untuk VoiceOver.
    ///
    /// `static` karena dipanggil dari `LockArrivalPanel` (nested type). Murni:
    /// hanya bergantung pada argumen + `object.kind`, tidak pada instance.
    ///
    /// **Tidak pernah menyebut visualnya.** "Gambar Jupiter dengan pita
    /// oranye" tidak menambah informasi yang tidak sudah ada di nama dan jenis
    /// benda, tapi ia menambah satu kalimat panjang yang harus didengarkan
    /// setiap kali pengguna menyapu. Yang wajib ikut diucapkan adalah penanda
    /// **sisa** — tanpa itu, gambar objek basi terdengar persis seperti
    /// hasil pengukuran sekarang.
    /// `includeTechnicalDetails` memisahkan dua hal yang harusnya tidak
    /// tercampur: nama + jenis adalah **pengumuman utama** (dibacakan saat
    /// panel muncul), sementara RA/Dec/mag dibaca hanya kalau pengguna
    /// memang membuka detail. Kalau detail ikut di pengumuman utama, setiap
    /// kali panel tampil pengguna mendengar lima angka sebelum tahu benda apa
    /// yang sedang dilihat.
    static func visualPanelLabel(object: CelestialObject,
                                  stale: Bool,
                                  includeTechnicalDetails: Bool = true) -> String {
        var parts = [object.name, object.kind.spokenName]
        if includeTechnicalDetails {
            parts.append(String(format: "magnitudo %.2f", object.magnitude))
        }
        if stale {
            parts.append("Sisa pandangan sebelumnya, bukan hasil sekarang.")
        }
        return parts.joined(separator: ". ")
    }
}
