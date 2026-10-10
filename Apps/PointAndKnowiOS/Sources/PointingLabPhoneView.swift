import SwiftUI
import CelestialEngine
import PointingKit

/// Sisi iPhone Pointing Lab (ADR-004): menulis target manual untuk jam dan
/// menerima berkas percobaan. Analisis lengkap dilakukan di luar app; ringkasan
/// di sini hanya untuk memeriksa di lapangan bahwa datanya masuk akal.
struct PointingLabPhoneView: View {
    @ObservedObject var link: PhoneLinkService

    @AppStorage("pointingLab.phoneTargets") private var storedTargets = Data()
    @State private var name = ""
    @State private var bearing = ""
    @State private var elevation = ""
    @State private var sentTargets: Bool?

    private var targets: [LabTarget] {
        (try? JSONDecoder().decode([LabTarget].self, from: storedTargets)) ?? []
    }

    private func save(_ list: [LabTarget]) {
        storedTargets = (try? JSONEncoder().encode(list)) ?? Data()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target manual") {
                    TextField("Nama penanda", text: $name)
                    TextField("Bearing dari Utara sebenarnya (°)", text: $bearing)
                        .keyboardType(.decimalPad)
                    TextField("Elevasi (°)", text: $elevation)
                        .keyboardType(.numbersAndPunctuation)
                    Button("Tambah target", action: addTarget)
                        .disabled(parsedTarget == nil)
                    ForEach(targets) { t in
                        Text(verbatim: PointingLabText.targetRow(t))
                    }
                    .onDelete { offsets in
                        var list = targets
                        list.remove(atOffsets: offsets)
                        save(list)
                    }
                    Button("Kirim target ke jam") {
                        sentTargets = link.send(labTargets: targets)
                    }
                    .disabled(targets.isEmpty)
                    if let sentTargets {
                        Image(systemName: sentTargets ? "checkmark.circle" : "xmark.circle")
                            .accessibilityLabel(sentTargets ? "Terkirim" : "Gagal terkirim")
                    }
                }
                Section("Berkas dari jam") {
                    if link.labFiles.isEmpty {
                        Text("Belum ada berkas")
                    }
                    ForEach(link.labFiles, id: \.self) { url in
                        LabFileRow(url: url)
                    }
                }
            }
            .navigationTitle("Lab Pointing")
            .onAppear { link.refreshLabFiles() }
            .refreshable { link.refreshLabFiles() }
        }
    }

    private var parsedTarget: LabTarget? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let b = Double(bearing.replacingOccurrences(of: ",", with: ".")),
              let e = Double(elevation.replacingOccurrences(of: ",", with: ".")),
              (-90...90).contains(e) else { return nil }
        return .manual(name: trimmed, bearingDeg: b, elevationDeg: e)
    }

    private func addTarget() {
        guard let t = parsedTarget else { return }
        save(targets.filter { $0.id != t.id } + [t])
        name = ""; bearing = ""; elevation = ""
    }
}

/// Satu berkas JSONL: jumlah percobaan dan galat sumbu yang dipakai di
/// kerangka berutara (median / P90 / P95).
private struct LabFileRow: View {
    let url: URL

    private var summary: String {
        guard let data = try? Data(contentsOf: url) else { return "?" }
        return PointingLabText.fileSummary(data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: url.lastPathComponent)
                .font(.footnote)
            Text(verbatim: summary)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            ShareLink(item: url) {
                Label("Ekspor", systemImage: "square.and.arrow.up")
            }
        }
    }
}
