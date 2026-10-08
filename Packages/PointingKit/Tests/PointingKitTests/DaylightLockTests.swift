import XCTest
import CelestialEngine
@testable import PointingKit

/// Siang hari harus terasa sampai ke **keputusan aplikasi**, bukan berhenti di
/// lapisan `VisibilityFilter`.
///
/// **Kenapa perlu ada tes di sini.** `DaylightStarVisibilityTests` di paket
/// engine membuktikan resolver tidak mengembalikan keyakinan tinggi saat
/// siang. Tapi keputusan itu belum sampai ke tempat yang berbahaya: `.lock`
/// adalah keadaan yang memicu haptic sukses, bunyi, pengumuman VoiceOver,
/// visual pengenal, dan izin GoTo. Di antara resolver dan `.lock` ada
/// langkah-langkah lain (smoothing, `PointingStateMachine`, ambang penguncian),
/// dan tidak satu pun dari langkah itu yang menguji terang.
///
/// **Cacat yang ditutup di sini.** Versi pertama berkas ini menunjuk **bintang
/// paling terang** (Sirius) tepat pada tengah hari Jakarta. Pada tanggal itu
/// Sirius ada di bawah horizon, jadi resolver menolaknya lebih dulu karena
/// `belowHorizon` — bukan karena terang. Kesimpulan "tidak terkunci" tetap
/// benar, dan tetap benar ketika penyaringan siang dihapus total: mutasi
/// `if false` di `VisibilityFilter.classify` membuat keempat tes berkas ini
/// tetap hijau. Uji yang hijau tanpa pengujian seperti ini adalah yang paling
/// berbahaya, karena ia memberi kesan jalur controller sampai `.lock` sudah
/// diawasi terang.
///
/// Perbaikannya bukan assertion baru, tapi **arah tuju** plus syarat yang
/// benar-benar dibuktikan. Arah tunjuk dipilih dari katalog, bukan ditulis
/// tangan, dengan empat syarat yang semuanya harus benar.
final class DaylightLockTests: XCTestCase {

    /// Pengamat Jakarta (WIB, UTC+7). Latitude ditulis dengan titik desimal agar
    /// tanda negatifnya tidak ambigu: `-6,2` tanpa titik adalah `-62`.
    private let observer = Observer(latitudeDeg: -6.2, longitudeDeg: 106.8)

    /// **Tengah hari lokal** di zona Jakarta (WIB, UTC+7): 15 Jan 2026 12:00
    /// WIB = 05:00 UTC.
    ///
    /// Angka dipilih eksplisit, bukan "sekitar 1,7e9". `PointingControllerTests`
    /// memakai `1_700_000_000`, yang untuk Jakarta jatuh di **tengah malam**
    /// (Matahari -3,7 derajat), bukan siang. Tes yang butuh langit terang tidak
    /// boleh memakai cap waktu yang hanya kelihatan benar.
    ///
    /// **Kenapa 15 Januari, bukan 21 Juni.** Versi pertama memakai tanggal yang
    /// paling mudah dibaca sebagai "siang yang jelas", dan pilihan itu membuat
    /// berkas ini mustahil punya jam kontrol: pada 21 Juni Sirius adalah benda
    /// **pagi**, dan sepanjang malam Jakarta ia di bawah horizon. Satu tanggal
    /// harus melayani dua syarat yang berlawanan — langit terang saat tengah
    /// hari, dan bintang yang bisa ditunjuk saat gelap — dan hanya sebagian
    /// hari dalam tahun yang keduanya benar-benar benarkan. Angka di sini
    /// dipilih lewat pengukuran, bukan tebakan; dua prasyarat di bawah
    /// mengunci hasilnya.
    private let noon = Date(timeIntervalSince1970: 1_768_453_200)

    /// Policy produksi, bukan `.permissive`.
    ///
    /// `.permissive` sengaja menyetel `sunAltitudeForDarknessDeg: 91` supaya
    /// policy pengujian tidak membuang apa pun. Kalau tes ini memakainya, siang
    /// hari memang terkunci — bukan karena `.lock` bocor, tapi karena gerbang
    /// siang dimatikan atas permintaan. Tes kejujuran tidak boleh memakai policy
    /// yang sengaja dibuat longgar.
    private var productionPolicy: VisibilityPolicy { VisibilityPolicy() }

    /// Policy yang hanya melonggarkan **gerbang kegelapan**, untuk bukti positif.
    ///
    /// Longgaran sengaja dibuat sempit: `minAltitudeDeg`,
    /// `limitingMagnitude`, dan `minSunSeparationDeg` tetap sama, jadi
    /// satu-satunya yang berubah adalah "apakah langit cukup gelap".
    private var darknessRelaxedPolicy: VisibilityPolicy {
        var policy = productionPolicy
        policy.sunAltitudeForDarknessDeg = 91
        return policy
    }

    private func makeResolver(policy: VisibilityPolicy) -> PointingResolver {
        PointingResolver(catalogue: Catalogue.brightStars,
                         policy: policy,
                         ephemeris: AstronomyKitEphemeris())
    }

    private func quaternion(viewPointingAt target: HorizontalCoord) -> Quaternion {
        // Sumbu bawaan controller (lengan bawah), konvensi CoreMotion — ADR-002.
        DeviceAttitude.synthetic(aim: PointingControllerConfig().aim, pointingAt: target).quaternion
    }

    // MARK: - Prasyarat

    /// Langit benar-benar terang, dan konteksnya **berasal** dari Matahari
    /// nyata.
    ///
    /// Baris kedua adalah penjaga yang paling mudah hilang diam-diam: tanpa
    /// konteks yang dihitung dari tanggal, resolver bisa mendapat `skyContext`
    /// yang jatuh ke cabang "tanpa efemeris" dan memakai asumsi langit gelap
    /// `sunAltitudeDeg = -90` — yang justru **meloloskan** bintang. Penyaringan
    /// siang akan terlihat bekerja karena kebetulan, bukan karena jalannya
    /// benar.
    func testFixtureSkyIsBrightAndComesFromTheEphemeris() throws {
        let context = makeResolver(policy: productionPolicy)
            .skyContext(observer: observer, date: noon)

        XCTAssertGreaterThan(context.sunAltitudeDeg, 60,
                             "Matahari harus tinggi; kalau tidak, seluruh berkas ini menguji malam")
        XCTAssertFalse(context.isDark, "langit harus terang pada waktu ini")
        XCTAssertGreaterThan(context.sunAltitudeDeg, -90,
                             "konteks harus berasal dari Matahari nyata, bukan asumsi langit gelap")
    }

    // MARK: - Pemilihan arah tunjuk

    /// Bintang acuan beserta jam kontrol malamnya.
    ///
    /// Dipilih dari katalog dengan empat syarat yang semuanya harus benar:
    ///
    /// 1. **Tinggi** pada tengah hari (di atas 30 derajat). Tanpa ini,
    ///    "tidak terkunci" bisa datang dari `belowHorizon` — persis cacat Sirius
    ///    di versi pertama.
    /// 2. **Ditolak hanya karena terang.** `VisibilityFilter.classify` diuji
    ///    langsung, bukan disimpulkan dari "tidak ada jawaban". Perhatikan
    ///    urutan pemeriksaan `classify`: bawah horizon, magnitudo, dekat
    ///    Matahari, baru terang. Menyalakan "terang" tanpa mematikan tiga
    ///    sebelumnya akan menghasilkan alasan yang salah dan tes yang hijau.
    /// 3. **Akan terkunci kalau gerbang kegelapan dilonggarkan.** Ini bukti
    ///    positifnya. Tanpa bukti ini, berkas ini hanya membuktikan bahwa
    ///    beberapa bintang tidak terkunci siang — dan itu bisa tetap benar
    ///    karena alasan yang salah.
    /// 4. **Ada jam malam saat ia tinggi.** Syarat ini tidak masuk akal untuk
    ///    pengujian siang, tapi wajib untuk kontrol positif: versi pertama
    ///    memilih bintang berdasarkan kecerahan saja, lalu kontrol malamnya
    ///    gagal karena bintang itu memang tidak pernah tinggi setelah gelap.
    ///
    /// Longgaran pada syarat 3 lewat **policy**, bukan lewat
    /// `SkyContext(isDark: true)`. `classify` membaca
    /// `context.sunAltitudeDeg`, jadi konteks gelap yang dipalsukan tanpa
    /// mengubah policy akan terlihat benar sambil tidak menguji apa pun.
    private func pickTarget() throws -> (star: CelestialObject, night: Date) {
        let resolver = makeResolver(policy: productionPolicy)
        let relaxedResolver = makeResolver(policy: darknessRelaxedPolicy)
        let context = resolver.skyContext(observer: observer, date: noon)

        var examined = 0
        for object in Catalogue.brightStars {
            guard let direction = resolver.horizontal(of: object,
                                                     observer: observer,
                                                     date: noon),
                  direction.altitudeDeg > 30
            else { continue }
            examined += 1

            let resolution = resolver.diagnose(pointing: direction,
                                               observer: observer,
                                               date: noon,
                                               coneDeg: 20.0)
            guard let sun = resolution.sunHorizontal,
                  let reason = resolution.rejected.first(where: { $0.object.id == object.id })
            else { continue }

            let separation = SkyMath.angularSeparationHorizontalDeg(direction, sun)
            // Syarat 2: satu-satunya alasan penolakan yang boleh berlaku.
            // `classify` diuji ulang dengan jarak Matahari yang **benar**,
            // karena memberi nilai karangan akan membangkitkan
            // `tooCloseToSun` lebih dulu dan membiarkan syarat ini lolos
            // tanpa pernah menguji gerbang terang.
            let classified = VisibilityFilter.classify(
                altitudeDeg: direction.altitudeDeg,
                magnitude: object.magnitude,
                separationFromSunDeg: separation,
                context: context,
                policy: productionPolicy)
            guard reason.visibility == .daylight, classified == .daylight else { continue }

            // Syarat 3: bukti positif, hanya gerbang kegelapan yang dilonggarkan.
            let relaxed = relaxedResolver.resolve(pointing: direction,
                                                  observer: observer,
                                                  date: noon,
                                                  coneDeg: 20.0)
            guard relaxed.level == .high, relaxed.best?.id == object.id else { continue }

            // Syarat 4: kontrol malam harus benar-benar ada.
            guard let night = nightControlTime(resolver: resolver, star: object) else { continue }
            return (object, night)
        }

        XCTFail("tidak ada bintang yang memenuhi keempat syarat pada \(noon); "
                + "diperiksa \(examined) bintang di atas 30 derajat. Fixture berubah "
                + "dan berkas ini tidak lagi menguji apa pun")
        throw XCTSkip("fixture tidak punya arah tunjuk siang")
    }

    /// Jam malam saat `star` tinggi, dicari dari resolver.
    ///
    /// Dicari, bukan ditulis: cap waktu yang "terlihat benar" sudah terbukti
    /// menyesatkan dua kali di berkas ini. Dua syarat diperiksa eksplisit —
    /// langit gelap **dan** bintang di atas 30 derajat — dan "tidak ada"
    /// mengembalikan `nil` supaya pemanggil bisa lanjut ke bintang berikutnya,
    /// bukan lebih dulu gagal.
    private func nightControlTime(resolver: PointingResolver,
                                  star: CelestialObject) -> Date? {
        for hour in stride(from: 0.0, through: 23.0, by: 1.0) {
            let candidate = noon.addingTimeInterval(hour * 3600)
            guard resolver.skyContext(observer: observer, date: candidate).isDark,
                  let direction = resolver.horizontal(of: star,
                                                     observer: observer,
                                                     date: candidate),
                  direction.altitudeDeg > 30
            else { continue }
            return candidate
        }
        return nil
    }

    /// Arah tunjuk tepat ke `object` pada waktu `date`, seperti yang dilakukan
    /// aplikasi.
    private func aim(at object: CelestialObject,
                     date: Date,
                     resolver: PointingResolver) throws -> Quaternion {
        let direction = try XCTUnwrap(
            resolver.horizontal(of: object, observer: observer, date: date),
            "objek \(object.id) harus punya arah horizontal pada waktu ini")
        return quaternion(viewPointingAt: direction)
    }

    private func controller(resolver: PointingResolver) -> PointingController {
        PointingController(resolver: resolver,
                           observer: observer,
                           config: PointingControllerConfig(coneDeg: 20.0))
    }

    /// Tahan arah tunjuk yang sama berulang kali, seperti pengguna yang menjaga
    /// jam tetap diam sampai pergelangan dianggap tenang.
    private func hold(_ controller: PointingController,
                      quaternion q: Quaternion,
                      since start: Date,
                      steps: Int = 12) {
        for step in 0..<steps {
            controller.feed(quaternion: q,
                            timestamp: start.addingTimeInterval(Double(step) * 0.1))
        }
    }

    // MARK: - Yang dijaga

    /// Syarat 1 dan 2, diuji sebagai hal yang berdiri sendiri.
    ///
    /// Bukan pengulangan: tiga tes di bawah bergantung pada pemilihan arah
    /// tunjuk yang benar. Kalau pemilihan itu bergerak ke bintang yang lebih
    /// redup atau lebih rendah, berkas ini tetap hijau sambil berhenti menguji
    /// gerbang siang.
    func testDaylightTargetIsRejectedForDaylightAndNothingElse() throws {
        let target = try pickTarget().star
        let resolver = makeResolver(policy: productionPolicy)
        let resolution = resolver.diagnose(pointing: try XCTUnwrap(
            resolver.horizontal(of: target, observer: observer, date: noon)),
            observer: observer, date: noon, coneDeg: 20.0)

        let direction = try XCTUnwrap(
            resolver.horizontal(of: target, observer: observer, date: noon))
        let sun = try XCTUnwrap(resolution.sunHorizontal)

        XCTAssertGreaterThan(direction.altitudeDeg, 30,
                             "\(target.name) harus tinggi; kalau tidak ia ditolak karena bawah horizon")
        XCTAssertGreaterThan(SkyMath.angularSeparationHorizontalDeg(direction, sun),
                             productionPolicy.minSunSeparationDeg,
                             "\(target.name) harus cukup jauh dari Matahari")
        XCTAssertLessThanOrEqual(target.magnitude,
                                 productionPolicy.limitingMagnitude,
                                 "\(target.name) harus cukup terang untuk lolos batas magnitudo")
        XCTAssertEqual(resolution.rejected.first { $0.object.id == target.id }?.visibility,
                       .daylight,
                       "satu-satunya alasan penolakan yang boleh berlaku")
    }

    /// Siang hari, arah tunjuk tepat ke bintang yang hanya tertahan terang
    /// **tidak boleh** menghasilkan `.lock`.
    func testNoonAimAtBrightStarNeverLocks() throws {
        let resolver = makeResolver(policy: productionPolicy)
        let target = try pickTarget().star
        let controller = self.controller(resolver: resolver)

        hold(controller, quaternion: try aim(at: target, date: noon, resolver: resolver),
             since: noon)

        XCTAssertNotEqual(controller.snapshot.state, .lock,
                          "siang hari tidak boleh terkunci pada \(target.name)")
    }

    /// Tidak terkunci saja belum cukup: keadaan harus tetap jujur, yaitu
    /// menjelaskan **kenapa** tidak ada jawaban.
    func testNoonAimExplainsItselfInsteadOfGoingSilent() throws {
        let resolver = makeResolver(policy: productionPolicy)
        let target = try pickTarget().star
        let controller = self.controller(resolver: resolver)

        hold(controller, quaternion: try aim(at: target, date: noon, resolver: resolver),
             since: noon)

        let snapshot = controller.snapshot
        XCTAssertNotEqual(snapshot.state, .lock)
        XCTAssertNotEqual(snapshot.state, .uncertain,
                          "langit terang bukan ambiguitas; jangan samakan")
        XCTAssertEqual(snapshot.searchHint, .daylight,
                       "harus menyalahkan terang, bukan 'tidak ada kandidat'")
        XCTAssertFalse(controller.hapticLog.contains { $0.event == .lockSucceeded },
                       "tidak boleh ada haptic sukses di siang hari")
    }

    /// Bukti positif untuk tes di atas: **malam**, arah tunjuk ke bintang yang
    /// **sama**, **harus** terkunci.
    ///
    /// Tanpa ini, "tidak terkunci" bisa berarti tesnya salah arah dan tidak
    /// pernah menguji apa pun.
    func testSameStarLocksAtNightSoTheDaylightRefusalIsTheCause() throws {
        let resolver = makeResolver(policy: productionPolicy)
        let picked = try pickTarget()
        let night = picked.night

        // Prasyarat yang diulang, bukan dipercaya: jam kontrol gelap DAN
        // bintangnya tinggi.
        XCTAssertTrue(resolver.skyContext(observer: observer, date: night).isDark)
        let nightDirection = try XCTUnwrap(
            resolver.horizontal(of: picked.star, observer: observer, date: night))
        XCTAssertGreaterThan(nightDirection.altitudeDeg, 30)

        let controller = self.controller(resolver: resolver)
        hold(controller,
             quaternion: try aim(at: picked.star, date: night, resolver: resolver),
             since: night)

        XCTAssertEqual(controller.snapshot.state, .lock,
                       "malam harus terkunci; kalau tidak, penolakan siang tadi karena alasan lain")
        XCTAssertTrue(controller.hapticLog.contains { $0.event == .lockSucceeded })
    }
}