import XCTest
import CelestialEngine
@testable import PointingKit

/// Setiap medan yang **dikirim jam** wajib punya jejak di laporan yang dibaca
/// pengguna — atau dinyatakan terang-terangan bahwa ia bukan isi laporan.
///
/// **Cacat yang dijaga, dan kenapa bentuknya begini.** Sampai siklus ini
/// `altitudeDeg`/`azimuthDeg` ikut di **setiap** pesan keadaan sejak versi
/// pertama dan tidak pernah tampil di iPhone. Yang membuatnya bertahan bukan
/// kelalaian sekali, melainkan **bentuk gerbangnya**: `swift-ui-lint.sh`
/// membaca teks, `check-visuals.py` membaca piksel, dan `swift-typecheck.sh`
/// hanya mengurai sintaks. Ketiganya buta terhadap *kolom yang tidak pernah
/// ditulis* — ketiadaan tidak punya teks maupun piksel.
///
/// Karena itu uji ini tidak memeriksa satu medan tertentu. Ia **menyapu
/// seluruh medan** yang ada di pesan sekarang, lewat `Mirror`, jadi medan
/// yang ditambahkan tahun depan ikut terjaga tanpa ada yang ingat
/// menambahkannya ke sini. Untuk tiap medan: ubah **hanya** medan itu di
/// bentuk kabel, bangun ulang pesannya, lalu tuntut laporan **berubah**.
/// Medan yang tidak mengubah apa pun harus terdaftar di `bukanIsiLaporan`
/// beserta alasannya.
///
/// Ini bukan uji "view memanggil fungsi". Yang diukur adalah perilaku
/// produk: **fakta yang dikirim jam sampai ke mata pembaca.**
final class LinkReportCoverageTests: XCTestCase {

    /// Medan yang **bukan** isi laporan keadaan, beserta alasannya.
    ///
    /// Setiap entri wajib benar. Daftar pengecualian yang tidak bisa basi
    /// adalah daftar yang cepat atau lambat berbohong, jadi isinya hanya
    /// medan yang alasannya **struktural** — bukan "belum sempat".
    private static let bukanIsiLaporan: [String: String] = [
        // Jenis pesan memilih bagian mana yang dirender; ia sendiri bukan isi.
        "kind": "jenis pesan: ia memilih bagian, bukan mengisi baris",
        // Nama beku dari jam. Ia **sudah** dipakai — lewat
        // `reportedObjectName`, yang menerjemahkannya memakai katalog dan
        // id. Jadi mutasinya tidak mengubah laporan, dan itu memang benar:
        // yang tampil bukan nama beku, melainkan nama katalog pembaca.
        // Mutasi `objectID` **berubah** laporannya dan itu yang diuji.
        "objectName": "dipakai lewat reportedObjectName, bukan tampil mentah",
        // Ketidakterkalibrasian bukan angka — ia kalimat, dari
        // `calibrationNoteText`, dicetak `LinkView` di bawah baris-baris.
        // Menaruhnya sebagai baris akan membuat satu fakta punya dua
        // bentuk yang bisa berbeda.
        "isCalibrated": "kalimat status kalibrasi, bukan baris angka",
    ]

    // MARK: - Bahan

    /// Pesan keadaan **seperti yang benar-benar dibangun jam**.
    ///
    /// Dibangun lewat `PointingLinkMessage.state(from:at:sigmaDeg:)`, bukan
    /// lewat init dengan semua medan diisi. Bedanya penting dan terukur:
    /// fixture yang mengisi **semua** medan membuat `yawOffsetDeg`,
    /// `residualSpreadDeg`, dan `sampleCount` hadir di pesan `.pointingState`
    /// — padahal jam tidak pernah mengirimnya di jenis pesan itu — dan sapuan
    /// di bawah lalu melaporkannya sebagai "dikirim tetapi tidak sampai ke
    /// laporan". Dua belas medan jadi tuduhan palsu dalam satu uji, dan uji
    /// yang merah karena alat ukurnya sendiri tidak bisa dipercaya lagi.
    ///
    /// Memakai pembuat sungguhan juga berarti: kalau suatu hari jam
    /// benar-benar mulai mengirim ketiga medan itu di pesan keadaan,
    /// **fixture-nya ikut berubah** dan uji ini akan menuntutnya tampil —
    /// tanpa ada yang perlu ingat memperbarui daftar.
    private func fullMessage(kind: LinkMessageKind = .pointingState) -> PointingLinkMessage {
        let snapshot = PointingSnapshot(
            state: .lock,
            intent: CelestialIntent(
                level: .high,
                best: CelestialObject(id: "jupiter", name: "Jupiter", kind: .planet,
                                      raDeg: 0, decDeg: 0, magnitude: -2.0),
                candidates: []),
            rawPointing: HorizontalCoord(altitudeDeg: 42.5, azimuthDeg: 118.0),
            calibratedPointing: HorizontalCoord(altitudeDeg: 42.5, azimuthDeg: 118.0),
            angularRateDegPerSec: 0.5,
            isCalibrated: true
        )
        switch kind {
        case .pointingState:
            return PointingLinkMessage.state(from: snapshot,
                                             at: Date(timeIntervalSince1970: 1_700_000_000),
                                             sigmaDeg: 1.2)
        case .calibrationReady:
            return PointingLinkMessage.calibration(
                PointingCalibration(yawOffsetDeg: 12.0,
                                    residualSpreadDeg: 1.5,
                                    sampleCount: 40),
                at: Date(timeIntervalSince1970: 1_700_000_000))
        case .policyUpdate, .stateRequest, .acknowledgement:
            // Tiga jenis ini memang tidak dibandingkan barisnya di sini
            // (`reportRows` tidak punya bagian untuk keduanya); yang diuji
            // hanya bagian yang benar-benar dirender LinkView.
            return PointingLinkMessage(kind: kind,
                                       sentAt: Date(timeIntervalSince1970: 1_700_000_000))
        }
    }

    private var catalogue: [CelestialObject] {
        [
            CelestialObject(id: "jupiter", name: "Jupiter", kind: .planet,
                            raDeg: 0, decDeg: 0, magnitude: -2.0),
            CelestialObject(id: "saturnus", name: "Saturnus", kind: .planet,
                            raDeg: 0, decDeg: 0, magnitude: 1.0),
        ]
    }

    /// Nama medan yang benar-benar tersimpan di pesan.
    ///
    /// Dari `Mirror`, bukan dari daftar yang ditulis tangan — daftar tangan
    /// akan basi persis pada medan yang lupa ditambahkan, yaitu medan yang
    /// uji ini ada untuk menangkap.
    private func wireFieldNames() -> [String] {
        Mirror(reflecting: fullMessage()).children.compactMap(\.label).sorted()
    }

    /// Medan mana yang **ikut terkirim** di jenis pesan mana.
    ///
    /// Ditulis tangan, dan itu disengaja: ini bukan daftar medan (yang akan
    /// basi), melainkan daftar **jalur kirim**. Kalau medan baru dikirim,
    /// `testEveryWireFieldReachesTheReport` tetap menuntutnya tampil — ia
    /// hanya tidak bisa menuntutnya di jenis pesan yang memang tidak
    /// membawanya.
    ///
    /// **Peta ini dulu tidak dibaca siapa pun.** Ia dideklarasikan, diberi
    /// docstring yang menjanjikan "medan yang tidak ada di peta akan gagal
    /// uji", lalu sapuan di bawah melewatinya dan memakai
    /// `plist[field] != nil` sebagai gantinya. Akibatnya terukur: peta
    /// mengklaim `note` terkirim di tiga jenis pesan padahal **tidak satu pun
    /// pembuat pesan mengisinya**, dan tidak ada gerbang yang merah. Sekarang
    /// peta itu dipakai — lihat dua penjaga di uji utama.
    ///
    /// **Himpunan kosong berarti "tidak ada pembuat pesan yang mengisinya"**,
    /// bukan "belum diperiksa". Hanya `note` yang begitu: medan itu ada di
    /// format kabel dan sengaja dibiarkan `nil` oleh semua pembuat (lihat
    /// `LinkMessageTests` — kalimat jadi tidak boleh lahir di dalam paket).
    private static let dikirimDi: [String: Set<LinkMessageKind>] = [
        "state": [.pointingState],
        "objectID": [.pointingState],
        "objectName": [.pointingState],
        "level": [.pointingState],
        "altitudeDeg": [.pointingState],
        "azimuthDeg": [.pointingState],
        "angularRateDegPerSec": [.pointingState],
        "pointingSigmaDeg": [.pointingState],
        "isCalibrated": [.pointingState],
        "yawOffsetDeg": [.calibrationReady],
        "residualSpreadDeg": [.calibrationReady],
        "sampleCount": [.calibrationReady],
        "note": [],
        "sentAt": [.pointingState, .calibrationReady],
        "kind": [.pointingState, .calibrationReady],
    ]

    /// Laporan yang **dibaca pengguna** untuk satu pesan, dari semua bagian.
    ///
    /// Sapuan harus melihat seluruh laporan, bukan satu bagian: `yawOffsetDeg`
    /// hidup di bagian kalibrasi, dan memeriksanya terhadap `stateRows` saja
    /// akan melaporkannya sebagai medan mati padahal ia tampil.
    private func reportRows(_ message: PointingLinkMessage) -> [LinkReport.Row] {
        switch message.kind {
        case .calibrationReady:
            return LinkReport.calibrationRows(message)
        case .pointingState, .policyUpdate, .stateRequest, .acknowledgement:
            return LinkReport.stateRows(message, catalogue: catalogue)
        }
    }

    /// Nilai pengganti untuk satu medan: berbeda dari aslinya, tetap sah.
    ///
    /// Lewat bentuk kabel (`plist`) supaya tidak perlu satu `switch` per
    /// medan — `switch` itu justru daftar tangan yang sama, yang harus
    /// diperbarui setiap kali medan bertambah.
    private func mutatedPlist(field: String,
                              from message: PointingLinkMessage) -> [String: Any]? {
        var plist = message.plist
        guard let original = plist[field] else { return nil }
        switch original {
        case let value as Double:
            plist[field] = value + 37.0
        case let value as Int:
            plist[field] = value + 11
        case let value as Bool:
            plist[field] = !value
        case let value as String:
            // String apa pun yang berbeda. Untuk `state`/`level`/`kind`
            // nilai asing akan ditolak pembaca kabel, dan itu **juga**
            // perubahan yang terlihat — tetapi pesannya jadi `nil` dan
            // laporannya kosong, yang akan terbaca seperti "medan ini tidak
            // tampil". Jadi untuk medan berkategori, pakai nilai sah lain.
            plist[field] = Self.alternativeString(field: field, original: value)
        default:
            return nil
        }
        return plist
    }

    private static func alternativeString(field: String, original: String) -> String {
        switch field {
        case "state": return original == "lock" ? "uncertain" : "lock"
        case "level": return original == "high" ? "low" : "high"
        case "objectID": return "saturnus"
        case "objectName": return "Saturnus"
        // `kind` harus tetap **jenis yang sah**. Sebelum ini ia jatuh ke
        // cabang `default` dan menjadi `"pointingStateX"`, yang ditolak
        // pembaca kabel — pesannya `nil`, mutasinya dilewati, dan kedua
        // pasangan (kind, jenis) hilang dari hitungan tanpa satu gerbang
        // pun menyebutnya. Memetakannya ke jenis lain membuat mutasinya
        // sah sekaligus bermakna: ia menguji klaim "kind memilih bagian".
        case "kind": return original == "pointingState" ? "calibrationReady" : "pointingState"
        default: return original + "X"
        }
    }

    // MARK: - Uji utama

    /// **Uji inti.** Setiap medan yang dikirim jam mengubah laporan, atau
    /// terdaftar sebagai bukan isi laporan.
    ///
    /// Disapu **per jenis pesan**, karena satu medan bisa menjadi isi di satu
    /// jenis dan bukan di jenis lain: `yawOffsetDeg` adalah isi pesan
    /// kalibrasi, dan memang tidak muncul di laporan keadaan.
    func testEveryWireFieldReachesTheReport() {
        // Kontrol: kalau sapuan ini tidak menemukan medan, hijau berarti
        // "tidak ada yang diperiksa" — persis hijau yang tidak hijau.
        let names = wireFieldNames()
        XCTAssertGreaterThanOrEqual(names.count, 10,
                                    "sapuan medan tidak membaca pesan: \(names)")

        // Penjaga 1: setiap medan di pesan punya jalur kirim yang dinyatakan.
        // Tanpa ini medan baru lolos hanya karena tidak ada yang menyebutnya.
        let unmapped = names.filter { Self.dikirimDi[$0] == nil }
        XCTAssertTrue(unmapped.isEmpty,
                      "medan ini ada di pesan tetapi tidak punya entri `dikirimDi`: \(unmapped)")

        // Penjaga 1b: arah sebaliknya. Entri peta yang tidak menunjuk medan
        // nyata akan menaikkan `expected` di bawah tanpa menambah satu pun
        // pemeriksaan — gerbangnya merah dengan pesan "sapuan menipis",
        // padahal sapuannya utuh dan yang salah adalah peta. Tanpa penjaga
        // ini, penyebabnya harus ditebak dari pesan kegagalan yang menyesatkan.
        let phantom = Self.dikirimDi.keys.filter { !names.contains($0) }
        XCTAssertTrue(phantom.isEmpty,
                      "entri `dikirimDi` ini tidak menunjuk medan yang ada di pesan: \(phantom)")

        // Penjaga 2: peta dan kenyataan harus sepakat. Untuk setiap pasangan
        // (medan, jenis) yang **diklaim** terkirim, pembuat pesan sungguhan
        // wajib mengisinya. Inilah yang dulu tidak diperiksa, dan yang
        // membuat `note` bisa mengklaim tiga jenis pesan tanpa satu pun
        // pembuat mengisinya.
        for kind in [LinkMessageKind.pointingState, .calibrationReady] {
            let plist = fullMessage(kind: kind).plist
            let claimedButAbsent = Self.dikirimDi
                .filter { $0.value.contains(kind) && plist[$0.key] == nil }
                .keys.sorted()
            XCTAssertTrue(claimedButAbsent.isEmpty,
                          "peta mengklaim medan ini terkirim di \(kind.rawValue) "
                          + "tetapi pembuat pesan tidak mengisinya: \(claimedButAbsent)")
        }

        var invisible: [String] = []
        var checked = 0
        for kind in [LinkMessageKind.pointingState, .calibrationReady] {
            let base = fullMessage(kind: kind)
            let baseline = reportRows(base)
            XCTAssertFalse(baseline.isEmpty,
                           "laporan \(kind.rawValue) kosong — sapuan akan vakum")
            // Hanya medan yang **dinyatakan** terkirim di jenis ini. Inilah
            // pemakaian `dikirimDi` yang sesungguhnya: sebelumnya loop ini
            // menyapu semua nama dan membuang yang kebetulan `nil`, sehingga
            // medan yang seharusnya terkirim tetapi tidak pernah diisi
            // terlihat sama dengan medan yang memang bukan isi jenis ini.
            for field in names where Self.dikirimDi[field]?.contains(kind) == true {
                guard let plist = mutatedPlist(field: field, from: base),
                      let mutated = PointingLinkMessage(plist: plist) else { continue }
                checked += 1
                let rows = reportRows(mutated)
                if rows == baseline && Self.bukanIsiLaporan[field] == nil {
                    invisible.append("\(field) (di \(kind.rawValue))")
                }
            }
        }

        // Ambang ini **dihitung dari peta**, bukan angka pilihan. Angka tetap
        // (`20`) dulu lolos hanya karena fixture lama mengisi setiap medan di
        // setiap jenis pesan; begitu fixture dibangun dari pembuat sungguhan,
        // angkanya jatuh ke 14 dan gerbangnya merah — padahal yang salah
        // adalah angkanya, bukan cakupannya. Menghitung dari peta membuat
        // gerbang ini mengukur "apakah setiap jalur kirim yang dinyatakan
        // benar-benar diperiksa", dan itu properti yang tidak bisa basi.
        let expected = Self.dikirimDi.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(checked, expected,
                       "hanya \(checked) dari \(expected) pasangan (medan, jenis) "
                       + "yang benar-benar diperiksa — sapuan ini menipis")
        XCTAssertTrue(invisible.isEmpty,
                      "Medan ini dikirim jam tetapi tidak pernah sampai ke laporan, "
                      + "dan tidak terdaftar sebagai bukan isi laporan: \(invisible)")
    }

    /// Kebalikannya: medan yang **terdaftar** sebagai bukan isi laporan tidak
    /// boleh diam-diam mulai tampil tanpa ada yang memperbarui alasannya.
    ///
    /// Tanpa uji ini daftar pengecualian akan membusuk jadi tempat sampah:
    /// entri lama tetap "sah" walaupun keadaannya sudah berubah.
    func testDeclaredExemptionsAreStillExempt() {
        let base = fullMessage()
        let baseline = reportRows(base)
        for field in Self.bukanIsiLaporan.keys {
            // `kind` sengaja dilewati: mengubahnya mengubah **bagian** yang
            // dibaca, jadi laporannya memang berbeda — dan itu benar. Yang
            // diklaim tentang `kind` adalah "ia memilih bagian", bukan "ia
            // tidak berpengaruh". Menguji klaim itu butuh uji tersendiri,
            // bukan perbandingan baris.
            if field == "kind" { continue }
            guard let plist = mutatedPlist(field: field, from: base),
                  let mutated = PointingLinkMessage(plist: plist) else {
                return XCTFail("pengecualian `\(field)` tidak bisa diuji — alasannya basi")
            }
            XCTAssertEqual(reportRows(mutated), baseline,
                           "`\(field)` dinyatakan bukan isi laporan tetapi laporannya berubah; "
                           + "hapus dari daftar pengecualian")
        }
    }

    /// `kind` memang memilih bagian: dua jenis pesan yang berbeda menghasilkan
    /// laporan yang berbeda. Itu klaim yang tertulis di daftar pengecualian,
    /// jadi ia diuji, bukan diasumsikan.
    func testKindSelectsTheSection() {
        XCTAssertNotEqual(reportRows(fullMessage(kind: .pointingState)),
                          reportRows(fullMessage(kind: .calibrationReady)),
                          "jenis pesan tidak memilih bagian — pengecualian `kind` salah")
    }

    /// Setiap pengecualian punya alasan yang menjelaskan **kenapa**, bukan
    /// hanya nama medan.
    func testEveryExemptionCarriesAReason() {
        for (field, reason) in Self.bukanIsiLaporan {
            XCTAssertGreaterThan(reason.count, 20,
                                 "alasan untuk `\(field)` terlalu pendek untuk berguna")
        }
    }

    /// Baris waktu benar-benar bergerak mengikuti `sentAt`.
    ///
    /// `sentAt` dikecualikan dari sapuan di atas karena barisnya diformat ke
    /// jam:menit:detik; uji ini menutup celah itu secara langsung, supaya
    /// pengecualiannya tidak menjadi tempat menyembunyikan medan mati.
    func testTimeRowIsNotFrozenToASingleMoment() {
        var early = fullMessage()
        early.sentAt = Date(timeIntervalSince1970: 1_700_000_000)
        var late = fullMessage()
        late.sentAt = Date(timeIntervalSince1970: 1_700_009_000)

        func timeValue(_ message: PointingLinkMessage) -> String? {
            reportRows(message)
                .first { $0.title == TextLocalization.text(.linkRowTime) }?.value
        }
        XCTAssertNotNil(timeValue(early))
        XCTAssertNotEqual(timeValue(early), timeValue(late),
                          "baris waktu tidak bergerak mengikuti waktu kirim")
    }
}
