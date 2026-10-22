import Foundation
import AVFAudio
import PointingKit

/// Bunyi pendek saat engine mengunci — saluran multi-modal bagi pengguna
/// yang tidak melihat layar, sejajar dengan haptic.
///
/// Sengaja **opsional** (lihat `AudioCue.isOn`, default nyala) dan hanya
/// berbunyi untuk `.lockSucceeded`: bunyi saat engine ragu adalah false
/// confidence berwujud suara. Nadanya **disintesis di memori** (prosedural,
/// tanpa aset) lewat `AVAudioPlayerNode` + `AVAudioPCMBuffer`, jadi tidak
/// butuh berkas bunyi apa pun — sama seperti visual yang tanpa aset.
@MainActor
final class AudioCueEngine {

    /// Bunyikan nada pendek bila cocok dengan kejadian yang diizinkan.
    ///
    /// Menerima array peristiwa yang **sama** dengan yang diberikan ke haptic,
    /// supaya pemanggilnya (engine) tidak perlu tahu peristiwa mana yang
    /// berbunyi. Pemilihan ada di sini: hanya `.lockSucceeded`. Membunyikan
    /// peristiwa lain menjaga janji PRD bahwa "ragu" tidak boleh terdengar
    /// seperti "berhasil".
    ///
    /// **Keputusan itu tidak lagi ditulis di berkas ini.** Pemilihan
    /// peristiwa audible hidup di `AudioEventPolicy` (PointingKit, teruji di
    /// Linux), karena badan `events.contains(.lockSucceeded)` yang dulu
    /// tinggal di sini memutuskan politik PRD ("ragu tidak boleh terdengar
    /// seperti berhasil") di `Apps/`, yang tidak pernah dibangun
    /// `swift-test.sh`. Terukur: empat mutasinya — termasuk `|| .uncertain`
    /// yang membuat engine ragu berbunyi persis seperti engine yakin —
    /// **semuanya** lolos ke-45 aturan UI. Di sini hanya meneruskan daftar
    /// peristiwanya dan saklar penggunanya.
    func play(_ events: [HapticEvent]) {
        guard AudioEventPolicy.shouldPlay(events: events,
                                          isAudioEnabled: AudioCue.isOn) else { return }
        playTone()
    }

    // MARK: - Sintesis nada (prosedural, tanpa aset)

    private let sampleRate: Double = 44100
    private let duration: Double = 0.13
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?

    /// Siapkan node + nada sekali saja.
    ///
    /// Semua panggilan dibungkus `try?`/`guard`: audio adalah aksesibilitas
    /// opsional, jadi kegagalan (mis. sesi tidak bisa aktif di perangkat
    /// tertentu) cukup diabaikan daripada menggagalkan app.
    private func ensureResources() {
        guard audioEngine == nil else { return }
        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buf.frameLength = frameCount
        if let channel = buf.floatChannelData {
            let samples = channel[0]
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                // Amplop naik lalu turun: bunyi "ping" lembut, bukan klik.
                let envelope = sin(.pi * Double(i) / Double(frameCount))
                samples[i] = Float(0.28 * sin(2 * .pi * 880 * t) * envelope)
            }
        }

        engine.connect(node, to: engine.mainMixerNode, format: format)
        // `mixWithOthers`: jangan memotong musik latar pengguna.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()

        audioEngine = engine
        playerNode = node
        buffer = buf
    }

    private func playTone() {
        ensureResources()
        guard let node = playerNode, let buf = buffer else { return }
        node.stop()
        node.scheduleBuffer(buf, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    /// Lepaskan sesi audio dan mesinnya.
    ///
    /// **Kenapa ini ada, padahal `ensureResources` sudah malas.** Bunyi kunci
    /// hanya 0,13 detik, tetapi biayanya dibayar setelah bunyinya habis:
    /// `setActive(true)` menahan sesi audio tetap aktif, dan sesi aktif
    /// menahan perangkat audio bangun. Pada jam yang dipakai sepanjang malam
    /// di lapangan, itu baterai yang dibayar untuk suara yang tidak ada.
    ///
    /// **Ini kelas cacat yang tidak terlihat gerbang mana pun.** Diukur dengan
    /// menyapu seluruh `Apps/` untuk pasangan akuisisi/pelepasan: pembaruan
    /// lokasi punya `startUpdatingLocation`/`stopUpdatingLocation`, device
    /// motion punya pasangannya, dan `setActive(true)` **tidak punya
    /// `setActive(false)` di mana pun**. Aturan 93 tidak bisa melihatnya
    /// karena ia memanen pasangan dari badan `start()` app jam — sedangkan
    /// sesi audio diakuisisi **malas**, di dalam `AudioCueEngine`, bukan di
    /// `start()`. Compiler juga diam: tidak ada yang salah secara sintaks.
    ///
    /// Aman dipanggil saat belum pernah ada bunyi: semuanya `guard`/`try?`,
    /// jadi app yang tidak pernah berbunyi tidak membayar apa pun.
    func stop() {
        guard audioEngine != nil else { return }
        playerNode?.stop()
        audioEngine?.stop()
        // Urutannya penting: mesin dihentikan **sebelum** sesi dilepas.
        // Melepas sesi yang masih dipakai mesin membuat `AVAudioSession`
        // menghentikan mesin dengan cara yang tidak terkendali, dan itu
        // memunculkan galat yang tidak bisa dibedakan dari kegagalan nyata.
        try? AVAudioSession.sharedInstance().setActive(false,
                                                       options: .notifyOthersOnDeactivation)
        audioEngine = nil
        playerNode = nil
        buffer = nil
    }
}

/// Preferensi bunyi saat kunci — satu kunci `UserDefaults` untuk jam & iPhone.
enum AudioCueStorage {
    static let key = "audioCueEnabled"
}

enum AudioCue {
    /// Default **nyala**: bunyi kunci adalah aksesibilitas, bukan gangguan.
    ///
    /// **Keputusan "belum diset = nyala" tidak ditulis di sini.** Ia hidup di
    /// `AudioPreference.isEnabled(stored:)` (PointingKit, teruji di Linux),
    /// karena badan yang dulu tinggal di sini memutuskan politik preferensi
    /// pengguna di `Apps/`, yang tidak pernah dibangun `./swift-test.sh`.
    /// Di sini hanya membaca nilai tersimpan dan meneruskannya.
    ///
    /// **Klaim yang ditarik (22 Okt 2026).** Versi pertama komentar ini
    /// menulis bahwa mutasi `return true` — mengabaikan saklar pengguna —
    /// "lolos seluruh gerbang". Itu **salah**, dan salahnya terukur: `swift
    /// test` memerahkannya dengan dua kegagalan di
    /// `PreferenceDefaultsTests`. Yang membuat klaim itu lahir bukan repo,
    /// melainkan `Tools/sapu-buta-apps.py`, yang menjalankan dua gerbang teks
    /// lalu mencetak "LOLOS SELURUH GERBANG" — alat yang mengukur sebagian
    /// dan mengucapkan seluruh. Alatnya sudah diperbaiki lebih dulu (gerbang
    /// ketiga + kontrol positif); klaimnya ditarik di sini.
    ///
    /// **Cacat yang benar-benar terukur, dan yang dijaga sekarang.** Bukan
    /// menghapus cabang, melainkan membalik nilainya: `bool(forKey:)` membaca
    /// kunci kosong sebagai `false`, sehingga "belum diset" runtuh menjadi
    /// "dimatikan" dan bawaan nyala hilang. Bentuk itu **mengompilasi** tanpa
    /// satu pun peringatan dan tidak meninggalkan tanda di kedua gerbang teks.
    /// Karena itu `as? Bool` di bawah bukan gaya penulisan: ia satu-satunya
    /// yang mempertahankan perbedaan `nil` dari `false`, dan
    /// `PreferenceDefaultsTests` menuntutnya secara eksplisit.
    static var isOn: Bool {
        get {
            AudioPreference.isEnabled(
                stored: UserDefaults.standard.object(forKey: AudioCueStorage.key) as? Bool)
        }
        set { UserDefaults.standard.set(newValue, forKey: AudioCueStorage.key) }
    }
}
