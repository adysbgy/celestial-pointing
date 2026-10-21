import Foundation

/// Peran sebuah properti `@Published` — diputuskan **sebelum** propertinya
/// memicu render, bukan setelah ada yang mengeluh batai cepat habis.
///
/// **Kenapa modul ini ada, dan kenapa ia pengganti keputusan implisit.**
/// Di repo ini ada lima `ObservableObject` yang di-observasi layar
/// (`PointingEngine`, `MotionLogger`, `LocationProvider`, `WatchLinkService`,
/// `PhoneLinkService`, `ConfidenceTraceStore`, `ExperimentRecorder`). Setiap
/// properti `@Published` yang berubah memanggil `objectWillChange` **untuk
/// setiap layar yang mengobservasi objeknya** — jadi properti yang ditulis
/// 20× per detik dan tidak dibaca satu layar pun membayar redraw yang tidak
/// pernah menghasilkan satu piksel.
///
/// Kelas cacat itu sudah pernah tertangkap sekali, untuk satu objek:
/// `sampleCount` milik `PointingEngine` (terukur: 20×/detik, nol pembacaan,
/// seluruh 52 aturan UI tetap hijau — lihat komentar `ObservedState`). Yang
/// dijaga sejak itu hanyalah objek itu **saja**. Terukur lagi setelahnya,
/// dengan sapuan yang sama atas **semua** berkas `Apps/`:
///
///   * `MotionLogger.isRunning` — ditulis di tiga jalur (`start`, `stop`,
///     `handleFailure`), nol pembacaan.
///   * `WatchLinkService.lastPolicyFromPhone` — ditulis saat iPhone mengirim
///     ambang keyakinan baru, lalu diteruskan lewat `onPolicyReceived` ke
///     engine. Nilainya sendiri tidak pernah dibaca lagi oleh siapa pun.
///
/// Keduanya lolos seluruh 76 aturan UI, `swift-typecheck.sh`, dan
/// `swift-test.sh` — semuanya hijau dengan objektif yang salah tetap hidup.
/// Yang membuatnya bisa bertahan adalah bahwa tiap keputusan hidup di
/// berkasnya sendiri: tidak ada satu tempat pun yang menuntut setiap
/// `@Published` di `Apps/` punya peran.
///
/// **Yang membuat peran ini bukan komentar.** Aturannya diuji dari Linux
/// atas **teks** sumber `Apps/` (pola yang sama dengan
/// `PreferenceDefaultsTests`): setiap properti `@Published` yang benar-benar
/// ada di `Apps/` wajib punya peran di daftar ini, dan setiap peran wajib
/// menyebut properti yang benar-benar ada. Properti baru tidak bisa lahir
/// tanpa yang memutuskan perannya, dan peran yang menyebut properti yang
/// sudah dihapus langsung merah.
public enum ObservedProperty {

    /// Peran sebuah properti `@Published`.
    public enum Role: Equatable, Sendable {
        /// Dibaca layar. Perubahannya **boleh** memicu render.
        case renderInput
        /// Penjaga peristiwa: nilainya diteruskan ke closure `@Published`
        /// bersamanya (mis. `onPolicyReceived`) dan tidak pernah dibaca lagi.
        ///
        /// Bukan `renderInput` (tidak ada layar yang butuh render karenanya)
        /// dan bukan `bookkeeping` juga — bedanya penting di bawah.
        case eventCarrier
        /// Pembukuan/internal. Tidak boleh `@Published` sama sekali.
        case bookkeeping
    }

    /// Properti `@Published` yang **benar-benar ada** di `Apps/`, beserta
    /// perannya, dikelompokkan menurut berkas pemiliknya.
    ///
    /// Pemiliknya disebut karena peran bisa berbeda untuk nama yang sama di
    /// objek berbeda: `location` milik `PointingEngine` adalah masukan render
    /// semua layar, sementara `location` milik `LocationProvider` dibaca
    /// `PointingEngine.bind` lalu dipublikasikan ulang sebagai `engine.location`.
    /// Daftar tanpa nama berkas akan menyatukan keduanya menjadi satu aturan
    /// yang salah untuk salah satunya.
    ///
    /// **Yang TIDAK diklaim.** Daftar ini tidak menyebut properti yang bukan
    /// `@Published` (`sampleCount` milik `PointingEngine`, yang justru wajib
    /// tidak `@Published`), dan tidak menyebut properti `@State`/`@AppStorage`
    /// — masing-masing punya gerbangnya sendiri.
    public static let roles: [String: [String: Role]] = [
        "Apps/Shared/PointingEngine.swift": [
            "snapshot": .renderInput,
            "location": .renderInput,
            "sensorNote": .renderInput,
            "lastLockedObject": .renderInput,
            "skyContext": .renderInput,
            "slewVerdict": .renderInput,
            "lockArrival": .renderInput,
        ],
        "Apps/Shared/MotionLogger.swift": [
            // Ditulis di tiga jalur, dibaca nol layar: sensor hidup/mati sudah
            // sampai ke pengguna lewat `PointingEngine.snapshot` dan
            // `PointingEngine.sensorNote` (`publishSensorLoss`), bukan lewat
            // properti ini.
            "isRunning": .bookkeeping,
            // Pembacaan: `PointingView` menampilkannya lewat
            // `engine.sensorNote` yang diisi dari sini.
            "unavailableReason": .renderInput,
            // Baris "Sampel" di layar Diagnostik iPhone.
            "sampleCount": .renderInput,
        ],
        "Apps/Shared/LocationProvider.swift": [
            "location": .renderInput,
            // Ditulis, diteruskan ke `PointingEngine.sensorNote`, dibaca UI.
            "note": .renderInput,
            // `statusText` sendiri tidak pernah dibaca UI (sudah dicatat di
            // bodynya), nilainya diteruskan ke `note`.
            "statusText": .eventCarrier,
        ],
        "Apps/PointAndKnowWatch/Sources/WatchLinkService.swift": [
            // Pesan diteruskan ke `onPolicyReceived` (dipakai app jam untuk
            // memasang ambang di engine), jadi nilainya sendiri tidak perlu
            // memicu render layar mana pun.
            "lastPolicyFromPhone": .eventCarrier,
            // Dibaca `CalibrationView` (`.onChange` + teks peringatan) dan
            // `PointingView` (teks).
            "lastMessageNote": .renderInput,
            "isReachable": .renderInput,
            "sendFailureCount": .renderInput,
        ],
        "Apps/PointAndKnowiOS/Sources/PhoneLinkService.swift": [
            "lastCalibration": .renderInput,
            // Dibaca `CalibrationView`/`LinkView` sebagai catatan tautan.
            "lastNote": .renderInput,
            "lastState": .renderInput,
            "receivedCount": .renderInput,
            "isActivated": .renderInput,
            "isReachable": .renderInput,
        ],
        "Apps/PointAndKnowiOS/Sources/DiagnosticsView.swift": [
            // `@Published private(set) var trace` — dibaca `body` layar
            // Diagnostik untuk menggambar grafik keyakinan.
            "trace": .renderInput,
            "count": .renderInput,
        ],
        "Apps/PointAndKnowiOS/Sources/ExperimentRecorder.swift": [
            // Dipakai tukar situasi perekaman eksperimen di beberapa view.
            "currentLocation": .renderInput,
            "note": .renderInput,
            "selectedTargetID": .renderInput,
            "statusMessage": .renderInput,
        ],
    ]

    /// Peran untuk properti bernama `name` milik berkas `path` (relatif akar
    /// repo, mis. `Apps/Shared/PointingEngine.swift`).
    ///
    /// Nama yang tidak dikenal dijawab `nil` — bukan `.renderInput`:
    /// properti baru yang belum diputuskan perannya harus **merah**, bukan
    /// diam-diam dianggap aman, karena diam-diam-aman-nya persis cacat yang
    /// modul ini tutup.
    public static func role(for name: String, in path: String) -> Role? {
        roles[path]?[name]
    }

    /// Properti yang wajib **tidak** `@Published`: pembukuan (ditulis sering,
    /// tidak pernah tampil) dari semua pemilik.
    ///
    /// Diturunkan dari `roles`, bukan daftar kedua.
    public static var bookkeeping: [(path: String, name: String)] {
        // Ditulis sebagai loop, bukan `flatMap`+`compactMap` bersarang:
        // type-checker Swift 6 menyerah pada rantai itu ("unable to type-check
        // this expression in reasonable time"), dan memecahnya lebih jelas
        // daripada menambahkan anotasi tipe di tengah rantai.
        var hasil: [(path: String, name: String)] = []
        for (path, props) in roles {
            for (name, role) in props where role == .bookkeeping {
                hasil.append((path: path, name: name))
            }
        }
        hasil.sort { $0.path == $1.path ? $0.name < $1.name : $0.path < $1.path }
        return hasil
    }
}
