import Foundation
import PointingKit

/// Penyimpan antara app jam dan **complication** (WidgetKit).
///
/// **Kenapa ini perlu.** Complication watchOS berjalan di proses **terpisah**
/// dari app jam — ia tidak bisa membaca `@StateObject` engine, tidak bisa
/// memanggil `PointingEngine`, dan tidak punya akses ke layar apa pun. Satu-
///-satunya cara ia tahu "objek terakhir yang terkunci" adalah lewat berkas
/// yang dibagi. Karena itu app jam **menulis** ringkasan setiap kali keadaan
/// berubah, dan complication **membaca**nya saat watchOS meminta entri timeline.
///
/// Bentuk yang ditulis/dibaca adalah `ComplicationDigest` milik **PointingKit**
/// (bukan struct lokal di sini). Alasannya: aturan "bagaimana ringkasan ini
/// ditampilkan" (`headline`, `hasAnswer`, `isConfirmed`) adalah **janji tampilan**
/// yang harus bisa diuji di Linux. Kalau bentuknya atau aturan display-nya
/// diletakkan di app, keduanya tidak punya tempat uji — yang ada hanya
/// kompilasi di Mac. Dengan `ComplicationDigest` di PointingKit, logika yang
/// sama yang dijaga oleh `PointingPresentationTests` juga dipakai app dan
/// complication — tidak ada dua versi aturan.
///
/// **Kenapa App Group + fallback.** Berbagi antar-proses di watchOS butuh
/// App Group (`containerURL(forSecurityApplicationGroupIdentifier:)`). Tapi
/// CI membangun **tanpa tanda tangan** (`CODE_SIGNING_ALLOWED=NO`), dan di
/// situ container App Group mengembalikan `nil`. Kalau kita mengandalkan
/// container itu tanpa cadangan, complication akan diam di setiap build CI
/// (dan di Simulator tanpa entitas) — persis "kegagalan diam" yang dilarang
/// PRD. Makanya ada fallback ke direktori cache: penyimpanan tetap jalan
/// (sekadar tidak terbaca complication saat belum ada App Group yang
/// diaktifkan di profil), dan yang penting **kompilasi & tes lolos** tanpa
/// sertifikat.
public final class ComplicationStore {

    public static let shared = ComplicationStore()

    /// Nama berkas — identik di app dan extension.
    static let fileName = "complication-snapshot.json"
    /// App Group bersama. Harus diaktifkan di profil provisi untuk benar-benar
    /// terbagi; tanpa itu, `containerURL` mengembalikan `nil` dan kita pakai
    /// fallback cache.
    ///
    /// ID-nya dibaca dari Info.plist (`CPAppGroupID`, diturunkan dari
    /// `BUNDLE_ID_PREFIX` di `Config/Base.xcconfig`) supaya awalan bundle bisa
    /// diganti tanpa menyentuh kode (ADR-005). Nilai tetap hanya cadangan.
    static let appGroupID = (Bundle.main.object(forInfoDictionaryKey: "CPAppGroupID") as? String)
        ?? "group.dev.celestial.pointandknow"

    private let fileManager: FileManager

    /// Bila diisi, dipakai apa adanya (khusus tes). `nil` di produksi.
    private let baseDirectory: URL?

    public init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    /// URL tempat menyimpan. App Group bila tersedia, else cache app.
    ///
    /// Dua lokasi ini **berbeda** saat App Group belum aktif, jadi di situ
    /// complication (jika ia punya App Group) tidak akan melihat tulisan app
    /// (yang jatuh ke cache). Itu bukan bug diam-diam: di perangkat nyata
    /// dengan App Group diaktifkan, keduanya sama. Fallback hanya menjaga
    /// agar penyimpanan tidak crash saat tidak ada container.
    ///
    /// **Kenapa `#if canImport(Darwin)`.** `containerURL(forSecurityApplicationGroupIdentifier:)`
    /// hanya ada di Apple platform. Menuliskannya di belakang `#if` berarti
    /// berkas ini bisa dikompilasi & diuji di Linux — jadi logika
    /// encode/decode/tulisnya benar-benar terverifikasi, bukan cuma
    /// "kelihatan benar". Complication sendiri tetap jalan persis sama di watchOS.
    private var storeURL: URL {
        // Tes mengarahkan ke direktori sementara sendiri (App Group tidak ada
        // di Linux, jadi tanpa ini snapshot tes menimpa cache asli).
        if let base = baseDirectory {
            return base.appendingPathComponent(Self.fileName)
        }
        #if canImport(Darwin)
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            return group.appendingPathComponent(Self.fileName)
        }
        #endif
        let cache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cache.appendingPathComponent(Self.fileName)
    }

    /// Tulis ringkasan. Aman dipanggil dari main actor; pemanggil sudah
    /// membatasi ke transisi keadaan, jadi ini tidak terjadi 20×/dtk.
    public func record(_ digest: ComplicationDigest) {
        guard let data = try? JSONEncoder().encode(digest) else { return }
        let url = storeURL
        // Tulis atomik langsung ke URL tujuan. Sengaja **tidak** memakai
        // `replaceItem(at:withItemAt:)` + berkas sementara: API itu hanya
        // tersedia di Apple platform (Linux `swiftc -parse` tidak tipe-check,
        // tapi di Apple ia menuntut `backupItemName:` & `resultingItemURL:`),
        // dan ia juga gagal kalau berkas tujuan belum ada.
        // `Data.write(_:to:options: .atomic)` sudah menulis lewat berkas
        // sementara lalu rename di dalam Foundation — jadi tidak perlu
        // meniru langkah "tulis sementara lalu pindah" sendiri, dan tetap
        // atomik.
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // Kegagalan tulis complication bukan alasan menghentikan engine,
            // dan bukan alasan membuat app crash. Dicatat ke log sistem; layar
            // tetap menampilkan keadaan dari memory.
            NSLog("ComplicationStore: gagal menulis snapshot (\(error.localizedDescription))")
        }
    }

    /// Baca ringkasan terakhir. `nil` bila belum pernah ditulis.
    public func read() -> ComplicationDigest? {
        guard let data = try? Data(contentsOf: storeURL) else { return nil }
        return try? JSONDecoder().decode(ComplicationDigest.self, from: data)
    }
}