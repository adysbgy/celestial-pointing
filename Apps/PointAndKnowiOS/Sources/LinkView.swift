import SwiftUI
import CelestialEngine
import PointingKit

/// Status tautan ke jam, dan apa yang terakhir dilaporkan jam.
///
/// Berguna saat pengujian lapangan: kalau jam dan iPhone tidak terhubung,
/// rekaman Experiment 1 di iPhone tetap sah (iPhone memakai sensornya sendiri),
/// tapi angka "dari jam" tidak akan pernah muncul. Layar ini membuat perbedaan
/// itu terlihat alih-alih diam-diam mengosongkan data.
struct LinkView: View {

    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore

    var body: some View {
        NavigationStack {
            List {
                Section("Tautan") {
                    row("Status", link.isActivated ? "Aktif" : "Belum aktif")
                    row("Terjangkau", link.isReachable ? "Ya" : "Tidak")
                    row("Pesan diterima", "\(link.receivedCount)")
                    if let note = link.lastNote {
                        Text(note).font(.footnote).foregroundStyle(Color.nightAwareSecondary)
                    }
                    Button("Minta keadaan terakhir") { link.requestState() }
                }

                Section("Keadaan terakhir dari jam") {
                    if let state = link.lastState {
                        row("Keadaan", state.state?.shortLabel ?? "—")
                        row("Objek", state.objectName ?? "—")
                        row("Keyakinan", state.level?.displayName ?? "—")
                        if let rate = state.angularRateDegPerSec {
                            // Nilainya ditulis "0.5°/dtk" untuk mata; yang
                            // diucapkan bentuk katanya. Dua-duanya dari
                            // angka yang sama — tidak ada versi kedua yang
                            // bisa menyimpang.
                            row("Laju", String(format: "%.1f°/dtk", rate))
                                .accessibilityLabel(RowSpeech.spokenRow(
                                    title: "Laju",
                                    spokenValue: RowSpeech.spokenRate(rate)))
                        }
                        row("Waktu", state.sentAt.formatted(date: .omitted, time: .standard))
                        if let note = state.calibrationNoteText ?? state.note {
                            Text(note).font(.footnote).foregroundStyle(Color.nightAwareSecondary)
                        }
                    } else {
                        Text("Belum ada keadaan dari jam.")
                            .foregroundStyle(Color.nightAwareSecondary)
                    }
                }

                Section("Kalibrasi terakhir dari jam") {
                    if let calibration = link.lastCalibration {
                        row("Offset yaw",
                            calibration.yawOffsetDeg.map { String(format: "%.1f°", $0) } ?? "—")
                        row("Sebaran",
                            calibration.residualSpreadDeg.map { String(format: "%.1f°", $0) } ?? "—")
                        row("Jumlah acuan", calibration.sampleCount.map(String.init) ?? "—")
                    } else {
                        Text("Jam belum melaporkan kalibrasi.")
                            .foregroundStyle(Color.nightAwareSecondary)
                    }
                }

                Section("Sampel dari jam") {
                    let fromWatch = trace.samples.filter(\.fromWatch)
                    row("Terekam", "\(fromWatch.count)")
                    Text("Sampel dari jam tidak membawa jarak kandidat, jadi rasionya terhadap σ kosong. Yang bisa dilihat dari sini adalah keadaan dan keyakinan yang dilaporkan jam.")
                        .font(.footnote)
                        .foregroundStyle(Color.nightAwareSecondary)
                    if fromWatch.contains(where: { $0.sigmaDeg <= 0 }) {
                        // σ nol berarti jam tidak menyertakannya. Menampilkannya
                        // sebagai "0.0°" akan terbaca seperti akurasi sempurna.
                        Text("Sebagian sampel tidak menyertakan σ. Sigma yang tidak terukur ditulis 0, bukan angka bawaan — jangan dibaca sebagai akurasi sempurna.")
                            .font(.footnote)
                            .foregroundStyle(PointingTone.warning.color)
                    }
                }
            }
            .navigationTitle("Tautan")
            .scrollContentBackground(.hidden)
            .onAppear { link.activate() }
        }
        .appBackground()
        .forceDarkScheme()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(Color.nightAwareSecondary)
        }
        // Baris "judul … nilai" digabung jadi **satu** pengumuman.
        //
        // Tanpa ini VoiceOver membaca dua elemen tanpa hubungan: "Laju"
        // lalu "0.5°/dtk" — dan pada layar ini nilainya justru yang penting.
        // Kalimatnya dari `PointingKit` (`RowSpeech`), bukan dirangkai di
        // sini, supaya ketiga layar yang punya `row` identik tidak punya
        // tiga versi aturan pengumuman. Lihat juga `SkyContextView.row`.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(RowSpeech.label(title: title, value: value))
    }
}
