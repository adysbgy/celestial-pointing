import XCTest
import CelestialEngine
@testable import PointingKit

/// Uji untuk **kapan** pengumuman keadaan boleh dibunyikan.
///
/// **Kenapa ini ada, padahal `StateAnnouncement` sudah teruji.** Fungsi itu
/// menyusun kalimatnya; ia tidak memutuskan kapan kalimat itu dibunyikan.
/// Keputusan itu tinggal di view sebagai:
///
///     guard announcedState != newState else { return }
///     announcedState = newState
///     AccessibilityNotification.Announcement(...).post()
///
/// dan itu tiga baris yang **tidak pernah dibangun** `swift-test.sh` (Apps/
/// tidak ikut tes Linux), tidak diparse sebagai logika oleh
/// `swift-typecheck.sh` (hanya `-parse` sintaks), dan tidak dibaca satu pun
/// aturan teks di `swift-ui-lint.sh`. Terukur pada salinan utuh repo ini,
/// proses baru: membalik guard menjadi `!=` -> **seluruh 73 aturan UI lulus**,
/// dan app diamnya sudah berubah jadi kebalikannya -- ia berbunyi **saat
/// keadaan tidak berubah** dan **diam saat keadaan berubah**.
///
/// Yang lebih mahal dari diam: `snapshot` ditulis 20 kali per detik, jadi
/// guard yang dibalik membuat VoiceOver mengucapkan "Terkunci pada Vega"
/// dua puluh kali per detik selamanya. Itu bukan lagi cacat yang tidak
/// terlihat -- itu app yang tidak bisa dipakai pembaca layar sama sekali,
/// dan tidak ada gerbang lokal yang berbunyi.
///
/// Karena itu keputusannya dipindah ke sini sebagai fungsi murni: masukan
/// (keadaan yang terakhir diumumkan, keadaan sekarang) -> **apakah berbunyi
/// dan keadaan mana yang harus disimpan**. View tinggal menuruti hasilnya.
///
/// Yang **tidak** diklaim: apakah `post()` benar-benar sampai ke VoiceOver.
/// Itu wilayah perangkat. Yang diuji adalah keputusan yang mendahuluinya.
final class AnnouncementGateTests: XCTestCase {

    // MARK: - Berbunyi hanya saat keadaan berubah

    /// Perpindahan keadaan: berbunyi **dan** keadaan baru disimpan.
    func testStateChangeSpeaksAndRemembersTheNewState() {
        let step: AnnouncementGate.Step<PointingState> =
            AnnouncementGate.step(announced: .idle, current: .lock)
        XCTAssertTrue(step.shouldSpeak)
        XCTAssertEqual(step.remember, .lock,
                       "keadaan baru wajib disimpan, kalau tidak pengumuman "
                       + "berikutnya akan mengulang keadaan yang sama")
    }

    /// Keadaan sama: **diam**, dan ingatan tetap sama.
    ///
    /// Ini yang menjaga `snapshot` 20 Hz tidak menjadi 20 pengumuman per
    /// detik. Tanpa cabang ini, seluruh alasan guard itu ada hilang.
    func testUnchangedStateStaysSilent() {
        let step: AnnouncementGate.Step<PointingState> =
            AnnouncementGate.step(announced: .lock, current: .lock)
        XCTAssertFalse(step.shouldSpeak,
                       "keadaan yang sama tidak boleh diumumkan ulang -- "
                       + "snapshot ditulis 20x/detik")
        XCTAssertEqual(step.remember, .lock)
    }

    /// Pembukaan app: keadaan awal belum pernah diumumkan, jadi pembacaan
    /// pertama **tidak** berbunyi.
    ///
    /// **Kenapa.** `onChange` tidak memicu pada nilai awal, tetapi peluncuran
    /// app tetap menulis cuplikan pertama. Mengumumkan "Siap" saat app baru
    /// dibuka hanya menunda pembacaan isi layar, dan pengguna belum
    /// melakukan apa pun yang perlu dikabarkan.
    func testFirstSnapshotIsSilentButRemembered() {
        let step: AnnouncementGate.Step<PointingState> =
            AnnouncementGate.step(announced: nil, current: .pointing)
        XCTAssertFalse(step.shouldSpeak,
                       "peluncuran app bukan peristiwa yang perlu dikabarkan")
        XCTAssertEqual(step.remember, .pointing,
                       "tetap disimpan supaya perubahan berikutnya yang berbunyi")
    }

    /// Peluncuran app yang langsung jatuh ke `.lock` juga tidak berbunyi --
    /// tetapi keadaan itu tetap diingat.
    func testFirstSnapshotDoesNotSpeakEvenForLock() {
        let step: AnnouncementGate.Step<PointingState> =
            AnnouncementGate.step(announced: nil, current: .lock)
        XCTAssertFalse(step.shouldSpeak)
        XCTAssertEqual(step.remember, .lock)
    }

    // MARK: - Urutan penuh: tiap perpindahan berbunyi tepat sekali

    /// Rentetan cuplikan nyata: tiap **perubahan** berbunyi tepat sekali,
    /// dan tiap pengulangan diam.
    ///
    /// Ini bentuk yang sebenarnya terjadi di pergelangan: puluhan sampel per
    /// detik dalam keadaan yang sama, lalu satu perpindahan.
    func testEveryTransitionSpeaksExactlyOnceAcrossArepeatedSequence() {
        let sequence: [PointingState] = [
            .idle, .idle, .pointing, .pointing, .pointing,
            .searching, .searching, .lock, .lock, .lock, .lock,
            .pointing, .uncertain,
        ]
        var announced: PointingState?
        var spoken: [PointingState] = []
        for state in sequence {
            let step: AnnouncementGate.Step<PointingState> =
                AnnouncementGate.step(announced: announced, current: state)
            if step.shouldSpeak { spoken.append(state) }
            announced = step.remember
        }
        // .idle pertama adalah cuplikan pertama (diam); sisanya perpindahan.
        XCTAssertEqual(spoken, [.pointing, .searching, .lock, .pointing, .uncertain])
    }

    /// Jumlah pengumuman = jumlah perpindahan, bukan jumlah sampel.
    ///
    /// Angka dibandingkan langsung supaya gerbang ini tidak bisa menjadi
    /// hijau yang khidmat: sembilan belas sampel berisi lima perpindahan
    /// harus berbunyi lima kali, dan **bukan** sembilan belas.
    func testNumberOfAnnouncementsEqualsNumberOfTransitions() {
        let samples: [PointingState] = Array(repeating: .lock, count: 19)
            + [.pointing]
        var announced: PointingState? = .lock   // sudah pernah diumumkan
        var count = 0
        for state in samples {
            let step: AnnouncementGate.Step<PointingState> =
                AnnouncementGate.step(announced: announced, current: state)
            if step.shouldSpeak { count += 1 }
            announced = step.remember
        }
        XCTAssertEqual(count, 1,
                       "19 sampel dalam keadaan yang sama tidak boleh berbunyi "
                       + "19 kali; hanya perpindahannya yang berbunyi")
    }

    // MARK: - Semua keadaan punya kalimat di tujuan

    /// Setiap keadaan yang bisa **menjadi tujuan** pengumuman punya kalimat
    /// tidak kosong dari `StateAnnouncement`.
    ///
    /// Gerbang dan kalimat diuji terpisah (`AnnouncementGateTests` vs
    /// `StateAnnouncementTests`), jadi satu sisi bisa benar sementara sisi
    /// lain kosong. Uji ini menyambung keduanya: apa pun keadaan tujuan yang
    /// dihasilkan gerbang, kalimatnya ada.
    func testEverySpeakableDestinationHasANonEmptySentence() {
        let all: [PointingState] = [.idle, .pointing, .searching,
                                    .lock, .uncertain, .unavailable]
        for state in all {
            let step: AnnouncementGate.Step<PointingState> =
                AnnouncementGate.step(announced: nil, current: state)
            XCTAssertEqual(step.remember, state,
                          "\(state): gerbang wajib menyimpan keadaannya, "
                          + "kalau tidak perubahan berikutnya tidak akan "
                          + "terdengar")
            let text = StateAnnouncement.text(for: PointingSnapshot(state: state))
            XCTAssertFalse(text.isEmpty, "\(state): kalimat pengumuman kosong")
        }
    }

    // MARK: - Nilai berbentuk String (layar kalibrasi)

    /// Gerbangnya generik, dan itu bukan demi fleksibilitas: layar
    /// `CalibrationView` mengawasi **hasil aksi** (`String`), bukan keadaan
    /// engine. Memaksa `PointingState` di sana akan membuat view menyimpan
    /// keadaan buatan yang tidak pernah berubah.
    func testStringGateBehavesTheSameWay() {
        let awal: AnnouncementGate.Step<String> =
            AnnouncementGate.step(announced: nil, current: "Belum siap dipakai")
        XCTAssertFalse(awal.shouldSpeak)
        XCTAssertEqual(awal.remember, "Belum siap dipakai")

        let sama: AnnouncementGate.Step<String> =
            AnnouncementGate.step(announced: "Acuan tercatat",
                                  current: "Acuan tercatat")
        XCTAssertFalse(sama.shouldSpeak)

        let baru: AnnouncementGate.Step<String> =
            AnnouncementGate.step(announced: "Acuan tercatat",
                                  current: "Kiriman gagal")
        XCTAssertTrue(baru.shouldSpeak)
        XCTAssertEqual(baru.remember, "Kiriman gagal")
    }

    /// Pengulangan hasil yang sama **tidak** berbunyi, meski layarnya
    /// disegarkan berkala.
    ///
    /// Layar kalibrasi memakai `TimelineView(.periodic(from:by: 30))` supaya
    /// daftar acuan dihitung ulang. Tanpa gerbang, setiap penyegaran akan
    /// mengulang "Acuan tercatat" — hasil yang benar menjadi deru, dan pada
    /// akhirnya pengguna mematikan VoiceOver.
    func testRepeatedStatusAfterPeriodicRefreshStaysSilent() {
        var announced: String? = "Acuan tercatat"
        var count = 0
        for _ in 0..<120 {   // 60 menit, penyegaran tiap 30 detik
            let step: AnnouncementGate.Step<String> =
                AnnouncementGate.step(announced: announced,
                                      current: "Acuan tercatat")
            if step.shouldSpeak { count += 1 }
            announced = step.remember
        }
        XCTAssertEqual(count, 0,
                       "hasil yang sama tidak boleh berbunyi ulang saat "
                       + "layar disegarkan berkala")
    }
}
