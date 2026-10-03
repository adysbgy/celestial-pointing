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

    public init(intent: CelestialIntent,
                context: SkyContext,
                rejected: [RejectedObject] = [],
                ephemerisFailures: [EphemerisBody] = [],
                consideredCount: Int = 0,
                sunHorizontal: HorizontalCoord? = nil) {
        self.intent = intent
        self.context = context
        self.rejected = rejected
        self.ephemerisFailures = ephemerisFailures
        self.consideredCount = consideredCount
        self.sunHorizontal = sunHorizontal
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
    public func diagnose(pointing: HorizontalCoord,
                         observer: Observer,
                         date: Date,
                         coneDeg: Double = 20.0) -> Resolution {
        let jd = SkyMath.julianDate(from: date)
        let context = skyContext(observer: observer, date: date)

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
                policy: policy
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
        let intent = ConfidenceModel.evaluate(
            candidates: candidates,
            coneDeg: coneDeg,
            nearestNeighbourDeg: Self.nearestNeighbourSeparation(candidates),
            policy: confidencePolicy
        )

        return Resolution(intent: intent,
                          context: context,
                          rejected: rejected,
                          ephemerisFailures: failures,
                          consideredCount: considered,
                          sunHorizontal: sunHorizontal)
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
