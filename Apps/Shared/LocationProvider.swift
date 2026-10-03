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
/// Satu implementasi dipakai app Watch maupun app iPhone.
@MainActor
final class LocationProvider: NSObject, ObservableObject {

    /// Lokasi terakhir yang sah, atau `nil` bila belum ada.
    @Published private(set) var location: ObserverLocation?
    /// Penjelasan status untuk ditampilkan ke pengguna.
    @Published private(set) var statusText = "Lokasi belum diminta"

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
            statusText = "Izin lokasi ditolak — memakai lokasi bawaan"
        default:
            manager.startUpdatingLocation()
            statusText = "Mencari lokasi…"
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Delegasi

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
                self.statusText = "Mencari lokasi…"
            case .denied, .restricted:
                self.statusText = "Izin lokasi ditolak — memakai lokasi bawaan"
            case .notDetermined:
                self.statusText = "Menunggu izin lokasi…"
            @unknown default:
                self.statusText = "Status lokasi tidak dikenal"
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        let coordinate = last.coordinate
        let accuracy = last.horizontalAccuracy
        Task { @MainActor in
            let label = String(format: "%.4f, %.4f",
                               coordinate.latitude, coordinate.longitude)
            self.location = ObserverLocation(
                latitudeDeg: coordinate.latitude,
                longitudeDeg: coordinate.longitude,
                label: label,
                source: "corelocation",
                capturedAt: last.timestamp
            )
            self.statusText = String(format: "Lokasi ±%.0f m", accuracy)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.statusText = "Lokasi gagal: \(message)"
        }
    }
}
