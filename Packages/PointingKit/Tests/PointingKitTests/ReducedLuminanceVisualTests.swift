import XCTest
import CelestialEngine

@testable import PointingKit

/// Layar redup (Always-On) — apa yang **boleh** diklaim gambarnya.
///
/// **Kelas cacat yang dijaga di sini.** Layar redup `ReducedLuminanceView`
/// adalah satu-satunya permukaan jam yang menampilkan objek terkunci **tanpa
/// gambar**: ia hanya menulis nama dan keadaan sebagai teks. Aturan yang
/// berlaku di tiga permukaan lain — kartu jam, panel iPhone, complication —
/// tidak sampai ke sini, karena keputusannya tidak pernah dinyatakan sebagai
/// nilai yang bisa diuji. Yang tersisa hanyalah ingatan orang yang sedang
/// menulis view, dan layar yang paling sering dilihat (pergelangan yang miring
/// sedikit, tanpa disentuh) justru yang paling miskin.
///
/// Yang membuat ini lebih dari sekadar kelengkapan: begitu gambar masuk ke
/// layar redup, **satu** pertanyaan identitas ikut masuk — bolehkah gambar itu
/// menampilkan ciri pengenalnya (cincin Saturnus, bentuk galaksi)? Kalau
/// jawabannya disalin per-view, layar redup menjadi tempat keempat yang bisa
/// berbeda pendapat, dan di situ perbedaannya paling berbahaya: layar ini
/// sengaja miskin konteks (tanpa badge keyakinan, tanpa panel peringatan,
/// tanpa baris kedua untuk menulis "Ragu"), jadi gambar yang lebih yakin
/// daripada teksnya tidak punya apa pun di sebelahnya untuk membantahnya.
///
/// Yang **tidak diuji di sini**: apakah `isConfirmed` dihitung dengan benar —
/// itu `IdentityConfirmationAgreementTests` dan turunannya di
/// `PointingEngine`. Berkas ini hanya menjaga pemetaan keyakinan → rencana
/// gambar, dan bahwa layar redup terikat pada `MotionPolicy` yang sama.
final class ReducedLuminanceVisualTests: XCTestCase {

    private func object(id: String, kind: ObjectKind) -> CelestialObject {
        CelestialObject(id: id, name: id, kind: kind,
                        raDeg: 100, decDeg: -10, magnitude: 1.0)
    }

    /// Objek yang **dikonfirmasi** boleh memakai ciri pengenalnya.
    ///
    /// Teks tidak membedakan cincin Saturnus dari bola polos. Kalau layar redup
    /// menyembunyikan ciri objek yang sudah dikunci, ia menampilkan lebih
    /// sedikit daripada yang berhak ditampilkan — dan satu-satunya alasan untuk
    /// itu adalah kebiasaan, bukan aturan.
    func testConfirmedObjectKeepsItsDistinguishingFeature() {
        let visual = CelestialVisual(object: object(id: "saturn", kind: .planet))
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: visual, isConfirmed: true),
                       .identifiable(visual),
                       "ciri pengenal objek yang sudah dikunci tidak boleh disembunyikan")
    }

    /// Objek yang **belum pasti** kehilangan cirinya, tapi bukan gambarnya.
    ///
    /// Ini alasan yang sama yang sudah menjaga tiga permukaan lain
    /// (`drawableStarColorIndex`, `Palette.drawable`, `drawableMorphology`).
    /// Rencananya sengaja **bukan** "jangan gambar apa-apa": itu membuang
    /// satu-satunya kanal yang tersedia di layar sekilas. Yang benar adalah
    /// menggambar dengan ciri dilepas, dan penanda ragu menempel pada gambar —
    /// di app, `CelestialVisualView` yang menyamar saat `isConfirmed == false`
    /// dan menggambar lencana tanda tanya.
    func testUnconfirmedObjectLosesItsFeatureAndKeepsTheVisual() {
        let visual = CelestialVisual(object: object(id: "saturn", kind: .planet))
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: visual, isConfirmed: false),
                       .candidate(visual),
                       "kandidat tetap digambar, tapi tanpa ciri pengenal")
    }

    /// Tanpa objek, tidak ada gambar — dan keyakinan tidak boleh membangkitkannya.
    ///
    /// Visual generik akan menampilkan benda yang **tidak** ditentukan engine,
    /// dan itu klaim yang dilarang PRD. Layar redup tanpa objek tetap bisa
    /// menampilkan keadaannya ("Mencari") sebagai teks.
    func testNoObjectMeansNoVisual() {
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: nil, isConfirmed: false), .none)
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: nil, isConfirmed: true), .none,
                       "keyakinan tidak boleh mengarang benda dari ketiadaan")
    }

    /// Rencananya membawa gambarnya utuh, bukan salinan yang sudah dilemahkan.
    ///
    /// Kalau `plan` menyamar sendiri (mis. memaksa warna netral di sini),
    /// penyamaran akan terjadi **dua kali** dan yang kedua tidak terlihat —
    /// lalu `CelestialVisualView` kehilangan kemampuan menyamarkannya sendiri
    /// saat ia juga dipakai kartu jam. Pemetaan di sini hanya soal keyakinan;
    /// penyamaran tetap satu tempat.
    func testPlanDoesNotPreWeakenTheVisual() {
        let visual = CelestialVisual(object: object(id: "jupiter", kind: .planet))
        guard case .candidate(let carried) =
                ReducedLuminanceVisual.plan(visual: visual, isConfirmed: false) else {
            return XCTFail("kandidat harus digambar")
        }
        XCTAssertEqual(carried, visual,
                       "penyamaran milik view, bukan milik pemetaan keyakinan")
    }

    /// Denyut **selalu** mati di layar redup, apa pun jenis objeknya.
    ///
    /// watchOS hanya menyegarkan layar redup sekali per detik, jadi mana pun
    /// yang menggerakkan gambar di sana membakar baterai untuk frame yang tidak
    /// pernah terlihat mulus. Dipakai bintang karena ia satu-satunya jenis yang
    /// memang berdenyut — supaya yang diuji benar-benar objek yang akan
    /// berdenyut kalau kebijakannya salah.
    func testReducedScreenNeverAnimates() {
        let star = CelestialVisual(object: object(id: "sirius", kind: .star))
        XCTAssertTrue(star.hasPulse, "prasyarat uji: bintang memang berdenyut")
        let policy = MotionPolicy(reduceMotion: false,
                                  isLuminanceReduced: true,
                                  isSceneActive: true)
        XCTAssertFalse(ReducedLuminanceVisual.allowsMotion(policy: policy),
                       "layar redup tidak punya aturan gerak sendiri")
    }

    /// Layar redup **tidak** menambah aturan gerak: ia hanya membaca
    /// `MotionPolicy`. Kalau ia pernah punya ambang sendiri, dua permukaan bisa
    /// berbeda diam-diam — dan yang berbeda di sini adalah baterai.
    func testReducedScreenFollowsMotionPolicyForBothForms() {
        let waking = MotionPolicy(reduceMotion: false,
                                  isLuminanceReduced: false,
                                  isSceneActive: true)
        XCTAssertTrue(ReducedLuminanceVisual.allowsMotion(policy: waking),
                      "prasyarat: layar normal tetap boleh berdenyut")
        for policy in [MotionPolicy(reduceMotion: true, isLuminanceReduced: false, isSceneActive: true),
                       MotionPolicy(reduceMotion: false, isLuminanceReduced: false, isSceneActive: false)] {
            XCTAssertFalse(ReducedLuminanceVisual.allowsMotion(policy: policy),
                           "keputusan gerak harus persis `MotionPolicy`, bukan lebih longgar")
        }
    }
}
