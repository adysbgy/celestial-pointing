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
    /// Pemasok lokasi: dibutuhkan supaya penolakan izinnya bisa ditampilkan
    /// (lihat `location.note`), bukan diam.
    @ObservedObject var location: LocationProvider

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
                    // Putusan GoTo: mengapa teleskop boleh / tidak boleh
                    // bergerak. `SlewPlanner` sudah menghitungnya sejak FASE 3,
                    // tapi tidak satu layar pun pernah membacanya — jadi
                    // penolakan karena Matahari (melindungi alat & mata) dan
                    // penolakan karena keyakinan rendah terlihat sama: tidak
                    // terlihat. `nil` saat aman, jadi baris ini tidak pernah
                    // berbunyi di sebelah GoTo yang justru berjalan.
                    SlewVerdictBanner(decision: engine.slewVerdict)
                    if let note = motion.unavailableReason ?? engine.sensorNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(PointingTone.danger.color)
                            .multilineTextAlignment(.center)
                    }
                    // Izin lokasi ditolak (atau gagal) **harus terlihat**, bukan
                    // diam: engine tetap jalan dengan lokasi darurat, tapi
                    // pengguna berhak tahu bahwa langit dihitung untuk Jakarta,
                    // bukan tempatnya. `note` ini `nil` saat normal — beda dari
                    // `statusText` yang memakai teks netral — jadi menampilkannya
                    // tidak pernah memunculkan pesan menakutkan saat segalanya
                    // beres.
                    if let note = location.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(PointingTone.warning.color)
                            .multilineTextAlignment(.center)
                    }
                    // Peringatan ini harus muncul tepat saat lokasinya BUKAN
                    // hasil pengukuran. Dibandingkan lewat `isFallback`, bukan
                    // lewat string `source` apa adanya: string itu bisa berubah
                    // di `LocationProvider` tanpa ada yang ingat memeriksanya,
                    // dan perbandingan mentah akan **membalik** peringatan ini
                    // diam-diam — memperingatkan justru saat lokasi sungguhan.
                    if engine.location.isFallback {
                        Text(TextLocalization.text(.pointingLocationFallbackPrefix,
                                                  engine.location.label))
                            .font(.caption2)
                            .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                    }
                    linkRow
                    // Alat riset (ADR-004). Sengaja di ujung gulir, bukan di
                    // toolbar: ia bukan bagian alur produk, tapi harus bisa
                    // dicapai di build perangkat tanpa flag khusus.
                    NavigationLink {
                        PointingLabView(engine: engine, motion: motion, link: link)
                    } label: {
                        Label("Lab Pointing", systemImage: "flask")
                    }
                    .font(.footnote)
                }
                .padding(.horizontal, 2)
            }
            // Tanpa judul di layar akar jam: empat ikon toolbar sudah memenuhi
            // baris atas, dan judulnya terpotong jadi "Point & K…" (SE 40 mm,
            // Ultra 3). Nama app sudah tampil di peluncur dan di VoiceOver.
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
                    .accessibilityLabel(TextLocalization.text(.pointingSkyContextLabel))
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
                                        ? TextLocalization.text(.pointingCalibrationInstalled)
                                        : TextLocalization.text(.pointingCalibrationNotInstalled))
                }
                // Mode Malam: 1 ketuk. Ikon bulan berubah jadi bulan-terselubung
                // saat aktif supaya keadaannya terbaca tanpa warna.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nightMode.toggle()
                    } label: {
                        Image(systemName: nightMode ? "moon.fill" : "moon")
                    }
                    .accessibilityLabel(nightMode
                                        ? TextLocalization.text(.pointingNightModeOn)
                                        : TextLocalization.text(.pointingNightModeOff))
                }
                // Bunyi saat kunci: 1 ketuk. Default nyala (aksesibilitas
                // multi-modal), bisa dimatikan bila mengganggu.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        audioCueEnabled.toggle()
                    } label: {
                        Image(systemName: audioCueEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(audioCueEnabled
                                        ? TextLocalization.text(.pointingAudioCueOn)
                                        : TextLocalization.text(.pointingAudioCueOff))
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
            // Kalimatnya datang dari `StateAnnouncement` (PointingKit), bukan
            // dari `switch` di sini. Dulu ia hidup sebagai literal di view ini,
            // dan itu berarti (a) katalog string tidak bisa menjangkaunya, jadi
            // pengguna Bahasa Inggris mendengar kalimat Indonesia, dan (b)
            // iPhone — yang kini mengumumkan hal yang sama — harus menyalin
            // kalimatnya, dengan dua versi kebenaran sebagai hasilnya.
            AccessibilityNotification.Announcement(
                StateAnnouncement.text(for: engine.snapshot)).post()
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
            Text(engine.snapshot.guidanceText)
                .font(.caption)
                .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let rate = engine.snapshot.angularRateDegPerSec {
                Text(NumberFormat.degreesPerSecond(rate, fractionDigits: 0))
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
        var parts = [RowSpeech.stateLine(state), engine.snapshot.guidanceText]
        if let rate = engine.snapshot.angularRateDegPerSec {
            // Bentuk kalimat utuh dari katalog, lewat aksesornya — bukan
            // pemanggilan kunci yang ditulis ulang di sini. Alasannya bukan
            // cuma terjemahan: menyisipkan kata "derajat" sebagai literal
            // memaksa Bahasa Inggris mengucapkan "derajat", dan "%0.f derajat"
            // adalah kehendak Bahasa Indonesia yang tidak bisa dinyatakan
            // sebagai angka polos.
            //
            // Dan `spokenWristRate` ada justru supaya **kalimat ini bisa
            // diuji di Linux**. Versi sebelumnya merakitnya sendiri di view,
            // jadi tidak ada satu pun uji yang bisa memverifikasi apa pun
            // tentang kalimat yang diucapkan ini. Yang tersisa di view hanya
            // keputusan "kapan parts.append" — keputusan yang memang milik view.
            parts.append(RowSpeech.spokenWristRate(rate))
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Baris tautan iPhone

    private var linkRow: some View {
        HStack(spacing: 4) {
            Image(systemName: link.isReachable ? "iphone.gen3.radiowaves.left.and.right" : "iphone.slash")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(TextLocalization.text(link.isReachable
                                      ? .pointingLinkConnected
                                      : .pointingLinkDisconnected))
                .font(.caption2)
            if link.sendFailureCount > 0 {
                Text(TextLocalization.text(.pointingLinkFailures,
                                           Int64(link.sendFailureCount)))
                    .font(.caption2)
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
        .foregroundStyle(SurfacePalette.active.textSecondaryColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(linkAccessibilityLabel)
    }

    private var linkAccessibilityLabel: String {
        // Keseluruhan kalimat, termasuk bagian jumlah kegagalan, **disusun di
        // `LinkStatusText`** — bukan di sini.
        //
        // Versi sebelumnya merakitnya sendiri:
        //
        // ```swift
        // var text = link.isReachable ? "iPhone terhubung" : "iPhone tidak terjangkau"
        // text += LinkStatusText.sendFailures(link.sendFailureCount)
        // ```
        //
        // Dua cacat sekaligus. Yang pertama, literal pertamanya tidak pernah
        // melewati katalog — dan tidak ada gerbang yang melihatnya: bukan
        // argumen `Text(...)` (Aturan 4), bukan penugasan ke properti
        // berakhiran Note/Label (Aturan 12), dan bukan literal peritel
        // aksesibilitas mana pun (Aturan 16 dibuat untuk kelas ini). Yang
        // kedua, `text += …` memaku urutan di kode, sehingga bahasa yang
        // ingin meletakkan jumlah sebelum kata "gagal" tidak bisa mengatakannya.
        //
        // Yang membuatnya bertahan lama: **baris yang ditampilkan di atasnya
        // sudah benar.** `linkRow` memakai
        // `TextLocalization.text(.pointingLinkConnected)` — teks yang sama,
        // punya kunci, ada Bahasa Inggrinya. Jadi komponennya terlihat benar
        // di layar, dan yang salah cuma kalimat yang dibacakan.
        LinkStatusText.linkSpeech(isReachable: link.isReachable,
                                  sendFailureCount: link.sendFailureCount)
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
    ///
    /// **Nilai bawaan `false`, bukan `true`** — alasan yang sama dengan
    /// `CelestialVisualView.isConfirmed`: nilai bawaan adalah jawaban untuk
    /// pemanggil yang lupa meneruskan keyakinan, dan arah kelalaian yang
    /// salah harus memihak ke "terlalu hati-hati". Dijaga `Aturan 18`.
    var isConfirmed: Bool = false
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

    /// Pengguna meminta reduksi gerak.
    ///
    /// `NightAwareContainer` sudah mematikan animasi saat layar redup, dan itu
    /// bentuk lain dari aturan yang sama — dua bentuk gerak, satu ambang.
    /// Yang belum ada sebelum unit ini adalah sisi **pengguna**: pengguna yang
    /// menyalakan Reduce Motion akan tetap melihat kartu memompa setiap kali
    /// kunci baru, karena layar jam normal tidak pernah membaca preferensi itu.
    ///
    /// `MotionPolicy` di `PointingKit` yang memutuskan — teruji di Linux, dan
    /// dipakai iPhone juga, supaya kedua app tidak bisa berbeda pendapat.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Scene sedang aktif (terlihat di layar).
    ///
    /// Dibaca supaya `motion` di bawah jujur. Denyut itu sendiri dikelola
    /// `PulsingCelestialVisual`, yang punya `scenePhase`-nya sendiri.
    @Environment(\.scenePhase) private var scenePhase

    private var motion: MotionPolicy {
        MotionPolicy(reduceMotion: reduceMotion,
                     // Layar redup tidak pernah mencapai kartu ini: saat
                     // `isLuminanceReduced` menyala, `NightAwareContainer`
                     // merender `ReducedLuminanceView` sebagai gantinya.
                     // `false` jadi jujur, bukan sekadar formalitas — kalau
                     // suatu saat kartu ikut dirender di layar redup, nilainya
                     // sudah ada dan tidak perlu ditebak.
                     isLuminanceReduced: false,
                     // Scene tidak aktif ikut mematikan denyut. Ini **alasan
                     // baterai**, bukan aksesibilitas (lihat `MotionPolicy`):
                     // denyut di latar belakang tidak pernah terlihat, jadi
                     // tidak ada yang dikorbankan.
                     isSceneActive: scenePhase == .active)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let visual {
                // Visual + denyutnya dipegang `PulsingCelestialVisual`: denyut
                // butuh `TimelineView`-nya sendiri (lihat komentar di sana),
                // dan kartu ini **tidak boleh** ikut hidup di dalamnya —
                // kartu adalah jawaban, bukan hiasan.
                PulsingCelestialVisual(visual: visual,
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
                                       isConfirmed: isConfirmed,
                                       motion: motion)
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
                            .background(level.tone.badgeFillColor,
                                        in: .capsule)
                            .foregroundStyle(level.tone.color)
                    }
                }
                Text(kindLine)
                    .font(.caption)
                    .foregroundStyle(SurfacePalette.active.textSecondaryColor)
                if isStale {
                    Text(TextLocalization.text(.objectDetailStaleNoteDisplay))
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
            // Dan hanya kalau pengguna tidak meminta reduksi gerak. Tanpa
            // baris ini, preferensi Reduce Motion di iPhone **tidak pernah**
            // berpengaruh di jam: `NightAwareContainer` hanya menangani
            // Always-On, dan layar jam normal berjalan 20 kali per detik
            // tanpa pernah membaca preferensi pengguna.
            guard motion.allowsTransitions else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                appearScale = 1.04
                appearOpacity = 1
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.08)) {
                appearScale = 1
            }
        }
        // Saat jam kembali aktif, jam denyut di-set ulang **sekali** — lihat
        // `PulsingCelestialVisual`, yang memegang denyutnya sendiri.
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
            parts.append(ObjectSpeech.confidence(level))
        }
        parts.append(kindAccessibilityLabel)
        if isStale {
            parts.append(ObjectSpeech.staleNote)
        }
        return parts.joined(separator: ". ")
    }

    private var kindAccessibilityLabel: String {
        // `spokenName`, bukan `displayName`: frasa "Objek langit dalam"
        // terdengar janggal saat diucapkan, jadi pengucapannya terpisah.
        var parts = [object.kind.spokenName]
        // Fase Bulan menyusul jenisnya, bukan menggantikannya: "bulan, sabit
        // muda" — jenis dulu, lalu bentuknya. Ini satu-satunya informasi di
        // panel jam yang **hanya** bisa dilihat: gambarnya menampilkan bentuk
        // fase, sedangkan `magnitudo` dan RA/Dec tidak memberi tahu apa pun
        // tentang bentuknya. `spokenPhase` mengembalikan `nil` untuk bukan
        // Bulan dan untuk fase yang tidak diketahui, jadi tidak ada yang
        // ditebak di sini.
        // Fase Bulan: satu-satunya informasi di panel ini yang **hanya** bisa
        // dilihat. Sama seperti warna bintang dan bentuk objek langit dalam di
        // bawahnya, fase adalah **ciri pengenal** — dan saat engine ragu gambar
        // memakai piringan netral, jadi suara tidak boleh mengucapkan fase.
        // `isConfirmed` diteruskan supaya pengumuman cocok dengan gambar, bukan
        // lebih yakin darinya. (Lihat `MoonPhaseSpeech`.)
        if let phase = visual?.spokenPhase(isConfirmed: isConfirmed) {
            parts.append(phase)
        }
        // Bentuk objek langit dalam: galaksi, gugus bola, gugus terbuka,
        // nebula. Sama alasannya dengan fase Bulan — gambarnya menampilkan
        // bentuk yang berbeda per jenis, dan `spokenName` ("objek langit
        // jauh") tidak membedakan satu pun dari yang lain. Tanpa ini, "Gugus
        // Ptolemy" dan "Gugus Hercules" terdengar sama persis padahal di
        // layar keduanya digambar berbeda. `spokenDeepSkyMorphology`
        // mengembalikan `nil` untuk bukan objek langit dalam, untuk id
        // yang tidak ada di katalog, **dan saat engine ragu** — jadi tidak
        // ada bentuk yang ditebak, dan pengumuman selalu cocok dengan gambar.
        if let morphology = visual?.spokenDeepSkyMorphology(isConfirmed: isConfirmed) {
            parts.append(morphology)
        }
        // Warna spektral bintang: titik digambar biru (Rigel), merah
        // (Betelgeuse), putih-biru (Sirius) dari indeks B−V, dan `spokenName`
        // ("bintang") tidak membedakan satu pun dari yang lain. Tanpa ini
        // kedua bintang di atas terdengar sama padahal di layar warnanya
        // bertolak belakang.
        //
        // `isConfirmed` diteruskan karena warna **adalah ciri pengenal**:
        // saat engine ragu, gambar memakai warna "tidak mengklaim" dan
        // ucapan tidak boleh menyebut warna apa pun. `nil` juga untuk
        // bukan-bintang, jadi tidak ada warna yang ditebak.
        if let color = visual?.spokenStarColor(isConfirmed: isConfirmed) {
            parts.append(color)
        }
        parts.append(ObjectSpeech.magnitude(object.magnitude))
        if object.kind == .star {
            parts.append(ObjectSpeech.coordinates(raDeg: object.raDeg,
                                                  decDeg: object.decDeg))
        }
        return parts.joined(separator: ", ")
    }

    /// Baris jenis untuk tampilan layar — **ringkas**, karena berdiri sendiri
    /// di bawah nama besar dan sudah tidak dibaca sebagai kalimat.
    ///
    /// Berbeda dari `speechLine` di atasnya, yang diucapkan dan karena itu
    /// memakai kata penuh ("magnitudo 1.4", "RA … derajat"). Baris ini memakai
    /// bentuk layar yang sudah punya bentuknya sendiri di katalog
    /// (`object.display.magnitude`, `object.display.coordinates`): "mag 1.4",
    /// "RA 101.3° Dec −16.7°". Keduanya dulu dirakit sebagai literal
    /// `String(format:)` di dalam view — yang lolos dari Aturan 4 (bukan
    /// argumen `Text`) dan Aturan 6 (tanpa kunci katalog), dan yang tidak
    /// terlihat salah karena angka dan derajat sama di semua bahasa.
    private var kindLine: String {
        var parts = [kindLabel]
        // Lewat aksesor `ObjectSpeech`, bukan pemanggilan kunci langsung.
        //
        // Aksesor itu dipindahkan ke paket **karena baris ini tidak bisa
        // diuji di Linux** — selama masih dirakit di view, tidak ada satu
        // pun uji yang bisa menyatakan bentuk yang benar. Kalau baris ini
        // menulis kuncinya sendiri, pemindahan itu jadi sia-sia: isi kunci
        // sama persis, semua gerbang hijau, dan tidak ada yang berubah —
        // persis kelas "terang tapi tidak hijau" yang repo ini hunts.
        parts.append(ObjectSpeech.magnitudeDisplay(object.magnitude))
        if object.kind == .star {
            parts.append(ObjectSpeech.coordinatesDisplay(raDeg: object.raDeg,
                                                         decDeg: object.decDeg))
        }
        return parts.joined(separator: " · ")
    }

    /// Label jenis untuk tampilan dan pengumuman — **satu sumber** untuk
    /// jam dan iPhone (`ObjectKindLabels`), jadi keduanya tidak bisa
    /// menampilkan nama berbeda untuk benda yang sama.
    private var kindLabel: String { object.kind.displayName }
}

/// Gambar benda langit beserta denyut glow-nya.
///
/// **Kenapa view terpisah, bukan `pulse:` langsung di kartu.** Denyut butuh
/// penyegaran per frame, dan itu **hanya** bisa diandalkan lewat `TimelineView`.
/// Membaca `Date()` di dalam `body` kartu tidak cukup: `CelestialVisual`
/// adalah `Equatable`, jadi selama terkunci pada satu bintang argumen kartu
/// tidak berubah antar sampel sensor — SwiftUI boleh melewati evaluasi ulang
/// `body`, dan `Date()` bukan dependensi yang bisa dilihatnya. Hasilnya bintang
/// yang diam: cacat yang sama, hanya berpindah tempat.
///
/// Dipisah dari kartu juga karena alasan yang sudah dipakai di app iPhone:
/// denyut dan isi panel punya aturan berbeda. Kalau kartu ikut hidup di dalam
/// `TimelineView`, mematikan denyut berarti mematikan kartu — dan kartu adalah
/// **jawaban**, bukan hiasan.
///
/// `motion` diterima dari kartu, bukan dihitung ulang di sini: satu sumber
/// aturan (`MotionPolicy` di `PointingKit`) untuk jam dan iPhone.
struct PulsingCelestialVisual: View {

    let visual: CelestialVisual
    let diameter: CGFloat
    let isConfirmed: Bool
    let motion: MotionPolicy

    /// Jam denyut. Di-set ulang **sekali** saat scene kembali aktif: tanpa itu
    /// fase melompat maju beberapa detik dalam satu frame, dan lompatan itu
    /// terbaca sebagai kedipan, bukan denyut — alasan yang sama dengan
    /// `resyncPulse` di app iPhone.
    @State private var pulseStart = Date()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            // Gerbang `hasPulse` bukan hiasan: `Canvas` digambar ulang setiap
            // kali nilai yang ditangkapnya berubah, jadi `pulse` yang bergerak
            // memaksa planet, Bulan, dan Matahari digambar ulang untuk piksel
            // yang identik — denyut hanya dibaca `drawStar`. `hasPulse` diuji
            // di Linux, jadi keputusan ini tidak bergantung pada daftar jenis
            // lokal yang bisa basi. Dijaga Aturan 21.
            if motion.allowsContinuousMotion && visual.hasPulse {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                    CelestialVisualView(visual: visual,
                                        diameter: diameter,
                                        isConfirmed: isConfirmed,
                                        // Gerbang `hasPulse` juga di sini, bukan
                                        // hanya di kondisi `if` di atas —
                                        // supaya invariannya menempel pada
                                        // pemanggilan dan tidak bisa hilang saat
                                        // kondisinya direfaktor. Dijaga Aturan 21.
                                        pulse: visual.hasPulse ? pulsePhase : 0)
                }
            } else {
                // Tanpa `TimelineView` denyut benar-benar berhenti, bukan
                // "cukup kecil". `pulsePhase` mengembalikan **nol persis** di
                // keadaan gated, jadi kedua cabang menghasilkan gambar yang
                // sama saat gerak mati.
                CelestialVisualView(visual: visual,
                                    diameter: diameter,
                                    isConfirmed: isConfirmed,
                                    pulse: 0)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            pulseStart = Date()
        }
    }

    /// Fase denyut dalam radian — **nol persis** saat denyut tidak boleh jalan.
    private var pulsePhase: Double {
        motion.pulsePhase(elapsedSeconds: Date().timeIntervalSince(pulseStart))
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
                // Judul baris ini adalah **nama barisnya** ("Langit"), bukan
                // nilainya. Dulu di sini `skyContextDark` ("Gelap") dipakai
                // sebagai judul *dan* sebagai salah satu nilai, sehingga
                // barisnya terbaca "Gelap: Gelap" — benar hanya karena
                // kebetulan, dan tidak pernah menyebut apa yang diukur.
                // `skyContextSkyLabel` memisahkan keduanya; dijaga Aturan 22.
                row(TextLocalization.text(.skyContextSkyLabel),
                    context.isDark ? TextLocalization.text(.skyContextDark)
                                   : TextLocalization.text(.skyContextLight))
                row(TextLocalization.text(.skyContextSun),
                    NumberFormat.degrees(context.sunAltitudeDeg, fractionDigits: 0))
                if let moonAlt = context.moonAltitudeDeg {
                    row(TextLocalization.text(.skyContextMoon),
                        NumberFormat.degrees(moonAlt, fractionDigits: 0))
                }
                if let fraction = context.moonIlluminationFraction {
                    row(TextLocalization.text(.skyContextMoonPhase),
                        NumberFormat.percent(fraction, fractionDigits: 0))
                }
            } else {
                Text(TextLocalization.text(.skyContextNotComputed))
            }
            Section(TextLocalization.text(.skyContextSection)) {
                row(TextLocalization.text(.skyContextCalibration),
                    engine.snapshot.isCalibrated
                        ? TextLocalization.text(.calibrationStatusAppliedShort)
                        : TextLocalization.text(.calibrationStatusNotAppliedShort))
                if let pointing = engine.pointing {
                    row(TextLocalization.text(.skyContextAzimuth),
                        NumberFormat.degrees(pointing.azimuthDeg))
                    row(TextLocalization.text(.skyContextAltitude),
                        NumberFormat.degrees(pointing.altitudeDeg))
                }
                row(TextLocalization.text(.skyContextLocation), engine.location.label)
                row(TextLocalization.text(.skyContextLocationSource),
                    engine.location.sourceDisplayName)
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
        // Bentuk kalimatnya dari `RowSpeech`, bukan dirangkai di sini: ini
        // adalah duplikat keempat dari `row(_:_:)` dengan format yang sama
        // persis, dan menyatukan sumbernya menutup kelas cacat ini.
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }
}
