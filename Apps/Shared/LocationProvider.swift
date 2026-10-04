import Foundation
import Combine
import CoreLocation
import PointingKit

/// Sumber lokasi pengamat.
///
/// **Kenapa lokasi penting sampai segitunya.** Resolver memakai garis bujur
/// untuk menghitung waktu sidereal; salah 1° berarti seluruh langit bergeser 1°.
/// Jadi lokasi tidak boleh ditebak: kelas ini selalu menandai dari mana angkanya
/// datang (`source`), dan selama belum ada lokasi sungguhan pemanggil memakai
/// `ObserverLocation.fallback` yang jelas berlabel "bawaan" — supaya rekaman
/// Experiment 1 tidak pernah diam-diam memakai lokasi karangan.
///
/// **Kenapa ada `onLocationChanged`.** Lokasi sungguhan datang beberapa detik
/// setelah `start()` — yaitu setelah UI selesai dirender. Kalau tidak ada yang
/// memberi tahu engine saat itu, engine akan menghitung seluruh langit untuk
/// lokasi bawaan (Jakarta) selamanya, sementara layar menampilkan koordinat
/// sungguhan di sebelahnya. Langit yang tergeser ratusan derajat tapi terlihat
/// normal persis jenis kesalahan yang tidak boleh dibiarkan: tidak ada yang
/// akan menyadarinya dari UI. Callback ini memindahkan tanggung jawab itu ke
/// pemanggil (biasanya `PointingEngine`), sehingga tidak ada jalur di mana
/// lokasi berubah tanpa engine ikut tahu.
///
/// Satu implementasi dipakai app Watch maupun app iPhone.
///
/// **Kenapa TIDAK ada `@preconcurrency` pada konformansnya.** Atribut itu dulu
/// dipakai di sini karena `CLLocationManagerDelegate` adalah protokol
/// Objective-C yang tidak di-`@MainActor`, sedangkan kelas ini di-`@MainActor`.
/// Ternyata ia tidak berpengaruh sama sekali: **setiap** metode delegasi di
/// bawah sudah `nonisolated` dan menyerahkan hasilnya ke main actor lewat
/// `Task`, jadi tidak ada satu pun persyaratan protokol yang dilanggar isolasi.
/// Compiler Xcode 16.4 mengatakannya sendiri —
/// `@preconcurrency attribute on conformance to 'CLLocationManagerDelegate' has
/// no effect` — dan fix-it-nya memang membuang atribut itu.
///
/// Sengaja dibuang, bukan dibiarkan sebagai peringatan yang menganggur: dengan
/// atribut itu, kesalahan isolasi **baru** di kemudian hari (mis. metode
/// delegasi yang lupa `nonisolated`) diturunkan menjadi peringatan runtime.
/// Tanpa atribut, kesalahan yang sama menjadi **galat kompilasi** — jauh lebih
/// awal ketahuan, dan itu arah yang benar untuk aturan "gagal-tertutup".
///
/// Metode delegasi wajib ditandai `@objc`: tanpa penanda itu metodenya tidak
/// pernah dipanggil — gejalanya bukan galat kompilasi, melainkan lokasi yang
/// tidak pernah muncul. Urutannya harus `@objc nonisolated`; dibalik, parser
/// menolaknya.
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {

    /// Lokasi terakhir yang sah, atau `nil` bila belum ada.
    @Published private(set) var location: ObserverLocation?
    /// Penjelasan status untuk ditampilkan ke pengguna.
    @Published private(set) var statusText = SensorStatusText.locationNotRequested
    /// Peringatan yang **harus dilihat** pengguna: `nil` di luar keadaan
    /// gagal.
    ///
    /// Bukan `statusText` apa adanya: `statusText` memakai nilai seperti
    /// "Lokasi belum diminta" dan "Mencari lokasi…" yang **bukan** kesalahan.
    /// Membakar semuanya ke layar justru memunculkan pesan yang menakutkan
    /// saat segalanya normal. Karena itu ini `nil` di luar penolakan izin &
    /// kegagalan pengambilan — satu-satunya dua kasus yang benar-benar butuh
    /// diumumkan (PRD: jangan diam saat izin ditolak).
    @Published private(set) var note: String?

    /// Dijalankan **setiap kali** lokasi sungguhan berubah.
    ///
    /// Dijalankan di main actor. Pemanggil bertanggung jawab meneruskan
    /// perubahan ini ke engine; kalau tidak, engine akan memakai lokasi lama
    /// tanpa ada yang menyadarinya.
    var onLocationChanged: ((ObserverLocation) -> Void)?

    /// Lokasi yang harus dipakai sekarang — lokasi sungguhan bila ada,
    /// kalau tidak lokasi darurat yang jelas berlabel.
    var effectiveLocation: ObserverLocation { location ?? .fallback }

    /// Apakah lokasi ini sungguhan (bukan darurat).
    var hasRealLocation: Bool { location != nil }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Akurasi puluhan meter sudah jauh lebih dari cukup: galat 50 m hanya
        // menggeser langit ~0.0005°. Meminta akurasi terbaik hanya menghabiskan
        // baterai jam.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Minta izin lalu mulai memperbarui lokasi.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Mesin tetap jalan dengan lokasi darurat — tapi penolakan izin
            // **harus terlihat**, bukan diam (PRD: jangan diam saat izin
            // ditolak). `note` yang menampilkannya ada di `PointingView` &
            // `DiagnosticsView`; `statusText` sendirian tidak pernah dibaca UI.
            statusText = SensorStatusText.locationDeniedStatus
            note = SensorStatusText.locationDeniedNote
        default:
            manager.startUpdatingLocation()
            statusText = SensorStatusText.locationSearching
            note = nil
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Delegasi

    @objc nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
                self.statusText = SensorStatusText.locationSearching
                self.note = nil
            case .denied, .restricted:
                self.statusText = SensorStatusText.locationDeniedStatus
                self.note = SensorStatusText.locationDeniedNote
            case .notDetermined:
                self.statusText = SensorStatusText.locationWaiting
            @unknown default:
                self.statusText = SensorStatusText.locationUnknownStatus
            }
        }
    }

    @objc nonisolated func locationManager(_ manager: CLLocationManager,
                                            didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        let coordinate = last.coordinate
        let accuracy = last.horizontalAccuracy
        Task { @MainActor in
            let label = String(format: "%.4f, %.4f",
                               coordinate.latitude, coordinate.longitude)
            let location = ObserverLocation(
                latitudeDeg: coordinate.latitude,
                longitudeDeg: coordinate.longitude,
                label: label,
                source: "corelocation",
                capturedAt: last.timestamp
            )
            self.location = location
            self.statusText = SensorStatusText.locationAccuracy(meters: accuracy)
            // Penolakan izin tadi sudah lewat: sekarang ada lokasi sungguhan,
            // jadi peringatannya tidak lagi berlaku.
            self.note = nil
            // Beri tahu pemanggil supaya engine memakai koordinat ini, bukan
            // lokasi bawaan yang dipakai saat `start()`.
            self.onLocationChanged?(location)
        }
    }

    @objc nonisolated func locationManager(_ manager: CLLocationManager,
                                            didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.statusText = SensorStatusText.locationFailedStatus(message)
            self.note = SensorStatusText.locationFailedNote(message)
        }
    }
}
