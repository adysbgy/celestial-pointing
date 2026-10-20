import SwiftUI
import CelestialEngine
import PointingKit

/// Visual prosedural untuk benda langit — **tanpa aset eksternal**.
///
/// Kenapa procedural, bukan gambar: aset bitmap berarti hak cipta, lisensi,
/// dan berkas yang harus ikut bertambah saat ukurannya berubah. Yang digambar
/// di sini semuanya primitif vektor (`Canvas`), jadi ukurannya mengikuti
/// Dynamic Type dan tetap tajam di setiap layar.
///
/// **Yang tidak ada di berkas ini: logika.** Warna bola, sudut terminator,
/// indeks warna bintang, dan pemilihan ciri pengenal planet semuanya datang
/// dari `CelestialVisual` di `PointingKit`, yang teruji di Linux. Berkas ini
/// hanya menerjemahkan model itu menjadi piksel. Kalau sebuah keputusan visual
/// bisa salah tanpa ada yang bisa mengujinya, keputusan itu **tidak boleh ada
/// di sini** — itu sebabnya palet planet dipindahkan ke `PointingKit`, bukan
/// tetap sebagai enum warna lokal.
///
/// **Semua warna membaca `NightMode.isOn`**, jadi mode malam benar-benar
/// merah murni — termasuk pada gambar, bukan hanya pada teks.
struct CelestialVisualView: View {

    let visual: CelestialVisual
    /// Ukuran gambar dalam poin.
    let diameter: CGFloat
    /// Apakah engine yakin terhadap identitas ini.
    ///
    /// Saat `false`, gambar disamar (tanpa ciri pengenal) dan tanda tanya
    /// digambar di atasnya. Ini bukan sekadar gaya: PRD melarang visual yang
    /// **menglaim identitas** saat engine ragu. Cincin Saturnus di atas planet
    /// yang mungkin saja Jupiter adalah klaim itu — dan ia lebih berbahaya
    /// daripada teks, karena gambar tidak pernah mengajak pengguna membacalah
    /// huruf kecilnya.
    ///
    /// **Kenapa nilai bawaan `false`, bukan `true`.** Nilai bawaan adalah
    /// jawaban untuk pemanggil yang **lupa** — dan pemanggil yang lupa
    /// persis yang tidak pernah dieksekusi oleh mata, karena tidak ada
    /// argumen untuk dibaca. Dengan `true`, layar baru yang dibuat tanpa
    /// meneruskan keyakinan akan langsung menggambar seluruh ciri pengenal
    /// sementara badge di sebelahnya bertuliskan "Ragu". Dengan `false`,
    /// kelalaian yang sama berujung pada gambar yang disamar: terlalu hati-
    /// hati, bukan terlalu yakin. Arah yang salah dari dua-duanya sudah
    /// ditetapkan PRD ("uncertainty > false confidence"), jadi nilai bawaan
    /// harus memihak ke arah itu.
    ///
    /// Dijaga `Aturan 18` di `swift-ui-lint.sh`: nilai bawaan `true` pada
    /// nama seperti ini tidak bisa dikompilasi ulang tanpa gerbang merah.
    var isConfirmed: Bool = false

    /// Fase denyut glow, dalam radian.
    ///
    /// Diberi dari luar, bukan dihitung sendiri di sini: supaya jam bisa
    /// menghentikan denyut saat layar redup, dan iPhone bisa menghentikannya
    /// saat layar tidak aktif — tanpa view ini perlu tahu soal Always-On.
    var pulse: Double = 0

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            drawBody(context: context, center: center, radius: radius)
            if !isConfirmed { drawCandidateMarker(context: context, size: size) }
        }
        .frame(width: diameter, height: diameter)
        // **Samaran, bukan hanya lencana.**
        //
        // Saat engine belum pasti, ciri pengenal sudah ditahan
        // (`drawable(isConfirmed:)`, Aturan 50/51) — tetapi yang tersisa
        // adalah cakram/kabut kosong yang masih berbentuk benda langit pasti,
        // dan lencana tanda tanya duduk di **sudut**, sementara mata membaca
        // bentuk lebih dulu. Samaran memakai `DrawingGroup` dengan
        // `rasterize` sebab filter `blur` butuh raster: lapisan ini memuat
        // dirinya sendiri, difilter, lalu dipasang kembali.
        //
        // **Kenapa hanya saat `!isConfirmed`.** Rasterisasi memaksa frame
        // fokus sendiri dan menggeser anti-aliasing glow; gambar yang sudah
        // pasti tidak boleh membayar itu. Dan jenisnya dibaca dari model
        // (`UncertainBlur.allows`), bukan dicabang di sini: Bulan dikecualikan
        // karena sabitnya fakta tanggal yang wajib bertahan saat ragu
        // (`check_moon_phase_survives_uncertainty`), bintang & Matahari
        // karena warna sudah menyamar dan blur pada 38 pt hanya menghapusnya.
        //
        // **Kenapa `.linear`, bukan bawaan `sRGB`.** Dua kelompok di layar ini
        // — "engine ragu" (baru) dan "engine yakin" (sudah ada) — memutuskan
        // penyamaran dari predikat yang sama (`isConfirmed || allows`). Kalau
        // satu jalur merasterisasi dalam ruang warna berbeda dari jalur lain,
        // gambar yang sudah yakin pun berubah warnanya **hanya** karena ada
        // kelompok kedua di layar yang butuh rasterisasi — cacat yang tidak
        // bisa dibaca dari kode dan tidak bisa ditangkap uji di Linux.
        // `.linear` membuat rasterisasi itu tidak mengubah piksel sama sekali.
        // `drawingGroup(...)` sudah merasterisasi, jadi `blur` di bawahnya
        // tidak menambah biaya lapisan kedua. Parameter ketiga
        // (`rendersAsynchronously:`) **tidak ada** di `drawingGroup` — ia milik
        // `Canvas`; menambahkannya adalah galat kompilasi yang hanya muncul di
        // runner macOS, karena Linux tidak membangun `Apps/`.
        .drawingGroup(opaque: false, colorMode: .linear)
        .opacity(isConfirmed || UncertainBlur.allows(visual.kind)
                 ? 1
                 : Self.uncertainBlurOpacity)
        .blur(radius: isConfirmed || UncertainBlur.allows(visual.kind)
              ? 0
              : Self.uncertainBlurRadius(diameter: diameter))
        // Grafis tidak pernah diumumkan sebagai teks — VoiceOver membaca nama
        // objek & keyakinannya (lihat `ObjectDetailView`), dan menambah
        // deskripsi gambar hanya menambah yang harus dilalui pengguna.
        .accessibilityHidden(true)
    }

    private func drawBody(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        switch visual.kind {
        case .planet: drawPlanet(context: context, center: center, radius: radius)
        case .moon: drawMoon(context: context, center: center, radius: radius,
                             isConfirmed: isConfirmed)
        case .star: drawStar(context: context, center: center, radius: radius)
        case .sun:
            // Corona menjangkau `sunCoronaReach` × radius, jadi piringan
            // Matahari **harus** menyusut agar halo muat di frame. Kalau
            // piringan memenuhi frame, `Canvas` memotong corona dan yang
            // tampak kembali jadi disk terang tanpa glow — cacat yang siklus
            // ini tutup. Konstanta dibaca dari model (sama seperti port
            // Python), bukan diketik di sini.
            drawSun(context: context, center: center,
                    radius: radius / CGFloat(VisualFrame.sunCoronaReach))
        case .deepSky:
            // Keyakinan diteruskan: bentuk adalah ciri pengenal, sama seperti
            // cincin Saturnus. Lihat `DeepSkyCatalogue.drawableMorphology`.
            drawDeepSky(context: context, center: center, radius: radius,
                        isConfirmed: isConfirmed)
        }
    }

    // MARK: - Warna sadar mode malam

    /// Ubah komponen warna mentah dari model menjadi `Color` yang hormat mode
    /// malam.
    ///
    /// **Kenapa kecerahan diambil dari `nightModeBrightness`, bukan `luminance`.**
    /// Mode malam membuang hue (paksa merah), jadi yang harus bertahan adalah
    /// **urutan terang** — planet yang tadinya paling terang tetap paling
    /// terang, kalau tidak setiap planet berubah menjadi satu merah rata dan
    /// mode malam justru menghilangkan informasi yang bisa dibaca.
    ///
    /// Dan "paling terang" itu harus diukur dalam **kanal merah**, bukan
    /// luminance penuh. Luminance penuh menghitung hijau dan biru yang
    /// tidak akan pernah sampai ke mata di mode malam — dan mengatakannya
    /// membuat Merkurius (abu terang) tampak lebih terang dari Mars
    /// (merah), membalik urutan yang benar. Aturan ini sudah tinggal di
    /// model (`CelestialVisual.RGBComponents.nightModeBrightness`) dan
    /// diuji di Linux; di sini tidak ada angka warna sendiri.
    /// **Satu-satunya** tempat warna gambar diubah menjadi warna SwiftUI, dan
    /// satu-satunya tempat mode malam diterapkan.
    ///
    /// Kenapa hanya satu: versi sebelumnya punya tiga pintasan terpisah
    /// (`color`, `accent`, `shadowAccent`), masing-masing memanggil
    /// pemetaan malamnya sendiri. Itu memungkinkan pemetaan **dua
    /// kali** -- dan pemetaan tidak idempoten. Dihitung: piringan gelap
    /// bulan dipetakan ke kanal merah 0,047; kalau peta itu dijalankan lagi
    /// sebagai permukaan, hasilnya 0,357 -- hampir delapan kali lebih terang,
    /// tanpa ada yang menulis angka baru pun. Kecerahan bergeser
    /// tanpa ada yang menulis angka baru pun, jadi cacat seperti ini
    /// tidak akan pernah terlihat dari membaca kode.
    ///
    /// Perannya dinyatakan sebagai argumen, bukan lewat pintasan terpisah,
    /// supaya "terlalu gelap ikut dipetakan seperti permukaan" tidak bisa
    /// ditulis.
    private static func color(_ raw: CelestialVisual.RGBComponents,
                              isShadow: Bool = false) -> Color {
        guard NightMode.isOn else {
            return Color(red: raw.red, green: raw.green, blue: raw.blue)
        }
        // Mode malam **diturunkan dari kanal merah warna siang**, bukan
        // dipetakan di sini. Versi lama menulis angka malam sendiri per
        // warna, dan 10 dari 13 di antaranya bukan merah murni -- pita terang
        // Bulan, misalnya, menyimpan 77% luminansinya di hijau/biru,
        // padahal file ini menjanjikan "merah murni ... termasuk pada
        // gambar". Aturannya sekarang satu (`NightVisual`), sama dengan bola
        // planet, dan punya uji di Linux.
        let night = NightVisual.mapped(raw, isShadow: isShadow)
        return Color(red: night.red, green: night.green, blue: night.blue)
    }

    /// Aksen yang memancarkan cahaya (pita, cincin, kutub, kabut).
    private static func accent(_ raw: CelestialVisual.RGBComponents) -> Color {
        color(raw)
    }

    /// Radius samaran untuk gambar yang **belum pasti**, sebagai fraksi
    /// diameter.
    ///
    /// **Kenapa fraksi, bukan angka titik.** Gambar yang sama dipakai pada
    /// 38 pt di kartu jam dan 132 pt di panel iPhone; radius titik tetap
    /// berarti samaran yang hampir tak terlihat di jam (0.6 px) atau samaran
    /// yang menghapus objeknya di iPhone. Fraksi membuat *jumlah detail
    /// yang hilang* sama di kedua ukuran.
    ///
    /// **Kenapa 0.06, dan apa yang TIDAK diklaim.** Nilai ini dipilih dari
    /// bangun geometrinya, bukan dari pengukuran di perangkat: pita Jupiter
    /// adalah pecahan radius, jadi menyamarkan selebar ~6% diameter
    /// menghapus tepi pita (yang sempit) tanpa meleburkan cakramnya (yang
    /// selebar penuh) — tujuannya **bukan** menyembunyikan benda, melainkan
    /// menghilangkan ketegasan bentuknya. Tidak ada satu pun gerbang yang
    /// mengukur radius ini di layar; yang dijaga di Linux adalah **siapa**
    /// yang disamarkan (`UncertainBlurTests`), bukan seberapa.
    private static func uncertainBlurRadius(diameter: CGFloat) -> CGFloat {
        diameter * 0.06
    }

    /// Opasitas gambar yang disamarkan. Turun tipis, bukan dramatis: samaran
    /// harus terbaca sebagai "mungkin", bukan sebagai "hilang". Nilainya
    /// dijaga tetap tinggi supaya lencana tanda tanya di atasnya (digambar
    /// di dalam kanvas, jadi ikut tersamar) tetap punya kontras terhadap
    /// latar — lencana itu satu-satunya penanda tekstual keraguan di gambar.
    private static let uncertainBlurOpacity: Double = 0.75

    /// Shading bola untuk piringan Bulan: warna dasar → ujung gelapnya.
    ///
    /// Pusat dan radius awalnya sama dengan `drawSphere` untuk planet; yang
    /// berbeda radius **akhirnya** — dibaca dari
    /// `CelestialVisual.moonSphereGradientEndRadius` (1.15, bukan 1.35), karena
    /// piringan Bulan diputar sebesar sudut sisi terangnya sehingga pada sabit
    /// seluruh pita menyala jatuh dekat tepi piringan. Diukur pada 200 px:
    /// purnama +33.5% (1.15) vs +28.5% (1.35), sabit 24.1 vs 20.9 — jadi
    /// memakai 1.35 melemahkan keduanya, bukan hanya sabitnya.
    ///
    /// Arah cahaya tidak dipakai di sini, dan itu **bukan** kelalaian: gradien
    /// yang berpusat di pusat piringan tidak punya arah, jadi ia kebal
    /// terhadap putaran pita. Gradien yang digeser ikut berputar, sehingga
    /// "cahaya dari kiri-atas" menghadap arah yang salah begitu sisi terangnya
    /// ke bawah — dan arah cahaya Bulan memang sudah dinyatakan oleh
    /// terminatornya, bukan oleh gradiennya.
    ///
    /// `isShadow: true` untuk piringan yang **tidak** memancarkan cahaya:
    /// peredupannya ditempelkan di atas aturan `shadow`, bukan di atas aturan
    /// `surface` — kalau tidak, kanal merahnya naik dan kontras sabit runtuh.
    private static func sphereGradient(center: CGPoint, radius: CGFloat,
                                       base: CelestialVisual.RGBComponents,
                                       isShadow: Bool = false) -> GraphicsContext.Shading {
        let dark = CelestialVisual.moonSphereDark(base)
        return .radialGradient(
            Gradient(colors: [isShadow ? shadowAccent(base) : accent(base),
                              isShadow ? shadowAccent(dark) : accent(dark)]),
            center: center,
            startRadius: 0,
            endRadius: radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius))
    }

    /// Isi sebuah cakram sebagai **bola**, bukan cakram rata.
    private static func fillSphere(context: GraphicsContext, disc: Path, center: CGPoint,
                                   radius: CGFloat, base: CelestialVisual.RGBComponents,
                                   isShadow: Bool = false) {
        context.fill(disc, with: sphereGradient(center: center, radius: radius,
                                                base: base, isShadow: isShadow))
    }

    /// Aksen untuk bagian yang **tidak memancarkan cahaya**: piringan gelap
    /// bulan dan isi lencana ragu.
    ///
    /// Terpisah dari `accent` dengan alasan yang diuji: memetakan bagian
    /// gelap lewat aturan permukaan akan menaikkannya ke kanal merah 0,44,
    /// dan kontras sabit terhadap gelap jatuh ke 2,99:1 -- di layar yang
    /// justru paling dipakai untuk melihat bulan, tepat saat mode malam
    /// dipilih supaya penglihatan malam terjaga.
    private static func shadowAccent(_ raw: CelestialVisual.RGBComponents) -> Color {
        color(raw, isShadow: true)
    }

    // MARK: - Planet

    private func drawPlanet(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard let planet = visual.planet else {
            // Planet yang tidak dikenali → bola netral tanpa pita. Bola polos
            // tidak mengklaim apa pun; pita yang salah akan.
            drawSphere(context: context, center: center, radius: radius,
                       from: Self.neutralBody, to: Self.neutralShadow)
            return
        }
        // **Palet yang boleh digambar**, bukan palet mentahnya. Saat engine
        // ragu, ini mengembalikan bola netral + `feature: .none`, sehingga
        // warna identitas planet (oker Mars, cokelat Jupiter) tidak ikut
        // tampil di sebelah badge "Ragu". Aturannya hidup di model
        // (`Palette.drawable(isConfirmed:)`) supaya terukur di Linux — lihat
        // docstring-nya untuk cacat yang ditutupnya.
        //
        // `guard isConfirmed` di bawah **tetap ada** dan bukan duplikat: ia
        // yang menutup `feature`, sedangkan `drawable` sudah mengembalikan
        // `.none`. Keduanya menjaga hal yang sama dari dua arah, jadi satu
        // kelalaian di salah satunya tidak cukup untuk meloloskan ciri.
        let palette = planet.palette.drawable(isConfirmed: isConfirmed)

        // **Fase planet dalam (Venus, Merkurius).** Bila fase-nya diketahui,
        // piringan digambar sebagai bagian yang menyala + bagian gelap, bukan
        // bola penuh. Venus yang tergambar bulat adalah gambar yang menyatakan
        // sesuatu yang tidak ada: dari Bumi ia berayun dari sabit tipis ke
        // cakram hampir penuh, dan bentuk itulah ciri paling dikenalnya.
        //
        // Hanya saat **terkunci** (`isConfirmed`). Aturan yang sudah berlaku
        // untuk pita Jupiter dan cincin Saturnus berlaku sama di sini: warna
        // boleh tampil pada kandidat, **bentuk** tidak. Sabit adalah bentuk —
        // menggambarnya pada objek yang belum dipastikan berarti menyampaikan
        // identitas yang belum dimiliki engine.
        if isConfirmed, let phase = visual.phaseGeometry(waxing: visual.isWaxing) {
            let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                              width: radius * 2, height: radius * 2))
            // Sisi gelap planet: praktis hitam, tanpa earthshine seperti Bulan
            // (lihat `planetUnlit`). Aturan `shadow`, sama dengan piringan
            // gelap Bulan: bagian ini tidak memancarkan cahaya.
            context.fill(disc,
                         with: .color(Self.shadowAccent(CelestialVisual.accents.planetUnlit)))
            drawLitBand(context: context, center: center, radius: radius, phase: phase, disc: disc,
                        litFill: .color(Self.color(palette.light)),
                        decorate: { inner in
                            // Peredupan limb di dalam pita: gradien radial
                            // **berpusat di pusat piringan**, bukan digeser
                            // ke kiri-atas seperti bola penuh. Gradien yang
                            // digeser ikut berputar bersama pita, sehingga
                            // "cahaya dari kiri-atas" akan menghadap arah yang
                            // salah begitu sisi terangnya ke bawah — dan
                            // planetnya tetap tampak seperti bola, jadi
                            // tidak ada yang bisa menangkapnya dari layar.
                            // Radius akhir dibaca dari model, **bukan** ditulis
                            // 1.15 di sini: sampai siklus ini baris ini punya
                            // salinan keduanya, jadi mengubah
                            // `moonSphereGradientEndRadius` tidak pernah
                            // menyentuh Venus dan Merkurius (terukur 0 piksel)
                            // — padahal konstantanya mengklaim dipakai di
                            // kedua bahasa.
                            inner.fill(disc, with: .radialGradient(
                                Gradient(colors: [Self.color(palette.light),
                                                  Self.color(palette.dark)]),
                                center: center, startRadius: 0,
                                endRadius: radius * CGFloat(CelestialVisual.moonSphereGradientEndRadius)))
                            // Ciri pengenal (kawah Merkurius, kabut Venus) ikut
                            // terpotong ke bagian yang menyala, jadi tidak
                            // pernah menonjol keluar dari sabit.
                            switch palette.feature {
                            case .craters:
                                self.drawCraters(context: inner, center: center, radius: radius)
                            case .haze:
                                self.drawHaze(context: inner, center: center, radius: radius)
                            // `.paleDisk` dan `.blueDisk` **harus** ada di sini,
                            // bukan dilipat ke `break`. Keduanya milik Uranus
                            // dan Neptunus, dan keduanya `showsPhase == false`
                            // (lihat `Planet.showsPhase`), jadi cabang ini tidak
                            // pernah dieksekusi hari ini. Menuliskannya eksplisit
                            // menjaga sifat itu **terbaca**: kalau kelak ada
                            // planet berfase yang memakai ciri ini, `switch`-nya
                            // sudah punya tempatnya, dan menambahkan gambarnya
                            // tidak menuntut menemukan cabang ini lebih dulu.
                            //
                            // Yang TIDAK diklaim: cabang ini belum pernah diukur
                            // menggambar apa pun — tidak ada planet berfase yang
                            // memakainya. Isinya `break` yang sama seperti
                            // `.bands`/`.rings`/`.polarCaps`, dan itu jujur.
                            case .paleDisk, .blueDisk:
                                break
                            case .bands, .rings, .polarCaps, .none:
                                break
                            }
                        })
            return
        }

        // **Bola radius penuh — kecuali Saturnus yang sudah terkunci.**
        //
        // Cincin Saturnus menggambar bolanya **sendiri**, pada
        // `VisualFrame.saturnBodyRadius` (0.53 R). Lihat `drawRings`, dan
        // lihat docstring `saturnBodyRadius`: "kalau bola tetap memakai radius
        // frame penuh sementara cincin mengisi frame, bola menutupi cincin dan
        // hasilnya piring, bukan Saturnus".
        //
        // Sampai siklus ini baris ini tetap menggambar bola 1.0 R **juga** pada
        // kasus itu, jadi yang sampai ke layar adalah **dua** piringan: cakram
        // 1.0 R yang bocor ke seluruh frame di luar bidang cincin, di bawah
        // bola 0.53 R milik cincinnya. Terukur pada 200 px: **seluruh** 12 712
        // piksel di luar elips cincin menyala — di kutub atas dan bawah
        // piringan, di tempat yang seharusnya hanya latar. Di kartu jam itu
        // terbaca sebagai "dua bola bersarang", bukan Saturnus.
        //
        // Tidak satu pun gerbang menangkapnya, dan alasannya khas repo ini:
        // pemeriksaan "cincin Saturnus lebih lebar dari bola" hanya menuntut
        // jangkauan > 0.8 R, sementara **cakram bocor itu sendiri** menjangkau
        // 1.0 R. Dibuktikan dengan menghapus cincinnya seluruhnya dari view:
        // gerbang itu tetap hijau. Cacat ini lolos justru karena ada bentuk
        // lain yang kebetulan selebar cincin.
        //
        // Kasus **ragu** tetap memakai bola radius penuh: di sana tidak ada
        // cincin yang menggambar bolanya, dan yang harus tampil memang hanya
        // warnanya. Itu sebabnya syaratnya memuat `isConfirmed`, bukan hanya
        // `palette.feature == .rings`.
        if !(isConfirmed && palette.feature == .rings) {
            drawSphere(context: context, center: center, radius: radius,
                       from: palette.light, to: palette.dark)
        }
        // Saat identitas belum pasti, hanya **warnanya** yang boleh tampil —
        // bentuknya tidak. Cincin Saturnus adalah penanda yang sama
        // meyakinkannya dengan pita Jupiter, jadi menampilkannya pada kandidat
        // yang belum terkunci berarti menyampaikan identitas yang tidak
        // dimiliki engine. `palette.feature` sudah diuji di Linux, jadi
        // pemetaan planet → ciri tidak bisa lagi diam-diam bergeser.
        guard isConfirmed else { return }
        switch palette.feature {
        case .bands: drawBands(context: context, center: center, radius: radius,
                               palette: palette)
        case .rings: drawRings(context: context, center: center, radius: radius)
        case .polarCaps: drawPolarCaps(context: context, center: center, radius: radius)
        case .craters: drawCraters(context: context, center: center, radius: radius)
        case .haze: drawHaze(context: context, center: center, radius: radius)
        case .paleDisk: drawPaleDisk(context: context, center: center, radius: radius)
        case .blueDisk: drawBlueDisk(context: context, center: center, radius: radius)
        case .none: break
        }
    }

    /// Warna bola untuk planet yang id-nya tidak dikenali, **dan** satu-satunya
    /// warna yang boleh tampil saat engine ragu.
    ///
    /// Netral keabu-abuan, bukan warna planet mana pun: bola ungu akan
    /// menyiratkan "ini planet tertentu", padahal yang diketahui hanya "ini
    /// planet yang tidak kita kenali".
    ///
    /// **Kenapa nilainya dibaca dari model, bukan ditulis di sini.** Angka ini
    /// dulu hidup di view, dan view tidak bisa diuji di Linux. Sejak ia juga
    /// menentukan seluruh jalur "ragu" planet (`Palette.drawable(isConfirmed:)`),
    /// jalur itu harus terukur — jadi nilainya pindah ke `CelestialVisual` dan
    /// di sini hanya diteruskan. Menulis ulang angkanya di sini akan
    /// mengembalikan salinan kedua yang bisa berbeda diam-diam dari model.
    private static let neutralBody = CelestialVisual.neutralBody
    private static let neutralShadow = CelestialVisual.neutralShadow

    /// Gradien bola: pencahayaan dari kiri-atas, bayangan di kanan-bawah.
    ///
    /// `opacity` dipakai **dua** pemanggil, dan keduanya harus memakai gradien
    /// yang sama persis: `drawPlanet` menggambar bola, lalu `drawBands`
    /// menggambarnya **lagi** di atas pita untuk memulihkan lengkung yang tadi
    /// terhapus pita. Karena yang digambar ulang adalah gradien yang sama,
    /// daerah yang tidak tertutup pita **tidak berubah sama sekali** — gradien
    /// yang ditumpuk di atas dirinya sendiri menghasilkan dirinya sendiri.
    /// Kalau pemulihan itu memakai gradien yang dihitung sendiri, lengkung
    /// yang dipulihkan tidak akan sama dengan lengkung yang terhapus, dan
    /// selisihnya justru muncul sebagai pita yang lebih terang di tempat yang
    /// salah — cacat baru yang tidak bisa dibaca dari kode.
    private func drawSphere(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                            from light: CelestialVisual.RGBComponents,
                            to dark: CelestialVisual.RGBComponents,
                            opacity: Double = 1) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .radialGradient(
            Gradient(colors: [Self.color(light).opacity(opacity),
                              Self.color(dark).opacity(opacity)]),
            // Arah cahaya datang dari model, bukan angka yang ditulis ulang di
            // sini: `drawCraters` memakai arah yang sama untuk memutuskan sisi
            // mana bibir kawahnya yang terang. Kalau kedua angka ini berbeda,
            // kawahnya akan tampak **menonjol keluar** dari bola alih-alih
            // cekung — kekeliruan yang tidak bisa ditangkap mata, hanya bisa
            // dihitung (lihat `CelestialVisual.sphereLightOffset`).
            center: CGPoint(x: center.x + radius * CelestialVisual.sphereLightOffset.x,
                            y: center.y + radius * CelestialVisual.sphereLightOffset.y),
            startRadius: radius * 0.1,
            endRadius: radius * 1.35))
    }

    /// Pita Jupiter: pita oranye-kokelat sejajar ekuator + Bintik Merah Besar.
    ///
    /// Pita digambar sebagai **pita horizontal tersusun**, bukan elips penuh,
    /// karena elips penuh akan menutupi bola dan terlihat seperti cincin.
    ///
    /// **Geometri pita datang dari `CelestialVisual.jupiterBands()`, bukan
    /// dari rumus di sini.** Versi lama memakai
    /// `cos((t - 0.5) * .pi * 0.92)` sambil berkomentar "pita mengikuti
    /// keliling bola: makin dekat kutub, makin pendek" — dan kosinus itu
    /// bukan keliling bola. Di kartu jam, pita teratas berhenti 3.6 pt
    /// (19% radius) di dalam piringan, jadi kedua kutub tampil sebagai bola
    /// polos dengan pita mengambang di tengahnya. Bentuk bola yang benar
    /// (`sqrt(1 - y^2)`) sekarang diuji di Linux
    /// (`testJupiterBandsReachTheLimb`), jadi view tidak lagi bisa
    /// menyimpang diam-diam — persis alasan cincin Saturnus dan kutub Mars
    /// sudah lebih dulu pindah ke `VisualFrame`/`CelestialVisual`.
    private func drawBands(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                           palette: CelestialVisual.Palette) {
        // Lebar pita dikalibrasi untuk kontras tinggi di layar kecil: pita
        // yang terlalu tipis hilang di layar jam. Angkanya milik model
        // (`jupiterBands`), dan `check-visuals.py` menjaga agar port Python
        // tidak tertinggal saat nilainya berubah.
        for band in CelestialVisual.jupiterBands() {
            let y = center.y + CGFloat(band.centerY) * radius
            let halfWidth = radius * CGFloat(band.halfWidth)
            guard halfWidth > 1 else { continue }
            let halfHeight = radius * CGFloat(band.halfHeight)
            // **Pita digambar sebagai tali busur, bukan elips.** Tepi pita
            // mengikuti busur limb: pada ketinggian `y ± halfHeight` bola
            // sudah menyempit, sementara elips mempertahankan lebarnya sampai
            // ujung. Diukur sebagai IoU pada render 200 px, elips hanya
            // menutupi **79%** pita yang benar; yang hilang 20,5–22,1% — dua
            // sudut di dekat limb, di mana bola tetap polos sementara pita
            // sudah berhenti. Itu bentuk yang membuat piringan terbaca sebagai
            // stiker rata, dan ia juga menggantung di luar tepi bola pada
            // pita bawah.
            //
            // Yang dipakai adalah ketinggian **bertanda** tepi atas dan bawah
            // (`band.centerY ∓ band.halfHeight`), karena tanda itulah yang
            // menentukan sisi mana yang lebih dalam. Semuanya dari model, jadi
            // `check-visuals` bisa menahannya di kedua bahasa.
            //
            // **Tepinya poligon yang mengikuti busur, bukan empat simpul.**
            // Empat simpul (trapesium) tidak bisa mengikuti lingkaran: ruas
            // garis lurus antara tepi atas dan tepi bawah memotong ke dalam
            // busur, paling dalam di tengah pita. Pada pita kutub — setinggi
            // jarak antar pusatnya, 0.2857 R — tepi kirinya di baris tengah
            // jatuh di **0.350 R** sementara bola di ketinggian itu
            // **0.515 R**; selisih 0.165 R itu persis yang dilaporkan CI
            // ("jangkauan 0.355 R, bola 0.519 R, selisih 16.4% R"). Tepi
            // atasnya bahkan jatuh tepat di kutub, jadi gerbang busur limb
            // tidak menemukan pita sama sekali ("tepi pita tidak ditemukan").
            //
            // Jumlah ruasnya dari model (`CelestialVisual.bandEdgeSteps`),
            // dan panah taksirannya `≈1.6·10⁻⁴ R` — jauh di bawah satu piksel
            // di kartu jam.
            let edges = CelestialVisual.jupiterBandEdges(
                centerY: band.centerY, halfHeight: band.halfHeight)
            var ribbon = Path()
            for (index, edge) in edges.enumerated() {
                let point = CGPoint(
                    x: center.x - radius * CGFloat(edge.halfWidth),
                    y: center.y + CGFloat(edge.height) * radius)
                if index == 0 {
                    ribbon.move(to: point)
                } else {
                    ribbon.addLine(to: point)
                }
            }
            // Sisi kanan: telusuri kembali dari bawah ke atas, memakai lebar
            // yang sama di tiap ketinggian (bola simetris kiri-kanan).
            for edge in edges.reversed() {
                ribbon.addLine(to: CGPoint(
                    x: center.x + radius * CGFloat(edge.halfWidth),
                    y: center.y + CGFloat(edge.height) * radius))
            }
            ribbon.closeSubpath()
            // Warna pita dibaca dari model, mode malam dihitung dari kanal
            // merahnya. Versi lama menulis angka malam sendiri
            // (`0.34 + 0.18 * shade / 2`), dan urutan hasilnya **terbalik**:
            // pita paling gelap (kanal merah 0.72) menjadi lebih terang dari
            // pita paling terang (0.85) -- 0.43 vs 0.34. Mode malam
            // mengorbankan hue secara sengaja, tapi terang-gelap tidak boleh
            // ikut terbalik; itu informasi yang masih terbaca di malam.
            //
            // **Nada pita datang dari model, bukan dari `index % 3` di sini.**
            // Sampai siklus ini peta indeks→warna hidup dua kali: di baris ini
            // dan di larik `render-visuals.py`. Keduanya menyusun pita
            // tan→rust→cream berulang, dan terukur hanya **dL 0.020** antar
            // pita bersebelahan — pitanya ada, tetapi tidak terpisah. Peta itu
            // sekarang satu tempat (`CelestialVisual.jupiterBandTones`), dan
            // polanya diuji di Linux.
            let bandColor = CelestialVisual.jupiterBandColour(
                for: CelestialVisual.jupiterBandTone(at: band.centerY))
            // **Pita dinaungi cahaya bola sebagai bagian dari warnanya, bukan
            // dicat rata lalu ditutupi ulang.** Dua generasi sebelumnya
            // berdebat: pita rata menghapus lengkung bola (jadi stiker), dan
            // menutupinya lagi dengan gradien bola penuh memulihkan lengkung
            // tetapi mencuci warna pitanya.
            //
            // Diukur pada port Python yang memakai konstanta yang sama, render
            // 200 px, ss=2 (residual keterpisahan vs lengkung, ambang 0.05 /
            // 70%):
            //
            //     opasitas 0.85, tutup ulang 0.75 : lengkung 71.9%, residual 0.002
            //     opasitas 0.85, tutup ulang 0.60 : lengkung 57.4%, residual 0.093
            //     opasitas 0.55, tutup ulang 0.60 : lengkung 71.3%, residual 0.007
            //
            // Kolomnya berlawanan arah, dan itu bukan soal menyetel angka: dua
            // besaran itu diukur dari pixel yang sama dengan arah berlawanan —
            // kontras pita tinggal di tepi piringan, sementara lengkung justru
            // diukur sebagai gelapnya tepi itu. Satu konstanta opasitas tidak
            // bisa memenuhi keduanya.
            //
            // Jadi naungannya digambar **ke dalam bentuk pitanya sendiri**
            // (sama seperti pemulihan Bintik Merah Besar di bawah), bukan ke
            // seluruh cakram. Lengkung jadi intrinsik — tidak perlu dipulihkan
            // karena tidak pernah terhapus — dan warna pita tetap terbaca
            // karena gradiennya hanya menutupi satu pita, bukan seluruh bola.
            context.fill(ribbon,
                         with: .color(Self.accent(bandColor)
                             .opacity(CelestialVisual.jupiterBandOpacity)))
            context.drawLayer { bandContext in
                bandContext.clip(to: ribbon)
                drawSphere(context: bandContext, center: center, radius: radius,
                           from: palette.light, to: palette.dark,
                           opacity: CelestialVisual.bandLimbShadingStrength)
            }
        }

        // Bintik Merah Besar: elips merah di belahan selatan, sedikit di bawah
        // ekuator — posisinya memang di sana secara nyata.
        //
        // **Pusatnya datang dari `CelestialVisual.jupiterSpot()`, bukan dari
        // angka di sini.** Versi sebelumnya menulis
        // `CGRect(x: center.x - radius * 0.36, y: center.y + radius * 0.18, …)`
        // — dan itu `CGRect`, jadi angkanya adalah **sudut**, bukan pusat.
        // Port Python membacanya sebagai pusat, sehingga gambar yang diukur
        // seluruh gerbang visual menaruh bintiknya 0.26 R (setengah lebarnya
        // sendiri) di sebelah kiri tempat bintik ini benar-benar tergambar.
        // Kedua tafsir sama-sama menggambar elips yang sama besarnya, jadi
        // tidak ada pemeriksaan bentuk yang bisa membedakannya — persis kelas
        // "gerbang mengukur sebagian klaimnya" yang berulang di repo ini.
        let spot = CelestialVisual.jupiterSpot()
        let spotRect = CGRect(x: center.x + CGFloat(spot.centerX - spot.width / 2) * radius,
                              y: center.y + CGFloat(spot.centerY - spot.height / 2) * radius,
                              width: radius * CGFloat(spot.width),
                              height: radius * CGFloat(spot.height))
        let spotPath = Path(ellipseIn: spotRect)
        context.fill(spotPath,
                     with: .color(Self.accent(CelestialVisual.accents.jupiterSpot)))

        // **Restorasi peredupan limb di atas bintik.** Kelas cacat yang sama
        // dengan pita di atas: bintik digambar sebagai elips warna **rata**,
        // jadi ia menghapus lengkung bola di dalamnya. Diukur pada baris
        // pusatnya (y = +0.31 R, render 200 px): bola di bawahnya meredup
        // 0.580 -> 0.532 (+8.4%), sementara baris yang sama **dengan** bintik
        // menanjak 0.449 -> 0.532 (**-18.4%**) — arahnya terbalik.
        //
        // Gerbang piksel yang ada tidak menangkapnya: `check_banded_disc_keeps
        // _its_curvature` mengukur **baris ekuator**, dan bintiknya duduk di
        // +0.31 R. Karena itu gerbang barunya
        // (`check_jupiter_spot_keeps_its_curvature`) mengukur baris ini.
        //
        // Yang dipakai kembali adalah gradien `drawSphere` yang sama, dipotong
        // ke elips bintiknya — jadi arah cahayanya tidak bisa berbeda pendapat
        // dengan bolanya, dan di luar bintik tidak ada piksel yang berubah.
        var spotShaded = context
        spotShaded.clip(to: spotPath)
        drawSphere(context: spotShaded, center: center, radius: radius,
                   from: palette.light, to: palette.dark,
                   opacity: CelestialVisual.jupiterSpotLimbShadingStrength)
    }

    /// Cincin Saturnus: elips yang digambar **di belakang** bola dan **di
    /// depan** paruh bawahnya.
    ///
    /// Dua operasi, tidak lebih: cincin belakang digambar penuh sebelum bola
    /// (bola menimpanya secara alami), lalu cincin depan digambar lagi dengan
    /// `clip` pada setengah bawah. Versi sebelumnya mencoba menimpanya dengan
    /// warna `.clear` — yang **tidak** menimpa apa pun, hanya melukis
    /// transparan — jadi cincin belakang tetap terlihat penuh melewati bola
    /// dan hasilnya bukan cincin melainkan piring.
    private func drawRings(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // **Geometri cincin datang dari `VisualFrame`, bukan dari angka di
        // sini.** Cincin adalah bentuk yang paling mudah salah secara tak
        // terlihat: `Canvas` memotong apa pun di luar `frame`-nya dengan tepi
        // lurus, jadi cincin yang terlalu lebar tidak tampak "agak kepotong"
        // -- ia tampak sebagai dua garis yang berhenti mendadak. Versi lama
        // memakai `3.8 x radius` (ujungnya di x = +/-1.9R, yaitu 0.9R di luar
        // frame) dan terpotong tegak. Uji `testSaturnRingStaysInsideTheFrame`
        // menutupnya di Linux, tempat bentuk ini bisa diuji.
        let ring = VisualFrame.saturnRing()
        // Bola **mengecil** mengikuti cincin. Kalau bola tetap memakai radius
        // frame penuh sementara cincin mengisi frame, bola menutupi cincin dan
        // hasilnya piring, bukan Saturnus.
        let bodyRadius = VisualFrame.saturnBodyRadius(for: ring)
        let ringColor = Self.accent(CelestialVisual.accents.saturnRing)
        let palette = CelestialVisual.Planet.saturn.palette
        let axialRatio = CGFloat(ring.halfHeight / ring.halfWidth)

        // **Cincin digambar sebagai pita, bukan satu elips pekat.**
        //
        // Versi lama menggambar satu elips opasitas 0.45 untuk paruh belakang,
        // satu elips 0.8 untuk paruh depan, lalu sebuah elips hitam 0.28
        // sebagai "pembelah Cassini". Tiga hal salah sekaligus:
        //
        //   1. Pita D/C/B/A yang punya nama di data nyata tidak ada — yang
        //      tergambar satu bidang rata.
        //   2. Elips hitam itu diletakkan 0.34 x radius bola dari tepi luar,
        //      sedangkan pembelah Cassini nyata berada di 0.886 R cincin:
        //      jadi ia memotong pita A, bukan memisahkan B dari A.
        //   3. Elips itu hanya digambar di dalam klip paruh **bawah**, jadi
        //      paruh belakang tidak punya celah sama sekali — padahal satu
        //      cincin yang sama harus terlihat punya celah dari kedua sisi.
        //
        // Sekarang strukturnya datang dari `VisualFrame.saturnRingBands()`
        // (teruji di Linux), dan **setiap pita digambar di kedua paruh**
        // dengan skala opasitas belakang dari model. Dengan begitu
        // ketidak-simetrisan seperti di atas tidak bisa ditulis ulang tanpa
        // mengubah modelnya juga.
        //
        // Tiap pita digambar sebagai **satu path cincin** (elips luar + elips
        // dalam dengan arah berlawanan, `evenOdd`), bukan elips lalu elips
        // hitam di atasnya. Dua alasan: elips hitam akan menghapus bola yang
        // ada di bawahnya di paruh depan, dan lubang yang dihasilkan
        // `destinationOut` bekerja pada seluruh konteks — bukan pada pita itu
        // saja — sehingga pita berikutnya ikut terpotong.
        func ringPath(_ outerRadius: CGFloat, _ innerRadius: CGFloat) -> Path {
            var path = Path()
            let outerRect = CGRect(x: center.x - outerRadius,
                                   y: center.y - outerRadius * axialRatio,
                                   width: outerRadius * 2,
                                   height: outerRadius * 2 * axialRatio)
            path.addEllipse(in: outerRect)
            if innerRadius > 0 {
                let innerRect = CGRect(x: center.x - innerRadius,
                                       y: center.y - innerRadius * axialRatio,
                                       width: innerRadius * 2,
                                       height: innerRadius * 2 * axialRatio)
                path.addEllipse(in: innerRect)
            }
            return path
        }

        let bands = VisualFrame.saturnRingBands()
        let fullWidth = CGFloat(ring.halfWidth) * radius

        // Paruh BELAKANG dulu: seluruhnya di atas bola, sehingga bola yang
        // digambar sesudahnya menutupi bagian yang memang di belakang.
        var back = context
        back.clip(to: Path(CGRect(x: 0, y: 0,
                                  width: center.x * 2, height: center.y)))
        for band in bands {
            back.fill(ringPath(CGFloat(band.outerRadius) * fullWidth,
                               CGFloat(band.innerRadius) * fullWidth),
                      with: .color(ringColor.opacity(
                        band.opacity * VisualFrame.ringBackHalfOpacityScale)),
                      style: FillStyle(eoFill: true))
        }

        // Bola Saturnus, di antara paruh belakang dan paruh depan.
        drawSphere(context: context, center: center, radius: CGFloat(bodyRadius) * radius,
                   from: palette.light, to: palette.dark)

        // Paruh DEPAN: paruh bawah elips, di atas bola. Karena pita digambar
        // sebagai path cincin, ia benar-benar melintas di muka bola pada
        // ekuator — yang persis seperti yang terlihat pada Saturnus.
        var front = context
        front.clip(to: Path(CGRect(x: 0, y: center.y,
                                   width: center.x * 2, height: center.y)))
        for band in bands {
            front.fill(ringPath(CGFloat(band.outerRadius) * fullWidth,
                                CGFloat(band.innerRadius) * fullWidth),
                       with: .color(ringColor.opacity(band.opacity)),
                       style: FillStyle(eoFill: true))
        }
    }

    /// Kutub Mars: kapsul es di utara dan selatan.
    ///
    /// **Bentuknya elips yang diiris piringan, bukan elips datar.** Versi
    /// sebelumnya menggambar elips dengan lebar tetap 0.55 R yang tepinya
    /// ditempelkan di tepi bola — hasilnya bukan kutub di permukaan bola,
    /// melainkan **elips yang mengambang di dalam piringan**: selalu ada rim
    /// merah di atas dan di sisi kiri-kanan kutubnya (terukur 25 px pada
    /// render 400 px). Kutub adalah ciri pengenal Mars, jadi bentuk yang
    /// salah di sini adalah **klaim yang salah** — persis yang PRD larang.
    ///
    /// Geometri (pusat, tinggi, **dan lebar**) datang dari
    /// `CelestialVisual.polarCaps()`, yang teruji di Linux. Di sini tidak ada
    /// rumus kutub lagi: lebarnya sudah diturunkan dari tepi bola di model.
    ///
    /// **Kenapa `clip` ke piringan wajib, bukan hiasan.** Elips selebar tepi
    /// bola pada `centerY` tetap **menjulur keluar** bola di baris lain —
    /// pada y = −0.9 R lebarnya 0.530 R sementara bola hanya 0.436 R. Tanpa
    /// klip, kutubnya justru meluber ke latar: cacat yang sama, hanya
    /// berpindah arah. Irisan itulah yang membuat tepi luar kutub mengikuti
    /// lengkung bola, seperti kap es yang menempel.
    private func drawPolarCaps(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let capColor = Self.accent(CelestialVisual.accents.marsPolarCap)
        let caps = CelestialVisual.polarCaps()
        // Piringan: batas irisan untuk kedua kutub.
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        for cap in [caps.north, caps.south] {
            var inner = context
            inner.clip(to: disc)
            let rect = CGRect(
                x: center.x - CGFloat(cap.halfWidth) * radius,
                y: center.y + CGFloat(cap.centerY - cap.halfHeight) * radius,
                width: CGFloat(cap.halfWidth) * radius * 2,
                height: CGFloat(cap.halfHeight) * radius * 2)
            // **Luruh ke tepi dalamnya, bukan warna rata.**
            //
            // Sampai siklus ini isinya `capColor.opacity(0.85)` — satu warna
            // rata — sehingga tepi **dalam** kutub adalah batas elips yang
            // sempurna. Diukur pada kolom tengah render 400 px: lompatan
            // **111.4 luminans dalam satu piksel** (utara) dan **139.8**
            // (selatan), sementara bola Mars di baris yang sama bergerak
            // 0.9 luminans per piksel. Elips bertepi tajam terbaca sebagai
            // **stiker putih yang ditempel**; embun beku menipis ke arah
            // ekuator, jadi batasnya kabur.
            //
            // Arah, jangkauan, dan kedua opasitasnya datang dari model
            // (`CelestialVisual.polarCapFade`). Di sini tidak ada satu angka
            // pun: mengulang aturannya berarti dua aturan yang akan berbeda,
            // dan yang berbeda itu tidak terlihat sebagai apa pun di layar.
            let fade = CelestialVisual.polarCapFade(cap: cap)
            let stops = [
                Gradient.Stop(color: capColor.opacity(fade.edgeOpacity), location: 0),
                Gradient.Stop(color: capColor.opacity(fade.fullOpacity), location: 1),
            ]
            inner.fill(Path(ellipseIn: rect),
                       with: .linearGradient(Gradient(stops: stops),
                                             startPoint: CGPoint(x: center.x,
                                                                 y: center.y
                                                                    + CGFloat(fade.innerEdgeY) * radius),
                                             endPoint: CGPoint(x: center.x,
                                                               y: center.y
                                                                  + CGFloat(fade.fullY) * radius)))
        }
    }

    /// Merkurius: abu berkawah.
    ///
    /// Posisi kawah ditulis relatif terhadap pusat & radius supaya proporsinya
    /// tetap sama pada kartu jam maupun panel besar di iPhone.
    ///
    /// **Kenapa tiga lapisan, bukan satu cakram gelap.** Versi pertama
    /// menggambar tiap kawah sebagai satu cakram `Color.black.opacity(0.18)`.
    /// Diukur pada ukuran sebenarnya di jam (38 pt, 76 px @2x), hasilnya
    /// terbaca sebagai **stiker abu-abu yang ditempel** di bola — bukan
    /// permukaan berkawah. Sebabnya fisis: cekungan selalu punya dinding yang
    /// menghadap cahaya dan dinding yang membelakanginya, sementara cakram
    /// rata tidak punya keduanya. Merkurius adalah planet yang ciri
    /// pengenalnya justru kawah, jadi gambar yang tidak membacanya sebagai
    /// kawah gagal menyampaikan satu-satunya hal yang ia punya.
    ///
    /// Urutannya penting dan tidak boleh ditukar:
    ///
    ///   1. **Bibir gelap** — cakram penuh seukuran kawah, warnanya
    ///      `craterFloor`. Ini sisi yang membelakangi cahaya.
    ///   2. **Bibir terang** — cakram yang sama, tapi digeser ke arah sumber
    ///      cahaya dan dipotong oleh cakram kawah, jadi yang tersisa hanya
    ///      **sabit** di sisi yang menghadap cahaya. Warna `craterRim`.
    ///   3. **Dasar cekungan** — cakram lebih kecil di tengah, kembali ke
    ///      `craterFloor`, supaya bagian tengahnya lebih gelap dari bibir
    ///      yang menghadap cahaya dan kawahnya benar-benar terbaca cekung.
    ///
    /// Arah bibir terangnya **bukan** pilihan di sini: ia datang dari
    /// `CelestialVisual.craterRelief`, yang menurunkannya dari
    /// `CelestialVisual.sphereLightOffset` — arah yang sama dengan gradien
    /// bola. Angka yang ditulis ulang di sini akan membuat kawah terang di
    /// sisi yang salah, dan kawah yang terbalik tetap terlihat seperti kawah.
    private func drawCraters(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let craters: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.30, -0.22, 0.20), (0.28, -0.05, 0.15), (-0.12, 0.32, 0.17),
            (0.34, 0.34, 0.11), (0.02, -0.48, 0.13)
        ]
        let relief = CelestialVisual.craterRelief(
            craters: craters.map { (Double($0.0), Double($0.1), Double($0.2)) })
        let floor = Self.accent(CelestialVisual.accents.craterFloor)
        let rim = Self.accent(CelestialVisual.accents.craterRim)

        for crater in relief {
            let size = CGFloat(crater.radius) * radius
            let cx = center.x + CGFloat(crater.centerX) * radius
            let cy = center.y + CGFloat(crater.centerY) * radius
            let disc = Path(ellipseIn: CGRect(x: cx - size, y: cy - size,
                                              width: size * 2, height: size * 2))

            // 1. Seluruh cekungan dalam keadaan dinaungi. Kelegapannya
            //    **bukan** angka tetap di sini: `floorDepth` dari model
            //    adalah kedalaman cekungan ini, dan model mendokumentasikan
            //    dirinya sendiri sebagai "dipakai sebagai kelegapan lapisan
            //    hitam". Selama view menulis 0.85 tetap, nilai model itu
            //    dihitung lalu dibuang — dan kawahnya tergambar sebagai
            //    cakram gelap rata, bukan cekungan. Angka 0.85 juga 3,9×
            //    kedalaman maksimum model (0.22), jadi ia menenggelamkan
            //    sabit bibir yang justru membuat kawah terbaca cekung.
            context.fill(disc, with: .color(floor.opacity(crater.floorDepth)))

            // 2. Bibir yang menghadap cahaya: cakram yang digeser ke arah
            //    sumber cahaya, dipotong oleh cakram kawah. Sisanya sabit.
            //    Geseran dibuat cukup besar (≈0,45·ukuran) supaya sabitnya
            //    terlihat di ukuran jam 76 px; kalau terlalu kecil, ia tertelan
            //    dasar cakram (bug yang dulu membuat kawah terbaca sebagai
            //    stiker rata). Geseran ini **bukan** `rimStrength`: kekuatan
            //    mengatur seberapa terang sabitnya, bukan seberapa jauh ia
            //    bergeser — mencampurnya berarti kawah redup lenyap.
            let offset = size * 0.45
            let rimDisc = Path(ellipseIn: CGRect(
                x: cx + CGFloat(crater.rimDirectionX) * offset - size,
                y: cy + CGFloat(crater.rimDirectionY) * offset - size,
                width: size * 1.84, height: size * 1.84))
            var lit = context
            lit.clip(to: disc)
            // Kelegapan bibir mengikuti `rimStrength` dari model: kawah di sisi
            // gelap (dan di tepi piringan) meredup, bukan menghilang, karena di
            // sana cahaya langsung lebih sedikit. Geseran tetap 0,45·ukuran.
            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * CGFloat(crater.rimStrength))))

            // 3. Dasar yang lebih gelap di tengah, jelas di dalam sabit bibirnya.
            let innerSize = size * 0.5
            context.fill(Path(ellipseIn: CGRect(x: cx - innerSize, y: cy - innerSize,
                                                width: innerSize * 2,
                                                height: innerSize * 2)),
                         with: .color(floor.opacity(0.75)))
        }
    }

    /// Venus: kabut tebal yang menutupi detail permukaan.
    private func drawHaze(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let haze = Self.accent(CelestialVisual.accents.venusHaze)
        // Geometri dari model, bukan angka di sini. Port Python pernah
        // menggambar elips ini **0.14 R lebih ke bawah** karena menyalin sudut
        // `CGRect` sebagai pusat; satu-satunya cara kelas cacat itu tertutup
        // adalah kedua bahasa membaca rumus yang sama. Lihat
        // `CelestialVisual.venusHaze`.
        let geometry = CelestialVisual.venusHaze()
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * CGFloat(geometry.halfWidth),
                                           y: center.y + radius * CGFloat(geometry.centerY - geometry.halfHeight),
                                           width: radius * CGFloat(geometry.halfWidth * 2),
                                           height: radius * CGFloat(geometry.halfHeight * 2))),
                     with: .linearGradient(
                        Gradient(colors: [haze.opacity(0), haze.opacity(0.7)]),
                        startPoint: CGPoint(x: center.x, y: center.y - radius),
                        endPoint: CGPoint(x: center.x, y: center.y)))
    }

    /// Uranus: satu sabuk horizontal yang sangat samar.
    ///
    /// **Kenapa tidak memakai `drawBands`.** `drawBands` menggambar tujuh pita
    /// bergantian terang/gelap dengan Bintik Merah Besar — ciri Jupiter.
    /// Uranus di teleskop kecil tampak sebagai piringan nyaris polos, jadi
    /// pita Jupiter di sini akan menyatakan rincian yang tidak pernah
    /// terlihat. Yang membedakan Uranus justru kepolosannya.
    private func drawPaleDisk(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        var inner = context
        inner.clip(to: disc)
        // Geometri dan opasitas dibaca dari model, bukan ditulis di sini:
        // port Python menggambar elips yang sama dari `uranusBand()`.
        let band = CelestialVisual.uranusBand()
        let color = Self.accent(CelestialVisual.accents.uranusBand)
        inner.fill(Path(ellipseIn: CGRect(
            x: center.x - radius * CGFloat(band.halfWidth),
            y: center.y + radius * CGFloat(band.centerY - band.halfHeight),
            width: radius * CGFloat(band.halfWidth * 2),
            height: radius * CGFloat(band.halfHeight * 2))),
                   with: .color(color.opacity(CelestialVisual.uranusBandOpacity)))
    }

    /// Neptunus: satu bintik gelap di belahan selatan.
    ///
    /// **Kenapa bintik, bukan pita.** Pita awan Neptunus jauh lebih redup
    /// daripada Jupiter/Saturnus; yang benar-benar membedakannya adalah
    /// bintik gelapnya. Menggambar pita saja membuat Neptunus tampak identik
    /// dengan Uranus berwarna biru — dan dua planet yang tampak sama berarti
    /// ciri pengenalnya berhenti menjadi ciri pengenal.
    private func drawBlueDisk(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        var inner = context
        inner.clip(to: disc)
        let spot = CelestialVisual.neptuneSpot()
        // Bintik gelap: warna gelap piringan itu sendiri, bukan warna baru —
        // supaya ia tidak pernah terbaca sebagai objek yang menempel di atas
        // bola.
        let color = Self.accent(CelestialVisual.accents.neptuneSpot)
        inner.fill(Path(ellipseIn: CGRect(
            x: center.x + radius * CGFloat(CelestialVisual.neptuneSpotCenterX - spot.halfWidth),
            y: center.y + radius * CGFloat(spot.centerY - spot.halfHeight),
            width: radius * CGFloat(spot.halfWidth * 2),
            height: radius * CGFloat(spot.halfHeight * 2))),
                   with: .color(color.opacity(CelestialVisual.neptuneSpotOpacity)))
    }

    // MARK: - Bulan

    /// Bulan: piringan gelap + pita terang berfase.
    /// - Parameter isConfirmed: apakah engine sudah mengunci identitasnya.
    ///   **Peredupan permukaan** (maria + kawah) hanya digambar saat terkunci:
    ///   pola gelap-terang Bulan menyebut muka yang mana, jadi ia ciri
    ///   pengenal, sama seperti pita Jupiter dan cincin Saturnus. Fase tetap
    ///   digambar — sabit bukan identitas, semua benda berfase punya sabit.
    ///   Sebelum ini `drawMoon` tidak menerima parameter itu sama sekali
    ///   (terukur: nol kemunculan `isConfirmed` di badannya), sehingga Bulan
    ///   yang ragu tampil dengan maria lengkap.
    private func drawMoon(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                          isConfirmed: Bool) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))

        // **Fase tidak diketahui: piringan abu netral, bukan piringan gelap.**
        //
        // Sampai siklus ini cabang ini menggambar warna *tidak menyala* dan
        // berhenti, dan hasilnya **identik piksel demi piksel** dengan bulan
        // baru (diukur: 0 dari 40.000 piksel berbeda). Bulan baru adalah
        // fakta tentang langit — f = 0, dan pengguna bisa memeriksanya dengan
        // mata sendiri. "Fase tidak dihitung" bukan fakta tentang apa pun;
        // ia berarti efemeris gagal atau arahnya tidak tersedia. Menggambar
        // yang kedua sebagai yang pertama berarti gambar itu **menyatakan**
        // bulan baru setiap kali perhitungan gagal, dan jam tidak punya teks
        // lain di kartunya untuk membantah.
        //
        // Aturan yang sama dengan `moon-unknown-phase` pada port Python, jadi
        // gerbang piksel bisa mengukur keduanya.
        guard let phase = visual.phaseGeometry(waxing: visual.isWaxing) else {
            // Piringan polos — tapi **bola**, bukan cakram rata. Lihat
            // `moonLimbShadingStrength`: tanpa ini piringan fase tak diketahui
            // terukur rata 0.0% sementara planet di sebelahnya melengkung 55%,
            // dan yang terlihat jadi guntingan kertas, bukan benda langit.
            // Kasus inilah yang paling menuntut: `moon-new` (fase 0) tetap
            // rata 0.0% pada setiap kekuatan, jadi fase **tak diketahui** satu-
            // satunya kartu "Bulan tanpa sabit" yang bisa melengkung.
            Self.fillSphere(context: context, disc: disc, center: center, radius: radius,
                            base: CelestialVisual.accents.moonPhaseUnknown)
            return
        }

        // Piringan gelap dulu (bagian yang tidak menyala) — tanpa ini sabit
        // akan tampak seperti bulan sabit berdiri sendiri di ruang kosong.
        // Piringan gelap memakai aturan `shadow`, bukan `surface`: ia tidak
        // memancarkan cahaya, dan memetakannya lewat aturan permukaan akan
        // menaikkannya ke kanal merah 0.44 sehingga kontras sabit terhadap
        // gelap jatuh ke 2.99:1 -- tepat di layar yang paling dipakai untuk
        // melihat bulan, dan tepat saat mode malam dipilih.
        //
        // **Piringan ini sengaja tetap rata**, dan itu bukan kelalaian.
        // Percobaan memberi gradien bola di sini diukur dan dibuang, karena
        // dua hal: (1) earthshine dilukis sebagai cakram warna **rata** di
        // atas seluruh piringan, jadi gradiennya terhapus justru di fase
        // tempat sisi gelap paling terlihat — terukur, `moon-new` tetap +0.0%
        // pada setiap kekuatan 0…0.80; dan (2) memperdalamnya mematikan
        // gerbang earthshine pada kekuatan 0.20. Sisi gelap Bulan disinari
        // Bumi, sumber yang **lebar**, jadi piringan rata di sana memang
        // gambar yang benar — sedangkan pita terangnya disinari sumber titik.
        context.fill(disc,
                     with: .color(Self.shadowAccent(CelestialVisual.accents.moonUnlit)))

        // Earthshine: cahaya samar di sisi gelap Bulan yang dipantulkan Bumi.
        // Ditarik dari `illuminationFraction` (model), bukan angka di sini, dan
        // kekuatannya dihitung oleh `earthshineStrength` (diuji di Linux) supaya
        // tidak pernah muncul saat purnama (f = 1, tak ada sisi gelap) maupun
        // saat fase tak diketahui (kartu ragu tidak menyatakan sabit).
        // Dilukis **sebelum** pita terang, jadi pita itu menutupinya di sisi
        // menyala — earthshine hanya terlihat di sisi gelap, persis seperti di
        // langit. Opasitas mengikuti kekuatan agar sabit tipis (sisi gelap
        // paling luas) bercahaya paling terang.
        let earthshine = CelestialVisual.earthshineStrength(
            illuminationFraction: visual.illuminationFraction ?? 0)
        if earthshine > 0 {
            context.fill(disc,
                         with: .color(Self.shadowAccent(
                            CelestialVisual.accents.moonEarthshine).opacity(earthshine)))
        }

        drawLitBand(context: context, center: center, radius: radius, phase: phase, disc: disc,
                    litFill: Self.sphereGradient(center: center, radius: radius,
                                                 base: CelestialVisual.accents.moonLit),
                    decorate: { inner in
                        // Gerbangnya dari model (`drawsMoonSurfaceShading`),
                        // bukan `if isConfirmed` di sini — supaya keputusannya
                        // bisa diuji di Linux, tempat `Apps/` tidak dibangun.
                        guard CelestialVisual.drawsMoonSurfaceShading(
                            isConfirmed: isConfirmed) else { return }
                        Self.drawMoonSurfaceShading(inner, center: center, radius: radius)
                        drawMoonCraters(inner, center: center, radius: radius)
                    })
    }

    /// Kawah Bulan, digambar **di dalam** pita terang.
    ///
    /// **Kenapa ini butuh pemisahannya sendiri.** Maria membuat Bulan berbintik
    /// belahan gelap-terang; kawah membuatnya terlihat sebagai **bola**. Keduanya
    /// mengisi hal yang berbeda: salah satunya kelalaian yang terlihat di layar
    /// 38 pt, yang satu lagi tidak (yang terlihat adalah "Bulan yang tidak
    /// seperti koin"). Yang kedua ini juga **bentuk** — bukan warna — dan
    /// justru bentuk itulah yang tidak dijaga satu pun gerbang gambar saat ini:
    /// seluruh gerbang gambar Bulan mengukur **terang/gelap**, bukan lengkung.
    ///
    /// **Kenapa di dalam maria, bukan salah satu darinya.** Kawah yang
    /// digambar sebagai cakram gelap rata menenggelamkan maria di bawahnya.
    /// Karena itu strukturnya sama seperti Merkurius: dinding depan yang
    /// menghadap cahaya, dinding belakang, dan dasar cekungan — semuanya dari
    /// `craterRelief`, bukan angka yang ditulis ulang di sini.
    ///
    /// **Kenapa ia ikut terpotong sabit.** Ia dipanggil di dalam klip pita
    /// terang yang sama dengan maria, jadi kawah di sisi gelap tidak pernah
    /// muncul. Yang perlu dicatat: kawah **mungkin** terlihat di sabit
    /// **ekor** (saat sisi gelap Bumi tidak melihat kawahnya), karena model ini
    /// tidak mengklaim orientasi Bulan terhadap Bumi. Diaku, tidak diurai —
    /// memproyeksikannya dengan rotasi akan berarti mengklaim pengetahuan yang
    /// engine ini tidak punya.
    private func drawMoonCraters(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let relief = CelestialVisual.craterRelief(
            craters: VisualFrame.moonCraters.map { c in
                // `Crater` menyimpan pusat dan radius terpisah; `craterRelief`
                // mengharapkan tupel `(x, y, radius)` yang sama dengan Merkurius.
                (c.offsetX, c.offsetY, c.radius)
            })
        let floor = Self.accent(CelestialVisual.accents.craterFloor)
        let rim = Self.accent(CelestialVisual.accents.craterRim)

        for crater in VisualFrame.moonCraters.enumerated() {
            let (index, geometry) = crater
            let r = relief[relief.indices.contains(index) ? index : relief.startIndex]
            // Jarak dari pusat cakram → berapa besar ia harus menyusut supaya
            // piringan terbaca sebagai bola. 1.0 di tengah, 0.0 di tepi.
            // Modelnya `craterForeshortening`, diuji di Linux.
            let centreDistance = (geometry.offsetX * geometry.offsetX
                                  + geometry.offsetY * geometry.offsetY).squareRoot()
            let shrink = VisualFrame.craterForeshortening(radiusFromCentre: centreDistance)
            // Kawah yang jatuh tepat di tepi: faktornya nol, jadi ia hilang.
            // Itu yang benar, tapi tetap dijaga di sini supaya barisnya tidak
            // pernah menggambar cakram berskala nol (yang bisa membawa bentuk
            // degenerat ke kanvas).
            guard shrink > 0.02, geometry.radius > 0.02 else { continue }
            let strength = CGFloat(r.rimStrength) * CGFloat(geometry.darkness) * CGFloat(shrink)
            // Radius yang **sebenarnya**, bukan radius mentah: ini yang membuat
            // kawah Clavius (0.78 R dari pusat) menyusut dari 0.14 R ke 0.08 R.
            let size = radius * CGFloat(geometry.radius * shrink)
            let cx = center.x + CGFloat(geometry.offsetX) * radius
            let cy = center.y + CGFloat(geometry.offsetY) * radius
            let disc = Path(ellipseIn: CGRect(x: cx - size, y: cy - size,
                                              width: size * 2, height: size * 2))

            // 1. Dasar cekungan — dinding yang membelakangi cahaya. Kelegapan
            //    ikut `floorDepth` dari model, dan makin pekat makin ke tepi
            //    (kawah tepi adalah yang paling tersembunyi di balik lengkung).
            context.fill(disc,
                         with: .color(floor.opacity(CGFloat(r.floorDepth) * strength)))

            // 2. Bibir yang menghadap cahaya: digeser ke arah sumber cahaya
            //    lalu dipotong cakram kawah, sehingga yang tersisa hanya sabit.
            //    Geseran 0.45 · ukuran, sama seperti Merkurius — bukan angka
            //    baru yang bisa menyimpang di antara dua tempat pemanggilan.
            let offset = size * 0.45
            let rimDisc = Path(ellipseIn: CGRect(
                x: cx + CGFloat(r.rimDirectionX) * offset - size,
                y: cy + CGFloat(r.rimDirectionY) * offset - size,
                width: size * 1.84, height: size * 1.84))
            var lit = context
            lit.clip(to: disc)
            lit.fill(rimDisc, with: .color(rim.opacity(0.9 * strength)))

            // 3. Dasar tengah yang lebih gelap, supaya cekungannya terbaca
            //    **cekung** — bukan sekadar gelap.
            let innerSize = size * 0.5
            context.fill(Path(ellipseIn: CGRect(x: cx - innerSize, y: cy - innerSize,
                                                width: innerSize * 2,
                                                height: innerSize * 2)),
                         with: .color(floor.opacity(0.75 * strength)))
        }
    }

    /// Bercak gelap (maria) di permukaan Bulan.
    ///
    /// Konstanta milik view, bukan model: ini tekstur hias, bukan pernyataan
    /// tentang langit. Yang **tidak** boleh di sini adalah hal yang menyatakan
    /// identitas atau geometri (fase, sisi terang) — semuanya datang dari
    /// model supaya bisa diuji.
    ///
    /// **Kenapa beriak, bukan lingkaran.** Versi sebelumnya menggambar setiap
    /// bercak sebagai `Path(ellipseIn:)` — lingkaran sempurna bertepi keras.
    /// Pada ukuran kartu jam (38 pt) mata mengenali lingkaran seragam jauh
    /// sebelum mengenali pola gelapnya, dan hasilnya terbaca sebagai **polka
    /// dot**, bukan dataran gelap. Maria sesungguhnya adalah dataran lava yang
    /// tepinya tidak beraturan dan menyatu dengan permukaan di sekitarnya.
    ///
    /// Tepi tidak beraturan datang dari riak harmonik: `r(θ) = size · (1 +
    /// amp · wobble(θ))` dengan `wobble` campuran orde 2, 3, dan 5. Orde ganjil
    /// dan genap bersama-sama mencegah bentuknya terbaca sebagai elips yang
    /// digoyangkan; amplitudo dan fase **berbeda tiap bercak** supaya tidak ada
    /// dua bercak yang berbagi siluet yang sama. Angka riaknya sejajar
    /// satu-satu dengan `maria` dan dijaga gerbang drift terhadap port Python,
    /// yang menggambar susunan yang sama.
    private static let maria: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.72, 0.02, 0.30), (-0.46, -0.36, 0.28), (-0.18, -0.44, 0.22),
        (0.06, -0.26, 0.22), (0.36, -0.06, 0.18), (0.62, -0.34, 0.13),
        (0.24, 0.18, 0.15), (-0.26, 0.34, 0.24), (-0.56, 0.38, 0.20),
        (-0.34, -0.70, 0.13), (-0.24, -0.16, 0.14)
    ]

    /// Riak tepi tiap bercak: (amplitudo, fase), sejajar satu-satu dengan
    /// `maria`. **Inilah yang membuat bercak bukan lingkaran.**
    private static let mariaRipple: [(CGFloat, CGFloat)] = [
        (0.20, 0.7), (0.17, 2.4), (0.22, 4.1), (0.15, 1.2),
        (0.19, 5.3), (0.24, 3.0), (0.16, 0.3), (0.21, 2.9),
        (0.18, 4.8), (0.23, 1.7), (0.15, 3.6)
    ]

    /// Lebar pita pelunakan tepi bercak, pecahan jari-jari tepinya.
    ///
    /// Tanpa ini, tepi beriak pun tetap tepi **keras**: ia berhenti mendadak
    /// dari opasitas penuh ke nol, dan pada ukuran kartu jam batas tajam itu
    /// terbaca sebagai stiker yang ditempel, bukan permukaan. Diukur pada
    /// kartu jam: pelunakan 0.35 menaikkan kontras bercak dari 5.9% ke 8.8%
    /// **tanpa** menaikkan opasitas puncaknya, karena piksel tepi yang dulu
    /// melompat kini ikut membawa sebagian massa gelapnya.
    private static let mariaEdgeSoftness: CGFloat = 0.35

    private static func drawMoonSurfaceShading(_ context: GraphicsContext,
                                               center: CGPoint, radius: CGFloat) {
        for (index, blob) in maria.enumerated() {
            let (dx, dy, size) = blob
            let ripple = index < mariaRipple.count ? mariaRipple[index] : (0, 0)
            let mx = center.x + dx * radius
            let my = center.y + dy * radius
            let edge = size * radius

            // Siluet beriak: satu putaran penuh, jari-jari bergantung sudut.
            let steps = 48
            var path = Path()
            for step in 0...steps {
                let theta = 2 * Double.pi * Double(step) / Double(steps)
                let phase = Double(ripple.1)
                let wobble = (cos(2 * theta + phase)
                              + cos(3 * theta + 2 * phase)
                              + cos(5 * theta + 0.5 * phase)) / 3
                let r = edge * (1 + ripple.0 * CGFloat(wobble))
                let point = CGPoint(x: mx + r * CGFloat(cos(theta)),
                                    y: my + r * CGFloat(sin(theta)))
                step == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()

            // Pelunakan tepi: opasitas penuh sampai ambang, lalu meluruh nol di
            // tepi terluar riak. Dinyatakan sebagai gradien radial, bukan
            // sebagai lapisan bertumpuk: lapisan bertumpuk menjumlahkan alfa
            // dan menaikkan opasitas puncaknya, sedangkan yang diinginkan
            // justru tepi yang memudar pada opasitas puncak yang sama.
            let outer = edge * (1 + ripple.0)
            let inner = edge * (1 - mariaEdgeSoftness)
            let shoulder = outer > 0 ? max(0, min(1, inner / outer)) : 0
            context.fill(path, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.black.opacity(0.12), location: 0),
                    .init(color: Color.black.opacity(0.12), location: shoulder),
                    .init(color: Color.black.opacity(0), location: 1)
                ]),
                center: CGPoint(x: mx, y: my), startRadius: 0, endRadius: outer))
        }
    }

    /// Pita terang sebuah benda berfase (Bulan **dan** planet dalam).
    ///
    /// Dipakai bersama supaya sabit Venus dan sabit Bulan digambar oleh kode
    /// yang sama — kalau tidak, dua salinan rumus kurva akan cepat atau lambat
    /// berbeda, dan yang salah tetap tampak seperti sabit yang meyakinkan.
    /// Geometri kurvanya sendiri datang dari `PhaseGeometry` (diuji di Linux);
    /// di sini hanya penempatan dan warna.
    ///
    /// - Parameters:
    ///   - phase: geometri dari `visual.phaseGeometry(waxing:)`.
    ///   - disc: piringan penuh, dipakai sebagai daerah klip.
    ///   - litFill: isian pita yang menyala. **Shading, bukan `Color`**, supaya
    ///     Bulan bisa memberinya gradien bola (piringan rata terbaca sebagai
    ///     guntingan kertas) sementara planet dalam tetap memakai warna rata
    ///     yang sudah punya peredupan limbnya sendiri lewat `decorate`.
    ///   - decorate: gambar tambahan di permukaan yang menyala (maria Bulan,
    ///     kawah Merkurius, kabut Venus). Dijalankan **di dalam** klip pita
    ///     yang sudah diputar, jadi hiasannya tidak pernah menonjol keluar dari
    ///     bagian yang menyala — kalau tidak, bercak gelap di sisi gelap akan
    ///     membuat sabit tampak lebih lebar daripada fraksi yang dihitung
    ///     engine.
    private func drawLitBand(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                             phase: CelestialVisual.PhaseGeometry, disc: Path,
                             litFill: GraphicsContext.Shading,
                             decorate: ((GraphicsContext) -> Void)? = nil) {
        // Pita terang = daerah antara limb dan terminator, dari kutub atas ke
        // kutub bawah. Bentuknya dibangun dari dua kurva, jadi digambar sebagai
        // Path tertutup.
        //
        // **Kedua kurva datang dari model (`PhaseGeometry`), bukan dari rumus
        // di sini.** Bukan sekadar kerapian: rumus yang sama pernah hidup di
        // view dan mengambil `abs(terminatorOffset)` lalu mengalikan lagi
        // dengan sisi — membuang tanda yang sudah menentukan sisi terminator.
        // Akibatnya untuk tiap fase di atas separuh (f > 0.5) pita yang
        // digambar menjadi **komplemen** dari fraksi yang benar: bulan 85%
        // tampil sebagai sabit 15%, dan bulan purnama tampil sebagai
        // **piringan gelap** — sementara angka "Fase Bulan 100%" tertulis
        // persis di atasnya pada layar Ketelitian.
        //
        // Cacat itu lolos karena separuh fase lainnya memang benar (sabit
        // 25% tergambar 25%), dan karena tidak ada teks di layar yang bisa
        // dibaca pengguna untuk mengeceknya. Sekarang luas kurvanya diuji di
        // Linux (`testLitBandAreaMatchesTheIlluminatedFraction`), sehingga
        // view tidak lagi bisa menyimpang diam-diam.
        let steps = 72
        var lit = Path()
        // Limb: kutub atas ke kutub bawah di sisi yang menyala.
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let normalizedY = -1 + 2 * t
            let point = CGPoint(x: center.x + CGFloat(phase.limbX(atNormalizedHeight: normalizedY)) * radius,
                                y: center.y + CGFloat(normalizedY) * radius)
            step == 0 ? lit.move(to: point) : lit.addLine(to: point)
        }
        // Kembali lewat terminator (kutub bawah ke kutub atas), memakai
        // **offset bertanda** dari model.
        for step in stride(from: steps, through: 0, by: -1) {
            let t = Double(step) / Double(steps)
            let normalizedY = -1 + 2 * t
            let x = CGFloat(phase.terminatorX(atNormalizedHeight: normalizedY)) * radius
            lit.addLine(to: CGPoint(x: center.x + x, y: center.y + CGFloat(normalizedY) * radius))
        }
        lit.closeSubpath()

        // `clip` ke piringan: wajib, karena untuk fase gibbous sisi limb bisa
        // keluar dari disk.
        //
        // **Seluruh pita diputar sebesar sudut sisi terang**, bukan hanya
        // dicerminkan. Sabit yang digambar di sini berdiri tegak dengan sisi
        // terang ke kanan; di langit, sisi terang menghadap Matahari, dan di
        // lintang Indonesia (dekat ekuator) arah itu sering menghadap ke
        // **bawah**. Tanpa putaran ini gambar akan benar untuk pengamat di
        // lintang tinggi dan salah untuk pengamat di tempat aplikasi ini
        // dipakai -- dan salahnya tidak terlihat, karena sabitnya tetap
        // berbentuk sabit.
        //
        // Sudutnya datang dari `terminatorRotationRadians` (model), yang sudah
        // memperhitungkan sisi mana yang menyala pada fase ini. Memakai sudut
        // Matahari mentah akan memasang sabit dan gibbous di sisi yang
        // berlawanan.
        //
        // `angle == nil` berarti sudutnya tidak diketahui: pita digambar apa
        // adanya (tanpa putaran), bukan diputar ke sudut karangan.
        context.drawLayer { layer in
            if let angle = visual.terminatorRotationRadians {
                // `rotate` berputar terhadap titik asal, jadi titik pusat
                // piringan harus dibawa ke asal dulu lalu dikembalikan.
                //
                // Sudutnya **dibalik** lewat `drawRotationRadians`, bukan
                // diteruskan apa adanya: `brightLimbAngle` memakai konvensi
                // matematis (positif = sisi terang ke atas), sedangkan
                // `GraphicsContext` berkoordinat layar (y ke bawah), tempat
                // sudut positif berputar searah jarum jam. Tanpa pembalikan
                // itu sabit tercermin vertikal — sisi terang menghadap ke
                // arah yang salah, tanpa ada teks di layar yang bisa
                // membuktikannya. Konversinya diuji di Linux.
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .radians(CelestialVisual.drawRotationRadians(
                    brightLimbAngleRadians: angle)))
                layer.translateBy(x: -center.x, y: -center.y)
            }
            layer.clip(to: disc)
            // Pita yang menyala: **permukaan**, jadi aturan `surface`.
            // Versi lama menulis (0.95, 0.85, 0.80) untuk malam -- 77%
            // luminansinya ada di hijau dan biru, kanal yang paling merusak
            // penglihatan malam. Angka itu justru terlihat "merah" di layar.
            layer.fill(lit, with: litFill)
            // Hiasan permukaan: **di dalam** bagian yang menyala saja, jadi
            // bercak ini tidak pernah mengubah lebar sabit yang terlihat.
            if let decorate {
                layer.drawLayer { inner in
                    inner.clip(to: lit)
                    decorate(inner)
                }
            }
        }
    }

    // MARK: - Bintang

    private func drawStar(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // **Geometri bintang datang dari `VisualFrame`, bukan dari angka di
        // sini.** Bintang adalah bentuk yang paling mudah keluar frame tanpa
        // terasa: intinya kecil, tapi glow dan spike-nya dikalikan beberapa
        // kali dari inti itu, dan `Canvas` memotong apa pun di luar frame
        // dengan **tepi lurus** — bukan dengan memudar. Jadi yang kelewat
        // besar tidak tampak "agak kepotong"; ia tampak sebagai bola cahaya
        // yang berhenti mendadak di keempat tepi kartu. Di katalog bintang
        // terang, 24 dari 25 di antaranya keluar (dihitung, bukan ditebak),
        // dan Sirius yang paling parah: 0.81R hilang.
        //
        // Inti kini dihitung **mundur dari ruang yang tersedia**, jadi
        // memperbesar glow/spike tidak bisa lagi mendorong ujungnya keluar.
        // Ujinya ada di Linux (`testEveryCatalogueStarStaysInsideTheFrame`).
        let geometry = VisualFrame.star(
            relativeSize: CelestialVisual.drawableStarSize(visual,
                                                           isConfirmed: isConfirmed))
        let coreRadius = radius * CGFloat(geometry.coreRadius)
        let color = starColor
        // Denyut halus datang dari `pulse` — bukan timer di dalam view, supaya
        // layar redup bisa menghentikannya (lihat `NightAwareContainer`).
        // Amplitudonya dibaca dari geometri yang sama, karena batas frame
        // dihitung pada **puncak** denyut: kalau view berdenyut lebih besar
        // daripada yang dipakai model saat menghitung batas, bintang akan
        // muat saat diam dan terpotong setiap kali denyut memuncak.
        let pulseFactor = 1 + CGFloat(geometry.pulseAmplitude) * CGFloat(sin(pulse))

        // Glow berlapis: cincin dengan opasitas menurun.
        for (index, scale) in geometry.glowScales.enumerated() {
            let r = coreRadius * CGFloat(scale) * pulseFactor
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                               width: r * 2, height: r * 2)),
                         with: .radialGradient(
                            Gradient(colors: [color.opacity(Self.glowOpacities[
                                min(index, Self.glowOpacities.count - 1)]),
                                              color.opacity(0)]),
                            center: center, startRadius: 0, endRadius: r))
        }
        // Empat diffraction spike tipis — ciri mata telanjang, sekaligus
        // membuat bintang terasa besar tanpa memperbesar disk intinya.
        //
        // **Bukan satu `Path` yang di-stroke.** Versi lama menggambar keempat
        // spike sebagai garis dengan `lineWidth` tetap dan opasitas rata:
        // batang sama tebal dari pangkal ke ujung, berujung rata. Pada ukuran
        // kartu jam ia terbaca sebagai **penanda bidik**, bukan cahaya —
        // batang seragam tidak pernah terjadi pada cahaya yang terdifraksi.
        //
        // Sekarang tiap spike adalah baji yang **menyempit** (pangkal
        // `spikeRootWidthFactor` → ujung `spikeTipWidthFactor`) dan
        // **memudar** ke nol di ujungnya, diisi gradien linier yang arahnya
        // keluar. Kedua nisbahnya tinggal di model (`VisualFrame.star`), jadi
        // uji Linux bisa menegakkan bahwa ujungnya memang lebih tipis
        // daripada pangkalnya — sifat yang tidak bisa dibaca dari closure
        // `Canvas`, dan karena itu sebelumnya tidak ada yang menjaganya.
        let spikeLength = coreRadius * CGFloat(geometry.spikeScale) * pulseFactor
        // **Setengah** lebar: `spikeRootWidthFactor` adalah lebar **penuh**
        // (angka yang sama dengan `lineWidth` lama), jadi jangan dipakai
        // mentah sebagai setengah lebar — itu membuat spike dua kali lebih
        // berat daripada sebelumnya, dan perubahannya jadi mengubah tebal
        // sekaligus bentuk. Yang diubah di sini hanya bentuknya.
        let rootHalf = coreRadius * CGFloat(geometry.spikeRootWidthFactor) * 0.5 * pulseFactor
        let tipHalf = coreRadius * CGFloat(geometry.spikeTipWidthFactor) * 0.5 * pulseFactor
        for (dx, dy) in [(CGFloat(1), CGFloat(0)), (CGFloat(-1), CGFloat(0)),
                         (CGFloat(0), CGFloat(1)), (CGFloat(0), CGFloat(-1))] {
            let tip = CGPoint(x: center.x + dx * spikeLength,
                              y: center.y + dy * spikeLength)
            // Setengah lebar digeser tegak lurus arah spike.
            let px = -dy
            let py = dx
            var wedge = Path()
            wedge.move(to: CGPoint(x: center.x + px * rootHalf,
                                   y: center.y + py * rootHalf))
            wedge.addLine(to: CGPoint(x: tip.x + px * tipHalf,
                                      y: tip.y + py * tipHalf))
            wedge.addLine(to: CGPoint(x: tip.x - px * tipHalf,
                                      y: tip.y - py * tipHalf))
            wedge.addLine(to: CGPoint(x: center.x - px * rootHalf,
                                      y: center.y - py * rootHalf))
            wedge.closeSubpath()
            context.fill(wedge, with: .linearGradient(
                Gradient(stops: [
                    .init(color: color.opacity(geometry.spikeOpacity), location: 0),
                    .init(color: color.opacity(0), location: 1)
                ]),
                startPoint: center, endPoint: tip))
        }
    }

    /// Opasitas tiap lapis glow, dari terluar ke terdalam.
    ///
    /// Terluar paling redup dan terdalam pekat: glow yang pekat di seluruh
    /// lebarnya tidak tampak seperti cahaya yang memudar, melainkan seperti
    /// piringan padat.
    private static let glowOpacities: [Double] = [0.10, 0.22, 1.0]

    /// Warna bintang dari indeks B−V, diwarnai ulang ke merah saat mode malam.
    ///
    /// **Kenapa konversi B−V → RGB linear.** Tabel warna stellar sungguhan
    /// (B−V ≈ 0 putih, +1.85 merah, −0.24 biru) dipetakan lewat satu
    /// interpolasi, jadi warnanya **menaiki** dengan B−V persis seperti pada
    /// bintang sungguhan. Menghapus semua hijau/biru saat mode malam **harus**
    /// menghancurkan informasi warna itu — dan memang begitu: mode malam
    /// mengorbankan warna demi rhodopsin, itu trade-off yang disengaja. Yang
    /// tidak boleh hilang adalah kontras terang-gelap, karena itulah yang
    /// masih terbaca di malam.
    private var starColor: Color {
        // Warna siang dihitung dari indeks B−V di `PointingKit`
        // (`CelestialVisual.starRGB`) -- rumus warna tidak lagi tinggal di
        // view, jadi urutannya bisa diuji di Linux.
        //
        // Indeksnya lewat `drawableStarColorIndex` dulu, **bukan** dipakai
        // mentah: warna spektral adalah ciri pengenal (biru Rigel vs merah
        // Betelgeuse), jadi saat engine belum pasti ia tidak boleh tampil --
        // aturan yang sudah berlaku untuk pita planet (`palette.feature`) dan
        // bentuk objek langit dalam (`drawableMorphology`). Yang tetap tampil
        // saat ragu hanyalah terang, dan terang tidak menyebut bintang mana.
        let index = CelestialVisual.drawableStarColorIndex(
            visual.colorIndexBV, isConfirmed: isConfirmed)
        let base = Self.color(CelestialVisual.starRGB(forColorIndex: index))
        guard NightMode.isOn else { return base }
        // Kecerahan diambil dari ukuran relatif (bintang paling terang tetap
        // paling terang), lalu warnanya dipaksakan ke merah. Kecerahan tetap
        // berasal dari **ukuran**, bukan dari warnanya: konversi B−V → RGB
        // tidak menjamin kanal merahnya mengikuti terang bintang sungguhan,
        // jadi menjadikannya sumber kecerahan akan membuat dua bintang dengan
        // terang berbeda berubah menjadi dua titik merah yang sama persis.
        // Mode malam memang membuang warna; ia tidak seharusnya membuang
        // terang juga.
        let brightness = NightVisual.floorBrightness
            + NightVisual.rangeBrightness * min(
                1, max(0, CelestialVisual.drawableStarSize(visual,
                                                           isConfirmed: isConfirmed)))
        return Color(red: brightness, green: 0, blue: 0)
    }

    // MARK: - Matahari

    private func drawSun(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // **Satu** gradient piringan, bukan dua piringan bertumpuk.
        //
        // Versi lama menggambar fotosfer penuh selebar 0.72 R lalu corona
        // selebar 1.0 R yang dimulai di 0.6 R dengan kelegapan 0.42. Di tepi
        // fotosfer kelegapannya karena itu melompat 1.0 -> 0.42 dalam satu
        // piksel: terukur 175/255, dan yang terlihat bukan tepi Matahari
        // melainkan dua benda bertumpuk. Profil radialnya sekarang tinggal di
        // model (`VisualFrame.sunProfile`, teruji di Linux), dan di sini tidak
        // ada satu angka radius pun — hanya pemetaan model ke gradient.
        //
        // Inti putih hanya di mode terang: di mode malam ia harus merah,
        // karena putih justru warna yang dilarang mode ini. Pemetaannya tetap
        // lewat `accent`/`color`, satu-satunya tempat mode malam diterapkan.
        let profile = VisualFrame.sunProfile(
            core: CelestialVisual.accents.sunCore,
            photosphere: CelestialVisual.accents.sunPhotosphere)
        let stops = profile.map { stop -> Gradient.Stop in
            let raw = stop.radiusFraction == 0 && !NightMode.isOn
                ? CelestialVisual.RGBComponents(red: 1, green: 1, blue: 1)
                : stop.color
            return Gradient.Stop(color: Self.accent(raw).opacity(stop.opacity),
                                 location: stop.radiusFraction)
        }
        // Piringan fotosfer dipotong tepat di lingkaran 1.0 R. Kelegapannya
        // di tepi (0.05) sengaja tidak nol — ia menyambung dengan halo corona
        // di bawah tanpa celah.
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                           width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(stops: stops),
                                           center: center,
                                           startRadius: 0, endRadius: radius))

        // Corona: halo lembut yang **paling terang di tepi piringan** lalu
        // memudar ke luar, menjangkau `sunCoronaReach` × radius. Dilukis
        // sebagai gradient kedua yang **ditumpangkan** di atas piringan.
        //
        // Bentuknya sengaja **pita**, bukan piringan: titik 0.0 transparan
        // (pusat), lalu mencapai puncak di tepi piringan (1.0 / reach), lalu
        // 0 di ujung. Kalau gradient dimulai dari `startRadius = radius` dengan
        // warna puncak di titik 0, seluruh lingkaran *dalam* piringan akan
        // tertutup warna puncak yang rata — corona menelan piringan. Pita
        // (transparan→puncak→transparan) membiarkan piringan terlihat di
        // dalamnya dan memberikan glow yang paling terang tepat di limb,
        // seperti corona nyata.
        //
        // Kelegapan puncaknya (`coronaOpacity`) adalah **satu-satunya** angka
        // yang hidup di view untuk Matahari; ia bukan nilai model, jadi
        // ditandai `VIEW:` dan dijaga oleh gerbang piksel
        // `check_sun_corona_reaches_beyond_the_disk` (kalau terlalu redup,
        // corona tidak terbaca; kalau terlalu pekat, ia menutupi piringan).
        let reach = CGFloat(VisualFrame.sunCoronaReach) * radius
        let coronaOpacity: Double = 0.40 // VIEW:
        let coronaColor = Self.accent(CelestialVisual.accents.sunPhotosphere)
        let coronaGradient = Gradient(stops: [
            Gradient.Stop(color: coronaColor.opacity(0), location: 0.0),
            Gradient.Stop(color: coronaColor.opacity(coronaOpacity),
                          location: 1.0 / VisualFrame.sunCoronaReach),
            Gradient.Stop(color: coronaColor.opacity(0), location: 1.0),
        ])
        context.fill(Path(ellipseIn: CGRect(x: center.x - reach, y: center.y - reach,
                                           width: reach * 2, height: reach * 2)),
                     with: .radialGradient(coronaGradient,
                                           center: center,
                                           startRadius: 0,
                                           endRadius: reach))
    }

    // MARK: - Objek langit dalam

    private func drawDeepSky(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                             isConfirmed: Bool) {
        // Kabut lembut: blob tumpang-tindih dengan opasitas rendah, tanpa
        // tepi keras. Tepi adalah ciri yang paling keliru untuk nebula/galaksi
        // -- tepi yang tepat justru terlihat "digambar".
        //
        // **Bentuknya datang dari morfologi objek, bukan dari satu rumus.**
        // Sampai siklus ini semua objek langit dalam digambar dengan tiga blob
        // yang sama, jadi galaksi Andromeda, gugus terbuka Pleiades, dan gugus
        // bola Hercules tampil **identik** -- tidak ada satu pun teks di layar
        // yang bisa membedakannya. Sekarang morfologinya dibaca dari
        // `DeepSkyCatalogue` (teruji di Linux) dan geometrinya dari
        // `VisualFrame.deepSky`, yang menjaga setiap bentuk tetap di dalam
        // frame. Morfologi `nil` (id tak dikenal) sengaja jatuh ke kabut
        // netral, bukan ke salah satu bentuk: menebak "ini galaksi" adalah
        // klaim identitas yang justru dilarang PRD.
        //
        // **Keyakinan ikut menentukan bentuk mana yang boleh tampil.**
        // Bentuk adalah ciri pengenal, sama seperti cincin Saturnus dan pita
        // Jupiter -- jadi aturannya sama: saat engine belum pasti, cirinya
        // tidak digambar. `drawableMorphology` mengembalikan `nil` saat
        // belum pasti, dan kabut netral yang tersisa tidak mengklaim jenis
        // apa pun. Sebelum ini, galaksi berpalung digambar penuh di sebelah
        // badge "Ragu", sehingga gambar lebih yakin daripada teksnya.
        let morphology = visual.objectID.flatMap {
            DeepSkyCatalogue.drawableMorphology(forObjectID: $0, isConfirmed: isConfirmed)
        }
        // Warna kabut mengikuti **morfologi yang boleh diklaim**, lewat
        // fungsi yang sama yang memutuskan bentuknya — bukan satu warna untuk
        // semua benda. Sebelum ini seluruh objek langit dalam memakai
        // `accents.deepSky`, jadi nebula emisi, nebula planetari, galaksi,
        // dan gugus bola digambar dengan warna yang sama; diukur, hue-nya
        // 0.636–0.642, yaitu satu angka.
        //
        // Warnanya diambil lewat `deepSkyColour(for:)` dengan `morphology`
        // yang **sama** dengan yang dipakai menggambar bentuk. Karena
        // `drawableMorphology` sudah mengembalikan `nil` saat engine ragu,
        // warna morfologi tidak bisa muncul di sebelah badge "Ragu" — gambar
        // yang lebih yakin daripada teksnya justru dilarang PRD.
        let core = Self.accent(CelestialVisual.deepSkyColour(for: morphology))
        let geometry = VisualFrame.deepSky(
            morphology: morphology,
            fuzziness: visual.fuzziness,
            // **Elongasi ikut `isConfirmed` lewat `morphology` di atas.**
            // Saat engine ragu, `morphology` sudah `nil`, jadi cabangnya
            // bukan `.planetaryNebula` dan elongasi tidak pernah dipakai —
            // siluet lonjong adalah klaim bentuk, sama seperti cangkangnya.
            // **Elongasi lewat gerbang keyakinan yang sama**, bukan lewat
            // `elongation(forObjectID:)` yang tidak sadar keyakinan. Dulu di
            // sini elongasi diambil langsung dari id: dengan id `m27` dan
            // engine ragu, morfologinya `nil` (kabut netral) tetapi siluetnya
            // tetap dipipihkan ke 0.60 -- gambar yang tidak mengklaim jenis
            // objek tapi memakai bentuk objeknya. Bentuk adalah ciri
            // pengenal, jadi ia tunduk pada aturan yang sama dengan cincin
            // Saturnus dan pita Jupiter.
            elongation: visual.objectID.map {
                DeepSkyCatalogue.drawableElongation(forObjectID: $0,
                                                    isConfirmed: isConfirmed)
            } ?? 1.0,
            // **Id juga lewat gerbang yang sama.** Susunan bintang per objek
            // adalah ciri pengenal juga: kalau engine ragu, gambar memakai
            // susunan bawaan, bukan susunan objeknya. Tanpa ini, kabut netral
            // masih bisa "menunjuk" satu gugus lewat tata letak bintangnya.
            objectID: isConfirmed ? visual.objectID : nil)
        for blob in geometry.blobs {
            let halfWidth = CGFloat(blob.halfWidth) * radius
            let halfHeight = CGFloat(blob.halfHeight) * radius
            guard halfWidth > 0, halfHeight > 0 else { continue }
            let centerOfBlob = CGPoint(x: center.x + CGFloat(blob.offsetX) * radius,
                                       y: center.y + CGFloat(blob.offsetY) * radius)
            // Gradiennya digambar di ruang yang **di-skala**, bukan pada
            // elips: `radialGradient` selalu melingkar, jadi menaruhnya pada
            // path elips akan memotong gradien di sumbu pendek dan
            // meninggalkan tepi rata -- persis cacat "digambar" yang ingin
            // dihindari. Skala sumbu y membuat gradiennya elips utuh.
            var blobContext = context
            blobContext.translateBy(x: centerOfBlob.x, y: centerOfBlob.y)
            if blob.angleDegrees != 0 {
                blobContext.rotate(by: .degrees(blob.angleDegrees))
            }
            blobContext.scaleBy(x: 1, y: halfHeight / halfWidth)
            blobContext.fill(
                Path(ellipseIn: CGRect(x: -halfWidth, y: -halfWidth,
                                       width: halfWidth * 2, height: halfWidth * 2)),
                with: .radialGradient(
                    Gradient(colors: [core.opacity(blob.opacity),
                                      core.opacity(0)]),
                    center: .zero, startRadius: 0, endRadius: halfWidth))
        }

        // **Bintang yang terbaca di dalam gugus.** Blob di atas adalah kabut;
        // untuk gugus, yang membuatnya terbaca sebagai gugus adalah titik-titik
        // cahaya yang bisa dipisahkan mata. Geometrinya datang dari model
        // (`clusterCores`), yang menurunkannya dari blob yang **sama** — jadi
        // bintang tidak bisa meleset dari kabutnya, dan tidak ada daftar posisi
        // kedua yang bisa tertinggal saat bentuknya dirapikan.
        //
        // Inti digambar **setelah** blob, bukan sebelumnya: kabut yang menutupi
        // bintang justru menghapus satu-satunya ciri yang membedakan gugus dari
        // nebula.
        //
        // Warnanya memakai `core` yang sama dengan kabutnya — gugus terbuka
        // putih-biru, gugus bola kuning-oranye — jadi bintang dan kabutnya satu
        // warna, persis seperti di langit: warnanya datang dari bintangnya.
        // Lewat `accent(...)`, jadi mode malam ikut memetakannya.
        // **`frameHalfExtent` di sini adalah `radius` dalam poin, dan itu
        // memang yang dibutuhkan model.** Lantai keterbacaan inti
        // (`readableCorePointRadius`) dinyatakan dalam poin, jadi radius frame
        // harus dalam satuan yang sama — bukan 1.0 (satuan model blob) yang
        // akan membuat lantai 0.8 "poin" dibaca sebagai 0.8 radius.
        let cores = VisualFrame.clusterCores(morphology: morphology,
                                             fuzziness: visual.fuzziness,
                                             frameHalfExtent: Double(radius))
        for star in cores.cores {
            let starRadius = CGFloat(star.radius) * radius
            guard starRadius > 0 else { continue }
            let starCenter = CGPoint(x: center.x + CGFloat(star.offsetX) * radius,
                                     y: center.y + CGFloat(star.offsetY) * radius)
            // Inti pekat + halo tipis. Halo sendirian akan kembali jadi kabut;
            // inti sendirian akan jadi titik yang hilang di ukuran kartu jam.
            // Opasitasnya mengikuti blob yang menaunginya, jadi gugus bola tetap
            // terlihat lebih padat di tengah daripada gugus terbuka.
            let halo = starRadius * Self.clusterCoreHaloScale
            context.fill(Path(ellipseIn: CGRect(x: starCenter.x - halo,
                                                y: starCenter.y - halo,
                                                width: halo * 2, height: halo * 2)),
                         with: .radialGradient(
                            Gradient(colors: [core.opacity(star.opacity * 0.5),
                                              core.opacity(0)]),
                            center: starCenter, startRadius: 0, endRadius: halo))
            context.fill(Path(ellipseIn: CGRect(x: starCenter.x - starRadius,
                                                y: starCenter.y - starRadius,
                                                width: starRadius * 2,
                                                height: starRadius * 2)),
                         with: .color(core.opacity(min(1, star.opacity + CGFloat(VisualFrame.clusterCoreBrighten)))))
        }
    }

    /// Pengali jari-jari halo di sekeliling inti bintang gugus.
    ///
    /// Konstanta milik view: ini hiasan lembut, bukan pernyataan tentang
    /// langit — sama kelasnya dengan bercak maria Bulan. Yang **tidak** boleh
    /// di sini adalah posisi atau ukuran intinya, dan keduanya datang dari
    /// model.
    private static let clusterCoreHaloScale: CGFloat = 2.4

    // MARK: - Penanda kandidat

    /// Tanda tanya di atas gambar yang **belum** terkonfirmasi.
    ///
    /// Ditempatkan di sudut kanan atas, bukan di tengah: penanda di tengah
    /// menutupi gambar dan membuat kelihatan rusak. Sudut cukup jelas tanpa
    /// menutupi.
    ///
    /// **Geometri lencana datang dari `VisualFrame.candidateMarker`, bukan
    /// dari angka di sini.** Lencana ini satu-satunya penanda di layar yang
    /// mengatakan "engine ragu" — jadi kalau ia terpotong tegak oleh
    /// `Canvas`, yang tersisa hanyalah gambar objek **tanpa** penanda, dan
    /// gambar tanpa penanda terbaca sebagai identitas yang pasti. Cacat pada
    /// bentuk ini justru membatalkan alasan bentuk ini ada.
    ///
    /// Jebakannya: lencana berada di **sudut**, jadi dua sisinya dekat tepi
    /// frame sekaligus. Versi lama memakai radius `0.22 · lebar` dengan pusat
    /// di `0.846 · lebar`, sehingga sisi kanan **dan** sisi atasnya keluar
    /// 0.132 R — 30% radiusnya hilang di dua sisi — dan lingkarannya tampil
    /// sebagai busur yang berhenti mendadak, bukan sebagai lingkaran. Itu
    /// dihitung, bukan ditebak, dan dikunci di Linux
    /// (`testLegacyCandidateMarkerOverflowedOnTwoSides`).
    private func drawCandidateMarker(context: GraphicsContext, size: CGSize) {
        // Satuan model adalah radius frame; `radius` di sini adalah satuan
        // yang sama dengan yang dipakai seluruh gambar lain.
        let marker = VisualFrame.candidateMarker()
        let radius = min(size.width, size.height) / 2
        let badgeRadius = CGFloat(marker.radius) * radius
        let center = CGPoint(x: size.width / 2 + CGFloat(marker.centerX) * radius,
                             y: size.height / 2 + CGFloat(marker.centerY) * radius)
        let circle = Path(ellipseIn: CGRect(x: center.x - badgeRadius,
                                           y: center.y - badgeRadius,
                                           width: badgeRadius * 2, height: badgeRadius * 2))
        // **Warna lencana datang dari model, bukan dari sini.** Versi lama
        // memakai `shadowAccent(candidateFill)` — dan pada mode malam jalur itu
        // tidak memetakan apa pun, jadi lencananya tetap biru-kehitaman: satu-
        // satunya piksel di layar merah yang bukan merah, tepat pada penanda
        // yang menjaga pengguna dari false confidence. `CandidateMarker`
        // menyatakan warna merah murni untuk kedua mode dan diuji di Linux
        // (`CandidateMarkerTests`).
        //
        // Garis dan glifnya memakai accessor token yang berdampingan dengan
        // isinya, bukan `CandidateMarker.stroke`. Keduanya satu benda: kalau
        // garisnya lewat jalur lain, garis itu bisa kembali menjadi warna yang
        // tidak diukur gerbang palet — persis cacat yang baru saja ditutup
        // pada isinya. Dibaca sekali ke `stroke`, bukan tiga kali: tiga
        // pemanggilan identik membuat "bagian yang sama" hanya kebetulan
        // yang tampak.
        let stroke = Self.color(CelestialVisual.candidateStroke(isNight: NightMode.isOn))
        context.fill(circle,
                     with: .color(Self.color(CelestialVisual.candidateFill(isNight: NightMode.isOn))))
        context.stroke(circle, with: .color(stroke), lineWidth: 1.5)
        // Tanda tanya digambar sebagai Path, bukan teks: supaya tidak ikut
        // diwarnai/ diperbesar oleh Dynamic Type, dan supaya konsisten di kedua
        // platform tanpa aset font.
        var glyph = Path()
        let r = CGFloat(marker.glyphRadius) * radius
        let top = center.y - r * 0.55
        glyph.move(to: CGPoint(x: center.x - r, y: top))
        glyph.addCurve(to: CGPoint(x: center.x, y: top + r * 0.55),
                       control1: CGPoint(x: center.x - r * 0.1, y: top - r * 0.35),
                       control2: CGPoint(x: center.x + r * 0.55, y: top + r * 0.05))
        glyph.addLine(to: CGPoint(x: center.x, y: center.y + r * 0.05))
        context.stroke(glyph, with: .color(stroke),
                       lineWidth: max(1, badgeRadius * 0.28))
        context.fill(Path(ellipseIn: CGRect(x: center.x - badgeRadius * 0.13,
                                           y: center.y + r * 0.42,
                                           width: badgeRadius * 0.26,
                                           height: badgeRadius * 0.26)),
                     with: .color(stroke))
    }
}