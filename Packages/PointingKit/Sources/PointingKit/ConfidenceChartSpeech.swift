import CelestialEngine

/// Ringkasan verbal grafik keyakinan, untuk VoiceOver.
///
/// Grafik confidence adalah **satu-satunya** `Chart` di app. Swift Charts tidak
/// memberi deskripsi otomatis yang berguna: yang bisa disimpulkan hanya
/// setiap titik satu per satu, dan pembaca layar tidak akan pernah menarik garis dari
/// sana. Sementara itu setiap elemen data lain di `DiagnosticsView` punya
/// pengumuman (`RowSpeech`, `visualPanelLabel`), jadi tanpa unit ini grafik ini
/// adalah **satu-satunya bagian layar itu yang diam** — dan justru bagian yang
/// paling sering dipakai untuk menilai apakah ambangnya sedang dilanggar.
///
/// Karena itu bentuknya bukan daftar angka, melainkan **kesimpulan**: berapa
/// sampel jatuh di tiap pita ambang. Angka mentah sudah tersedia di ekspor, dan
/// membacanya satu per satu tidak menghasilkan informasi apa pun.
///
/// **Kenapa di `PointingKit`, bukan di view.** Tiga aturan yang tidak bisa
/// dijaga di view: pita ambang harus sama dengan yang dipakai engine
/// (`policy`, bukan nilai bawaan), titik tepat di ambang harus dihitung dengan
/// operator yang sama dengan `uncertainReason`, dan kalimatnya harus disusun
/// dari kunci katalog. Kalau salah satu ditulis ulang di `DiagnosticsView`,
/// ringkasan suara dan keputusan engine bisa berbeda pendapat tanpa ada yang
/// melihatnya.
public struct ConfidenceChartSpeech: Equatable, Sendable {

    /// Sampel dengan jarak terukur, di bawah atau tepat pada batas yakin.
    public let confident: Int
    /// Sampel terukur yang melewati batas yakin tapi belum melewati batas pasti.
    public let middle: Int
    /// Sampel terukur yang melewati `maxSeparationSigma` — yang ditolak engine
    /// dengan sebab `tooFar`.
    public let tooFar: Int
    /// Sampel yang tercatat tapi jarak kandidatnya tidak terukur.
    public let unmeasured: Int
    /// Total rekaman, **termasuk** sampel tanpa jarak terukur.
    public let total: Int

    /// Sampel yang punya jarak terukur, yaitu jumlah ketiga pita.
    public var measured: Int { confident + middle + tooFar }

    /// Ringkasan satu kalimat, dalam urutan tetap.
    ///
    /// Urutannya disengaja: jumlah terukur dulu — pembaca layar perlu tahu
    /// ada data sebelum ditanya), lalu pita dari paling optimistis ke paling
    /// pesimis, lalu sisanya. Ketiga pita disebut **walaupun nol**, karena
    /// "tidak ada yang di antara dua batas" adalah informasi: itu yang biasanya
    /// ingin diketahui penguji saat engine menolak karena ambiguitas katalog,
    /// bukan karena jarak.
    public var spokenSummary: String {
        var parts: [String] = [
            TextLocalization.text(.chartSpeechMeasuredCount, Int64(measured))
        ]
        parts.append(TextLocalization.text(.chartSpeechBandConfident, Int64(confident)))
        parts.append(TextLocalization.text(.chartSpeechBandMiddle, Int64(middle)))
        parts.append(TextLocalization.text(.chartSpeechBandTooFar, Int64(tooFar)))
        if unmeasured > 0 {
            parts.append(TextLocalization.text(.chartSpeechUnmeasuredCount,
                                              Int64(unmeasured)))
        }
        return parts.joined(separator: " ")
    }

    /// Ketiga pita dari rasio yang sudah terukur.
    ///
    /// Shortcut untuk sumber yang sudah punya rasionya. `nil` kalau tidak ada
    /// satu pun rasio terukur: lalu **tidak ada yang boleh diucapkan**, dan
    /// mengembalikan `nil` lebih jujur daripada kalimat berisi nol-nol yang
    /// akan terbaca sebagai elemen yang sudah terbaca tapi tidak bermakna.
    public static func ratios(_ ratios: [Double],
                               policy: ConfidencePolicy = ConfidencePolicy()) -> ConfidenceChartSpeech? {
        let measured = ratios.filter { $0.isFinite }
        guard !measured.isEmpty else { return nil }
        return ConfidenceChartSpeech(samples: measured.map { Optional($0) }, policy: policy)
    }

    /// Bentuk dari sampel rekaman, lengkap dengan yang tidak terukur.
    ///
    /// **Kenapa `total` menghitung semuanya, bukan hanya yang terukur.**
    /// `ratioToSigma == nil` berarti sigma-nya nol atau tidak ada kandidat —
    /// kurucut grafik memang tidak bisa menggambarnya, sehingga menyebut
    /// "3 dari 5" akan terbaca seperti "3 dari 3". Itu kelas kesalahan yang
    /// paling berbahaya di layar diagnostik: jumlah yang terlihat lengkap
    /// padahal ada rekaman yang tidak terhitung.
    ///
    /// **Batas kedua pita adalah `ambiguitySigma`, dan itu keputusan yang
    /// sengaja diambil.** Di engine ambang itu membandingkan kandidat ke
    /// **tetangganya**, jadi maknanya berbeda dari jarak ke kandidat terbaik —
    /// tapi grafik **menggambarkannya sebagai garis horizontal** di sumbu yang
    /// sama, berlabel "batas ambigu".
    ///
    /// Kalau ringkasan suara memakai batas kedua yang lain (mis. dua kali
    /// `maxSeparationSigma`), maka dua penyajian dari data yang sama akan
    /// berbeda: mata menghitung pita dari garis yang benar-benar tergambar,
    /// telinga menghitung dari garis yang tidak ada. Untuk pembaca layar itu
    /// berarti "2 sampel terlalu jauh" sementara tidak ada satu pun titik pun
    /// melewati garis yang sedang dia lihat. Yang lebih buruk: pembaca itu
    /// tidak bisa menghitung batas yang tidak ada di layar.
    ///
    /// Jadi pita di sini **meniru garis yang tergambar**, dan ambangnya tetap
    /// dibaca dari `policy` yang berlaku — bukan nilai bawaan. Bedanya dengan
    /// `uncertainReason` dicatat di sini, bukan disembunyikan: pita "terlalu
    /// jauh" di sini berarti "di atas garis kedua", sementara
    /// `uncertainReason.tooFar` berarti "di atas `maxSeparationSigma`". Keduanya
    /// benar untuk pertanyaan yang berbeda, dan kalimat yang diucapkan
    /// sengaja menjawab pertanyaan yang sedang dijawab grafik.
    public init(samples: [Double?], policy: ConfidencePolicy = ConfidencePolicy()) {
        let certainLimit = policy.maxSeparationSigma
        // Batas kedua = garis kedua yang benar-benar tergambar di grafik.
        let farLimit = max(policy.ambiguitySigma, certainLimit)
        var confident = 0
        var middle = 0
        var tooFar = 0
        var unmeasured = 0
        for ratio in samples {
            guard let ratio, ratio.isFinite else {
                unmeasured += 1
                continue
            }
            // `>` dan bukan `>=`, sama persis dengan
            // `ConfidenceTrace.uncertainReason`: `maxSeparationSigma` adalah
            // batas **tolak**, sehingga titik tepat di ambang masih diterima.
            // Kalau ambang pita memakai `>=`, ringkasan suara akan
            // menyimpulkan "tidak yakin" untuk sampel yang engine terus terima
            // — dan selisihnya cuma satu sampel, jadi tak akan terlihat mata.
            if ratio > farLimit {
                tooFar += 1
            } else if ratio > certainLimit {
                middle += 1
            } else {
                confident += 1
            }
        }
        self.confident = confident
        self.middle = middle
        self.tooFar = tooFar
        self.unmeasured = unmeasured
        self.total = samples.count
    }
}