import Foundation

/// Gerbang "putusan GoTo boleh dipakai lagi, atau harus dihitung ulang".
///
/// **Kenapa ini ada.** `PointingEngine` menyimpan `SlewDecision` terakhir supaya
/// efemeris tidak dijalankan 20×/detik dari `publish` — `publish` dipanggil pada
/// setiap sampel sensor, dan menghitung ulang putusan di sana berarti memanggil
/// efemeris Matahari + target pada tiap sampel hanya untuk menggambar satu baris
/// peringatan. Versi pertama membatasi dengan **tanda tangan** saja: keadaan +
/// id objek. Itu menjawab satu pertanyaan dengan benar — "apakah subjek
/// putusannya berubah?" — dan melewatkan pertanyaan kedua.
///
/// **Pertanyaan yang terlewat.** Putusan GoTo tidak hanya bergantung pada
/// *objek mana* yang ditunjuk, melainkan pada **di mana** objek itu dan
/// **di mana** Matahari saat putusan dihitung. Keduanya bergerak. Objek yang
/// terkunci pada 30.2° dari Matahari (aman) akan melintasi ambang 30° beberapa
/// menit kemudian, dan objek yang terkunci pada 10.3° ketinggian akan turun di
/// bawah ambang 10° lebih cepat lagi. Dengan tanda tangan (keadaan, objek) yang
/// tidak berubah selama pengguna menahan tunjukan, **putusan lamanya bertahan
/// selamanya**: layar terus berkata "aman" atas geometri yang sudah tidak ada.
///
/// Itu kelas cacat yang sama dengan complication yang membaca snapshot sekali
/// lalu membeku, dan kelas false-confidence yang dilarang PRD — kali ini pada
/// satu-satunya bagian yang menyangkut keselamatan alat dan mata.
///
/// **Kenapa waktu, bukan geometri.** Menghitung geometri (efemeris) untuk
/// menyusun tanda tangan justru pekerjaan yang gerbang ini ada untuk
/// menghindari. Karena itu yang dipakai adalah **umur**: putusan boleh dipakai
/// selama ia lebih muda dari `maximumAge`. Ini aproksimasi, dan batasnya
/// dicatat, bukan disembunyikan:
///
/// - Matahari dan objek masing-masing bergerak ~0.25°/menit terhadap horizon,
///   jadi jarak antar keduanya berubah paling cepat ~0.5°/menit (saat
///   keduanya bergerak berlawanan arah).
/// - Dengan `maximumAge` 30 detik, perubahan terburuk sebelum putusan dihitung
///   ulang adalah ~0.25° — dua orde lebih kecil daripada ambang terkecil yang
///   dipakai (`minAltitudeDeg` 10°). Jadi putusan bisa **terlambat** paling
///   banyak seperempat derajat, tidak pernah salah secara besar.
///
/// Angka 30 detik sengaja sama dengan `PointingEngine.skyContextInterval`:
/// keduanya menjawab pertanyaan yang sama — "berapa lama hasil efemeris masih
/// berlaku sebelum ia harus diperbarui" — dan dua angka berbeda untuk satu
/// pertanyaan adalah cara aturan yang sama mulai berbeda pendapat.
///
/// **Batas yang jujur.** Gerbang ini tidak menghitung ulang saat objek
/// **melintasi** ambang; ia menghitung ulang saat umurnya habis, yang berarti
/// pelanggaran ambang bisa terlihat sampai 30 detik terlambat. Menutupnya
/// sepenuhnya menuntut geometri di dalam tanda tangan, dan itu biaya yang
/// gerbang ini ada untuk menghindari. Yang penting: keterlambatannya **terbatas
/// dan diketahui**, bukan tak terbatas seperti sebelumnya.
public struct SlewVerdictRefreshGate {

    /// Umur maksimum sebuah putusan sebelum ia harus dihitung ulang (detik).
    public var maximumAge: TimeInterval

    /// Tanda tangan putusan yang terakhir dihitung.
    private var signature: String?
    /// Kapan putusan itu dihitung.
    private var computedAt: Date?

    /// - Parameter maximumAge: umur maksimum putusan (detik). Harus positif;
    ///   nilai tak-positif berarti "hitung ulang setiap kali", yang tetap
    ///   benar secara keamanan (gagal-tertutup) tetapi membuang baterai.
    public init(maximumAge: TimeInterval = 30) {
        self.maximumAge = maximumAge
    }

    /// Apakah putusan untuk `signature` perlu dihitung ulang pada `date`.
    ///
    /// Bila `true`, pemanggil **wajib** memanggil `record(signature:at:)`
    /// setelah menghitung putusannya — kalau tidak, gerbang akan terus
    /// menjawab `true` dan menghitung ulang di tiap sampel.
    ///
    /// Dua alasan menjawab `true`, dan keduanya harus ada:
    /// 1. **Subjek berubah** — objek atau keadaan lain. Putusan atas objek
    ///    lain adalah putusan yang berbeda, bukan putusan yang menua.
    /// 2. **Umur habis** — subjeknya sama, tapi geometrinya sudah bergerak.
    public func needsRecompute(signature newSignature: String, at date: Date) -> Bool {
        guard let signature, let computedAt else { return true }
        if signature != newSignature { return true }
        return date.timeIntervalSince(computedAt) >= maximumAge
    }

    /// Catat bahwa putusan untuk `signature` baru saja dihitung pada `date`.
    ///
    /// Dipanggil hanya setelah putusan benar-benar dihitung: kalau ia dipanggil
    /// tanpa perhitungan, umur putusan lama akan diperpanjang tanpa isinya
    /// diperbarui — yaitu kebalikan dari yang gerbang ini jaga.
    public mutating func record(signature newSignature: String, at date: Date) {
        signature = newSignature
        computedAt = date
    }

    /// Lupakan putusan yang tersimpan.
    ///
    /// Dipakai saat konteksnya berubah tanpa lewat tanda tangan — mis. pengamat
    /// berpindah tempat, ketika langitnya bergeser seluruhnya dan tidak ada
    /// putusan lama yang masih jujur untuk dipertahankan.
    public mutating func reset() {
        signature = nil
        computedAt = nil
    }
}
