import CelestialEngine

/// Keputusan: **apakah pengumuman perlu dibunyikan**, dan nilai mana yang
/// harus diingat setelahnya.
///
/// **Kenapa keputusan ini pindah dari view ke sini.** Sampai giliran ini,
/// aturan "berbunyi hanya saat nilainya berubah" hidup sebagai tiga baris di
/// dalam `PointingView`, `RootView`, dan `CalibrationView`:
///
///     guard announcedStatus != newMessage else { return }
///     announcedStatus = newMessage
///     AccessibilityNotification.Announcement(newMessage).post()
///
/// Tiga baris itu tidak dijaga apa pun. `Apps/` tidak ikut `swift-test.sh`
/// (tes Linux tidak membangun SwiftUI), `swift-typecheck.sh` hanya `-parse`
/// (sintaks), dan `swift-ui-lint.sh` membaca teks — nol dari 73 aturannya
/// membaca guard pengumuman. Terukur pada salinan utuh repo, proses baru:
/// membalik `!=` menjadi `==` membuat **seluruh 73 aturan hijau**.
///
/// Akibatnya bukan sekadar "tidak berbunyi". Cuplikan keadaan ditulis 20 kali
/// per detik, jadi guard yang dibalik membalik **seluruh janji**: app diam
/// saat keadaan berubah (pengguna tidak pernah tahu lock berhasil), lalu
/// mengucapkan kalimat yang sama dua puluh kali per detik selama keadaan itu
/// bertahan — app tidak terpakai oleh pembaca layar sama sekali. Dan justru
/// keadaannya kebalikan di layar `CalibrationView`: di sana nilai yang
/// diumumkan adalah **hasil aksi** ("acuan tercatat", "kiriman gagal"), yang
/// berubah jarang — jadi guard yang dibalik di sana bermakna "bunyikan
/// ulang hasil yang sama tiap kali layar disegarkan dan ketika hasil baru
/// tidak pernah terdengar", dua-duanya salah.
///
/// **Batasnya.** Fungsi ini hanya memutuskan. Ia tidak memanggil
/// `AccessibilityNotification`, tidak tahu VoiceOver ada, dan tidak
/// memastikan suaranya sampai. Kesetiaan pada hasilnya di `Apps/` dijaga
/// Aturan 74 `swift-ui-lint.sh`; kebenaran keputusannya dijaga
/// `AnnouncementGateTests` di Linux.
public enum AnnouncementGate {

    /// Hasil satu langkah gerbang.
    public struct Step<T: Equatable & Sendable>: Equatable, Sendable {
        /// Apakah kalimat pengumuman perlu dibunyikan sekarang.
        public var shouldSpeak: Bool
        /// Nilai yang harus disimpan sebagai "sudah diumumkan".
        ///
        /// **Selalu** diisi `current`, termasuk saat tidak berbunyi. Kalau
        /// hanya disimpan ketika berbunyi, nilai pertama yang diam tidak akan
        /// pernah tercatat, dan perubahan berikutnya ke nilai yang sama akan
        /// berbunyi seolah nilai baru.
        public var remember: T?

        public init(shouldSpeak: Bool, remember: T?) {
            self.shouldSpeak = shouldSpeak
            self.remember = remember
        }
    }

    /// Langkah gerbang untuk satu nilai.
    ///
    /// - Parameters:
    ///   - announced: nilai yang terakhir diumumkan; `nil` = belum pernah.
    ///   - current: nilai sekarang.
    ///
    /// Aturannya tiga, dan ketiganya bertumpu pada satu alasan — pengumuman
    /// adalah kabar **peristiwa**, bukan pembacaan status berulang:
    ///
    /// 1. `announced == nil` -> **diam**. Peluncuran app bukan peristiwa;
    ///    mengumumkan "Siap" saat app baru dibuka hanya menunda pembacaan
    ///    isi layar, dan pengguna belum melakukan apa pun yang perlu
    ///    dikabarkan.
    /// 2. `announced == current` -> **diam**. Ini yang menjaga cuplikan
    ///    20 Hz dari menjadi 20 pengumuman per detik, dan isi layar yang
    ///    disegarkan berkala dari mengulang kalimat yang sama.
    /// 3. selain itu -> **berbunyi**. Inilah satu-satunya momen yang
    ///    ditunggu pengguna.
    ///
    /// Terhadap perbandingan: memakai `!=` di sini dan bukan `==` bukan
    /// pilihan gaya. Inilah persis mutasi yang lolos seluruh gerbang lama.
    ///
    /// Tipenya generik bukan karena fleksibilitas: layar jam mengawasi
    /// `PointingState` (Enumerasi `Equatable`), sedangkan layar kalibrasi
    /// mengawasi `String` status. Keduanya perlu keputusan yang sama, dan
    /// memakai fungsi terpisah berarti menulis gerbang yang sama dua kali.
    public static func step<T: Equatable & Sendable>(announced: T?,
                                                     current: T) -> Step<T> {
        guard let announced else {
            return Step(shouldSpeak: false, remember: current)
        }
        return Step(shouldSpeak: announced != current, remember: current)
    }
}
