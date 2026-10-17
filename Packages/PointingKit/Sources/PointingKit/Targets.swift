import Foundation
import CelestialEngine

/// Objek yang bisa dijadikan target pointing, beserta arahnya saat ini.
///
/// Dibuat sebagai tipe tersendiri karena target di lapisan app datang dari dua
/// tempat yang berbeda: bintang dari katalog (J2000, perlu presesi) dan benda
/// tata surya dari efemeris (sudah of-date). Menyatukan keduanya di satu tipe
/// mencegah UI dan harness harus tahu perbedaan itu.
public struct PointingTarget: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var kind: ObjectKind
    public var magnitude: Double
    /// Arah objek saat ini.
    public var direction: HorizontalCoord
    /// Apakah arah ini dihitung dari efemeris (benda bergerak) atau katalog.
    public var isMoving: Bool

    /// Nama target untuk layar, dalam bahasa aktif.
    ///
    /// `name` diisi dari `CelestialObject.name` (bintang & langit-dalam) atau
    /// `EphemerisBody.displayName` (Matahari/Bulan/planet), jadi ia memuat
    /// bentuk Bahasa Indonesia **yang dibekukan** — `Bulan`, `Matahari`,
    /// `Saturnus`. Daftar target Experiment 1 menampilkannya apa adanya, dan
    /// pada perangkat berbahasa Inggris pilihannya berbunyi `Bulan`.
    ///
    /// Accessor ini memakai `ObjectDisplayName.text(_:)` — jalur yang sama
    /// dengan `CelestialObject.localizedName` — supaya pemilih target dan
    /// baris laporan tidak bisa memberi dua nama berbeda untuk objek yang
    /// sama. Nama yang tidak punya terjemahan dikembalikan apa adanya.
    public var localizedName: String {
        ObjectDisplayName.text(name)
    }

    public init(id: String, name: String, kind: ObjectKind,
                magnitude: Double, direction: HorizontalCoord, isMoving: Bool) {
        self.id = id
        self.name = name
        self.kind = kind
        self.magnitude = magnitude
        self.direction = direction
        self.isMoving = isMoving
    }

    /// Apakah objek ini cukup tinggi untuk **dikunci oleh engine** pada
    /// policy tertentu.
    ///
    /// **Kenapa ia menerima policy, dan tidak memakai `altitudeDeg > 0`.**
    /// Cakrawala geometris (`> 0`) terlihat wajar tapi **salah**: engine hanya
    /// mengunci lewat `VisibilityFilter`, yang menyaring di
    /// `policy.minAltitudeDeg` — 5 derajat pada policy bawaan. Cakrawala
    /// geometris **bukan** ambang itu; alasannya sudah lengkap ditulis di
    /// `availableTargets`, dan aksesor yang tidak ikut menerimanya
    /// menghasilkan **dua jawaban berbeda untuk pertanyaan yang sama** di
    /// berkas yang sama.
    ///
    /// Terima policy sebagai parameter supaya ambang itu **tidak pernah ditulis
    /// dua kali**. Tidak ada nilai bawaan: kalau `policy` bisa lupa diteruskan,
    /// pemanggilnya kembali menebak — dan menebak ambang adalah kesalahan yang
    /// paling mahal di repo ini.
    ///
    /// Bandingkan `>` (bukan `>=`) dengan `availableTargets` yang menyingkirkan
    /// `altitudeDeg <= policy.minAltitudeDeg`: keduanya menyingkirkan titik yang
    /// tepat di ambang, jadi batas inklusif/exklusif harus sama supaya daftar
    /// dan accessor ini tidak pernah berbeda pendapat pada satu titik.
    public func isAboveHorizon(_ policy: VisibilityPolicy) -> Bool {
        direction.altitudeDeg > policy.minAltitudeDeg
    }

    /// Jarak sudut dari sebuah arah tunjuk (derajat).
    public func separation(from pointing: HorizontalCoord) -> Double {
        SkyMath.angularSeparationHorizontalDeg(pointing, direction)
    }
}

public extension PointingResolver {

    /// Semua target yang arahnya bisa dihitung sekarang.
    ///
    /// Bintang selalu bisa (katalog). Bulan/planet hanya bila efemeris
    /// tersedia dan perhitungannya berhasil. Matahari tidak pernah muncul:
    /// `horizontal(ofBody:)` menolaknya.
    ///
    /// - Parameter aboveHorizonOnly: buang objek yang tidak akan bisa
    ///   dikunci engine. Untuk kalibrasi dan Experiment 1 ini penting --
    ///   menunjuk objek yang tidak ada di langit hanya menghasilkan rekaman
    ///   yang menyesatkan.
    ///
    ///   **Ambangnya bukan cakrawala geometris, melainkan `policy.minAltitudeDeg`
    ///   milik resolver itu sendiri.** Versi lama memakai `altitudeDeg <= 0`
    ///   yang terlihat wajar tapi salah: engine hanya mengunci lewat
    ///   `VisibilityFilter`, yang menyaring di 5 derajat pada policy bawaan.
    ///   Akibatnya daftar menampilkan Sirius di 0,6 derajat, lalu `diagnose`
    ///   menolaknya sebagai `belowHorizon` -- setiap kali.
    ///
    ///   Yang rusak bukan angkanya, tapi kebohongannya: daftar itu menyatakan
    ///   sebuah objek "tersedia untuk ditunjuk" padahal persis tidak akan
    ///   pernah bisa dikunci. Membaca ambang dari `policy` juga menutup kelas
    ///   bug yang lebih luas: kalau `minAltitudeDeg` berubah, daftar ikut
    ///   berubah, karena tidak ada lagi angka yang ditulis dua kali.
    func availableTargets(observer: Observer,
                          date: Date,
                          aboveHorizonOnly: Bool = true) -> [PointingTarget] {
        var targets: [PointingTarget] = []

        for object in catalogue where object.kind == .star || object.kind == .deepSky {
            guard let direction = horizontal(of: object, observer: observer, date: date) else { continue }
            if aboveHorizonOnly && direction.altitudeDeg <= policy.minAltitudeDeg { continue }
            targets.append(PointingTarget(id: object.id,
                                          name: object.name,
                                          kind: object.kind,
                                          magnitude: object.magnitude,
                                          direction: direction,
                                          isMoving: false))
        }

        if considersSolarSystem {
            for body in EphemerisBody.pointableBodies {
                // Magnitudo dan arah diambil dari **satu** sampel efemeris
                // yang sama (`sample(ofBody:)`), bukan dari konstanta.
                //
                // **Kenapa ini bukan sekadar perbaikan presisi.** Dulunya
                // baris ini memakai `body.typicalBrightestMagnitude`:
                // magnitudo paling terang yang pernah mungkin bagi planet
                // itu, bukan magnitudo malam ini. Mars berayun -2.9…+1.8 dan
                // Merkurius -1.9…+5, jadi daftar bisa menaruh Mars **di atas**
                // bintang yang benar-benar lebih terang dan menyajikannya
                // sebagai "paling mudah ditunjuk", sementara engine menolak
                // menguncinya karena `tooFaint`. Terukur: pada 15 Juni 2026
                // daftar mengatakan Mars -2.9 padahal efemeris menghitung
                // +1.29 — selisih 4.2 magnitudo, arahnya selalu salah.
                //
                // Yang membuatnya berbahaya: angkanya **masuk akal**. Daftar
                // tidak pernah tampak rusak; yang salah hanya urutannya, dan
                // urutan tidak punya kolom tempat kesalahannya terbaca.
                guard let reading = sample(ofBody: body, observer: observer, date: date) else { continue }
                if aboveHorizonOnly && reading.direction.altitudeDeg <= policy.minAltitudeDeg { continue }
                targets.append(PointingTarget(id: body.rawValue,
                                              name: body.displayName,
                                              kind: body == .moon ? .moon : .planet,
                                              magnitude: reading.magnitude,
                                              direction: reading.direction,
                                              isMoving: true))
            }
        }

        // Terang dulu — itu yang paling mudah ditunjuk.
        return targets.sorted { $0.magnitude < $1.magnitude }
    }

    /// Target terdekat dari sebuah arah tunjuk, dalam batas sudut tertentu.
    ///
    /// Dipakai kalibrasi: kalau pengguna menunjuk Sirius, kita perlu tahu itu
    /// Sirius — bukan bintang lain yang kebetulan terdekat di katalog.
    ///
    /// **Sengaja hanya bintang**, sama seperti daftar acuan di
    /// `CalibrationSession.refreshReferenceTargets`. Penjagaan itu tidak boleh
    /// hanya ada di daftar: `captureNearest` melewati daftar dan memanggil
    /// fungsi ini langsung, jadi aturan "acuan harus punya tepi" harus tinggal
    /// di tempat yang **kedua** jalur lalui. Objek langit dalam tidak punya
    /// tepi, dan benda tata surya bergerak serta berfase; keduanya membuat
    /// "bagian mana yang kamu tunjuk" tidak punya jawaban, dan sampel acuannya
    /// berisik — melebarkan `residualSpreadDeg` atau, lebih buruk, memasang
    /// offset yang salah tanpa terlihat.
    func nearestTarget(to pointing: HorizontalCoord,
                       observer: Observer,
                       date: Date,
                       withinDeg: Double = 25.0,
                       aboveHorizonOnly: Bool = true) -> PointingTarget? {
        let candidates = availableTargets(observer: observer,
                                          date: date,
                                          aboveHorizonOnly: aboveHorizonOnly)
            .filter { $0.kind == .star }
            .map { (target: $0, separation: $0.separation(from: pointing)) }
            .filter { $0.separation <= withinDeg }
            .sorted { $0.separation < $1.separation }

        guard let best = candidates.first else { return nil }

        // Dua kandidat yang nyaris sama dekatnya tidak boleh dipilih diam-diam:
        // memilih yang salah membuat kalibrasi mengoreksi ke arah yang keliru.
        // Jarak 5° dipakai sebagai ambang "tidak bisa dibedakan dengan mata".
        if candidates.count >= 2 {
            let runnerUp = candidates[1].separation
            if runnerUp - best.separation < 5.0 { return nil }
        }
        return best.target
    }
}
