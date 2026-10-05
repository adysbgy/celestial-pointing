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
        // Grafis tidak pernah diumumkan sebagai teks — VoiceOver membaca nama
        // objek & keyakinannya (lihat `ObjectDetailView`), dan menambah
        // deskripsi gambar hanya menambah yang harus dilalui pengguna.
        .accessibilityHidden(true)
    }

    private func drawBody(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        switch visual.kind {
        case .planet: drawPlanet(context: context, center: center, radius: radius)
        case .moon: drawMoon(context: context, center: center, radius: radius)
        case .star: drawStar(context: context, center: center, radius: radius)
        case .sun: drawSun(context: context, center: center, radius: radius)
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
        let palette = planet.palette

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
                        litColor: Self.color(palette.light),
                        decorate: { inner in
                            // Peredupan limb di dalam pita: gradien radial
                            // **berpusat di pusat piringan**, bukan digeser
                            // ke kiri-atas seperti bola penuh. Gradien yang
                            // digeser ikut berputar bersama pita, sehingga
                            // "cahaya dari kiri-atas" akan menghadap arah yang
                            // salah begitu sisi terangnya ke bawah — dan
                            // planetnya tetap tampak seperti bola, jadi
                            // tidak ada yang bisa menangkapnya dari layar.
                            inner.fill(disc, with: .radialGradient(
                                Gradient(colors: [Self.color(palette.light),
                                                  Self.color(palette.dark)]),
                                center: center, startRadius: 0, endRadius: radius * 1.15))
                            // Ciri pengenal (kawah Merkurius, kabut Venus) ikut
                            // terpotong ke bagian yang menyala, jadi tidak
                            // pernah menonjol keluar dari sabit.
                            switch palette.feature {
                            case .craters:
                                self.drawCraters(context: inner, center: center, radius: radius)
                            case .haze:
                                self.drawHaze(context: inner, center: center, radius: radius)
                            case .bands, .rings, .polarCaps, .none:
                                break
                            }
                        })
            return
        }

        drawSphere(context: context, center: center, radius: radius,
                   from: palette.light, to: palette.dark)
        // Saat identitas belum pasti, hanya **warnanya** yang boleh tampil —
        // bentuknya tidak. Cincin Saturnus adalah penanda yang sama
        // meyakinkannya dengan pita Jupiter, jadi menampilkannya pada kandidat
        // yang belum terkunci berarti menyampaikan identitas yang tidak
        // dimiliki engine. `palette.feature` sudah diuji di Linux, jadi
        // pemetaan planet → ciri tidak bisa lagi diam-diam bergeser.
        guard isConfirmed else { return }
        switch palette.feature {
        case .bands: drawBands(context: context, center: center, radius: radius)
        case .rings: drawRings(context: context, center: center, radius: radius)
        case .polarCaps: drawPolarCaps(context: context, center: center, radius: radius)
        case .craters: drawCraters(context: context, center: center, radius: radius)
        case .haze: drawHaze(context: context, center: center, radius: radius)
        case .none: break
        }
    }

    /// Warna bola untuk planet yang id-nya tidak dikenali.
    ///
    /// Netral keabu-abuan, bukan warna planet mana pun: bola ungu akan
    /// menyiratkan "ini planet tertentu", padahal yang diketahui hanya "ini
    /// planet yang tidak kita kenali".
    private static let neutralBody = CelestialVisual.RGBComponents(red: 0.74, green: 0.72, blue: 0.68)
    private static let neutralShadow = CelestialVisual.RGBComponents(red: 0.28, green: 0.27, blue: 0.26)

    /// Gradien bola: pencahayaan dari kiri-atas, bayangan di kanan-bawah.
    private func drawSphere(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                            from light: CelestialVisual.RGBComponents,
                            to dark: CelestialVisual.RGBComponents) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .radialGradient(
            Gradient(colors: [Self.color(light), Self.color(dark)]),
            center: CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.32),
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
    private func drawBands(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Lebar pita dikalibrasi untuk kontras tinggi di layar kecil: pita
        // yang terlalu tipis hilang di layar jam. Angkanya milik model
        // (`jupiterBands`), dan `check-visuals.py` menjaga agar port Python
        // tidak tertinggal saat nilainya berubah.
        let bands = CelestialVisual.jupiterBands()
        for (index, band) in bands.enumerated() {
            let y = center.y + CGFloat(band.centerY) * radius
            let halfWidth = radius * CGFloat(band.halfWidth)
            guard halfWidth > 1 else { continue }
            let rect = CGRect(x: center.x - halfWidth,
                              y: y - radius * CGFloat(band.halfHeight),
                              width: halfWidth * 2,
                              height: radius * CGFloat(band.halfHeight) * 2)
            // Warna pita dibaca dari model, mode malam dihitung dari kanal
            // merahnya. Versi lama menulis angka malam sendiri
            // (`0.34 + 0.18 * shade / 2`), dan urutan hasilnya **terbalik**:
            // pita paling gelap (kanal merah 0.72) menjadi lebih terang dari
            // pita paling terang (0.85) -- 0.43 vs 0.34. Mode malam
            // mengorbankan hue secara sengaja, tapi terang-gelap tidak boleh
            // ikut terbalik; itu informasi yang masih terbaca di malam.
            let bandColor: CelestialVisual.RGBComponents
            switch index % 3 {
            case 0: bandColor = CelestialVisual.accents.jupiterBandTan
            case 1: bandColor = CelestialVisual.accents.jupiterBandRust
            default: bandColor = CelestialVisual.accents.jupiterBandCream
            }
            context.fill(Path(ellipseIn: rect),
                         with: .color(Self.accent(bandColor).opacity(0.55)))
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
        context.fill(Path(ellipseIn: spotRect),
                     with: .color(Self.accent(CelestialVisual.accents.jupiterSpot)))
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
            inner.fill(Path(ellipseIn: rect), with: .color(capColor.opacity(0.85)))
        }
    }

    /// Merkurius: abu berkawah.
    ///
    /// Posisi kawah ditulis relatif terhadap pusat & radius supaya proporsinya
    /// tetap sama pada kartu jam maupun panel besar di iPhone.
    private func drawCraters(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let craters: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.30, -0.22, 0.20), (0.28, -0.05, 0.15), (-0.12, 0.32, 0.17),
            (0.34, 0.34, 0.11), (0.02, -0.48, 0.13)
        ]
        for (dx, dy, size) in craters {
            let rect = CGRect(x: center.x + dx * radius - size * radius,
                              y: center.y + dy * radius - size * radius,
                              width: size * radius * 2,
                              height: size * radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.18)))
        }
    }

    /// Venus: kabut tebal yang menutupi detail permukaan.
    private func drawHaze(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let haze = Self.accent(CelestialVisual.accents.venusHaze)
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.55,
                                           y: center.y - radius * 0.72,
                                           width: radius * 1.10,
                                           height: radius * 1.44)),
                     with: .linearGradient(
                        Gradient(colors: [haze.opacity(0), haze.opacity(0.7)]),
                        startPoint: CGPoint(x: center.x, y: center.y - radius),
                        endPoint: CGPoint(x: center.x, y: center.y)))
    }

    // MARK: - Bulan

    /// Bulan: piringan gelap + pita terang berfase.
    private func drawMoon(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
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
            context.fill(disc,
                         with: .color(Self.accent(CelestialVisual.accents.moonPhaseUnknown)))
            return
        }

        // Piringan gelap dulu (bagian yang tidak menyala) — tanpa ini sabit
        // akan tampak seperti bulan sabit berdiri sendiri di ruang kosong.
        // Piringan gelap memakai aturan `shadow`, bukan `surface`: ia tidak
        // memancarkan cahaya, dan memetakannya lewat aturan permukaan akan
        // menaikkannya ke kanal merah 0.44 sehingga kontras sabit terhadap
        // gelap jatuh ke 2.99:1 -- tepat di layar yang paling dipakai untuk
        // melihat bulan, dan tepat saat mode malam dipilih.
        context.fill(disc,
                     with: .color(Self.shadowAccent(CelestialVisual.accents.moonUnlit)))

        drawLitBand(context: context, center: center, radius: radius, phase: phase, disc: disc,
                    litColor: Self.accent(CelestialVisual.accents.moonLit),
                    decorate: { inner in
                        Self.drawMoonSurfaceShading(inner, center: center, radius: radius)
                    })
    }

    /// Bercak gelap (maria) di permukaan Bulan.
    ///
    /// Konstanta milik view, bukan model: ini tekstur hias, bukan pernyataan
    /// tentang langit. Yang **tidak** boleh di sini adalah hal yang menyatakan
    /// identitas atau geometri (fase, sisi terang) — semuanya datang dari
    /// model supaya bisa diuji.
    private static func drawMoonSurfaceShading(_ context: GraphicsContext,
                                               center: CGPoint, radius: CGFloat) {
        for (dx, dy, size) in [(-0.28, -0.30, 0.26), (0.10, -0.44, 0.20),
                               (-0.34, 0.06, 0.22), (0.22, 0.26, 0.16)] {
            let rect = CGRect(x: center.x + dx * radius - size * radius,
                              y: center.y + dy * radius - size * radius,
                              width: size * radius * 2,
                              height: size * radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.12)))
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
    ///   - litColor: warna pita yang menyala (aturan `surface`).
    ///   - decorate: gambar tambahan di permukaan yang menyala (maria Bulan,
    ///     kawah Merkurius, kabut Venus). Dijalankan **di dalam** klip pita
    ///     yang sudah diputar, jadi hiasannya tidak pernah menonjol keluar dari
    ///     bagian yang menyala — kalau tidak, bercak gelap di sisi gelap akan
    ///     membuat sabit tampak lebih lebar daripada fraksi yang dihitung
    ///     engine.
    private func drawLitBand(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                             phase: CelestialVisual.PhaseGeometry, disc: Path,
                             litColor: Color,
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
            layer.fill(lit, with: .color(litColor))
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
        let geometry = VisualFrame.star(relativeSize: visual.relativeSize)
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
        let spikeLength = coreRadius * CGFloat(geometry.spikeScale) * pulseFactor
        var spikes = Path()
        spikes.move(to: CGPoint(x: center.x - spikeLength, y: center.y))
        spikes.addLine(to: CGPoint(x: center.x + spikeLength, y: center.y))
        spikes.move(to: CGPoint(x: center.x, y: center.y - spikeLength))
        spikes.addLine(to: CGPoint(x: center.x, y: center.y + spikeLength))
        context.stroke(spikes, with: .color(color.opacity(0.45)),
                       lineWidth: max(0.5, coreRadius * 0.18))
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
            + NightVisual.rangeBrightness * min(1, max(0, visual.relativeSize))
        return Color(red: brightness, green: 0, blue: 0)
    }

    // MARK: - Matahari

    private func drawSun(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let core = Self.accent(CelestialVisual.accents.sunCore)
        let photosphere = Self.accent(CelestialVisual.accents.sunPhotosphere)
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.72,
                                           y: center.y - radius * 0.72,
                                           width: radius * 1.44, height: radius * 1.44)),
                     with: .radialGradient(
                        Gradient(colors: [NightMode.isOn ? core : .white, core, photosphere]),
                        center: center, startRadius: 0, endRadius: radius * 0.72))
        // Corona: cincin luar yang memudar, digambar **di luar** disk supaya
        // tidak menutupi fotosfer.
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                           width: radius * 2, height: radius * 2)),
                     with: .radialGradient(
                        Gradient(colors: [core.opacity(0.42), core.opacity(0)]),
                        center: center, startRadius: radius * 0.6, endRadius: radius))
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
        let core = Self.accent(CelestialVisual.accents.deepSky)
        let morphology = visual.objectID.flatMap {
            DeepSkyCatalogue.drawableMorphology(forObjectID: $0, isConfirmed: isConfirmed)
        }
        let geometry = VisualFrame.deepSky(morphology: morphology,
                                           fuzziness: visual.fuzziness)
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
    }

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
        context.fill(circle,
                     with: .color(Self.shadowAccent(CelestialVisual.accents.candidateFill)))
        context.stroke(circle, with: .color(PointingTone.warning.color), lineWidth: 1.5)
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
        context.stroke(glyph, with: .color(PointingTone.warning.color),
                       lineWidth: max(1, badgeRadius * 0.28))
        context.fill(Path(ellipseIn: CGRect(x: center.x - badgeRadius * 0.13,
                                           y: center.y + r * 0.42,
                                           width: badgeRadius * 0.26,
                                           height: badgeRadius * 0.26)),
                     with: .color(PointingTone.warning.color))
    }
}