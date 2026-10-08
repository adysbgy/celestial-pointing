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

    // iPhone ditunjukkan dengan tepi atasnya (+Y), bukan dengan sumbu lengan
    // bawah jam (ADR-002).
    @StateObject private var engine = PointingEngine(
        config: PointingControllerConfig(aim: .screenUp)
    )
    @StateObject private var motion = MotionLogger()
    @StateObject private var location = LocationProvider()
    @StateObject private var link = PhoneLinkService()
    @StateObject private var trace = ConfidenceTraceStore()

    /// Sama seperti app jam: label keadaan dan keyakinan berasal dari
    /// `PointingKit`, jadi bridge harus terpasang sebelum layar pertama
    /// dirender — bukan saat tab pertama dibuka.
    init() { LocalizationBridge.install() }

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
    /// Keadaan terakhir yang sudah diumumkan ke VoiceOver.
    ///
    /// **Kenapa disimpan.** `engine.snapshot` ditulis ulang 20 kali per detik.
    /// Mengumumkan pada setiap perubahan cuplikan berarti VoiceOver mengucapkan
    /// "Mencari" berpuluh kali per menit dan menutupi semua hal lain yang ingin
    /// dibaca pengguna — jadi pengumuman hanya terjadi saat **keadaannya**
    /// benar-benar berganti. Ini pola yang sama dengan app jam, dan kalimatnya
    /// pun satu sumber (`StateAnnouncement`), supaya kedua app tidak bisa
    /// mengucapkan dua hal berbeda untuk cuplikan yang sama.
    @State private var announcedState: PointingState?
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
            PointingLabPhoneView(link: link)
                .tabItem { Label("Lab", systemImage: "flask") }
        }
        // Perkenalan sekali pakai: satu kartu, bukan tur panjang. Dibungkus
        // sheet supaya layar utama (dan hasil pengukuran) tetap hidup di
        // belakang — menutupnya tidak mereset alur.
        .sheet(isPresented: .init(
            get: { !onboardingSeen },
            // Penulis `isPresented` menerima "masih tampil?", bukan
            // "sudah dilihat?". Dulu nilainya disimpan apa adanya, jadi
            // menutup sheet menulis `onboardingSeen = false` dan sheet
            // langsung muncul lagi — kartu ini tidak pernah bisa ditutup.
            set: { presented in onboardingSeen = !presented })) {
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
        // Umumkan **perubahan** keadaan, bukan tiap sampel 20 Hz — sama
        // seperti app jam.
        //
        // **Kenapa ini ada, padahal iPhone bukan alat penunjuk.** Justru
        // karena itu: iPhone adalah tempat pengguna memeriksa "apakah ini
        // benar?", dan pengguna VoiceOver yang memeriksa hasil pengukuran di
        // sini dulu tidak mendapat kabar apa pun saat engine berpindah dari
        // "Mencari" ke "Terkunci". Janji produknya sama di kedua perangkat —
        // keadaan yang berubah harus terdengar — tetapi hanya app jam yang
        // memenuhinya, dan tidak ada layar yang tampak salah.
        //
        // Keadaan awal (`nil`) sengaja tidak diumumkan: membuka app bukan
        // peristiwa yang perlu dikabarkan, dan mengumumkan "Siap" pada
        // peluncuran hanya menunda pembacaan isi layar.
        .onChange(of: engine.snapshot.state) { _, newState in
            guard announcedState != newState else { return }
            announcedState = newState
            AccessibilityNotification.Announcement(
                StateAnnouncement.text(for: engine.snapshot)).post()
        }
        // Lokasi sungguhan datang belakangan; GoTo harus memakainya (ADR-006).
        .onChange(of: engine.location) { _, location in
            link.updateObserver(location.observer)
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
        // Koordinat GoTo dihitung dari lokasi engine iPhone (ADR-006).
        link.updateObserver(engine.location.observer)

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
    /// Berhenti saat scene tidak aktif **dan** saat pengguna meminta reduksi
    /// gerak: denyut yang jalan di latar belakang hanya membebani baterai
    /// tanpa pernah terlihat, dan denyut yang terus-menerus tanpa henti
    /// persis yang diminta untuk dihentikan oleh pengguna yang menyalakan
    /// Reduce Motion. `MotionPolicy` di `PointingKit` (**teruji di Linux**)
    /// adalah satu-satunya sumber aturan ini — view tidak punya ambangnya
    /// sendiri, supaya tidak bisa berbeda pendapat dengan app jam.
    ///
    /// `TimelineView` sendiri sudah berhenti saat scene tidak aktif, tapi
    /// jamnya di sini supaya nilainya tidak melompat saat app kembali dibuka
    /// — denyut yang melompat terbaca sebagai kedipan, bukan denyut.
    @State private var pulseStart = Date()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pulsePhase: Double {
        MotionPolicy(reduceMotion: reduceMotion,
                     isLuminanceReduced: false,
                     isSceneActive: scenePhase == .active)
            .pulsePhase(elapsedSeconds: Date().timeIntervalSince(pulseStart))
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
                    row(DiagnosticsText.rowState, engine.snapshot.state.shortLabel)
                    // Panduan berikutnya. `shortLabel` menjawab **apa**
                    // keadaan itu ("Mencari"), yang tidak pernah memberi tahu
                    // pengguna harus melakukan apa — dan di iPhone tidak ada
                    // tempat lain yang mengatakannya: app jam menampilkannya
                    // di bawah keadaan (`PointingView`), sedangkan di sini
                    // tidak ada sekilas pun, jadi layar utama iPhone
                    // menampilkan "Mencari" dan lalu diam.
                    //
                    // Barisnya sengaja memakai `guidanceText` yang sama
                    // dan kunci katalog yang sama, bukan kalimat baru: kalau
                    // kalimatnya ditulis terpisah di view, ia bisa menyimpang
                    // dari yang diucapkan jam — dan dua app yang memberi
                    // petunjuk berbeda adalah cacat yang paling buruk.
                    // `guidanceText` (bukan `state.guidance`) supaya alasan
                    // "mengapa tidak ada objek" dari engine ikut terbaca.
                    row(DiagnosticsText.rowGuidance, engine.snapshot.guidanceText)
                    // Putusan GoTo. Aturan keras PRD "POINT → OBJECT ID → SAFE
                    // GOTO" sudah dihitung `SlewPlanner` sejak FASE 3, tetapi
                    // `slewDecision` nol konsumen di `Apps/` — jadi penolakan
                    // karena `sunProximity` (melindungi alat & mata) dan
                    // penolakan karena `lowConfidence` (soal ketelitian)
                    // terlihat sama: tidak terlihat.
                    //
                    // **Kenapa memakai `SlewVerdictBanner`, bukan `row`.**
                    // Versi pertama menampilkannya lewat `row("GoTo", verdict)`,
                    // dan itu menyamakan peringatan **keselamatan alat** dengan
                    // baris data biasa di sebelahnya ("Kalibrasi: Sudah") —
                    // bobot visual yang sama untuk dua hal yang tidak sama
                    // pentingnya. Di jam, putusan yang sama tampil sebagai kartu
                    // berikon (satu sumber: `SlewVerdictBanner`); di iPhone ia
                    // justru turun pangkat menjadi teks abu-abu. Dua permukaan
                    // yang menyimpang soal seberapa mendesak sebuah penolakan
                    // adalah cacat yang tidak terlihat dari layar mana pun.
                    // Banner yang sama menutupnya, dan `nil`-nya berarti tidak
                    // ada yang perlu diperingatkan (`verdictText` `nil` saat
                    // GoTo aman), jadi ia tidak pernah berbunyi di sebelah GoTo
                    // yang justru berjalan.
                    SlewVerdictBanner(decision: engine.slewVerdict)
                    row(DiagnosticsText.rowCalibration,
                        engine.snapshot.isCalibrated
                            ? DiagnosticsText.valueCalibrated
                            : DiagnosticsText.valueNotCalibrated)
                    if let rate = engine.snapshot.angularRateDegPerSec {
                        row(DiagnosticsText.rowWristRate,
                            NumberFormat.degreesPerSecond(rate))
                            // "0.5°/dtk" terbaca oleh mata, tidak oleh suara.
                            // Yang diucapkan bentuk katanya — angkanya sama,
                            // jadi tidak ada versi kedua yang bisa menyimpang.
                            .accessibilityLabel(RowSpeech.spokenRow(
                                title: DiagnosticsText.rowWristRate,
                                spokenValue: RowSpeech.spokenRate(rate)))
                    }
                    if let object = engine.displayedObject {
                        // Sama seperti di jam: objek sisa harus terlihat sebagai
                        // sisa. Baris ini berada di bagian "Sekarang", jadi
                        // tanpa penanda ia terbaca sebagai hasil pengukuran
                        // sekarang.
                        row(engine.isDisplayingStaleObject
                                ? DiagnosticsText.rowObjectStale
                                : DiagnosticsText.rowObject,
                            engine.isDisplayingStaleObject
                                // Kalimatnya lahir dari katalog, bukan
                                // dirakit di sini. Bentuk lama menyisipkan
                                // nama ke dalam literal berinterpolasi, dan
                                // itu mematikan dua hal sekaligus: Aturan 4
                                // melewatinya tanpa laporan (penyebabnya kini
                                // diperbaiki di `swift-ui-lint.sh`), dan
                                // urutan kata terkunci di kode — bahasa lain
                                // tidak bisa menaruh penanda di depan nama.
                                ? ObjectSpeech.staleDisplayName(object.name)
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
                                             // Tingkat keyakinan yang berlaku
                                             // untuk arah tunjuk sekarang.
                                             // `answeredLevel` — bukan
                                             // `intent?.level` — karena
                                             // keyakinan yang menempel pada
                                             // keadaan tanpa jawaban adalah
                                             // klaim yang tidak berlaku (lihat
                                             // `PointingPresentation`).
                                             level: engine.snapshot.answeredLevel,
                                             lockArrivalToken: engine.lockArrival?.token,
                                             pulse: pulsePhase)
                        }
                    }
                    if let pointing = engine.pointing {
                        row(DiagnosticsText.rowDirection,
                            "\(NumberFormat.degrees(pointing.altitudeDeg)) / "
                                 + "\(NumberFormat.degrees(pointing.azimuthDeg))")
                    }
                    row(DiagnosticsText.rowSigmaInUse,
                        NumberFormat.degrees(
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
                        // Rincian **sebab** keraguan per penyebab.
                        //
                        // `diagnosis` di atas sengaja meringkas jadi satu
                        // kalimat: ia hanya menyebut sebab yang mendominasi
                        // (> separuh sampel ragu) atau sebab-sebab yang seri
                        // di puncak. Yang tidak bisa ia lakukan dalam satu
                        // kalimat adalah menyebut **berapa kali** tiap sebab
                        // muncul — dan itu justru yang hilang tanpa tanda.
                        //
                        // Akibatnya penguji bisa membaca "Perbaiki kalibrasi
                        // dulu." lalu menyimpulkan semua keraguan berasal dari
                        // kalibrasi, sementara ambiguitas katalog muncul pada
                        // sebagian sampel dan hilang begitu saja. Dua petunjuk
                        // perbaikan yang saling meniadakan, satu terlihat dan
                        // satu tidak — persis kelas yang
                        // `tiedUncertainReasons` tutup untuk kalimat
                        // diagnosisnya.
                        //
                        // Barisnya dibangun di `PointingKit`
                        // (`UncertainReasonBreakdown`) karena tiga aturan
                        // yang tidak bisa dijaga di view: urutan baris mengikuti
                        // deklarasi enum (bukan urutan `Dictionary` yang
                        // di-seed per proses), baris dengan hitungan nol tidak
                        // pernah tampil, dan ambang dominasi **sama** dengan
                        // yang dipakai `diagnosis`. Kalau salah satu ditulis
                        // ulang di sini, layar dan kalimat akan memberi
                        // jawaban berbeda untuk rekaman yang sama.
                        //
                        // `isEmpty` membuat seluruh blok hilang saat tidak ada
                        // sampel ragu — bukan daftar kosong di bawah
                        // kalimat, yang terbaca sebagai "ada sesuatu yang
                        // belum bisa ditampilkan".
                        //
                        // Barisnya memakai `RowSpeech.label` langsung, bukan
                        // helper `row` lokal: judulnya **sudah** berbahasa
                        // dari katalog, jadi melewati `row` berarti merakit
                        // kalimat yang sama dua kali — dan `row` sendiri
                        // sudah yelled lewat `RowSpeech`.
                        ForEach(uncertainBreakdown.rows, id: \.reason) { entry in
                            HStack {
                                Text(entry.reason.label)
                                Spacer()
                                Text(entry.countText.text)
                                    .foregroundStyle(Color.nightAwareSecondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(RowSpeech.label(
                                title: entry.reason.label,
                                value: entry.countText.text))
                        }
                    }
                }

                Section("Sensor & lokasi") {
                    row(DiagnosticsText.rowDeviceMotion,
                        motion.isAvailable
                            ? DiagnosticsText.valueMotionAvailable
                            : DiagnosticsText.valueMotionUnavailable)
                    row(DiagnosticsText.rowSample, "\(motion.sampleCount)")
                    row(DiagnosticsText.rowLocation, location.effectiveLocation.label)
                    row(DiagnosticsText.rowLocationSource,
                        location.effectiveLocation.sourceDisplayName)
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

    /// Rincian sebab keraguan — baris "sebab: n dari total".
    ///
    /// **Kenapa ini dihitung di paket, bukan di view.** Tiga aturan yang
    /// menentukan apakah rincian ini jujur tidak bisa ditegakkan di dalam
    /// `View`: urutan baris harus mengikuti deklarasi enum (`Dictionary` di-
    /// seed per proses, jadi urutan `dictionary.keys` berubah antar
    /// peluncuran), baris dengan hitungan nol harus **tidak** tampil, dan
    /// ambang dominasi harus sama dengan yang dipakai `diagnosis`. Lihat
    /// `UncertainReasonBreakdown` di `PointingKit` untuk alasannya.
    ///
    /// Policy-nya dibaca dari **sumber yang sama** dengan `confidenceChart`
    /// dan `diagnosis` di atas (`engine.controller.resolver.
    /// confidencePolicy`) — bukan nilai bawaan — supaya klasifikasi sebab dan
    /// ambang di grafik berasal dari satu keputusan yang sama. Kalau ini
    /// memakai `ConfidencePolicy()` bawaan sementara yang lain memakai policy
    /// yang berlaku, rincian bisa mengelompokkan sampel berbeda dari
    /// kalimat yang menjelaskan itu.
    private var uncertainBreakdown: UncertainReasonBreakdown {
        let policy = engine.controller.resolver.confidencePolicy
        return UncertainReasonBreakdown(
            counts: trace.trace.uncertainReasonCounts(policy: policy),
            policy: policy)
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
                // **Satu-satunya bagian layar ini yang sebelumnya diam.**
                //
                // Swift Charts tidak memberi deskripsi yang berguna: yang bisa
                // di Accessibility Reader hanyalah setiap titik satu per satu,
                // dan tidak ada pembaca layar yang akan menarik garis dari
                // sana. Setiap elemen data lain di layar ini punya pengumuman
                // (`RowSpeech`, `visualPanelLabel`), jadi grafiknyalah yang
                // terlihat paling kaya secara visual dan paling sunyi.
                //
                // Yang diucapkan bukan angka mentah, tapi **kesimpulan**: berapa
                // sampel jatuh di tiap pita ambang. Angka mentah sudah ada di
                // ekspor, dan membacanya satu per satu tidak menghasilkan
                // informasi apa pun. Pita batasnya dihitung di `PointingKit`
                // dari `policy` yang sama dengan yang dipakai engine -- kalau
                // ambangnya ditulis ulang di sini, ringkasan suara bisa
                // menyimpulkan "terlalu jauh" untuk titik yang jelas masih di
                // bawah garis yang sedang dilihat pengguna.
                //
                // Saat tidak ada satu pun jarak terukur, yang diucapkan
                // bukan kalimat berisi nol-nol (yang akan terbaca sebagai elemen
                // yang sudah dibaca tapi tidak bermakna), melainkan kalimat dari
                // katalog yang mengulang pesan yang sudah terlihat di layar.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenChartSummary)
            }

            HStack(spacing: 12) {
                legend(DiagnosticsText.legendConfident, .success)
                legend(DiagnosticsText.legendUncertain, .warning)
                legend(DiagnosticsText.legendUnknown, .danger)
            }
            .font(.caption2)
        }
    }

    /// Ringkasan verbal grafik, dihitung dari sampel yang sama dengan yang
    /// diplot.
    ///
    /// `nil` kalau tidak ada sampel dengan jarak terukur -- sama dengan kondisi
    /// `points.isEmpty` yang sudah menggambar pesan penggantinya, sehingga
    /// cabang keduanya tidak bisa berbeda pendapat soal "ada yang bisa
    /// dikatakan atau tidak".
    private var chartSpeech: ConfidenceChartSpeech? {
        ConfidenceChartSpeech(samples: trace.samples.map(\.ratioToSigma),
                              policy: engine.controller.resolver.confidencePolicy)
    }

    /// Pengumuman grafik.
    ///
    /// Cadangannya **kalimat dari katalog**, bukan `""`. Dua alasan:
    ///
    /// 1. `.accessibilityLabel(_:)` hanya menerima `String`, jadi ketiadaan
    ///    harus diterjemahkan menjadi sesuatu. `""` berarti pembaca layar
    ///    menemukan satu elemen yang sudah "terbaca" tapi tidak bermakna —
    ///    lebih buruk daripada tidak ada pengumuman, karena keduanya berbeda
    ///    rasa.
    /// 2. Isinya mengulang pesan yang sudah terlihat di layar pada cabang
    ///    "sampel ada, tapi belum ada jarak terukur", jadi suara dan mata
    ///    menyebut hal yang sama.
    ///
    /// Bentuk ini mengikuti pola yang sudah dipakai `CalibrationView`
    /// (`session?.flow.spokenPhaseSummary ?? TextLocalization.text(…)`):
    /// opsional dijawab dengan kunci katalog, bukan dengan literal.
    private var spokenChartSummary: String {
        chartSpeech?.spokenSummary
            ?? TextLocalization.text(.chartSpeechNothingMeasured)
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
        /// Tingkat keyakinan yang berlaku untuk arah tunjuk sekarang.
        ///
        /// `nil` saat keadaan tidak punya jawaban, **atau** saat objek ini
        /// sisa — dua keadaan yang berbeda, dan keduanya berarti "jangan
        /// tampilkan badge". Tanpa `level` di sini, badge itu tidak ada, dan
        /// komentar di `DiagnosticsView` yang berkata "gambar tidak pernah
        /// lebih yakin daripada badge di sebelahnya" menunjuk benda yang tidak
        /// digambar — pengguna yang melihat cincin Saturnus tidak punya cara
        /// tahu engine sedang ragu, karena satu-satunya penanda yang tersisa
        /// (`.uncertain` → gambar disamar) bekerja lewat absen, bukan lewat
        /// pernyataan.
        let level: ConfidenceLevel?
        let lockArrivalToken: Int?
        let pulse: Double

        @State private var appearScale: CGFloat = 1
        @State private var appearOpacity: Double = 1
        /// Pengguna meminta reduksi gerak: pop dimatikan, dan `TimelineView`
        /// denyut ikut berhenti (lihat `MotionPolicy` di `PointingKit`).
        ///
        /// `isLuminanceReduced` selalu `false` di iPhone: itu Always-On
        /// watchOS. Dimasukkan sebagai argumen eksplisit, bukan sekadar
        /// formalitas, supaya pemanggil di app jam dan di sini punya **bentuk
        /// yang sama** — kalau suatu saat ada layar redup di iPhone, aturannya
        /// sudah ada dan tidak perlu ditebak lagi.
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var motion: MotionPolicy {
            MotionPolicy(reduceMotion: reduceMotion,
                         isLuminanceReduced: false,
                         isSceneActive: true)
        }

        var body: some View {
            Group {
                // `visual.hasPulse` ikut di ambang, bukan hanya
                // `motion.allowsContinuousMotion`. Tanpa itu, setiap planet
                // memakai jalur TimelineView: 30 render per detik untuk
                // `Canvas` yang menggambar piksel identik setiap frame,
                // karena `pulse` hanya dibaca di `drawStar`. Properti
                // `hasPulse` diuji di Linux, jadi keputusan ini tidak
                // bergantung pada ingatan orang yang sedang menulis di view.
                if motion.allowsContinuousMotion && visual.hasPulse {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                        content(pulse: pulse)
                    }
                } else {
                    // Tanpa `TimelineView`: view tidak pernah di-refresh per
                    // frame, jadi denyut benar-benar berhenti — bukan
                    // "cukup kecil". Tiga hal bisa membawa ke sini:
                    // `reduceMotion`/redup (geraknya memang tidak boleh
                    // jalan), `hasPulse` salah (gambarnya memang diam), dan
                    // `pulsePhase` mengembalikan **nol persis** di keadaan
                    // gated — bukan amplitude kecil. Ketiganya menghasilkan
                    // gambar yang sama persis, dan itu yang membuat cabang
                    // ini boleh dicabut tanpa perlu menebak apa yang berubah.
                    content(pulse: 0)
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
                // Transisi dimatikan saat pengguna meminta reduksi gerak.
                // Bukan hanya karena bandwidth: `LockArrivalGate` sudah
                // menyaring agar token hanya naik pada kedatangan kunci yang
                // **sungguhan** baru, jadi satu-satunya gerak yang tersisa di
                // sini adalah gerak yang tidak diminta. `MotionPolicy` yang
                // memutuskan, bukan view ini — supaya app jam dan iPhone tidak
                // bisa berbeda pendapat.
                guard motion.allowsTransitions else { return }
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

        /// Isi panel, dipisah dari pembungkus denyut.
        ///
        /// Dipisah karena dua bentuk gerak di sini punya aturan berbeda:
        /// denyut kontinu punya `TimelineView`-nya sendiri, sementara isi
        /// panel harus tetap tampil sama persis saat denyut mati. Kalau isi
        /// panel ikut hidup di dalam `TimelineView`, mematikan denyut berarti
        /// mematikan panel — dan panel adalah **jawaban**, bukan hiasan.
        private func content(pulse currentPulse: Double) -> some View {
            HStack(alignment: .center, spacing: 16) {
                CelestialVisualView(visual: visual,
                                     diameter: 132,
                                     // Bukan `!isStale`: `.uncertain`
                                     // bukan sisa, tapi engine kurang
                                     // yakin — gambar tidak boleh lebih
                                     // yakin daripada badge "Ragu" di
                                     // sebelahnya.
                                     isConfirmed: isConfirmed,
                                     // Gerbang `hasPulse` **di sini juga**,
                                     // bukan hanya di kondisi `TimelineView`
                                     // di atas. Kondisi itu ada agar
                                     // `TimelineView` tidak dibangun untuk
                                     // planet; gerbang ini ada agar
                                     // `Canvas` tidak digambar ulang oleh
                                     // denyut. Kalau cabang di atas diubah
                                     // orang lain, baris ini tetap menjaga
                                     // invariannya — gerbangnya menempel
                                     // pada pemanggilan, bukan pada cabang
                                     // yang bisa dihapus tanpa jejak.
                                     // Dijaga Aturan 21 di `swift-ui-lint.sh`.
                                     pulse: visual.hasPulse ? currentPulse : 0)
                // Nama + jenis digabung jadi satu pengumuman VoiceOver,
                // dengan penanda **sisa** ikut terbawa — tanpa itu, objek
                // basi terdengar persis seperti hasil pengukuran sekarang.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // Nama = informasi utama: paling besar.
                        Text(object.name)
                            .font(.title2.bold())
                        // Badge keyakinan — permukaan yang **sama** dengan app
                        // jam, memakai `level.tone` yang sama. Ia hanya muncul
                        // untuk jawaban yang berlaku sekarang: pada objek sisa,
                        // "Yakin" di sebelahnya terbaca sebagai klaim keyakinan
                        // atas pengukuran sekarang — persis false confidence
                        // yang dilarang PRD.
                        if let level, !isStale {
                            Text(level.displayName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(level.tone.badgeFillColor, in: .capsule)
                                .foregroundStyle(level.tone.color)
                        }
                    }
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
                            DiagnosticsView.detailRow(DiagnosticsText.rowMagnitude,
                                                        NumberFormat.decimal(object.magnitude,
                                                                             fractionDigits: 2))
                            if object.kind == .star {
                                DiagnosticsView.detailRow(DiagnosticsText.rowRightAscension,
                                                          NumberFormat.degrees(object.raDeg,
                                                                               fractionDigits: 4))
                                    .accessibilityLabel(RowSpeech.label(
                                        title: DiagnosticsText.rowRightAscension,
                                        value: RowSpeech.spokenDegrees(object.raDeg, precision: 4)))
                                DiagnosticsView.detailRow(DiagnosticsText.rowDeclination,
                                                            NumberFormat.signedDegrees(object.decDeg))
                                    .accessibilityLabel(RowSpeech.label(
                                        title: DiagnosticsText.rowDeclination,
                                        value: RowSpeech.spokenDegrees(object.decDeg, precision: 4)))
                            }
                            DiagnosticsView.detailRow(DiagnosticsText.rowCatalogueId, object.id)
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
                    includeTechnicalDetails: false,
                    visual: visual,
                    isConfirmed: isConfirmed,
                    level: level))
            }
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
                                  includeTechnicalDetails: Bool = true,
                                  visual: CelestialVisual? = nil,
                                  // Nilai bawaan `false`, bukan `true` — sama
                                  // seperti `CelestialVisualView.isConfirmed`.
                                  // Yang dipengaruhi parameter ini adalah
                                  // **bentuk yang diucapkan** (galaksi vs
                                  // gugus bola): dengan `true`, pemanggil
                                  // yang lupa akan mengucapkan bentuk yang
                                  // persis sedang disembunyikan gambarnya.
                                  // Dijaga `Aturan 18`.
                                  isConfirmed: Bool = false,
                                  level: ConfidenceLevel? = nil) -> String {
        var parts = [object.name]
        // Tingkat keyakinan ikut diucapkan, sama seperti badge-nya ikut
        // digambar. Keduanya memakai ambang yang sama (`!stale`): pada objek
        // sisa, "Yakin" di sebelahnya terdengar sebagai klaim keyakinan atas
        // pengukuran sekarang — persis false confidence yang dilarang PRD.
        // `nil` berarti tidak ada yang boleh diklaim (keadaan tanpa jawaban),
        // bukan "ragu".
        if let level, !stale {
            parts.append(ObjectSpeech.confidence(level))
        }
        parts.append(object.kind.spokenName)
        // Fase Bulan: satu-satunya informasi di panel ini yang **hanya** bisa
        // dilihat. Bentuk sabit/cembung/purnama tampil sebagai gambar, dan
        // "Bulan" tidak mengatakan apa-apa tentang bentuknya. Jenis lain
        // sengaja tidak dideskripsikan gambarannya — lihat catatan di atas.
        // `spokenPhase` mengembalikan `nil` untuk bukan-Bulan dan untuk fase
        // yang tidak diketahui, jadi tidak ada fase yang ditebak di sini.
        // `spokenPhase` mengembalikan `nil` untuk bukan-Bulan, untuk fase
        // yang tidak diketahui, **dan saat engine ragu** — fase adalah ciri
        // pengenal, jadi tidak diucapkan saat gambar memakai piringan netral.
        if let phase = visual?.spokenPhase(isConfirmed: isConfirmed) {
            parts.append(phase)
        }
        // Bentuk objek langit dalam — lihat catatan panjang di
        // `spokenDeepSkyMorphology`. Ini kategori yang sama dengan fase Bulan:
        // satu-satunya informasi di panel ini yang **hanya** bisa dilihat
        // (bentuk galaksi vs gugus bola vs gugus terbuka), dan jenisnya
        // ("objek langit jauh") tidak membedakan satu pun dari yang lain.
        // `isConfirmed` diteruskan supaya pengumuman **cocok dengan gambar**:
        // saat engine ragu, gambar memakai kabut netral, jadi bentuknya juga
        // tidak boleh diucapkan.
        if let morphology = visual?.spokenDeepSkyMorphology(isConfirmed: isConfirmed) {
            parts.append(morphology)
        }
        // Warna spektral bintang — lihat catatan panjang di `StarColorSpeech`.
        // Ini kategori yang sama dengan fase Bulan: satu-satunya informasi di
        // panel ini yang **hanya** bisa dilihat (warna titik dari indeks B−V),
        // dan jenisnya ("bintang") tidak membedakan satu pun bintang dari
        // yang lain. Tanpa ini, "Rigel" dan "Betelgeuse" terdengar sama
        // persis padahal di layar keduanya digambar biru vs merah.
        // `spokenStarColor` mengembalikan `nil` untuk bukan-bintang **dan**
        // saat engine belum yakin — warna adalah ciri pengenal, jadi tidak
        // ada warna yang ditebak di sini.
        if let color = visual?.spokenStarColor(isConfirmed: isConfirmed) {
            parts.append(color)
        }
        if includeTechnicalDetails {
            parts.append(ObjectSpeech.magnitude(object.magnitude))
        }
        if stale {
            parts.append(ObjectSpeech.staleNote)
        }
        return parts.joined(separator: ". ")
    }
}
