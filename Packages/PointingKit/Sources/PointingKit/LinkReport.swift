import Foundation
import CelestialEngine

/// Satu baris "judul … nilai" yang **dibaca pembaca** dari laporan jam.
///
/// **Kenapa tipe ini ada.** `LinkView` di iPhone adalah satu-satunya layar
/// yang menjelaskan apa yang dilaporkan jam. Sampai siklus ini seluruh isinya
/// ditulis langsung di badan `view` — dan gerbang UI di repo ini bekerja pada
/// **teks** (`swift-ui-lint.sh`) dan pada **gambar** (`check-visuals.py`), jadi
/// tidak satu pun dari 87 aturan melihat kolom mana yang benar-benar dirender.
/// Terukur, bukan diduga: menghapus seluruh cabang σ dari `LinkView`
/// (tujuh baris, termasuk baris yang baru ditambahkan siklus sebelumnya)
/// meninggalkan **87 aturan hijau, `swift-typecheck.sh` exit 0**.
///
/// Konsekuensinya nyata dan sudah terjadi: `PointingLinkMessage` mengirim
/// `altitudeDeg`/`azimuthDeg` di **setiap** pesan keadaan, dan tidak ada satu
/// baris pun di iPhone yang menampilkannya. Bukan karena disengaja — karena
/// tidak ada yang mengukur. Sebuah medan yang dikirim tapi tidak pernah
/// dibaca tidak bisa dibedakan dari medan yang lupa dibaca.
///
/// Karena itu isi kolom dipindahkan ke sini: satu fungsi murni yang bisa
/// diuji di Linux, dan `LinkView` hanya merender hasilnya. Yang diuji bukan
/// "view memanggil sesuatu", melainkan **baris mana yang ada dan apa isinya**.
public enum LinkReport {

    /// Satu baris laporan: judul dari katalog, nilai yang sudah diformat.
    ///
    /// Sengaja hanya dua medan. Sebuah `spokenValue` ketiga sudah dicoba di
    /// sini dan **dihapus**: `row(...)` di `LinkView` sudah menggabungkan judul
    /// dan nilai menjadi satu pengumuman VoiceOver, sehingga bentuk ucapannya
    /// dibentuk di satu tempat yang sama untuk ketiga layar — dan medan ketiga
    /// yang tidak dibaca siapa pun tidak menjaganya apa pun.
    public struct Row: Equatable, Sendable {
        public var title: String
        public var value: String

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    /// Baris untuk bagian "keadaan terakhir dari jam".
    ///
    /// **Urutannya bagian dari keputusan, bukan selera.** Yang pertama adalah
    /// jawaban (keadaan dan objek), lalu seberapa tebal keyakinannya, lalu
    /// arah, lalu detail teknis. `LinkView` menampilkannya berurutan; layar
    /// yang menjelaskan laporan harus mendahulukan isi laporan.
    ///
    /// **`catalogue` wajib diteruskan**, alasannya sama dengan
    /// `reportedObjectName`: dua perangkat bisa menjalankan katalog berbeda,
    /// dan nama untuk id yang tidak dikenal pembaca adalah nama yang terlihat
    /// benar tanpa punya dasar.
    ///
    /// **Yang TIDAK diklaim.** Fungsi ini memutuskan **baris mana yang ada**
    /// dan **nilai apa yang tertulis**. Ia tidak memutuskan warna, ukuran,
    /// atau apakah barisnya muat di layar. Ia juga tidak menyembunyikan
    /// ketidakpastian: baris arah tetap muncul walaupun jam tidak
    /// terkalibrasi, karena yang dilaporkan adalah arah yang **dikirim jam**.
    /// Status kalibrasi sendiri **bukan** baris di sini — ia kalimat, dari
    /// `calibrationNoteText`, dan `LinkView` mencetaknya di bawah baris-baris
    /// ini. Menaruhnya di dua tempat akan membuat satu fakta punya dua
    /// kalimat yang bisa berbeda.
    public static func stateRows(_ message: PointingLinkMessage,
                                 catalogue: [CelestialObject]) -> [Row] {
        var rows: [Row] = []

        rows.append(Row(title: TextLocalization.text(.linkRowState),
                        value: message.state?.shortLabel ?? "—"))

        rows.append(Row(title: TextLocalization.text(.linkRowObject),
                        value: message.reportedObjectName(catalogue: catalogue) ?? "—"))

        rows.append(Row(title: TextLocalization.text(.linkRowConfidence),
                        value: message.level?.displayName ?? "—"))

        // Sigma yang berlaku di jam. Tanpa baris ini satu-satunya angka yang
        // menyatakan **seberapa tebal** keyakinan itu tidak pernah tampil,
        // padahal ia ikut di setiap pesan keadaan.
        //
        // Ditulis hanya bila ada: σ yang tidak disertakan sudah punya
        // peringatannya sendiri (`link.note.sigmaMissing` — σ=0 tidak boleh
        // terbaca sebagai akurasi sempurna), jadi baris kosong di sini akan
        // menduplikasi peringatan itu dengan cara yang lebih lemah.
        //
        // Sumbernya `confidencePolicy`, **bukan** `pointingSigmaDeg` mentah:
        // accessor itu menolak σ yang tidak berhingga atau ≤ 0, jadi angka
        // yang tidak bisa berlaku sebagai akurasi tidak pernah tercetak
        // sebagai akurasi. Nilai mentahnya tetap dipakai di tempat lain
        // (peringatan di atas) justru untuk **mendeteksi** ketiadaan itu.
        if let sigma = message.confidencePolicy?.pointingSigmaDeg {
            rows.append(Row(title: TextLocalization.text(.linkRowSigma),
                            value: NumberFormat.degrees(sigma)))
        }

        // Arah tunjuk yang **dikirim jam**. Dua medan ini ikut di setiap pesan
        // keadaan sejak awal dan tidak pernah dirender di iPhone — lihat
        // catatan di atas tipe ini.
        //
        // Ditampilkan sebagai satu baris, bukan dua: ketinggian dan azimut
        // hanya berarti bersama (satu sudut sendiri tidak menunjuk apa pun),
        // dan dua baris "judul … nilai" akan memisahkan pasangan yang harus
        // dibaca sebagai satu arah.
        //
        // Hanya bila **keduanya** ada. Setengah pasangan akan menampilkan
        // `42.5° / —`, yang terbaca seperti azimut yang gagal diukur padahal
        // artinya pesan itu tidak membawa arah sama sekali.
        if let altitude = message.altitudeDeg,
           let azimuth = message.azimuthDeg,
           altitude.isFinite, azimuth.isFinite {
            rows.append(Row(title: TextLocalization.text(.linkRowDirection),
                            value: LinkReport.directionText(altitudeDeg: altitude,
                                                            azimuthDeg: azimuth)))
        }

        if let rate = message.angularRateDegPerSec {
            // Bentuk tulisnya `0.5°/dtk` — bentuk ucapnya ("0.5 derajat per
            // detik") dibentuk `RowSpeech` di tempat yang sama untuk ketiga
            // layar, jadi tidak ada versi kedua yang bisa menyimpang.
            rows.append(Row(title: TextLocalization.text(.linkRowRate),
                            value: NumberFormat.degreesPerSecond(rate)))
        }

        // σ dan waktu dibentuk di `sigmaAndTimeRows`, dipakai bersama bagian
        // kalibrasi: dua medan ini ada di **kedua** jenis pesan, dan menulisnya
        // dua kali adalah cara paling pasti membuatnya berbeda.
        return rows + sigmaAndTimeRows(message)
    }

    /// Baris untuk bagian "kalibrasi terakhir dari jam".
    ///
    /// **Kenapa pindah ke sini.** Sama persis dengan `stateRows`: ketiga
    /// kolom ini dulu ditulis di badan `LinkView`, dan tidak satu pun gerbang
    /// melihatnya. Uji sapuan `LinkReportCoverageTests` menemukannya sebagai
    /// tiga medan yang dikirim jam tanpa jejak di laporan yang teruji —
    /// `yawOffsetDeg`, `residualSpreadDeg`, `sampleCount`.
    ///
    /// **Urutannya mengikuti cara membaca kalibrasi**, bukan urutan medan di
    /// pesan: berapa koreksinya, seberapa rapat sampelnya, lalu berapa banyak
    /// sampel. Yang pertama adalah hasilnya; dua berikutnya yang membuat hasil
    /// itu bisa dipercaya.
    ///
    /// **Yang TIDAK diklaim.** Fungsi ini tidak menilai apakah kalibrasinya
    /// bagus — ambang mutu ada di engine (`PointingCalibration`), bukan di
    /// lapisan tampilan. Nilai yang tidak dikirim ditulis `—`, bukan `0`.
    public static func calibrationRows(_ message: PointingLinkMessage) -> [Row] {
        [
            Row(title: TextLocalization.text(.linkRowYawOffset),
                value: message.yawOffsetDeg.map { NumberFormat.degrees($0) } ?? "—"),
            Row(title: TextLocalization.text(.linkRowSpread),
                value: message.residualSpreadDeg.map { NumberFormat.degrees($0) } ?? "—"),
            Row(title: TextLocalization.text(.linkRowReferenceCount),
                value: message.sampleCount.map(String.init) ?? "—"),
        ] + sigmaAndTimeRows(message)
    }

    /// Dua baris yang dipakai **oleh kedua jenis laporan** — keadaan dan
    /// kalibrasi — karena dua medan yang mereka laporkan juga dipakai keduanya.
    ///
    /// **Kenapa ini fungsi terpisah.** Uji sapuan `LinkReportCoverageTests`
    /// melaporkan `pointingSigmaDeg (di calibrationReady)` dan
    /// `sentAt (di calibrationReady)` sebagai medan yang dikirim jam tetapi
    /// tidak pernah sampai ke laporan: bagian kalibrasi menulis tiga baris
    /// kalibrasi dan berhenti, jadi dua medan yang **selalu** ikut di pesan
    /// kalibrasi tidak punya baris sama sekali. Konsekuensinya bukan
    /// kosmetik — pembaca iPhone tidak bisa tahu σ berapa yang dipakai jam
    /// saat kalibrasi itu dihasilkan, dan itu justru angka yang membuat
    /// kalibrasinya bisa dinilai.
    ///
    /// **Kapan keduanya muncul.** σ hanya bila ada (`confidencePolicy`
    /// menolak σ ≤ 0 atau tak berhingga — lihat `stateRows`), sehingga
    /// ketiadaannya tidak tercetak sebagai akurasi sempurna. Waktu selalu
    /// muncul: keduanya adalah pesan yang benar-benar terkirim.
    private static func sigmaAndTimeRows(_ message: PointingLinkMessage) -> [Row] {
        var rows: [Row] = []
        if let sigma = message.confidencePolicy?.pointingSigmaDeg {
            rows.append(Row(title: TextLocalization.text(.linkRowSigma),
                            value: NumberFormat.degrees(sigma)))
        }
        rows.append(Row(title: TextLocalization.text(.linkRowTime),
                        value: message.sentAt.formatted(date: .omitted, time: .standard)))
        return rows
    }

    /// Arah tunjuk dalam bentuk satu kalimat: `"42,5° / 118,0°"`.
    ///
    /// Urutannya **ketinggian lalu azimut**, dan urutan itu disebut di judul
    /// barisnya lewat `link.row.direction` — tanpa itu dua angka bersebelahan
    /// tidak bisa dibedakan mana yang mana.
    public static func directionText(altitudeDeg: Double,
                                     azimuthDeg: Double) -> String {
        NumberFormat.degrees(altitudeDeg) + " / " + NumberFormat.degrees(azimuthDeg)
    }
}
