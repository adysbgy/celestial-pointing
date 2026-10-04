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
    var isConfirmed: Bool = true

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
        // deskripsi gambar hanya menambah yang harus di-George.
        .accessibilityHidden(true)
    }

    private func drawBody(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        switch visual.kind {
        case .planet: drawPlanet(context: context, center: center, radius: radius)
        case .moon: drawMoon(context: context, center: center, radius: radius)
        case .star: drawStar(context: context, center: center, radius: radius)
        case .sun: drawSun(context: context, center: center, radius: radius)
        case .deepSky: drawDeepSky(context: context, center: center, radius: radius)
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
    private static func color(_ raw: CelestialVisual.RGBComponents) -> Color {
        guard NightMode.isOn else {
            return Color(red: raw.red, green: raw.green, blue: raw.blue)
        }
        // Rentang kanal merah dipetakan ke 0.35…1: merah paling redup masih
        // kontras di layar gelap, dan tidak ada yang berubah jadi putih.
        let brightness = 0.35 + 0.65 * min(1, max(0, raw.nightModeBrightness))
        return Color(red: brightness, green: 0, blue: 0)
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
    private func drawBands(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Lebar pita dikalibrasi untuk kontras tinggi di layar kecil: pita
        // yang terlalu tipis hilang di layar jam.
        let bandCount = 7
        for index in 0..<bandCount {
            let t = (Double(index) + 0.5) / Double(bandCount)
            let y = center.y - radius + 2 * radius * CGFloat(t)
            // Pita mengikuti keliling bola: makin dekat kutub, makin pendek.
            let halfWidth = radius * CGFloat(cos((t - 0.5) * .pi * 0.92))
            guard halfWidth > 1 else { continue }
            let rect = CGRect(x: center.x - halfWidth,
                              y: y - radius * 0.055,
                              width: halfWidth * 2,
                              height: radius * 0.11)
            let shade = index % 3
            let color: Color = NightMode.isOn
                ? Color(red: 0.34 + 0.18 * Double(shade) / 2, green: 0, blue: 0)
                : (shade == 0 ? Color(red: 0.85, green: 0.76, blue: 0.62)
                  : shade == 1 ? Color(red: 0.72, green: 0.52, blue: 0.38)
                  : Color(red: 0.90, green: 0.83, blue: 0.72))
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.55)))
        }
        // Bintik Merah Besar: elips merah di belahan selatan, sedikit di bawah
        // ekuator — posisinya memang di sana secara nyata.
        let spot = CGRect(x: center.x - radius * 0.36,
                          y: center.y + radius * 0.18,
                          width: radius * 0.52,
                          height: radius * 0.26)
        context.fill(Path(ellipseIn: spot),
                     with: .color(NightMode.isOn
                                  ? Color(red: 0.75, green: 0.12, blue: 0)
                                  : Color(red: 0.85, green: 0.35, blue: 0.25)))
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

        let outer = CGRect(x: center.x - CGFloat(ring.halfWidth) * radius,
                           y: center.y - CGFloat(ring.halfHeight) * radius,
                           width: CGFloat(ring.fullWidth) * radius,
                           height: CGFloat(ring.fullHeight) * radius)
        let ringColor: Color = NightMode.isOn
            ? Color(red: 0.62, green: 0.30, blue: 0.16)
            : Color(red: 0.86, green: 0.78, blue: 0.60)

        // Belakang cincin (paruh atas).
        context.fill(Path(ellipseIn: outer), with: .color(ringColor.opacity(0.45)))

        let palette = CelestialVisual.Planet.saturn.palette
        drawSphere(context: context, center: center, radius: CGFloat(bodyRadius) * radius,
                   from: palette.light, to: palette.dark)

        // Depan cincin (paruh bawah) -- digambar di atas bola. Batas bawahnya
        // adalah **setengah bawah frame** (`CGRect` penuh, bukan
        // `Path(ellipseIn:)`), jadi cincin tepat melewati ekuator bola --
        // yang persis seperti yang terlihat pada Saturnus.
        var front = context
        front.clip(to: Path(CGRect(x: 0, y: center.y,
                                  width: outer.maxX,
                                  height: outer.maxY - center.y)))
        front.fill(Path(ellipseIn: outer), with: .color(ringColor.opacity(0.8)))
        // Pembelah cincin (Cassini): cincin tidak pekat seragam.
        let gap = outer.insetBy(dx: CGFloat(bodyRadius) * radius * 0.34,
                                dy: outer.height * 0.09)
        front.fill(Path(ellipseIn: gap), with: .color(Color.black.opacity(0.28)))
    }

    /// Kutub Mars: kapsul es di utara dan selatan.
    private func drawPolarCaps(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let capColor: Color = NightMode.isOn
            ? Color(red: 0.55, green: 0.18, blue: 0.14)
            : Color(red: 0.97, green: 0.95, blue: 0.93)
        // Geometri kutub datang dari `CelestialVisual.polarCaps`, yang teruji
        // di Linux — **di sini tidak ada rumus kutub lagi**.
        //
        // Versi lama menghitung kutub utara `y - radius` tapi kutub selatan
        // `y + radius - capHeight`, dengan tinggi elips `2 · capHeight`.
        // Akibatnya kutub selatan berakhir di y = 1.26: **0.26R di luar
        // bola**, menggantung di ruang kosong, dan tidak simetris dengan
        // kutub utara (yang hanya meleset 0.004R). Kutub adalah ciri
        // pengenal Mars, jadi bentuk yang salah bukan soal rasa — ia lewat
        // apa yang PRD larang: gambar yang mengklaim identitas.
        // Sekarang kutub selatan adalah cermin kutub utara secara
        // konstruktif, jadi ketidak-simetrisan seperti itu tidak bisa
        // ditulis ulang tanpa mengubah bentuknya di sini juga.
        let caps = CelestialVisual.polarCaps()
        for cap in [caps.north, caps.south] {
            let rect = CGRect(x: center.x - CGFloat(cap.halfWidth) * radius,
                              y: center.y + CGFloat(cap.topY) * radius,
                              width: CGFloat(cap.halfWidth) * radius * 2,
                              height: CGFloat(cap.height) * radius)
            context.fill(Path(ellipseIn: rect), with: .color(capColor.opacity(0.85)))
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
        let haze = NightMode.isOn
            ? Color(red: 0.72, green: 0.30, blue: 0.16)
            : Color(red: 0.99, green: 0.96, blue: 0.82)
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

    private func drawMoon(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        // Piringan gelap dulu (bagian yang tidak menyala) — tanpa ini sabit
        // akan tampak seperti bulan sabit berdiri sendiri di ruang kosong.
        context.fill(disc, with: .color(NightMode.isOn
                                        ? Color(red: 0.09, green: 0.03, blue: 0.02)
                                        : Color(red: 0.13, green: 0.13, blue: 0.16)))

        guard let phase = visual.phaseGeometry(waxing: visual.isWaxing) else {
            // Fase tidak diketahui: gambar piringan polos redup. Piringan penuh
            // **tidak** mengklaim "purnama" (itu butuh f = 1), ia hanya
            // mengakui arah fase tidak dihitung — dan tidak pernah memihak ke
            // satu sisi.
            return
        }

        // Pita terang = daerah antara terminator dan limb di sisi yang menyala.
        // Bentuknya dibangun dari dua kurva, jadi digambar sebagai Path tertutup.
        //
        // Sisi limb diambil dari `litSide`, **bukan** dari tanda
        // `terminatorOffset`: untuk fase gibbous keduanya berlawanan. Ambil dari
        // tanda terminator → sabit menghadap ke belakang tepat pada fase yang
        // paling mudah dikenali pengguna, dan tidak ada teks di layar yang
        // memberitahu mereka.
        let side = CGFloat(phase.litSide)
        let semiWidth = CGFloat(phase.terminatorSemiWidth)
        let steps = 72
        var lit = Path()
        // Limb: busur dari kutub atas ke kutub bawah di sisi yang terang.
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let angle = -.pi / 2 + t * .pi
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius * side,
                                y: center.y + CGFloat(sin(angle)) * radius)
            step == 0 ? lit.move(to: point) : lit.addLine(to: point)
        }
        // Kembali lewat terminator (kutub bawah → kutub atas):
        // x = offset · R · √(1 − (y/R)²).
        for step in stride(from: steps, through: 0, by: -1) {
            let t = Double(step) / Double(steps)
            let y = center.y - radius + 2 * radius * CGFloat(t)
            let dy = (y - center.y) / radius
            let x = side * semiWidth * radius * CGFloat(sqrt(max(0, 1 - dy * dy)))
            lit.addLine(to: CGPoint(x: center.x + x, y: y))
        }
        lit.closeSubpath()

        // `clip` ke piringan: wajib, karena untuk fase gibbous sisi limb bisa
        // keluar dari disk.
        context.drawLayer { layer in
            layer.clip(to: disc)
            layer.fill(lit, with: .color(NightMode.isOn
                                         ? Color(red: 0.95, green: 0.85, blue: 0.80)
                                         : Color(red: 0.97, green: 0.95, blue: 0.90)))
            // Maria: bercak gelap **di dalam** bagian yang menyala saja, jadi
            // Maria digambar **hanya** di dalam bagian yang menyala, jadi
            // bercak ini tidak pernah mengubah lebar sabit yang terlihat.
            for (dx, dy, size) in [(-0.28, -0.30, 0.26), (0.10, -0.44, 0.20),
                                   (-0.34, 0.06, 0.22), (0.22, 0.26, 0.16)] {
                let rect = CGRect(x: center.x + dx * radius - size * radius,
                                  y: center.y + dy * radius - size * radius,
                                  width: size * radius * 2,
                                  height: size * radius * 2)
                layer.drawLayer { inner in
                    inner.clip(to: lit)
                    inner.fill(Path(ellipseIn: rect),
                               with: .color(Color.black.opacity(0.12)))
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
        let base = Self.starColor(forColorIndex: visual.colorIndexBV)
        guard NightMode.isOn else { return base }
        // Kecerahan diambil dari ukuran relatif (bintang paling terang tetap
        // paling terang), lalu warnanya dipaksakan ke merah.
        let brightness = 0.35 + 0.55 * visual.relativeSize
        return Color(red: brightness, green: 0, blue: 0)
    }

    /// RGB dari indeks warna B−V.
    ///
    /// Monochromat: panjang gelombang "berat" = merah. B−V positif (Merah,
    /// Arcturus, Betelgeuse) → hangat; negatif (biru, Rigel, Alnitak) → dingin.
    /// Ini tren yang benar secara astronomi dan cukup untuk perbedaan yang
    /// dilihat pengguna mata telanjang.
    static func starColor(forColorIndex index: Double) -> Color {
        let clamped = min(2.0, max(-0.5, index))
        // −0.35 … +1.35 → 0 … 1 (biru ke merah), lalu dingatkan sedikit di
        // ujung biru supaya Rigel tidak tampak ungu.
        let warmth = (clamped + 0.35) / 1.70
        return Color(red: 0.62 + 0.38 * warmth,
                     green: 0.78 - 0.16 * warmth,
                     blue: 1.00 - 0.72 * warmth)
    }

    // MARK: - Matahari

    private func drawSun(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let core = NightMode.isOn
            ? Color(red: 0.95, green: 0.45, blue: 0.10)
            : Color(red: 1.0, green: 0.93, blue: 0.62)
        let photosphere = NightMode.isOn
            ? Color(red: 1.0, green: 0.72, blue: 0.25)
            : Color(red: 1.0, green: 0.72, blue: 0.24)
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

    private func drawDeepSky(context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Kabut lembut: cincin tumpang-tindih dengan opasitas rendah, tanpa
        // tepi keras. Tepi adalah ciri yang paling keliru untuk nebula/galaksi
        // -- tepi yang tepat justru terlihat "digambar".
        //
        // **Geometri blob datang dari `VisualFrame.nebula`.** Blob digeser dari
        // pusat supaya kabut tidak simetris sempurna, dan geseran itu
        // memperkecil ruang yang tersisa ke tepi frame. Memakai radius tetap
        // untuk semua blob membuat blob yang digeser terpotong **tegak** oleh
        // `Canvas` -- tepat di tengah gradiennya, jadi potongannya terlihat.
        // Itulah yang dihitung model, dan ujinya ada di Linux.
        let core = NightMode.isOn
            ? Color(red: 0.78, green: 0.20, blue: 0.12)
            : Color(red: 0.72, green: 0.78, blue: 0.95)
        let nebula = VisualFrame.nebula(fuzziness: visual.fuzziness)
        for blob in nebula.blobs {
            let r = CGFloat(blob.radius) * radius
            guard r > 0 else { continue }
            let centerOfBlob = CGPoint(x: center.x + CGFloat(blob.offsetX) * radius,
                                       y: center.y + CGFloat(blob.offsetY) * radius)
            context.fill(Path(ellipseIn: CGRect(x: centerOfBlob.x - r, y: centerOfBlob.y - r,
                                               width: r * 2, height: r * 2)),
                         with: .radialGradient(
                            Gradient(colors: [core.opacity(blob.opacity),
                                              core.opacity(0)]),
                            center: centerOfBlob, startRadius: 0, endRadius: r))
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
        context.fill(circle, with: .color(NightMode.isOn
                                          ? Color(red: 0.18, green: 0.02, blue: 0.01)
                                          : Color(red: 0.10, green: 0.10, blue: 0.13)))
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