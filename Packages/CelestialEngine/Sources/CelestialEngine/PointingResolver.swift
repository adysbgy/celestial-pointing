import Foundation

/// Satu benda yang ditolak sebagai kandidat, beserta alasannya.
/// Dipakai untuk instrumentasi Experiment 1 dan untuk menjelaskan ke pengguna
/// mengapa sesuatu tidak muncul.
public struct RejectedObject: Equatable {
    public var object: CelestialObject
    public var visibility: Visibility
    public var separationDeg: Double
    public init(object: CelestialObject, visibility: Visibility, separationDeg: Double) {
        self.object = object
        self.visibility = visibility
        self.separationDeg = separationDeg
    }
}

/// Hasil resolusi lengkap, termasuk alasan di balik keputusan.
///
/// `intent` adalah jawabannya; sisanya adalah jejak audit — penting karena PRD
/// mewajibkan kita bisa menjelaskan mengapa engine yakin atau tidak yakin.
public struct Resolution: Equatable {
    public var intent: CelestialIntent
    public var context: SkyContext
    /// Benda yang lolos ke tahap kandidat tapi ditolak penyaring visibilitas.
    public var rejected: [RejectedObject]
    /// Benda tata surya yang efemerisnya gagal dihitung.
    /// Kalau tidak kosong, jawaban engine tidak boleh dianggap lengkap.
    public var ephemerisFailures: [EphemerisBody]
    /// Jumlah benda yang dipertimbangkan (bintang + benda tata surya).
    public var consideredCount: Int
    /// Arah Matahari saat itu, bila efemeris tersedia.
    ///
    /// Diekspos karena pengaman teleskop (Fase 3) butuh tahu seberapa jauh
    /// target dari Matahari. Kalau tidak ada, penyaring Matahari tidak bisa
    /// dijalankan dan pemanggil harus memperlakukannya sebagai tidak diketahui.
    public var sunHorizontal: HorizontalCoord?

    /// Jarak sudut terkecil antara kandidat terbaik dan kandidat lain di langit
    /// (derajat), dihitung dari posisi keduanya. `nil` bila kandidat < 2.
    ///
    /// **Kenapa disimpan, bukan dihitung ulang oleh pemanggil.** Inilah angka
    /// yang dipakai `ConfidenceModel` untuk memutuskan ambiguitas. Kalau
    /// pemanggil menghitungnya sendiri dari `intent.candidates`, ia hanya
    /// melihat tiga kandidat teratas — sedangkan keputusan engine dihitung dari
    /// seluruh kandidat dalam kerucut. Dua angka yang berbeda untuk pertanyaan
    /// yang sama adalah cara paling mudah membuat diagnostik berbohong tentang
    /// alasan engine ragu. Jadi yang disimpan adalah angka yang benar-benar
    /// dipakai.
    public var nearestNeighbourDeg: Double?

    /// Lebar kerucut arah tunjuk (derajat) yang dipakai pada resolusi ini.
    ///
    /// **Kenapa ini disimpan.** `rejected` memuat benda yang ditolak penyaring
    /// dari **seluruh langit**, bukan hanya benda di dalam kerucut arah tunjuk.
    /// Pemakai yang ingin menjelaskan "kenapa tidak ada objek **di arah itu**"
    /// tidak bisa menimbang seluruh daftar itu: benda di sisi langit yang lain
    /// tidak pernah sengaja ditunjuk pengguna. Tanpa kerucut yang dipakai, satu
    ///-satunya penaksir yang jujur adalah "tidak ada yang bisa dikatakan", dan
    /// itu membuang informasi yang sudah benar-benar dihitung.
    ///
    /// `nil` berarti tidak diketahui (resolusi yang dibuat tangan). Pemakai
    /// **wajib** memperlakukannya sebagai tidak diketahui, bukan mengasumsikan
    /// kerucut besar: mengarang cakupan akan mengubah alasan yang ditampilkan
    /// menjadi klaim yang tidak bisa diperiksa.
    public var pointingConeDeg: Double?

    public init(intent: CelestialIntent,
                context: SkyContext,
                rejected: [RejectedObject] = [],
                ephemerisFailures: [EphemerisBody] = [],
                consideredCount: Int = 0,
                sunHorizontal: HorizontalCoord? = nil,
                nearestNeighbourDeg: Double? = nil,
                pointingConeDeg: Double? = nil) {
        self.intent = intent
        self.context = context
        self.rejected = rejected
        self.ephemerisFailures = ephemerisFailures
        self.consideredCount = consideredCount
        self.sunHorizontal = sunHorizontal
        self.nearestNeighbourDeg = nearestNeighbourDeg
        self.pointingConeDeg = pointingConeDeg
    }
}

/// Engine inti: arah pointing + waktu + lokasi + katalog -> niat benda langit.
///
/// Aturan yang dipegang:
/// - Katalog bintang dalam J2000, jadi **wajib** dipresesi ke of-date.
/// - Benda tata surya dari efemeris sudah of-date, jadi **tidak** dipresesi.
/// - Benda yang tidak terlihat dibuang sebelum jadi kandidat. Engine tidak
///   boleh menjawab benda yang mustahil dilihat.
public struct PointingResolver {
    public var catalogue: [CelestialObject]
    public var policy: VisibilityPolicy
    /// Ambang keyakinan. Bisa dikalibrasi lewat Experiment 1.
    public var confidencePolicy: ConfidencePolicy

    /// Sumber efemeris. `nil` berarti benda tata surya tidak dipertimbangkan.
    public let ephemeris: SolarSystemEphemeris?

    /// Kerucut keamanan Matahari yang **tetap** (tidak mengikuti kebijakan
    /// visibilitas). Jika arah tunjuk berada dalam sudut ini dari Matahari
    /// (saat Matahari di atas horizon), resolver menolak mengklaim apa pun,
    /// berlaku sekalipun kebijakan paling permisif. Aturan keras PRD:
    /// menunjuk Matahari tidak boleh pernah menghasilkan kunci/identitas.
    /// Diameter sudut Matahari ~0,5°; 13° memberi ruang "kamu menunjuk ke
    /// Matahari" yang aman tanpa menolak objek yang sah di dekatnya.
    public static let sunSafeConeDeg: Double = 13.0

    public init(catalogue: [CelestialObject],
                policy: VisibilityPolicy = VisibilityPolicy(),
                confidencePolicy: ConfidencePolicy = ConfidencePolicy(),
                ephemeris: SolarSystemEphemeris? = nil) {
        self.catalogue = catalogue
        self.policy = policy
        self.confidencePolicy = confidencePolicy
        self.ephemeris = ephemeris
    }

    /// Apakah resolver ini mempertimbangkan Bulan & planet.
    public var considersSolarSystem: Bool { ephemeris != nil }

    // MARK: - Konteks langit

    /// Hitung konteks langit (Matahari, Bulan) untuk satu waktu & lokasi.
    ///
    /// Kalau efemeris tidak tersedia, langit diasumsikan gelap dan Bulan tidak
    /// diketahui — pemanggil harus sadar bahwa ini asumsi, bukan fakta.
    public func skyContext(observer: Observer, date: Date) -> SkyContext {
        guard let ephemeris else {
            return SkyContext(sunAltitudeDeg: -90, isDark: true)
        }
        let jd = SkyMath.julianDate(from: date)

        func horizon(_ body: EphemerisBody) -> HorizontalCoord? {
            guard let sample = try? ephemeris.apparent(body, at: date, from: observer) else {
                return nil
            }
            return SkyMath.equatorialToHorizontal(
                EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
                observer: observer,
                jd: jd
            )
        }

        let sunAltitude = horizon(.sun)?.altitudeDeg ?? -90
        let moon = horizon(.moon)
        var moonIllumination: Double?
        if let moonSample = try? ephemeris.apparent(.moon, at: date, from: observer) {
            moonIllumination = moonSample.illuminationFraction
        }

        return SkyContext(
            sunAltitudeDeg: sunAltitude,
            moonAltitudeDeg: moon?.altitudeDeg,
            moonIlluminationFraction: moonIllumination,
            isDark: VisibilityFilter.isDark(sunAltitudeDeg: sunAltitude, policy: policy)
        )
    }

    // MARK: - Resolusi

    /// Resolusi tanpa jejak audit.
    public func resolve(pointing: HorizontalCoord,
                        observer: Observer,
                        date: Date,
                        coneDeg: Double = 20.0) -> CelestialIntent {
        diagnose(pointing: pointing, observer: observer, date: date, coneDeg: coneDeg).intent
    }

    /// Resolusi lengkap dengan alasan keputusan.
    ///
    /// - Parameter overrideContext: konteks langit yang dipakai penyaring
    ///   visibilitas. `nil` (bawaan) berarti hitung dari efemeris lewat
    ///   `skyContext`. Parameter ini **hanya** jalur pengujian: ia memungkinkan
    ///   uji mengunci penyaringan ujung-ke-ujung (mis. cahaya Bulan mengeluarkan
    ///   bintang redup dari kandidat) tanpa harus merekayasa posisi Bulan
    ///   sungguhan di suatu tanggal. Tanpa default `nil`, semua panggilan
    ///   produksi tetap berjalan persis seperti sebelumnya.
    public func diagnose(pointing: HorizontalCoord,
                         observer: Observer,
                         date: Date,
                         coneDeg: Double = 20.0,
                         overrideContext: SkyContext? = nil) -> Resolution {
        let jd = SkyMath.julianDate(from: date)
        let context = overrideContext ?? skyContext(observer: observer, date: date)

        // Arahkan Matahari, untuk penyaring "terlalu dekat Matahari".
        var sunHorizontal: HorizontalCoord?
        if let ephemeris, let sunSample = try? ephemeris.apparent(.sun, at: date, from: observer) {
            sunHorizontal = SkyMath.equatorialToHorizontal(
                EquatorialCoord(raDeg: sunSample.raDeg, decDeg: sunSample.decDeg),
                observer: observer, jd: jd
            )
        }

        var candidates: [Candidate] = []
        var rejected: [RejectedObject] = []
        var failures: [EphemerisBody] = []
        var considered = 0

        // Gerbang pengaman Matahari: arah tunjuk **itu sendiri** tidak boleh
        // menunjuk ke Matahari. `tooCloseToSun` di `VisibilityFilter` hanya
        // memeriksa jarak tiap *kandidat* ke Matahari; ia tidak pernah
        // memeriksa apakah arah tunjuknya sendiri adalah Matahari. Tanpa ini,
        // menunjuk jam langsung ke Matahari menghasilkan kunci "Mars (medium)"
        // karena Mars kebetulan terdekat — klaim identitas palsu (false
        // confidence), persis yang dilarang PRD. Pengaman teleskop juga bergantung
        // pada ini: status `.lock` membuka izin GoTo, jadi arah pergelangan
        // tidak boleh pernah menjadi perintah motor. Cek ini sebelum kandidat
        // dihitung, dan kalau menyala, langsung kembalikan niat kosong (low,
        // tanpa best) — tidak ada kandidat yang boleh diklaim.
        //
        // Ambang tetap (`sunSafeConeDeg`), **bukan** `policy.minSunSeparationDeg`:
        // aturan "jangan pernah mengklaim identitas saat menunjuk Matahari"
        // adalah aturan keras PRD yang berlaku sekalipun kebijakan visibilitas
        // paling permisif (yang mematikan pemisahan Matahari lewat `minSunSeparationDeg: 0`).
        if let sunHorizontal, sunHorizontal.altitudeDeg > policy.minAltitudeDeg,
           SkyMath.angularSeparationHorizontalDeg(pointing, sunHorizontal) < Self.sunSafeConeDeg {
            return Resolution(intent: CelestialIntent(level: .low, best: nil, candidates: []),
                             context: context,
                             rejected: rejected,
                             ephemerisFailures: failures,
                             consideredCount: considered,
                             sunHorizontal: sunHorizontal,
                             nearestNeighbourDeg: nil,
                             pointingConeDeg: coneDeg)
        }

        func consider(_ object: CelestialObject,
                      horizontal: HorizontalCoord,
                      magnitude: Double) {
            considered += 1
            let sunSeparation = sunHorizontal.map {
                SkyMath.angularSeparationHorizontalDeg(horizontal, $0)
            }
            let visibility = VisibilityFilter.classify(
                altitudeDeg: horizontal.altitudeDeg,
                magnitude: magnitude,
                separationFromSunDeg: object.kind == .sun ? nil : sunSeparation,
                context: context,
                policy: policy,
                kind: object.kind
            )
            let separation = SkyMath.angularSeparationHorizontalDeg(pointing, horizontal)

            guard visibility.isCandidate else {
                rejected.append(RejectedObject(object: object, visibility: visibility,
                                               separationDeg: separation))
                return
            }
            if separation <= coneDeg {
                candidates.append(Candidate(object: object, separationDeg: separation))
            }
        }

        // 1. Bintang katalog (J2000) -> presesi -> horizontal.
        for object in catalogue where object.kind == .star || object.kind == .deepSky {
            let ofDate = SkyMath.precessJ2000ToDate(
                EquatorialCoord(raDeg: object.raDeg, decDeg: object.decDeg), jd: jd
            )
            consider(object,
                     horizontal: SkyMath.equatorialToHorizontal(ofDate, observer: observer, jd: jd),
                     magnitude: object.magnitude)
        }

        // 2. Benda tata surya (sudah of-date dari efemeris).
        if let ephemeris {
            for body in EphemerisBody.pointableBodies {
                do {
                    let sample = try ephemeris.apparent(body, at: date, from: observer)
                    consider(Self.catalogueObject(for: body, sample: sample),
                             horizontal: SkyMath.equatorialToHorizontal(
                                EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
                                observer: observer, jd: jd
                             ),
                             magnitude: sample.magnitude)
                } catch {
                    failures.append(body)
                }
            }
        }

        candidates.sort { $0.separationDeg < $1.separationDeg }
        // Dihitung sekali dan disimpan: angka yang sama dipakai untuk keputusan
        // keyakinan **dan** dilaporkan sebagai jejak audit. Kalau dua tempat
        // menghitungnya sendiri-sendiri, cepat atau lambat keduanya berbeda.
        let nearestNeighbour = Self.nearestNeighbourSeparation(candidates)
        let intent = ConfidenceModel.evaluate(
            candidates: candidates,
            coneDeg: coneDeg,
            nearestNeighbourDeg: nearestNeighbour,
            policy: confidencePolicy
        )

        return Resolution(intent: intent,
                          context: context,
                          rejected: rejected,
                          ephemerisFailures: failures,
                          consideredCount: considered,
                          sunHorizontal: sunHorizontal,
                          nearestNeighbourDeg: nearestNeighbour,
                          pointingConeDeg: coneDeg)
    }

    /// Ubah sampel efemeris menjadi entri katalog agar bisa ikut diresolusi.
    static func catalogueObject(for body: EphemerisBody, sample: EphemerisSample) -> CelestialObject {
        CelestialObject(
            id: body.rawValue,
            name: body.displayName,
            kind: body == .moon ? .moon : .planet,
            raDeg: sample.raDeg,
            decDeg: sample.decDeg,
            magnitude: sample.magnitude
        )
    }

    // MARK: - Arah benda saat ini

    /// Arah horizontal sebuah benda **saat ini** (bukan arah tunjuk).
    ///
    /// Dipakai oleh tiga hal di lapisan app yang semuanya butuh arah objek
    /// yang sebenarnya, bukan arah pergelangan:
    /// - kebenaran acuan saat kalibrasi (`CalibrationSolver.solve`),
    /// - label ground-truth Experiment 1 (`ObservationLog.analyze`),
    /// - target GoTo teleskop (`SlewPlanner.plan` — aturan PRD: teleskop
    ///   bergerak ke **posisi objek**, tidak pernah ke arah tunjuk).
    ///
    /// Aturan yang sama seperti `diagnose`: bintang dipresesi J2000 → of-date,
    /// benda tata surya diambil of-date dari efemeris (tidak dipresesi).
    ///
    /// - Returns: `nil` untuk Matahari (tidak pernah boleh jadi target), benda
    ///   tata surya tanpa efemeris, atau benda tata surya yang efemerisnya gagal.
    public func horizontal(of object: CelestialObject,
                           observer: Observer,
                           date: Date) -> HorizontalCoord? {
        // Benda tata surya dikenali dari id-nya (dibuat oleh
        // `catalogueObject(for:sample:)`). Matahari sengaja mengembalikan
        // `nil`: mengarahkan apa pun ke Matahari dilarang.
        if let body = EphemerisBody(rawValue: object.id) {
            guard body.isPointable else { return nil }
            return horizontal(ofBody: body, observer: observer, date: date)
        }
        let jd = SkyMath.julianDate(from: date)
        let ofDate = SkyMath.precessJ2000ToDate(
            EquatorialCoord(raDeg: object.raDeg, decDeg: object.decDeg), jd: jd
        )
        return SkyMath.equatorialToHorizontal(ofDate, observer: observer, jd: jd)
    }

    /// Arah horizontal benda berdasarkan **id** — bintang katalog maupun benda
    /// tata surya. `nil` bila id tidak dikenal atau arahnya tidak bisa dihitung.
    ///
    /// Ini jalur yang dipakai lapisan app untuk dua hal yang keduanya butuh
    /// arah objek dari sebuah id (bukan dari arah tunjuk):
    /// kalibrasi (`CalibrationSolver`) dan label ground-truth Experiment 1
    /// (`ObservationLog.analyze`).
    public func horizontal(ofObjectID id: String,
                           observer: Observer,
                           date: Date) -> HorizontalCoord? {
        if let object = catalogue.first(where: { $0.id == id }) {
            return horizontal(of: object, observer: observer, date: date)
        }
        if let body = EphemerisBody(rawValue: id) {
            return horizontal(ofBody: body, observer: observer, date: date)
        }
        return nil
    }

    /// Arah horizontal sebuah benda tata surya. `nil` bila efemeris tidak
    /// tersedia atau perhitungannya gagal — tidak pernah ditebak.
    ///
    /// Matahari **selalu** ditolak di sini. Arah Matahari hanya boleh keluar
    /// lewat `Resolution.sunHorizontal`, yaitu jalur yang dipakai pengaman
    /// teleskop untuk menghitung jarak aman — bukan sebagai arah yang bisa
    /// diserahkan ke motor.
    public func horizontal(ofBody body: EphemerisBody,
                           observer: Observer,
                           date: Date) -> HorizontalCoord? {
        guard body.isPointable else { return nil }
        guard let ephemeris else { return nil }
        guard let sample = try? ephemeris.apparent(body, at: date, from: observer) else {
            return nil
        }
        return SkyMath.equatorialToHorizontal(
            EquatorialCoord(raDeg: sample.raDeg, decDeg: sample.decDeg),
            observer: observer,
            jd: SkyMath.julianDate(from: date)
        )
    }

    /// Jarak sudut terkecil antara kandidat terbaik dan kandidat lain,
    /// dihitung dari koordinat sesungguhnya (bukan selisih jarak ke arah tunjuk).
    ///
    /// Dihitung di ruang ekuatorial of-date; kandidat sudah dalam kerangka itu
    /// (bintang sudah dipresesi, benda tata surya of-date dari efemeris).
    /// `nil` kalau kandidatnya kurang dari dua.
    static func nearestNeighbourSeparation(_ candidates: [Candidate]) -> Double? {
        guard candidates.count >= 2 else { return nil }
        let best = EquatorialCoord(raDeg: candidates[0].object.raDeg,
                                   decDeg: candidates[0].object.decDeg)
        var nearest = Double.greatestFiniteMagnitude
        for other in candidates.dropFirst() {
            let coord = EquatorialCoord(raDeg: other.object.raDeg, decDeg: other.object.decDeg)
            nearest = min(nearest, SkyMath.angularSeparationDeg(best, coord))
        }
        return nearest == .greatestFiniteMagnitude ? nil : nearest
    }
}
