import Foundation

/// Bentuk nada pendek saat engine mengunci — **angka yang dulu hanya hidup di
/// `Apps/`**, tempat `./swift-test.sh` tidak pernah membangunnya.
///
/// **Cacat yang ditutup berkas ini.**
///
/// `AudioCueEngine.ensureResources()` di `Apps/Shared/AudioCue.swift`
/// menyintesis nada kunci langsung di dalam gelung sampel:
///
///     let sampleRate: Double = 44100
///     let duration: Double = 0.13
///     ...
///     let envelope = sin(.pi * Double(i) / Double(frameCount))
///     samples[i] = Float(0.28 * sin(2 * .pi * 880 * t) * envelope)
///
/// Empat angka dan satu rumus amplop itu memutuskan **bagaimana "berhasil"
/// terdengar** — dan bunyi adalah satu-satunya saluran bagi pengguna yang
/// tidak melihat layar, yaitu tepat pengguna yang fitur ini ada untuknya.
/// Semuanya tinggal di `Apps/`, yang tidak pernah dibangun `./swift-test.sh`
/// di Linux dan tidak dijaga satu pun dari 45 aturan UI (diukur: nol
/// pemeriksaan di `Tools/` menyebut `sampleRate`, `880`, atau rumus
/// amplopnya). Politik **peristiwa** mana yang berbunyi sudah dipindah ke
/// `AudioEventPolicy`, dan politik **saklar** ke `AudioPreference`; yang
/// tersisa di `Apps/` justru bagian yang paling mudah rusak tanpa terlihat,
/// karena rusaknya hanya terdengar.
///
/// **Kenapa bentuk rusaknya berbahaya, bukan sekadar sumbang.**
///
///   * Amplop yang dibalik (`1 - envelope`) menghasilkan **klik** di kedua
///     ujung: sinyal mulai dan berhenti pada amplitudo penuh. Klik itu
///     terdengar seperti kerusakan perangkat, bukan seperti konfirmasi.
///   * Durasi nol atau sangat pendek membuat buffer lebih pendek dari satu
///     periode 880 Hz, sehingga yang terdengar adalah potongan gelombang —
///     nada yang tingginya berubah-ubah antar-kunci.
///   * Amplitudo di atas 1.0 memotong (clip) di `AVAudioPCMBuffer` float,
///     menghasilkan harmonisa kasar yang persis terdengar seperti "rusak".
///   * Frekuensi 0 membuat seluruh sampel nol: **bisu total**, tanpa satu
///     pun galat. Ini yang paling berbahaya, karena pengguna yang tidak
///     melihat layar tidak punya cara membedakan "tidak berbunyi" dari
///     "tidak ada yang dikunci".
///
/// Semua bentuk di atas **mengompilasi bersih** dan tidak meninggalkan jejak
/// di gerbang teks mana pun, karena yang salah adalah nilai yang sah secara
/// tipe.
///
/// **Batas yang diakui.** Modul ini tidak menyintesis audio dan tidak
/// menyentuh `AVFAudio` — `Apps/` tetap pemilik `AVAudioEngine`. Yang
/// dipindah adalah **bentuk nada**: nomor sampel, frekuensi, amplitudo,
/// amplop, dan berapa lama. Semuanya fungsi murni yang bisa dijalankan di
/// Linux, jadi "nada yang benar" bisa dibuktikan tanpa perangkat.
public enum ToneSynth {

    // MARK: - Angka nada

    /// Laju sampel buffer nada.
    ///
    /// 44100 Hz adalah laju yang dijamin tersedia di semua perangkat Apple
    /// dan tidak memaksa `AVAudioEngine` melakukan konversi laju di jalur
    /// pemutaran. Nada ini hanya 0,13 detik, jadi biaya memorinya tidak
    /// berarti.
    public static let sampleRate: Double = 44100

    /// Panjang nada, detik.
    ///
    /// 0,13 detik dipilih supaya terasa seperti **konfirmasi**, bukan
    /// pemberitahuan: cukup panjang untuk terdengar utuh oleh telinga, cukup
    /// pendek untuk tidak menutupi langkah berikutnya. Di bawah ~0,05 detik
    /// telinga membacanya sebagai klik, bukan nada.
    public static let duration: Double = 0.13

    /// Frekuensi nada, Hz.
    ///
    /// 880 Hz (A5) berada di daerah telinga paling peka, jadi nada ini
    /// terdengar jelas pada volume rendah — penting karena app ini dipakai
    /// di malam hari tanpa menyalakan layar.
    public static let frequency: Double = 880

    /// Amplitudo puncak, 0…1.
    ///
    /// 0,28 memberi ruang kepala yang lebar: `mixWithOthers` berarti nada ini
    /// bercampur dengan musik pengguna, dan puncak yang mendekati 1.0 akan
    /// terpotong (clip) justru saat musik ikut berbunyi.
    public static let peakAmplitude: Double = 0.28

    // MARK: - Amplop

    /// Nilai amplop pada sampel ke-`index` dari `frameCount` sampel.
    ///
    /// **Bentuknya sinus setengah gelombang**, `sin(π · i / N)`. Ia nol tepat
    /// di `i = 0` dan `i = N`, jadi tidak ada langkah mendadak di kedua ujung
    /// buffer — dan langkah mendadak itulah yang terdengar sebagai klik.
    /// Alternatif yang lebih sederhana, amplop linear, juga nol di kedua
    /// ujung; yang membuat sinus dipilih adalah turunannya juga nol di ujung,
    /// sehingga tidak ada sudut yang bisa terdengar sebagai "tick" halus pada
    /// nada sesingkat ini.
    ///
    /// Indeks di luar rentang **dijepit**, bukan dibiarkan menghasilkan nilai
    /// negatif atau lebih dari satu: pemanggil yang salah menghitung
    /// `frameCount` tidak boleh bisa membuat buffer yang melampaui amplitudo
    /// puncak.
    public static func envelope(atIndex index: Int, frameCount: Int) -> Double {
        guard frameCount > 0 else { return 0 }
        let clamped = min(max(index, 0), frameCount)
        return sin(.pi * Double(clamped) / Double(frameCount))
    }

    // MARK: - Sampel

    /// Nilai satu sampel nada, `-peakAmplitude…+peakAmplitude`.
    ///
    /// Ini **isi buffer** yang diputar `Apps/`: gelombang sinus pada
    /// `frequency`, dibatasi amplop di atas. Dipisah dari `envelope` supaya
    /// kedua paruh bisa diuji sendiri-sendiri — amplop yang benar dengan
    /// frekuensi nol tetap menghasilkan bisu, dan sebaliknya.
    public static func sample(atIndex index: Int, frameCount: Int) -> Double {
        guard frameCount > 0 else { return 0 }
        let t = Double(index) / sampleRate
        return peakAmplitude * sin(2 * .pi * frequency * t)
            * envelope(atIndex: index, frameCount: frameCount)
    }

    /// Jumlah sampel satu nada penuh.
    ///
    /// Dibulatkan, bukan dipotong: `0.13 × 44100 = 5733.0` tepat, tetapi
    /// perubahan durasi di kemudian hari tidak boleh diam-diam memendekkan
    /// nada sampai di bawah satu periode. Dijaga oleh uji
    /// `testFrameCountCoversAtLeastOneFullCycle`.
    public static var frameCount: Int {
        Int((sampleRate * duration).rounded())
    }
}
