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

    /// Preferensi mode malam, disimpan ke `UserDefaults` lewat `NightMode`.
    /// Satu ketukan membalik palet merah murni di seluruh layar (lihat
    /// `PointingTone.color` / `Color.nightAwareSecondary`).
    @AppStorage(NightModeStorage.key) private var nightMode = false
    /// Bunyi pendek saat engine mengunci — aksesibilitas multi-modal.
    /// Default nyala (lihat `AudioCue.isOn`); dimatikan via toolbar.
    @AppStorage(AudioCueStorage.key) private var audioCueEnabled = true

    /// Pengumuman perubahan keadaan untuk VoiceOver.
    ///
    /// Tanpa ini, pengguna yang memakai VoiceOver **tidak pernah tahu** kapan
    /// jam berhasil mengunci — padahal haptic "terkunci" adalah satu-satunya
    /// saluran yang tidak butuh mata, dan saluran itu tidak menjangkau mereka.
    /// Ini versi audio dari janji yang sama: keadaan yang berubah harus
    /// terdengar, bukan hanya terlihat.
    @State private var announcedState: PointingState?

    /// Ukuran ikon status, mengikuti Dynamic Type.
    ///
    /// `@ScaledMetric` — bukan angka tetap — supaya ikon dan teks mendapat
    /// tekanan yang sama saat pengguna memperbesar teks. `WatchMetrics.iconSize`
    /// memang diniatkan ikut scale (lihat komentarnya), dan ini cara
    /// mengaktifkannya tanpa memecah `WatchMetrics` yang dipakai sebagai
    /// constan di tempat lain.
    @ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 16

    var body: some View {
        // Saat layar redup (Always-On), watchOS mengabaikan sebagian gestur dan
        // meredupkan warna halus — jadi tampilan diganti versi sederhana &
        // kontras tinggi, bukan sekadar diredupkan. Pilihan ini dibuat di satu
        // tempat (`NightAwareContainer`) supaya tidak ada layar yang lupa.
        NightAwareContainer {
            fullView
        } reduced: {
            ReducedLuminanceView(engine: engine)
        }
    }

    private var fullView: some View {
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
                                         // `answeredLevel`, bukan `intent?.level`:
                                         // badge ini mengklaim keyakinan atas objek
                                         // yang ditampilkan, dan keyakinan hanya
                                         // berlaku bila keadaan punya jawaban.
                                         // `isStale` sudah menyembunyikannya pada
                                         // objek sisa; memakai predikat yang sama
                                         // membuat klaim itu tidak bisa bocor kalau
                                         // gerbang tampilannya berubah.
                                         level: engine.snapshot.answeredLevel,
                                         isStale: engine.isDisplayingStaleObject,
                                         // **Bukan** `!isStale`: `.uncertain`
                                         // punya jawaban tapi engine menyatakan
                                         // diri kurang yakin, dan `hasAnswer`
                                         // mencakupnya. Tanpa predikat ini,
                                         // selama ragu gambar menampilkan
                                         // seluruh ciri pengenal (cincin
                                         // Saturnus, pita Jupiter) sementara
                                         // badge di sebelahnya bertuliskan
                                         // "Ragu" — gambar lebih yakin daripada
                                         // teksnya, dan mata membaca gambar
                                         // lebih dulu. Lihat
                                         // `PointingSnapshot.confirmsIdentity`.
                                         // Visual dari sumber yang **sama** dengan
                                         // objeknya, jadi gambar tidak mungkin
                                         // milik benda lain.
                                         visual: engine.visualForDisplayedObject,
                                         isConfirmed: engine.confirmsDisplayedIdentity,
                                         // Token kedatangan kunci memicu animasi
                                         // "muncul" kartu **sekali** — bukan tiap
                                         // sampel 20 Hz selama terkunci, dan bukan
                                         // pada objek sisa. Lihat komentar di
                                         // `LockArrival`/`ObjectDetailView`.
                                         lockArrivalToken: engine.lockArrival?.token)
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
                            .font(.caption2)
                            .foregroundStyle(SurfacePalette.active.textSecondaryColor)
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
                    // Tombol berbasis ikon tidak punya teks, jadi tanpa label
                    // VoiceOver mengucapkan nama SF Symbol-nya ("info dot
                    // circle"), bukan maksud tombolnya.
                    .accessibilityLabel("Konteks langit dan ketelitian")
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
                    // Keadaan kalibrasi ikut diumumkan: ikon "scope" vs
                    // tanda-seru membedakan keduanya **hanya** secara visual,
                    // jadi pengguna VoiceOver tidak akan pernah tahu apakah
                    // jamnya sudah terkalibrasi — padahal pointing yang belum
                    // terkalibrasi adalah yang paling berbahaya untuk
                    // dipercaya.
                    .accessibilityLabel(engine.snapshot.isCalibrated
                                        ? "Kalibrasi, sudah terpasang"
                                        : "Kalibrasi, belum terpasang")
                }
                // Mode Malam: 1 ketuk. Ikon bulan berubah jadi bulan-terselubung
                // saat aktif supaya keadaannya terbaca tanpa warna.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nightMode.toggle()
                    } label: {
                        Image(systemName: nightMode ? "moon.fill" : "moon")
                    }
                    .accessibilityLabel(nightMode ? "Nonaktifkan Mode Malam" : "Aktifkan Mode Malam")
                }
                // Bunyi saat kunci: 1 ketuk. Default nyala (aksesibilitas
                // multi-modal), bisa dimatikan bila mengganggu.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        audioCueEnabled.toggle()
                    } label: {
                        Image(systemName: audioCueEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(audioCueEnabled ? "Nonaktifkan bunyi saat kunci" : "Aktifkan bunyi saat kunci")
                }
            }
        }
        // Latar aplikasi (gradien `#0A0A0F`/`#121216` bertingkat) digambar di
        // akar, dan skema dipaksa gelap supaya token permukaan yang sudah
        // diuji kontrasnya benar-benar muncul — bukan chrome sistem yang
        // berbalik terang di iPhone yang disetel terang. Mode malam (merah)
        // adalah lapisan di atas skema gelap ini, bukan penggantinya.
        .appBackground()
        .forceDarkScheme()
        // Umumkan **perubahan** keadaan, bukan tiap sampel 20 Hz.
        //
        // `announcedState` menyimpan keadaan terakhir yang diumumkan, jadi
        // pengumuman hanya terjadi saat keadaannya benar-benar berganti —
        // kalau tidak, VoiceOver akan mengucapkan "Terkunci" berpuluh kali per
        // menit dan menutupi semua hal lain yang ingin dibaca pengguna.
        .onChange(of: engine.snapshot.state) { _, newState in
            guard announcedState != newState else { return }
            announcedState = newState
            AccessibilityNotification.Announcement(announcementText(for: newState)).post()
        }
    }

    /// Teks yang diumumkan saat keadaan berubah.
    ///
    /// Kunci (`.lock`) diumumkan **dengan nama objeknya**, karena itulah
    /// satu-satunya momen yang ditunggu pengguna; mengumumkan "Terkunci" tanpa
    /// nama akan memaksanya mengusap layar untuk mencari tahu terkunci pada
    /// apa. Sebaliknya, kehilangan jawaban diumumkan sebagai "kehilangan" —
    /// bukan diam, karena diam di sini terbaca sebagai "masih terkunci".
    private func announcementText(for state: PointingState) -> String {
        switch state {
        case .lock:
            if let name = engine.snapshot.answeredObject?.name {
                return "Terkunci pada \(name)."
            }
            return "Terkunci."
        case .uncertain:
            return "Kurang yakin. \(state.guidance)"
        case .unavailable:
            return "Sensor mati. \(state.guidance)"
        case .idle, .pointing, .searching:
            return "\(state.shortLabel). \(state.guidance)"
        }
    }

    // MARK: - Kartu keadaan

    private var statusCard: some View {
        let state = engine.snapshot.state
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: state.symbolName)
                    .font(.headline)
                    .frame(width: statusIconSize, height: statusIconSize)
                    .foregroundStyle(state.tone.color)
                    // Simbolnya murni hiasan: label kartu di bawah sudah
                    // menyebut keadaannya. Tanpa baris ini VoiceOver
                    // mengucapkan nama berkas SF Symbol-nya.
                    .accessibilityHidden(true)
                Text(state.shortLabel)
                    .font(.headline)
                    .foregroundStyle(state.tone.color)
            }
            Text(state.guidance)
                .font(.caption)
                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let rate = engine.snapshot.angularRateDegPerSec {
                Text(String(format: "%.0f°/dtk", rate))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(rate > 8 ? PointingTone.warning.color
                                               : SurfacePalette.active.textSecondaryColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(WatchMetrics.cardPadding)
        .surfaceCard(level: .card, radius: WatchMetrics.cornerRadius)
        // Aksen tipis **hanya** di keadaan terkunci — satu-satunya momen yang
        // layak dirayakan, dan hanya di situ. Kalau aksen dipakai di semua
        // keadaan, "aktif" tidak berarti apa-apa; kalau dipakai di beberapa,
        // yang terpilih adalah yang benar.
        .overlay(alignment: .top) {
            if state == .lock {
                Capsule()
                    .fill(SurfacePalette.active.accentGradient)
                    .frame(height: 2)
                    .padding(.horizontal, 6)
            }
        }
        // Digabung jadi SATU elemen: tanpa `.combine`, VoiceOver membaca
        // simbol, label, panduan, dan laju sebagai empat item terpisah yang
        // harus diusap satu per satu — padahal keempatnya satu pengumuman.
        // Laju dibaca sebagai "laju pergelangan ... derajat per detik", bukan
        // "°/dtk" yang tak bermakna bagi pembaca layar.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityLabel)
    }

    /// Label kartu keadaan untuk VoiceOver.
    ///
    /// Sengaja tidak menyalin teks layar mentah: "°/dtk" tidak bermakna saat
    /// diucapkan, dan nama SF Symbol bukan kata yang bisa dibaca. Yang
    /// diumumkan adalah keadaan, panduannya, dan laju dengan satuannya.
    private var statusAccessibilityLabel: String {
        let state = engine.snapshot.state
        var parts = ["Keadaan: \(state.shortLabel).", state.guidance]
        if let rate = engine.snapshot.angularRateDegPerSec {
            parts.append(String(format: "Laju pergelangan %.0f derajat per detik.", rate))
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Baris tautan iPhone

    private var linkRow: some View {
        HStack(spacing: 4) {
            Image(systemName: link.isReachable ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau")
                .font(.caption2)
            if link.sendFailureCount > 0 {
                Text("· \(link.sendFailureCount) gagal")
                    .font(.caption2)
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
        .foregroundStyle(SurfacePalette.active.textSecondaryColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(linkAccessibilityLabel)
    }

    private var linkAccessibilityLabel: String {
        // Kegagalan kirim diumumkan, bukan hanya digambar: "· 3 gagal" tidak
        // terbaca sebagai kalimat bila digabung mentah.
        var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
        if link.sendFailureCount > 0 {
            text += ". \(link.sendFailureCount) kiriman gagal."
        }
        return text
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
    /// Model gambar untuk objek ini.
    ///
    /// Lewat parameter, bukan diambil dari engine di dalam view: panel ini
    /// sudah menerima `object` dari luar, jadi membaca sumber kedua membuat
    /// dua jalur yang bisa berbeda pendapat tentang benda mana yang sedang
    /// ditampilkan — dan gambar bisa jadi milik objek yang bukan yang
    /// tertulis di sebelahnya. `nil` → tidak ada gambar, bukan gambar generik.
    var visual: CelestialVisual?
    /// Apakah gambar boleh mengklaim identitas objek ini.
    ///
    /// Diterima dari luar (bukan `!isStale`), karena ambangnya **lebih ketat**
    /// daripada "bukan sisa": `.uncertain` punya jawaban, tapi engine
    /// menyatakan diri kurang yakin — dan pada keadaan itulah ciri pengenal
    /// (cincin Saturnus, pita Jupiter) paling berbahaya tampil, karena badge
    /// di sebelahnya justru bertuliskan "Ragu".
    var isConfirmed: Bool = true
    /// Diameter gambar dalam poin. Berbeda antara jam dan iPhone: kartu jam
    /// sempit, panel iPhone lega.
    var visualDiameter: CGFloat = WatchMetrics.visualDiameter
    /// Token kedatangan kunci (monoton, dari `LockArrival`).
    ///
    /// Dipakai memicu animasi "muncul" kartu. `LockArrival` sengaja memakai
    /// `Int` monoton (bukan `Date()`/`UUID()`) karena keduanya membuat setiap
    /// render menghasilkan nilai baru — dan itu justru membuat animasi diputar
    /// ulang terus-menerus. `nil` berarti "belum pernah terkunci" — `.onChange`
    /// di bawah mengabaikannya, jadi kartu tidak beranimasi saat membuka app
    /// di atas objek sisa, dan tidak memperingati keadaan yang sudah tidak
    /// berlaku (kelas false confidence).
    var lockArrivalToken: Int?

    /// Skala & opasitas untuk pop saat kunci baru tiba.
    ///
    /// Dipisah dari `lockArrivalToken` supaya animasinya hanya berjalan saat
    /// token **naik** (kedatangan kunci baru), bukan saat kembali `nil`
    /// (kunci dilepas → objek jadi sisa). Kalau memakai `.id(token)` langsung,
    /// identitas kartu berubah juga saat token jadi `nil`, sehingga kartu
    /// "dirayakan" kembali tepat saat jawabannya tidak lagi berlaku — justru
    /// yang dilarang PRD.
    @State private var appearScale: CGFloat = 1
    @State private var appearOpacity: Double = 1

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let visual {
                CelestialVisualView(visual: visual,
                                     diameter: visualDiameter,
                                     // Ambang ini **bukan** `!isStale`.
                                     // `.uncertain` punya jawaban (jadi bukan
                                     // sisa), tapi engine menyatakan diri
                                     // kurang yakin — dan pada keadaan itulah
                                     // gambar paling berbahaya: ia menampilkan
                                     // seluruh ciri pengenal sementara badge
                                     // di sebelahnya bertuliskan "Ragu". Mata
                                     // membaca gambar lebih dulu daripada
                                     // badge, jadi gambar tidak boleh lebih
                                     // yakin daripada teksnya.
                                     isConfirmed: isConfirmed)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(object.name)
                        // Nama benda adalah **informasi utama**: harus jadi yang paling besar dan
                        // tebal di kartu, karena inilah yang dicari pengguna.
                        .font(.title3.bold())
                    Spacer(minLength: 2)
                    // Badge keyakinan hanya untuk jawaban yang berlaku sekarang.
                    // Pada objek sisa, menampilkan "Yakin" di sebelahnya akan
                    // terbaca sebagai klaim keyakinan atas pengukuran sekarang —
                    // persis false confidence yang dilarang PRD.
                    if let level, !isStale {
                        Text(level.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(level.tone.color.opacity(0.2),
                                        in: .capsule)
                            .foregroundStyle(level.tone.color)
                    }
                }
                Text(kindLine)
                    .font(.caption)
                    .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                if isStale {
                    Text("Sisa pandangan sebelumnya — bukan hasil sekarang")
                        .font(.caption2)
                        .foregroundStyle(PointingTone.warning.color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WatchMetrics.cardPadding)
        .surfaceCard(level: .card, radius: WatchMetrics.cornerRadius)
        // Animasi halus saat kunci baru tiba: kartu memudar + sedikit
        // membesar lewat spring. Dipicu oleh `lockArrivalToken` yang **naik**,
        // bukan oleh `state == .lock`: kalau memakai keadaan, kartu berkedip
        // tiap sampel 20 Hz selama terkunci, dan objek sisa (yang
        // dipertahankan mesin keadaan) ikut "dirayakan". `LockArrivalGate`
        // sudah menyaring kedua kasus itu — token hanya naik saat ada
        // **kedatangan kunci baru** dengan objek yang berlaku sekarang.
        // `onChange` di bawah memainkan pop **sekali** saat token berubah, dan
        // mengabaikan saat token kembali `nil` (kunci dilepas), supaya kita
        // tidak merayakan jawaban yang sudah tidak berlaku.
        .scaleEffect(appearScale)
        .opacity(appearOpacity)
        .onChange(of: lockArrivalToken) { oldToken, newToken in
            // Hanya pop saat ada kedatangan baru (token naik dari nilai
            // sebelumnya), bukan saat kembali ke `nil`.
            guard let new = newToken, new != oldToken else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                appearScale = 1.04
                appearOpacity = 1
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.08)) {
                appearScale = 1
            }
        }
        // Satu elemen, karena nama + jenis + magnitudo + badge adalah satu
        // pengumuman. Yang paling penting di sini: **penanda sisa ikut
        // diucapkan**. Pengguna VoiceOver tidak melihat teks peringatannya,
        // jadi tanpa ini objek dari pandangan sebelumnya terdengar persis
        // seperti hasil pengukuran sekarang — false confidence dalam bentuk
        // audio, yang sama bentuknya dengan versi visualnya.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detailAccessibilityLabel)
    }

    /// Label panel objek untuk VoiceOver.
    ///
    /// `mag`, `RA`, dan `Dec` diucapkan lengkap ("magnitudo", bukan "mag"):
    /// singkatan yang hanya masuk akal secara visual tidak terbaca.
    private var detailAccessibilityLabel: String {
        var parts = [object.name]
        if let level, !isStale {
            parts.append("tingkat keyakinan \(level.displayName)")
        }
        parts.append(kindAccessibilityLabel)
        if isStale {
            parts.append("Sisa pandangan sebelumnya, bukan hasil sekarang.")
        }
        return parts.joined(separator: ". ")
    }

    private var kindAccessibilityLabel: String {
        // `spokenName`, bukan `displayName`: frasa "Objek langit dalam"
        // terdengar janggal saat diucapkan, jadi pengucapannya terpisah.
        var parts = [object.kind.spokenName]
        parts.append(String(format: "magnitudo %.2f", object.magnitude))
        if object.kind == .star {
            parts.append(String(format: "RA %.1f derajat, deklinasi %+.1f derajat",
                                object.raDeg, object.decDeg))
        }
        return parts.joined(separator: ", ")
    }

    private var kindLine: String {
        var parts = [kindLabel]
        parts.append(String(format: "mag %.2f", object.magnitude))
        if object.kind == .star {
            parts.append(String(format: "RA %.1f° Dec %+.1f°", object.raDeg, object.decDeg))
        }
        return parts.joined(separator: " · ")
    }

    /// Label jenis untuk tampilan dan pengumuman — **satu sumber** untuk
    /// jam dan iPhone (`ObjectKindLabels`), jadi keduanya tidak bisa
    /// menampilkan nama berbeda untuk benda yang sama.
    private var kindLabel: String { object.kind.displayName }
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
            Text(value).foregroundStyle(SurfacePalette.active.textSecondaryColor)
        }
        .font(.subheadline)
        // Baris "judul … nilai": tanpa penggabungan, VoiceOver membacanya
        // sebagai dua elemen terpisah tanpa hubungan — "Matahari" lalu
        // "-12" tanpa konteks apa yang diukur.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
