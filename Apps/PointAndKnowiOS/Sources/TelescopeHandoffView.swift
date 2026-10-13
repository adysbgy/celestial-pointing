import SwiftUI
import CelestialEngine
import PointingKit

/// Serah-terima teleskop: **bentuk koordinat apa yang akan dikirim ke mount**.
///
/// **Kenapa layar ini ada.** `TelescopeBridge` (dokumen §17–§20) sudah
/// menerjemahkan putusan GoTo yang **sudah** lolos uji aman menjadi perintah
/// motor: sumbu mana, kerangka koordinat mana, dan penolakan apa yang terjadi
/// kalau mount tidak bisa menerimanya. Seluruh logika itu teruji di Linux — dan
/// **nol pemanggil di seluruh `Apps/`**. Gerbang keselamatan yang tidak punya
/// wajah adalah gerbang yang tidak bisa diperiksa siapa pun saat berada di
/// lapangan, dan kelas cacat ini sudah dua kali tercatat di repo ini
/// (`slewDecision`, `Resolution.rejected`): dihitung, benar, dan tidak pernah
/// sampai ke layar.
///
/// **Yang TIDAK diklaim layar ini.**
/// - Ia tidak menyambung ke teleskop mana pun. Belum ada transport (§18
///   menuntut POC di Seestar fisik), jadi tidak ada perintah yang benar-benar
///   dikirim — dan karena itu tidak ada satu pun baris di sini yang boleh
///   dibaca sebagai "teleskop sudah bergerak".
/// - Ia tidak memutuskan boleh/tidak. Ia meneruskan putusan `SlewPlanner` dan
///   terjemahan `TelescopeBridge` apa adanya; kalau gerbangnya menolak, layar
///   hanya bisa menampilkan penolakan itu, bukan melunakkannya.
/// - Profil mount di bawah adalah **profil contoh** (mount ekuatorial, kerangka
///   J2000, bisa Abort). Angka itu menggambarkan perangkat yang belum
///   terhubung; yang benar datang dari `TelescopeTransport` saat perangkat
///   nyata ada.
///
/// **Kenapa sudut pergelangan tidak pernah muncul di sini.** Aturan keras PRD:
/// sudut pergelangan tidak pernah menjadi gerak motor. Yang ditampilkan hanya
/// target hasil identifikasi objek (`TelescopeCommand.target` adalah arah
/// objek, bukan arah tunjuk jam), dan `TelescopeCommand` sengaja tidak punya
/// inisialisator publik supaya tidak ada jalur lain membuatnya.
struct TelescopeHandoffSection: View {

    /// Engine yang berjalan — sumber putusan GoTo dan lokasi pengamat.
    @ObservedObject var engine: PointingEngine

    /// Profil mount yang dipakai untuk menerjemahkan.
    ///
    /// Satu tempat, bukan literal di dalam `body`: mount nyata menggantinya
    /// lewat `TelescopeTransport` (§17 — logika produk tidak boleh tahu
    /// mereknya), dan selama belum ada perangkat, nilai ini yang jujur
    /// menggambarkan apa yang **akan** diminta.
    private let capability = TelescopeCapability(
        axes: .equatorial,
        supportedFrames: [.j2000],
        firmwareVersion: "—",
        canAbort: true)

    /// Kerangka yang diminta untuk mount ekuatorial — **dinyatakan**, sama
    /// dengan bawaan `TelescopeBridge`. Mount yang memakai of-date cukup
    /// memberi tahu lewat parameter itu; mount yang tidak mendukungnya
    /// ditolak terang-terangan, bukan diam-diam dikonversi.
    private let preferredFrame: CoordinateFrame = .j2000

    var body: some View {
        Section(TextLocalization.text(.telescopeSectionTitle)) {
            capabilityRows
            targetRows
        }
    }

    // MARK: - Kemampuan mount

    @ViewBuilder
    private var capabilityRows: some View {
        row(TextLocalization.text(.telescopeMountLabel), axisName)
        if capability.axes == .equatorial {
            row(TextLocalization.text(.telescopeFrameLabel), preferredFrame.name)
        }
        row(TextLocalization.text(.telescopeFirmwareLabel), capability.firmwareVersion)
        row(TextLocalization.text(.telescopeAbortCapabilityLabel),
            capability.canAbort
            ? TextLocalization.text(.telescopeAbortCapabilityYes)
            : TextLocalization.text(.telescopeAbortCapabilityNo))
    }

    private var axisName: String {
        switch capability.axes {
        case .equatorial:
            return TextLocalization.text(.telescopeAxisEquatorial)
        case .altitudeAzimuth:
            return TextLocalization.text(.telescopeAxisAltAz)
        }
    }

    // MARK: - Target perintah

    @ViewBuilder
    private var targetRows: some View {
        // Dibaca sekali supaya `decision` dan `result` tidak bisa memutuskan
        // dari dua sumber yang berbeda.
        if let decision = engine.slewVerdict {
            let result = bridge.command(for: decision,
                                        observer: engine.location.observer,
                                        date: Date())
            switch result {
            case .success(let command):
                row(TextLocalization.text(.telescopeTargetLabel), command.objectName)
                Text(TelescopeDisplay.coordinateLine(for: command.target))
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            case .failure(let error):
                rejectedRows(for: error, decision: decision)
            }
        } else {
            Text(TextLocalization.text(.telescopeAwaitingObjectNote))
                .font(.footnote)
                .foregroundStyle(Color.nightAwareSecondary)
        }
    }

    @ViewBuilder
    private func rejectedRows(for error: TelescopeBridgeError,
                              decision: SlewDecision) -> some View {
        Text(TextLocalization.text(.telescopeRejectedTitle))
            .font(.headline)
            .foregroundStyle(PointingTone.warning.color)
        // Sebabnya ditampilkan lewat dua jalur yang sudah ada dan teruji:
        // kalimat bahaya dari `SlewVerdictBanner` (katalog, diuji di Linux) dan
        // keterangan khusus mount yang tidak bisa Abort. Yang **tidak**
        // dilakukan di sini adalah mengarang kalimat untuk
        // `.unsupportedAxis`/`.unsupportedFrame`/`.targetHasNoPosition` —
        // ketiganya belum punya kunci katalog, dan kalimat yang lahir di view
        // persis kelas yang ditutup Aturan 12.
        //
        // Banner menampilkan apa pun sendiri: saat putusannya `.allowed` (jadi
        // penolakannya soal kemampuan mount, bukan soal bahaya) `verdictText`
        // bernilai `nil` dan ia tidak menggambar apa-apa — bukan "aman", hanya
        // tidak ada bahaya yang perlu diterangkan.
        SlewVerdictBanner(decision: decision, padding: 8)
        if case .mountCannotAbort = error {
            Text(TextLocalization.text(.telescopeMountCannotAbort))
                .font(.footnote)
                .foregroundStyle(PointingTone.warning.color)
        }
        Text(TextLocalization.text(.telescopeRejectedNote))
            .font(.footnote)
            .foregroundStyle(Color.nightAwareSecondary)
    }

    // MARK: - Jembatan

    /// Jembatan yang dipakai layar ini.
    ///
    /// **Kenapa dibuat ulang tiap akses, bukan disimpan.** `PointingResolver`
    /// yang dipakai adalah milik engine yang sedang berjalan — termasuk
    /// efemeris dan ambang keyakinannya. Menyimpan salinan berarti layar bisa
    /// menerjemahkan dengan resolver yang berbeda dari yang menghitung
    /// putusannya, dan perbedaan itu tidak akan terlihat di layar mana pun.
    private var bridge: TelescopeBridge {
        TelescopeBridge(resolver: engine.controller.resolver,
                        capability: capability,
                        preferredFrame: preferredFrame)
    }

    // MARK: - Baris

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Color.nightAwareSecondary)
        }
        // Baris "judul … nilai" digabung jadi **satu** pengumuman, sama seperti
        // `LinkView` dan `SkyContextView` — kalimatnya dari `RowSpeech`, supaya
        // ketiga layar tidak punya tiga versi aturan pengumuman.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }
}
