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

    /// Objek yang **belum pasti** kehilangan gambarnya, bukan hanya cirinya.
    ///
    /// **Kenapa ini berubah dari `.candidate`.** Alasan versi lama ("bola
    /// netral masih memberi satu hal yang tidak diberi kata Ragu: ada sesuatu
    /// di arah itu") mengandaikan gambar itu bernama. Di layar redup ia tidak
    /// pernah bernama — yang ada di sebelahnya hanyalah nama berkurung ragu
    /// dan lencana tanda tanya, keduanya **lebih kecil** dari gambar, sementara
    /// bola itu sendiri adalah klaim bentuk. Pengamat yang melirik jam redup
    /// membaca gambar lebih dulu dan tanda tanya sebagai koreksi. Tiga
    /// permukaan lain (`drawableStarColorIndex`, `Palette.drawable`,
    /// `drawableMorphology`) menjawab pertanyaan yang sama dengan "jangan
    /// tampilkan cirinya"; jawaban yang paling konsisten dengan PRD adalah
    /// jangan tampilkan gambarnya sama sekali. Teks (nama + keadaan) tetap
    /// dirender oleh view, jadi kanal itu tidak hilang.
    func testUnconfirmedObjectIsNotDrawnAtAll() {
        let visual = CelestialVisual(object: object(id: "saturn", kind: .planet))
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: visual, isConfirmed: false),
                       .none,
                       "ragu = jangan gambar; lencana tanda tanya bukan bingkai, ia koreksi")
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

    /// Rencana tidak pernah membawa gambar saat ragu — jadi penyamaran tidak
    /// bisa terjadi dua kali dan tidak bisa berbeda pendapat dengan kartu jam.
    ///
    /// Versi lama uji ini menuntut `plan` **meneruskan** gambarnya utuh ke
    /// pemanggil, dengan alasan penyamaran milik view. Uji itu hijau atas
    /// rencana yang menggambar, jadi ia tidak bisa menangkap apa pun tentang
    /// apakah gambarnya seharusnya ada. Yang dijaga sekarang adalah
    /// kebalikannya: satu-satunya bentuk yang mengembalikan gambar adalah
    /// bentuk yang sudah dikunci, dan gambarnya utuh (bukan salinan yang
    /// dilemahkan di sini) — supaya `CelestialVisualView` tetap satu-satunya
    /// tempat penyamaran, untuk permukaan yang memang menggambar.
    func testOnlyAConfirmedPlanCarriesTheVisualIntact() {
        let visual = CelestialVisual(object: object(id: "jupiter", kind: .planet))
        guard case .identifiable(let carried) =
                ReducedLuminanceVisual.plan(visual: visual, isConfirmed: true) else {
            return XCTFail("objek yang dikunci harus digambar")
        }
        XCTAssertEqual(carried, visual,
                       "penyamaran milik view, bukan milik pemetaan keyakinan")
        XCTAssertEqual(ReducedLuminanceVisual.plan(visual: visual, isConfirmed: false), .none,
                       "ragu tidak membawa gambar, jadi tidak ada yang disamarkan")
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
