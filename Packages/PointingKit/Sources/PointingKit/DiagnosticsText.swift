import Foundation

/// Label baris, legenda, dan nilai untuk layar Diagnostik — satu sumber,
/// teruji di Linux.
///
/// **Kenapa berkas ini ada, dan kenapa bukan sekadar "tambah kunci".**
/// `DiagnosticsView` sudah benar di permukaan: setiap labelnya ada di
/// `Localizable.xcstrings`, lengkap dengan terjemahan Bahasa Inggris. Aturan 4
/// di `swift-ui-lint.sh` menyapu literal di argumen peritel teks dan menuntut
/// setiap literal itu ada di katalog — dan semuanya ada. Aturan 19 mencari
/// kunci yatim dan melaporkan bersih. Aturan 6 memeriksa paritas paket dan
/// katalog, dan sebanding.
///
/// Tiga gerbang hijau, dan tetap tidak satu pun kata Inggris sampai ke layar.
///
/// Sebabnya bukan di katalognya, melainkan di **tipe parameternya**.
/// `Text` punya dua inisialisator yang berperilaku berlawanan, dan yang mana
/// yang terpakai ditentukan oleh tipe tempat literal itu berdiri:
///
///     Text("Terkunci")     // LocalizedStringKey -> dicari di katalog
///     Text(someString)     // StringProtocol      -> DICETAK APA ADANYA
///
/// Apple mendokumentasikan yang kedua sebagai *"without localization"*. Helper
/// baris di layar ini bertipe `String`:
///
///     private func row(_ title: String, _ value: String) -> some View
///
/// Jadi `row("Keadaan", …)` menerima **kunci katalog** di dalam parameter
/// bertipe `String`, dan yang tercetak ke layar adalah kata Indonesianya.
/// Terjemahannya tidak pernah dibaca — di perangkat mana pun, di bahasa mana
/// pun, tanpa satu pun peringatan build.
///
/// **Kenapa gerbang yang ada tidak melihatnya.** Aturan 19 adalah yang paling
/// dekat: niatnya memang "kunci ini dipakai atau tidak", dan ia menjawab ya.
/// Jawabannya salah, karena kunci itu dipakai sebagai **teks Indonesia**, bukan
/// sebagai kunci. Ia mencari teks kunci di seluruh sumber sebagai substring
/// mentah, jadi kemunculannya di dalam `row("…")` menghitung sebagai rujukan.
///
/// **Yang diperbaiki bukan menambal situsnya, melainkan memindahkan teksnya ke
/// lapisan yang punya kunci.** Literal Bahasa Indonesia berhenti menjadi
/// identitas; identitasnya adalah kunci ber-namespace `diagnostics.*`, dan
/// Bahasa Indonesia menjadi **nilai bawaan** — persis pola `ExperimentText`,
/// `SensorStatusText`, dan `ObjectSpeech`.
///
/// **Kenapa kunci baru, bukan kunci yang sudah ada.** Enam label di layar ini
/// sudah punya padanan kata di katalog — "Kalibrasi" (`skyContext.calibration`),
/// "Lokasi" (`skyContext.location`), "Asal lokasi" (`skyContext.locationSource`),
/// "Sudah"/"Belum" (`calibration.status.*Short`), dan "Laju pergelangan"
/// (`row.speech.wristRateWord`). Semuanya **sengaja tidak dipakai ulang**.
///
/// Alasannya sudah tertulis di repo ini, di komentar `LocalizedText.rawValue`:
/// `"Kalibrasi"` adalah judul layar kalibrasi **dan** nama pesan tautan
/// `calibrationReady` untuk hal yang berbeda; kalau teksnya yang jadi kunci,
/// keduanya menyatu diam-diam dan mengubah satu ikut mengubah yang lain.
/// Kata yang sama di layar yang berbeda adalah dua keputusan penerjemahan yang
/// berbeda — layar Tautan dan layar Diagnostik boleh memilih kata Inggris yang
/// berbeda untuk "Kalibrasi" tanpa saling mengunci. Itu sebabnya `link.row.*`
/// ada meskipun `skyContext.*` sudah memuat kata yang sama.
///
/// **Batasnya.** Yang disediakan hanya teksnya; urutan dan kapan ia tampil
/// tetap milik pemanggil. Angka masuk lewat `String(format:)` supaya bahasa
/// lain bisa menempatkannya di urutan berbeda.
public enum DiagnosticsText {

    // MARK: - Judul baris

    /// "Keadaan" — keadaan engine sekarang.
    public static var rowState: String {
        TextLocalization.text(.diagnosticsRowState)
    }

    /// "Panduan" — kalimat yang memberi tahu harus berbuat apa.
    ///
    /// Terpisah dari `rowState` meskipun keduanya tampil bersebelahan: yang
    /// satu menjawab **apa** keadaannya, yang lain **apa yang harus
    /// dilakukan**. Bahasa yang menerjemahkan keduanya dengan kata yang sama
    /// kehilangan perbedaan itu.
    public static var rowGuidance: String {
        TextLocalization.text(.diagnosticsRowGuidance)
    }

    public static var rowCalibration: String {
        TextLocalization.text(.diagnosticsRowCalibration)
    }

    public static var rowWristRate: String {
        TextLocalization.text(.diagnosticsRowWristRate)
    }

    public static var rowObject: String {
        TextLocalization.text(.diagnosticsRowObject)
    }

    /// "Objek (sisa)" — nama objek yang ditampilkan adalah hasil kedaluwarsa.
    ///
    /// Bentuk sendiri, bukan `rowObject` + penanda yang disambung di view: dua
    /// string yang disambung mengunci urutannya di kode, dan bahasa lain tidak
    /// bisa menaruh penandanya di depan nama.
    public static var rowObjectStale: String {
        TextLocalization.text(.diagnosticsRowObjectStale)
    }

    public static var rowDirection: String {
        TextLocalization.text(.diagnosticsRowDirection)
    }

    public static var rowSigmaInUse: String {
        TextLocalization.text(.diagnosticsRowSigmaInUse)
    }

    public static var rowDeviceMotion: String {
        TextLocalization.text(.diagnosticsRowDeviceMotion)
    }

    public static var rowSample: String {
        TextLocalization.text(.diagnosticsRowSample)
    }

    public static var rowLocation: String {
        TextLocalization.text(.diagnosticsRowLocation)
    }

    public static var rowLocationSource: String {
        TextLocalization.text(.diagnosticsRowLocationSource)
    }

    // MARK: - Judul baris detail teknis

    public static var rowMagnitude: String {
        TextLocalization.text(.diagnosticsRowMagnitude)
    }

    /// "RA" — asensio rekta.
    ///
    /// Tetap disimpan sebagai kunci meskipun singkatan astronomi sering sama
    /// di banyak bahasa: bahasa yang menulisnya "AR" (ascensión recta) tidak
    /// punya cara lain untuk mengatakannya kalau teksnya terkunci di kode.
    public static var rowRightAscension: String {
        TextLocalization.text(.diagnosticsRowRightAscension)
    }

    /// "Dec" — deklinasi.
    public static var rowDeclination: String {
        TextLocalization.text(.diagnosticsRowDeclination)
    }

    public static var rowCatalogueId: String {
        TextLocalization.text(.diagnosticsRowCatalogueId)
    }

    // MARK: - Legenda grafik keyakinan

    /// Kata untuk pita "yakin". Dipakai legenda grafik **dan** pengumuman
    /// baris, jadi satu kunci melayani keduanya — dua permukaan yang menyebut
    /// hal yang sama tidak boleh punya dua terjemahan.
    public static var legendConfident: String {
        TextLocalization.text(.diagnosticsLegendConfident)
    }

    public static var legendUncertain: String {
        TextLocalization.text(.diagnosticsLegendUncertain)
    }

    public static var legendUnknown: String {
        TextLocalization.text(.diagnosticsLegendUnknown)
    }

    // MARK: - Nilai baris

    /// "Sudah" — kalibrasi terpasang.
    ///
    /// Sengaja **bukan** `calibration.status.appliedShort`, meskipun katanya
    /// sama. Kunci itu adalah keadaan alur kalibrasi di layar kalibrasi;
    /// yang ini adalah jawaban baris tabel "Kalibrasi" di layar diagnostik.
    /// Menggabungkannya berarti satu perubahan kata di alur kalibrasi diam-diam
    /// mengubah tabel diagnostik — dan tidak ada yang memberi tahu.
    public static var valueCalibrated: String {
        TextLocalization.text(.diagnosticsValueCalibrated)
    }

    public static var valueNotCalibrated: String {
        TextLocalization.text(.diagnosticsValueNotCalibrated)
    }

    /// "Ada" — sensor gerak tersedia.
    public static var valueMotionAvailable: String {
        TextLocalization.text(.diagnosticsValueMotionAvailable)
    }

    public static var valueMotionUnavailable: String {
        TextLocalization.text(.diagnosticsValueMotionUnavailable)
    }
}

// MARK: - Katalog kunci

public extension LocalizedText {

    // Kunci `diagnostics.*`. Namespace-nya dipisah dari `skyContext.*` dan
    // `link.*` karena kata yang sama di layar yang berbeda adalah keputusan
    // penerjemahan yang berbeda — lihat catatan di `DiagnosticsText`.

    static let diagnosticsRowState = LocalizedText(
        key: "diagnostics.row.state", id: "Keadaan")
    static let diagnosticsRowGuidance = LocalizedText(
        key: "diagnostics.row.guidance", id: "Panduan")
    static let diagnosticsRowCalibration = LocalizedText(
        key: "diagnostics.row.calibration", id: "Kalibrasi")
    static let diagnosticsRowWristRate = LocalizedText(
        key: "diagnostics.row.wristRate", id: "Laju pergelangan")
    static let diagnosticsRowObject = LocalizedText(
        key: "diagnostics.row.object", id: "Objek")
    static let diagnosticsRowObjectStale = LocalizedText(
        key: "diagnostics.row.objectStale", id: "Objek (sisa)")
    static let diagnosticsRowDirection = LocalizedText(
        key: "diagnostics.row.direction", id: "Arah")
    static let diagnosticsRowSigmaInUse = LocalizedText(
        key: "diagnostics.row.sigmaInUse", id: "Sigma dipakai")
    static let diagnosticsRowDeviceMotion = LocalizedText(
        key: "diagnostics.row.deviceMotion", id: "Device motion")
    static let diagnosticsRowSample = LocalizedText(
        key: "diagnostics.row.sample", id: "Sampel")
    static let diagnosticsRowLocation = LocalizedText(
        key: "diagnostics.row.location", id: "Lokasi")
    static let diagnosticsRowLocationSource = LocalizedText(
        key: "diagnostics.row.locationSource", id: "Asal lokasi")

    static let diagnosticsRowMagnitude = LocalizedText(
        key: "diagnostics.row.magnitude", id: "Magnitudo")
    static let diagnosticsRowRightAscension = LocalizedText(
        key: "diagnostics.row.rightAscension", id: "RA")
    static let diagnosticsRowDeclination = LocalizedText(
        key: "diagnostics.row.declination", id: "Dec")
    static let diagnosticsRowCatalogueId = LocalizedText(
        key: "diagnostics.row.catalogueId", id: "Id katalog")

    static let diagnosticsLegendConfident = LocalizedText(
        key: "diagnostics.legend.confident", id: "Yakin")
    static let diagnosticsLegendUncertain = LocalizedText(
        key: "diagnostics.legend.uncertain", id: "Ragu")
    static let diagnosticsLegendUnknown = LocalizedText(
        key: "diagnostics.legend.unknown", id: "Tidak tahu")

    static let diagnosticsValueCalibrated = LocalizedText(
        key: "diagnostics.value.calibrated", id: "Sudah")
    static let diagnosticsValueNotCalibrated = LocalizedText(
        key: "diagnostics.value.notCalibrated", id: "Belum")
    static let diagnosticsValueMotionAvailable = LocalizedText(
        key: "diagnostics.value.motionAvailable", id: "Ada")
    static let diagnosticsValueMotionUnavailable = LocalizedText(
        key: "diagnostics.value.motionUnavailable", id: "Tidak ada")
}
