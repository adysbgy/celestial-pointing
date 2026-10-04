import XCTest
import CelestialEngine
@testable import PointingKit

/// Janji tampilan: engine yang ragu harus **terlihat** ragu.
///
/// Seluruh aturan anti-false-lock di engine bisa dibatalkan oleh UI yang
/// memakai warna/ikon sama untuk `lock` dan `uncertain`. Uji ini menjaga jarak
/// itu tetap ada.
final class PointingPresentationTests: XCTestCase {

    func testEveryStateHasDistinctTone() {
        XCTAssertEqual(PointingState.idle.tone, .neutral)
        XCTAssertEqual(PointingState.pointing.tone, .active)
        XCTAssertEqual(PointingState.searching.tone, .active)
        XCTAssertEqual(PointingState.lock.tone, .success)
        XCTAssertEqual(PointingState.uncertain.tone, .warning)
        XCTAssertEqual(PointingState.unavailable.tone, .danger)
    }

    /// Inti janji PRD: ragu tidak boleh tampil seperti yakin.
    func testUncertainLooksDifferentFromLock() {
        XCTAssertNotEqual(PointingState.lock.tone, PointingState.uncertain.tone)
        XCTAssertNotEqual(PointingState.lock.symbolName, PointingState.uncertain.symbolName)
        XCTAssertNotEqual(PointingState.lock.shortLabel, PointingState.uncertain.shortLabel)
        XCTAssertNotEqual(PointingState.lock.guidance, PointingState.uncertain.guidance)
        XCTAssertFalse(PointingState.uncertain.looksConfident)
        XCTAssertTrue(PointingState.lock.looksConfident)
    }

    /// Setiap keadaan harus punya simbol yang bisa dirender.
    func testAllStatesHaveSymbolsAndLabels() {
        let states: [PointingState] = [.idle, .pointing, .searching, .lock, .uncertain, .unavailable]
        for state in states {
            XCTAssertFalse(state.symbolName.isEmpty, "\(state) tanpa simbol")
            XCTAssertFalse(state.shortLabel.isEmpty, "\(state) tanpa label")
            XCTAssertFalse(state.guidance.isEmpty, "\(state) tanpa panduan")
        }
        let symbols = Set(states.map(\.symbolName))
        XCTAssertEqual(symbols.count, states.count, "simbol antar-keadaan harus berbeda")
    }

    func testConfidenceLevelPresentation() {
        XCTAssertEqual(ConfidenceLevel.high.tone, .success)
        XCTAssertEqual(ConfidenceLevel.medium.tone, .warning)
        XCTAssertEqual(ConfidenceLevel.low.tone, .danger)
        XCTAssertNotEqual(ConfidenceLevel.high.tone, ConfidenceLevel.medium.tone)
        XCTAssertEqual(ConfidenceLevel.high.displayName, "Yakin")
        XCTAssertEqual(ConfidenceLevel.medium.displayName, "Ragu")
    }

    /// Snapshot membawa teks status yang cocok dengan keadaannya.
    func testSnapshotStatusTextMatchesState() {
        for state in [PointingState.idle, .pointing, .searching, .lock, .uncertain, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            XCTAssertEqual(snapshot.statusText, state.shortLabel)
        }
    }

    func testSnapshotExposesBestObject() {
        let object = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                     raDeg: 279, decDeg: 38, magnitude: 0.03)
        let snapshot = PointingSnapshot(state: .lock,
                                        intent: CelestialIntent(level: .high, best: object, candidates: []))
        XCTAssertEqual(snapshot.bestObject?.id, "vega")
        XCTAssertEqual(PointingSnapshot(state: .idle).bestObject, nil)
    }

    // MARK: - Objek sisa (anti false-confidence di layar)

    private let vega = CelestialObject(id: "vega", name: "Vega", kind: .star,
                                       raDeg: 279, decDeg: 38, magnitude: 0.03)

    /// Objek dari pandangan sebelumnya tidak boleh tampil sebagai hasil
    /// sekarang.
    ///
    /// Mesin keadaan sengaja mempertahankan `intent` supaya panel tidak
    /// berkedip saat pergelangan bergerak sedikit. Akibatnya `intent?.best`
    /// **tetap terisi** saat keadaan sudah kembali `pointing`. Menilai "basi"
    /// dari `intent?.best == nil` karena itu salah: ia melaporkan "bukan sisa"
    /// tepat pada objek yang paling basi, dan peringatan di layar tidak pernah
    /// bisa muncul. Yang menentukan adalah apakah keadaan punya jawaban.
    func testStaleObjectIsFlaggedWhenStateHasNoAnswer() {
        // Keadaan sudah tidak punya jawaban, tapi intent lama masih menempel —
        // inilah bentuk yang dulu lolos.
        let stale = PointingSnapshot(state: .pointing,
                                     intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertNotNil(stale.displayedObject(lastLocked: nil))
        XCTAssertTrue(stale.isDisplayingStaleObject(lastLocked: nil),
                      "objek dari arah tunjuk sebelumnya harus ditandai sisa")

        // Keadaan benar-benar punya jawaban → bukan sisa.
        for state in [PointingState.lock, .uncertain] {
            let live = PointingSnapshot(state: state,
                                        intent: CelestialIntent(level: .high, best: vega, candidates: []))
            XCTAssertFalse(live.isDisplayingStaleObject(lastLocked: nil),
                           "\(state) adalah jawaban sekarang, bukan sisa")
        }
    }

    /// Objek terakhir yang pernah terkunci boleh tetap tampil saat mencari —
    /// tapi **harus** ditandai sisa.
    func testLastLockedObjectShownWhileSearchingIsStale() {
        let searching = PointingSnapshot(state: .searching)
        XCTAssertEqual(searching.displayedObject(lastLocked: vega)?.id, "vega")
        XCTAssertTrue(searching.isDisplayingStaleObject(lastLocked: vega))

        // Tanpa intent tertinggal, idle/unavailable tidak menampilkan apa pun.
        for state in [PointingState.idle, .unavailable] {
            let snapshot = PointingSnapshot(state: state)
            XCTAssertNil(snapshot.displayedObject(lastLocked: vega),
                         "\(state) tidak boleh menampilkan objek apa pun")
            XCTAssertFalse(snapshot.isDisplayingStaleObject(lastLocked: vega))
        }
    }

    /// Sensor mati di tengah pandangan menyisakan objek lama — dan itu **wajib**
    /// tetap ditandai sisa.
    ///
    /// `refreshSnapshot(state: .unavailable)` sengaja tidak membuang
    /// `currentIntent` (mesin keadaan hanya membuangnya saat `stop()`), jadi
    /// keadaan ini benar-benar bisa membawa objek dari pandangan sebelumnya —
    /// bukan sekadar kemungkinan teoretis. Menyembunyikan panelnya bukan
    /// pilihan (panel yang hilang lalu muncul lagi terbaca sebagai pengukuran
    /// baru); yang tidak boleh adalah menampilkannya **tanpa** penanda, dan
    /// badge keyakinannya ikut hilang karena keadaan ini tidak punya jawaban.
    func testUnavailableWithRetainedIntentStillFlagsItAsStale() {
        let stale = PointingSnapshot(state: .unavailable,
                                     intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertEqual(stale.displayedObject(lastLocked: nil)?.id, "vega")
        XCTAssertTrue(stale.isDisplayingStaleObject(lastLocked: nil),
                      "objek dari pandangan sebelumnya harus ditandai sisa")
        XCTAssertNil(stale.answeredObject, "sensor mati tidak punya jawaban sekarang")
        XCTAssertNil(stale.answeredLevel, "keyakinan lama tidak berlaku saat sensor mati")
    }

    /// Jawaban yang berlaku sekarang dipisahkan dari objek yang ditampilkan.
    ///
    /// Yang **ditampilkan** sengaja mempertahankan objek terakhir (layar jam
    /// menandainya sisa). Yang **berlaku** hanya saat keadaan punya jawaban —
    /// itu yang boleh dikirim ke iPhone dan direkam ke riwayat, karena di sana
    /// tidak ada penanda "sisa" yang bisa menyelamatkan.
    func testAnsweredPredicatesIgnoreRetainedIntent() {
        let retained = CelestialIntent(
            level: .high, best: vega,
            candidates: [Candidate(object: vega, separationDeg: 0.7)])
        let stale = PointingSnapshot(state: .pointing, intent: retained)

        XCTAssertEqual(stale.bestObject?.id, "vega", "tampilan tetap mempertahankannya")
        XCTAssertNil(stale.answeredObject, "tapi itu bukan jawaban sekarang")
        XCTAssertNil(stale.answeredLevel)
        XCTAssertNil(stale.answeredSeparationDeg)

        for state in [PointingState.lock, .uncertain] {
            let live = PointingSnapshot(state: state, intent: retained)
            XCTAssertEqual(live.answeredObject?.id, "vega")
            XCTAssertEqual(live.answeredLevel, .high)
            XCTAssertEqual(live.answeredSeparationDeg, 0.7)
        }
    }

    /// Arah tunjuk juga punya predikat "berlaku sekarang", terpisah dari yang
    /// **disimpan** di cuplikan.
    ///
    /// `calibratedPointing` sengaja dipertahankan supaya panel jam tidak
    /// berkedip; akibatnya ia tetap terisi saat sensor mati, dengan nilai
    /// terakhir sebelum sensor hilang. Dua jalur membacanya untuk **dilaporkan
    /// ke tempat lain** — layar Ketelitian di jam dan pesan ke iPhone — dan
    /// keduanya harus berhenti pada saat yang sama. Kalau aturannya ditulis dua
    /// kali, keduanya bisa berbeda pendapat, dan yang paling berbahaya adalah
    /// versi yang tetap melaporkan angka lama tanpa penanda.
    func testReportedPointingIsNilWhenSensorIsDead() {
        let coord = HorizontalCoord(altitudeDeg: 42.5, azimuthDeg: 133.25)

        let dead = PointingSnapshot(state: .unavailable,
                                    calibratedPointing: coord,
                                    hasSensor: false)
        XCTAssertEqual(dead.calibratedPointing, coord, "nilai tersimpan tetap ada")
        XCTAssertNil(dead.reportedPointing, "tapi bukan pengukuran sekarang")

        let live = PointingSnapshot(state: .lock, calibratedPointing: coord, hasSensor: true)
        XCTAssertEqual(live.reportedPointing, coord)
    }

    // MARK: - Gambar tidak boleh lebih yakin daripada teksnya

    /// **Regresi: selama `.uncertain` gambar menampilkan seluruh ciri
    /// pengenal tanpa lencana tanda tanya.**
    ///
    /// Gerbang lamanya `isConfirmed = !isStale`, dan `isStale` dihitung dari
    /// `hasAnswer` — yang mencakup `.uncertain`. Jadi tepat pada keadaan
    /// tempat engine menyatakan diri **kurang yakin**, gambar menampilkan
    /// cincin Saturnus / pita Jupiter / kutub Mars secara utuh, sementara
    /// badge di sebelahnya bertuliskan "Ragu".
    ///
    /// Ini false confidence dalam bentuk yang paling sulit ditangkap: teksnya
    /// jujur, tidak ada yang bisa dibaca pengguna untuk mengeceknya, dan mata
    /// membaca gambar lebih dulu daripada badge.
    func testUncertainDoesNotConfirmIdentityToTheImage() {
        let candidate = PointingSnapshot(
            state: .uncertain,
            intent: CelestialIntent(level: .medium, best: vega, candidates: []))
        XCTAssertTrue(candidate.displayedObject(lastLocked: nil) != nil,
                      "ragu tetap menampilkan kandidatnya")
        XCTAssertFalse(candidate.isDisplayingStaleObject(lastLocked: nil),
                       "ragu bukan sisa — ini yang membuat gerbang lama lolos")
        XCTAssertFalse(candidate.confirmsIdentity(lastLocked: nil),
                       "tapi gambar tidak boleh mengklaim identitas saat engine ragu")
    }

    func testOnlyLockConfirmsIdentityToTheImage() {
        // Ambangnya `looksConfident` (hanya `.lock`), bukan `hasAnswer`.
        let locked = PointingSnapshot(
            state: .lock,
            intent: CelestialIntent(level: .high, best: vega, candidates: []))
        XCTAssertTrue(locked.confirmsIdentity(lastLocked: nil))

        // Semua keadaan lain — termasuk yang punya jawaban dan yang
        // mempertahankan intent lama — tidak boleh mengklaim identitas.
        for state in [PointingState.idle, .pointing, .searching, .uncertain, .unavailable] {
            let snapshot = PointingSnapshot(
                state: state,
                intent: CelestialIntent(level: .high, best: vega, candidates: []))
            XCTAssertFalse(snapshot.confirmsIdentity(lastLocked: nil),
                           "\\(state) tidak boleh menggambar ciri pengenal")
        }
    }

    /// Gambar yang mengklaim identitas mensyaratkan objek yang benar-benar
    /// ditampilkan. Tanpa ini, keadaan `.lock` tanpa kandidat akan menggambar
    /// ciri pengenal di atas bola generik.
    func testConfirmingIdentityRequiresAnObjectToShow() {
        let empty = PointingSnapshot(state: .lock)
        XCTAssertNil(empty.displayedObject(lastLocked: nil))
        XCTAssertFalse(empty.confirmsIdentity(lastLocked: nil),
                       "terkunci tanpa objek tidak boleh mengklaim identitas")
    }

    /// Ambang gambar harus **lebih ketat** daripada ambang sisa, bukan sama.
    ///
    /// Inilah inti cacatnya: gerbang lama menurunkan `isConfirmed` dari
    /// `!isStale`, sehingga kedua ambang runtuh menjadi satu dan `.uncertain`
    /// lolos sebagai gambar pasti. Uji ini mengunci bahwa ada keadaan yang
    /// **bukan sisa** tetapi tetap **tidak** mengonfirmasi identitas — yaitu
    /// bukti langsung bahwa dua ambang itu berbeda.
    func testIdentityThresholdIsStricterThanTheStaleThreshold() {
        // Cari keadaan yang membedakan kedua ambang: bukan sisa, tapi juga
        // tidak mengonfirmasi identitas.
        // `PointingState` sengaja tidak `CaseIterable` (enum engine), jadi
        // daftar kasusnya ditulis eksplisit — ikut merah bila ada keadaan
        // baru yang lupa dipertimbangkan di sini.
        let allStates: [PointingState] = [.idle, .pointing, .searching, .lock,
                                          .uncertain, .unavailable]
        let separating = allStates.filter { state in
            let snapshot = PointingSnapshot(
                state: state,
                intent: CelestialIntent(level: .high, best: vega, candidates: []))
            return !snapshot.isDisplayingStaleObject(lastLocked: nil)
                && !snapshot.confirmsIdentity(lastLocked: nil)
        }
        XCTAssertFalse(separating.isEmpty,
                       "ambang gambar tidak boleh runtuh menjadi ambang sisa")
        XCTAssertTrue(separating.contains(.uncertain),
                      "`.uncertain` harus jadi keadaan yang membedakan keduanya")
    }

    // MARK: - Ringkasan complication (janji lintas-proses)

    /// Complication hidup di proses terpisah, jadi ia hanya menerima ringkasan
    /// string. Yang paling berbahaya dari bentuk itu: penerima bisa saja
    /// menampilkan nama objek sebagai **jawaban**, sementara di app nama itu
    /// sudah ditandai ragu. Ringkasan harus menolak melakukan itu sendiri.
    func testDigestKeepsObjectNameButRefusesToClaimIdentity() {
        let snapshot = PointingSnapshot(
            state: .uncertain,
            intent: CelestialIntent(level: .medium, best: vega, candidates: []))
        let digest = ComplicationDigest(snapshot: snapshot, lastLocked: nil)

        XCTAssertEqual(digest.headline, "Vega",
                       "kandidat yang jujur tetap tampil di complication")
        XCTAssertFalse(digest.isConfirmed,
                       "tapi identitasnya tidak boleh diklaim pasti")
        XCTAssertTrue(digest.hasAnswer)
    }

    /// Saat terkunci, complication boleh menampilkan nama tanpa tanda ragu.
    func testDigestConfirmsIdentityOnlyOnLock() {
        let locked = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .lock,
                intent: CelestialIntent(level: .high, best: vega, candidates: [])),
            lastLocked: nil)
        XCTAssertTrue(locked.isConfirmed)
        XCTAssertEqual(locked.headline, "Vega")

        // Tidak ada keadaan selain `.lock` boleh mengonfirmasi identitas.
        for state in [PointingState.idle, .pointing, .searching, .uncertain, .unavailable] {
            let digest = ComplicationDigest(
                snapshot: PointingSnapshot(
                    state: state,
                    intent: CelestialIntent(level: .high, best: vega, candidates: [])),
                lastLocked: nil)
            XCTAssertFalse(digest.isConfirmed,
                           "\(state) tidak boleh mengirim identitas pasti ke complication")
        }
    }

    /// **Regresi: complication menampilkan nama kandidat seolah sudah pasti.**
    ///
    /// `digest.headline` sengaja menampilkan nama kandidat pada `.uncertain`
    /// (menutupinya akan membuat complication berbeda dari app). Tapi nama
    /// itu **ditempel tanpa satu penanda pun** — bukan dirupa teks, bukan
    /// ikon: complication hanya bisa menampilkan `headline` + simbol keadaan.
    ///
    /// Tiga permukaan lain sudah teach aturan yang sama dalam dua bentuk:
    /// gambar tidak boleh menampilkan ciri pengenal (`confirmsIdentity`), dan
    /// badge "Ragu" tampil di sebelah nama (`statusCard`, `LockArrivalPanel`).
    /// Complication adalah **permukaan keempat dari satu jawaban**, dan satu-
    /// satunya yang ikut ke pergelangan tangan — justru yang paling sering
    /// dipakai untuk "sekilas, lalu lanjut".
    ///
    /// `digest.isConfirmed` sudah ada, sudah ikut JSON, dan sudah diuji
    /// round-trip — tapi **tidak ada satu pun view yang membacanya**. Uji ini
    /// menuntut bentuk yang benar-benar dirender mengikutinya.
    func testUncertainCandidateNeverRendersIdenticallyToALock() {
        let locked = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .lock,
                intent: CelestialIntent(level: .high, best: vega, candidates: [])),
            lastLocked: nil)
        let candidate = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .uncertain,
                intent: CelestialIntent(level: .medium, best: vega, candidates: [])),
            lastLocked: nil)

        // Nama yang sama boleh tampil di keduanya (menutupinya saat ragu akan
        // menyembunyikan informasi yang jujur).
        XCTAssertEqual(locked.headline, candidate.headline)

        // Tapi keduanya tidak boleh **sama persis** sebagai tampilan: kalau
        // teks dan simbolnya sama, pergelangan tidak punya satu pun jalan untuk
        // tahu mana yang engine yakini dan mana yang tebakan.
        XCTAssertNotEqual(locked.presentedSymbolName, candidate.presentedSymbolName,
                          "kandidat ragu tidak boleh memakai simbol yang sama dengan terkunci")
        XCTAssertTrue(candidate.carriesUncertaintyMarker,
                      "kandidat yang belum pasti harus punya penanda di complicasi")
        XCTAssertFalse(locked.carriesUncertaintyMarker,
                       "terkunci tidak boleh memakai penanda ragu")
    }

    /// Penanda ragu hanya boleh muncul kalau memang ada **nama yang bisa
    /// disesatkan** — bukan di semua keadaan.
    func testUncertaintyMarkerOnlyAppearsWhereANameIsShown() {
        // Tanpa nama tidak ada yang bisa diklaim, jadi tidak ada penanda.
        let searching = ComplicationDigest(snapshot: PointingSnapshot(state: .searching),
                                           lastLocked: nil)
        XCTAssertFalse(searching.carriesUncertaintyMarker)

        // `hasAnswer` + `!isConfirmed` adalah syaratnya: nama kandidat yang
        // belum pasti. Keadaan tanpa jawaban jatuh ke label keadaan, dan
        // label keadaan sudah jujur tanpa tambahan penanda.
        for state in [PointingState.idle, .pointing, .searching, .unavailable] {
            let digest = ComplicationDigest(
                snapshot: PointingSnapshot(
                    state: state,
                    intent: CelestialIntent(level: .high, best: vega, candidates: [])),
                lastLocked: nil)
            XCTAssertFalse(digest.carriesUncertaintyMarker,
                           "\(state) menampilkan label keadaan, bukan nama")
        }
    }

    /// Penanda ragu harus **memakai** simbol keadaan ragu, bukan simbol
    /// netral. Ini yang membuatnya terbaca sekilas: di complication ada satu
    /// slot ikon, dan ikon itulah satu-satunya kanal kromatik.
    func testUncertainMarkerUsesTheStatesOwnSymbol() {
        let candidate = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .uncertain,
                intent: CelestialIntent(level: .medium, best: vega, candidates: [])),
            lastLocked: nil)
        XCTAssertEqual(candidate.presentedSymbolName,
                       PointingState.uncertain.symbolName,
                       "penanda harus ikut keadaan, bukan ikon tetap")
        XCTAssertEqual(candidate.presentedSymbolName, "questionmark.circle")
    }

    /// Baris kedua complication harus **berpindah prioritas**: begitu nama
    /// menjadi kandidat yang belum pasti, jenis benda dikalahkan oleh penanda.
    ///
    /// Yang diuji di sini adalah **keputusan isi baris kedua**, bukan
    /// susunan kalimat: view hanya punya satu slot baris, dan urutan prioritas
    /// itu hidup di sana. Yang bisa dijaga di Linux adalah syaratnya — penanda
    /// boleh jadi isi baris kedua tepat ketika `carriesUncertaintyMarker`, dan
    /// tidak boleh pada keadaan yang lain.
    ///
    /// Versi pertama uji ini cuma mengecek bahwa penanda tidak mengandung nama
    /// objek — pernyataan yang benar tetapi tidak bisa gagal: penanda memang
    /// tidak akan pernah memuat nama, karena ia bukan kalimat. Mengganti
    /// seluruh isi baris kedua dengan `objectKind.displayName` **tetap hijau**
    /// pada bentuk itu, padahal itulah persis cacatnya.
    func testUncertaintyMarkerOutranksTheObjectKindOnTheSubline() {
        // Penanda jadi isi baris kedua tepat pada keadaan ragu-yang-punya-nama.
        let candidate = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .uncertain,
                intent: CelestialIntent(level: .medium, best: vega, candidates: [])),
            lastLocked: nil)
        XCTAssertTrue(candidate.carriesUncertaintyMarker)
        XCTAssertEqual(candidate.sublineContent, .uncertaintyMarker,
                       "saat ragu, penanda harus mengalahkan jenis benda")

        // Dan jenis benda tetap jadi isi baris kedua saat tidak ada penanda —
        // kalau tidak, baris kedua jadi kosong di keadaan yang paling biasa.
        let locked = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .lock,
                intent: CelestialIntent(level: .high, best: vega, candidates: [])),
            lastLocked: nil)
        XCTAssertEqual(locked.sublineContent, .objectKind)

        // Keadaan tanpa jawaban tidak punya nama untuk diklaim dan tidak punya
        // jenis benda untuk disebut — baris kedua kosong lebih jujur daripada
        // mengulang label keadaan yang sudah jadi baris pertama.
        let idle = ComplicationDigest(snapshot: PointingSnapshot(state: .idle),
                                      lastLocked: nil)
        XCTAssertEqual(idle.sublineContent, .none)
    }

    /// Keadaan tanpa jawaban harus menampilkan **label keadaan**, bukan nama
    /// objek sisa dari pandangan sebelumnya.
    func testDigestShowsStateLabelWhenNoAnswer() {
        for state in [PointingState.idle, .pointing, .searching, .unavailable] {
            let digest = ComplicationDigest(
                snapshot: PointingSnapshot(state: state),
                lastLocked: vega)
            XCTAssertEqual(digest.headline, state.shortLabel,
                           "\(state) tidak punya jawaban — jangan tampilkan nama")
            XCTAssertFalse(digest.hasAnswer)
        }
    }

    /// Digest harus bisa melewati batas proses: encode → decode tidak boleh
    /// mengubah apa yang dilihat pengguna.
    func testDigestSurvivesCodableRoundTrip() {
        let original = ComplicationDigest(
            snapshot: PointingSnapshot(
                state: .lock,
                intent: CelestialIntent(level: .high, best: vega, candidates: [])),
            lastLocked: nil)
        let data = try? JSONEncoder().encode(original)
        let decoded = data.flatMap { try? JSONDecoder().decode(ComplicationDigest.self, from: $0) }

        XCTAssertEqual(decoded?.headline, original.headline)
        XCTAssertEqual(decoded?.isConfirmed, original.isConfirmed)
        XCTAssertEqual(decoded?.stateRaw, original.stateRaw)
        XCTAssertEqual(decoded, original, "round trip harus sama persis")
    }
}
