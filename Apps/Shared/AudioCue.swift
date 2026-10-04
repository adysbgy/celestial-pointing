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
    func play(_ events: [HapticEvent]) {
        guard AudioCue.isOn, events.contains(.lockSucceeded) else { return }
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
}

/// Preferensi bunyi saat kunci — satu kunci `UserDefaults` untuk jam & iPhone.
enum AudioCueStorage {
    static let key = "audioCueEnabled"
}

enum AudioCue {
    /// Default **nyala**: bunyi kunci adalah aksesibilitas, bukan gangguan.
    /// `object(forKey:)` dipakai supaya nilai yang belum pernah diset terbaca
    /// sebagai nyala, bukan sebagai `false` milik `bool(forKey:)`.
    static var isOn: Bool {
        get {
            if UserDefaults.standard.object(forKey: AudioCueStorage.key) == nil { return true }
            return UserDefaults.standard.bool(forKey: AudioCueStorage.key)
        }
        set { UserDefaults.standard.set(newValue, forKey: AudioCueStorage.key) }
    }
}
