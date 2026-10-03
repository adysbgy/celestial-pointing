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
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Minta keadaan terakhir") { link.requestState() }
                }

                Section("Keadaan terakhir dari jam") {
                    if let state = link.lastState {
                        row("Keadaan", state.state?.shortLabel ?? "—")
                        row("Objek", state.objectName ?? "—")
                        row("Keyakinan", state.level?.displayName ?? "—")
                        if let rate = state.angularRateDegPerSec {
                            row("Laju", String(format: "%.1f°/dtk", rate))
                        }
                        row("Waktu", state.sentAt.formatted(date: .omitted, time: .standard))
                        if let note = state.note {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Belum ada keadaan dari jam.")
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sampel dari jam") {
                    let fromWatch = trace.samples.filter(\.fromWatch)
                    row("Terekam", "\(fromWatch.count)")
                    Text("Sampel dari jam tidak membawa jarak kandidat, jadi rasionya terhadap σ kosong. Yang bisa dilihat dari sini adalah keadaan dan keyakinan yang dilaporkan jam.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tautan")
            .onAppear { link.activate() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
