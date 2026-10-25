import XCTest
@testable import PointingKit

/// Uji `ToneSynth` — bentuk nada kunci yang dulu hidup di `Apps/` tanpa uji.
///
/// Setiap uji di sini ditulis untuk **merah pada bentuk rusak yang sudah
/// disebut di docstring modul**, bukan sekadar mengulang angka yang ada.
/// Uji yang hanya `XCTAssertEqual(ToneSynth.frequency, 880)` akan hijau
/// meski seluruh amplopnya dibalik, jadi yang diuji di bawah adalah
/// **sifat** yang membuat nadanya terdengar seperti konfirmasi.
final class ToneSynthTests: XCTestCase {

    // MARK: - Angka nada

    /// Frekuensi tidak boleh nol.
    ///
    /// Nol membuat setiap sampel nol — **bisu total tanpa satu pun galat**.
    /// Itu bentuk rusak paling berbahaya di berkas ini: pengguna yang tidak
    /// melihat layar tidak punya cara membedakan "tidak berbunyi" dari
    /// "tidak ada yang dikunci".
    func testFrequencyIsAudible() {
        XCTAssertGreaterThan(ToneSynth.frequency, 0,
                             "frekuensi nol berarti bisu total, bukan nada")
        // Batas atas telinga manusia yang paling konservatif (~20 kHz).
        XCTAssertLessThan(ToneSynth.frequency, 20_000,
                          "di atas 20 kHz tidak terdengar siapa pun")
    }

    /// Amplitudo puncak harus di dalam 0…1 supaya tidak terpotong (clip).
    ///
    /// `AVAudioPCMBuffer` float menyimpan nilai di luar 1.0 apa adanya, dan
    /// pemotongan terjadi di mixer — hasilnya harmonisa kasar yang terdengar
    /// seperti kerusakan perangkat.
    func testPeakAmplitudeLeavesHeadroom() {
        XCTAssertGreaterThan(ToneSynth.peakAmplitude, 0,
                             "amplitudo nol berarti bisu")
        XCTAssertLessThanOrEqual(ToneSynth.peakAmplitude, 1.0,
                                 "di atas 1.0 akan terpotong di mixer")
        // Headroom: nada ini bercampur dengan musik pengguna (`mixWithOthers`).
        XCTAssertLessThanOrEqual(ToneSynth.peakAmplitude, 0.5,
                                 "puncak terlalu tinggi untuk bercampur aman")
    }

    /// Nada harus cukup panjang untuk terdengar sebagai nada, bukan klik.
    func testDurationIsLongEnoughToBeATone() {
        XCTAssertGreaterThanOrEqual(ToneSynth.duration, 0.05,
                                    "di bawah ~50 ms telinga membacanya klik")
        // Dan cukup pendek untuk tidak menutupi langkah berikutnya.
        XCTAssertLessThanOrEqual(ToneSynth.duration, 0.5,
                                 "nada konfirmasi tidak boleh terasa lama")
    }

    /// Jumlah sampel harus menutupi setidaknya satu periode penuh.
    ///
    /// Kalau tidak, yang terdengar adalah potongan gelombang yang tingginya
    /// bergantung pada fase akhir buffer — nadanya berubah-ubah antar-kunci.
    func testFrameCountCoversAtLeastOneFullCycle() {
        let periodSamples = ToneSynth.sampleRate / ToneSynth.frequency
        XCTAssertGreaterThanOrEqual(
            Double(ToneSynth.frameCount), periodSamples,
            "buffer lebih pendek dari satu periode: nadanya tidak utuh")
        // Dan cocok dengan durasi yang dinyatakan, bukan angka lain.
        XCTAssertEqual(Double(ToneSynth.frameCount),
                       (ToneSynth.sampleRate * ToneSynth.duration).rounded(),
                       accuracy: 1.0,
                       "frameCount tidak diturunkan dari durasi × laju sampel")
    }

    // MARK: - Amplop: tidak boleh ada klik

    /// Amplop harus **nol** di kedua ujung buffer.
    ///
    /// Inilah sifat yang mencegah klik. Amplop yang dibalik
    /// (`1 - sin(...)`) bernilai 1 di kedua ujung dan uji ini merah — persis
    /// bentuk rusak yang disebut docstring modul.
    func testEnvelopeIsSilentAtBothEnds() {
        let n = ToneSynth.frameCount
        XCTAssertEqual(ToneSynth.envelope(atIndex: 0, frameCount: n), 0.0,
                       accuracy: 1e-12,
                       "amplop tidak nol di awal: akan terdengar klik")
        XCTAssertEqual(ToneSynth.envelope(atIndex: n, frameCount: n), 0.0,
                       accuracy: 1e-12,
                       "amplop tidak nol di akhir: akan terdengar klik")
    }

    /// Amplop harus **memuncak di tengah** dan tidak pernah melewati 1.
    func testEnvelopePeaksInTheMiddleWithoutOvershoot() {
        let n = ToneSynth.frameCount
        var maxValue = -Double.infinity
        var maxIndex = -1
        for i in 0...n {
            let v = ToneSynth.envelope(atIndex: i, frameCount: n)
            XCTAssertLessThanOrEqual(v, 1.0 + 1e-12,
                                     "amplop melewati 1.0 di indeks \(i)")
            XCTAssertGreaterThanOrEqual(v, -1e-12,
                                        "amplop negatif di indeks \(i)")
            if v > maxValue { maxValue = v; maxIndex = i }
        }
        XCTAssertGreaterThan(maxValue, 0.99, "amplop tidak pernah mencapai puncak")
        // Puncak di paruh tengah, bukan menempel di salah satu ujung.
        XCTAssertGreaterThan(maxIndex, n / 4)
        XCTAssertLessThan(maxIndex, 3 * n / 4)
    }

    /// Amplop di luar rentang **dijepit**, bukan menghasilkan nilai liar.
    ///
    /// Pemanggil yang salah menghitung `frameCount` tidak boleh bisa membuat
    /// sampel melampaui amplitudo puncak.
    func testEnvelopeClampsOutOfRangeIndices() {
        let n = ToneSynth.frameCount
        XCTAssertEqual(ToneSynth.envelope(atIndex: -100, frameCount: n), 0.0,
                       accuracy: 1e-12)
        XCTAssertEqual(ToneSynth.envelope(atIndex: n + 100, frameCount: n), 0.0,
                       accuracy: 1e-12)
    }

    /// `frameCount` nol atau negatif tidak boleh membagi dengan nol.
    func testEnvelopeIsZeroForEmptyBuffer() {
        XCTAssertEqual(ToneSynth.envelope(atIndex: 0, frameCount: 0), 0.0)
        XCTAssertEqual(ToneSynth.envelope(atIndex: 5, frameCount: -3), 0.0)
        XCTAssertEqual(ToneSynth.sample(atIndex: 5, frameCount: 0), 0.0)
    }

    // MARK: - Sampel

    /// Setiap sampel harus di dalam `±peakAmplitude`.
    ///
    /// Amplop yang lupa dikalikan, atau amplitudo yang dipakai dua kali,
    /// membuat sampel melewati batas ini.
    func testEverySampleStaysWithinPeakAmplitude() {
        let n = ToneSynth.frameCount
        let limit = ToneSynth.peakAmplitude + 1e-12
        for i in 0..<n {
            let s = ToneSynth.sample(atIndex: i, frameCount: n)
            XCTAssertLessThanOrEqual(abs(s), limit,
                                     "sampel \(i) melewati amplitudo puncak")
        }
    }

    /// Sampel pertama dan terakhir harus (hampir) nol — ujung buffer sunyi.
    func testFirstAndLastSamplesAreSilent() {
        let n = ToneSynth.frameCount
        XCTAssertEqual(ToneSynth.sample(atIndex: 0, frameCount: n), 0.0,
                       accuracy: 1e-12)
        XCTAssertEqual(ToneSynth.sample(atIndex: n - 1, frameCount: n), 0.0,
                       accuracy: 1e-3,
                       "sampel terakhir tidak sunyi: akan terdengar klik")
    }

    /// Nada harus benar-benar berosilasi, bukan garis datar.
    ///
    /// Frekuensi nol atau amplop nol menghasilkan seluruh buffer nol, dan uji
    /// batas amplitudo di atas akan tetap hijau. Yang membedakan "bisu" dari
    /// "nada" adalah **ada sampel yang berganti tanda**.
    func testTheToneActuallyOscillates() {
        let n = ToneSynth.frameCount
        var signChanges = 0
        var previous = ToneSynth.sample(atIndex: 0, frameCount: n)
        for i in 1..<n {
            let s = ToneSynth.sample(atIndex: i, frameCount: n)
            if previous != 0 && s != 0 && (s > 0) != (previous > 0) {
                signChanges += 1
            }
            if s != 0 { previous = s }
        }
        // 880 Hz selama 0,13 s ≈ 114 periode → ~228 pergantian tanda.
        // Ambang bawah yang longgar tetap memisahkan "berosilasi" dari "datar".
        XCTAssertGreaterThan(signChanges, 100,
                             "sampel tidak berosilasi: nada ini bisu")
    }

    /// Jumlah periode dalam satu nada harus cocok dengan frekuensi × durasi.
    ///
    /// Ini mengunci **frekuensi yang benar-benar dipakai** sampel, bukan
    /// konstanta yang cuma dideklarasikan: konstanta `frequency` yang diubah
    /// tanpa mengubah rumus sampel akan memerahkan uji ini.
    func testOscillationCountMatchesTheDeclaredFrequency() {
        let n = ToneSynth.frameCount
        var signChanges = 0
        var previous = ToneSynth.sample(atIndex: 0, frameCount: n)
        for i in 1..<n {
            let s = ToneSynth.sample(atIndex: i, frameCount: n)
            if previous != 0 && s != 0 && (s > 0) != (previous > 0) {
                signChanges += 1
            }
            if s != 0 { previous = s }
        }
        let measuredHz = Double(signChanges) / 2.0 / ToneSynth.duration
        XCTAssertEqual(measuredHz, ToneSynth.frequency,
                       accuracy: ToneSynth.frequency * 0.02,
                       "frekuensi terukur \(measuredHz) Hz tidak cocok dengan "
                       + "konstanta \(ToneSynth.frequency) Hz")
    }
}
