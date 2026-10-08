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

    /// Fitur Alpaca mati secara bawaan (ADR-008): tanpa dinyalakan, app tidak
    /// pernah menyentuh jaringan lokal.
    @AppStorage("telescope.alpaca.enabled") private var alpacaEnabled = false
    @AppStorage("telescope.alpaca.address") private var alpacaAddress = String()

    var body: some View {
        NavigationStack {
            List {
                // Objek yang dikonfirmasi di jam (ADR-007). Nama dibentuk ulang
                // dari id dengan bahasa iPhone, bukan nama kiriman jam.
                Section(IdentificationText.phoneConfirmedTitle) {
                    if let confirmed = link.lastConfirmed {
                        let id = confirmed.message.objectID ?? "—"
                        Text(verbatim: DisplayLabel.objectName(
                            forObjectID: id,
                            catalogue: Catalogue.brightStars + DeepSkyCatalogue.objects)
                             ?? confirmed.message.objectName ?? id)
                            .font(.title2.bold())
                        Text(verbatim: IdentificationText.phoneConfirmedTime(confirmed.message.sentAt,
                                                                             live: confirmed.live))
                            .font(.footnote)
                            .foregroundStyle(Color.nightAwareSecondary)
                    } else {
                        Text(IdentificationText.phoneNothingConfirmed)
                            .foregroundStyle(Color.nightAwareSecondary)
                    }
                }

                Section(TelescopeText.section) {
                    Toggle(TelescopeText.enableAlpaca, isOn: $alpacaEnabled)
                        .onChange(of: alpacaEnabled) { _, on in
                            if !on { link.useMockTelescope() }
                        }
                    if alpacaEnabled {
                        TextField(TelescopeText.address, text: $alpacaAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        Button(TelescopeText.connect) {
                            Task { await link.connectAlpaca(address: alpacaAddress) }
                        }
                        .disabled(alpacaAddress.isEmpty || link.telescopeLink == .connecting)
                    }
                    Text(telescopeStatus)
                        .font(.footnote)
                        .foregroundStyle(Color.nightAwareSecondary)
                }

                Section(TextLocalization.text(.linkSectionTitle)) {
                    row(TextLocalization.text(.linkRowStatus),
                        link.isActivated
                        ? TextLocalization.text(.linkValueActive)
                        : TextLocalization.text(.linkValueInactive))
                    row(TextLocalization.text(.linkRowReachable),
                        link.isReachable
                        ? TextLocalization.text(.linkValueYes)
                        : TextLocalization.text(.linkValueNo))
                    row(TextLocalization.text(.linkRowMessagesReceived), "\(link.receivedCount)")
                    if let note = link.lastNote {
                        Text(note).font(.footnote).foregroundStyle(Color.nightAwareSecondary)
                    }
                    Button(TextLocalization.text(.linkRequestState)) { link.requestState() }
                }

                Section(TextLocalization.text(.linkSectionLastState)) {
                    if let state = link.lastState {
                        row(TextLocalization.text(.linkRowState), state.state?.shortLabel ?? "—")
                        row(TextLocalization.text(.linkRowObject), state.objectName ?? "—")
                        row(TextLocalization.text(.linkRowConfidence), state.level?.displayName ?? "—")
                        if let rate = state.angularRateDegPerSec {
                            // Nilainya ditulis "0.5°/dtk" untuk mata; yang
                            // diucapkan bentuk katanya. Dua-duanya dari
                            // angka yang sama — tidak ada versi kedua yang
                            // bisa menyimpang.
                            row(TextLocalization.text(.linkRowRate), NumberFormat.degreesPerSecond(rate))
                                .accessibilityLabel(RowSpeech.spokenRow(
                                    title: TextLocalization.text(.linkRowRate),
                                    spokenValue: RowSpeech.spokenRate(rate)))
                        }
                        row(TextLocalization.text(.linkRowTime),
                            state.sentAt.formatted(date: .omitted, time: .standard))
                        if let note = state.calibrationNoteText ?? state.note {
                            Text(note).font(.footnote).foregroundStyle(Color.nightAwareSecondary)
                        }
                    } else {
                        Text(TextLocalization.text(.linkNoStateYet))
                            .foregroundStyle(Color.nightAwareSecondary)
                    }
                }

                Section(TextLocalization.text(.linkSectionLastCalibration)) {
                    if let calibration = link.lastCalibration {
                        row(TextLocalization.text(.linkRowYawOffset),
                            calibration.yawOffsetDeg.map { NumberFormat.degrees($0) } ?? "—")
                        row(TextLocalization.text(.linkRowSpread),
                            calibration.residualSpreadDeg.map { NumberFormat.degrees($0) } ?? "—")
                        row(TextLocalization.text(.linkRowReferenceCount),
                            calibration.sampleCount.map(String.init) ?? "—")
                    } else {
                        Text(TextLocalization.text(.linkNoCalibrationYet))
                            .foregroundStyle(Color.nightAwareSecondary)
                    }
                }

                Section(TextLocalization.text(.linkSectionSamples)) {
                    let fromWatch = trace.samples.filter(\.fromWatch)
                    row(TextLocalization.text(.linkRowRecorded), "\(fromWatch.count)")
                    Text(TextLocalization.text(.linkSamplesNote))
                        .font(.footnote)
                        .foregroundStyle(Color.nightAwareSecondary)
                    if fromWatch.contains(where: { $0.sigmaDeg <= 0 }) {
                        // σ nol berarti jam tidak menyertakannya. Menampilkannya
                        // sebagai "0.0°" akan terbaca seperti akurasi sempurna.
                        Text(TextLocalization.text(.linkSigmaMissingNote))
                            .font(.footnote)
                            .foregroundStyle(PointingTone.warning.color)
                    }
                }
            }
            .navigationTitle(TextLocalization.text(.linkSectionTitle))
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

    private var telescopeStatus: String {
        switch link.telescopeLink {
        case .mock: return TelescopeText.stateMock
        case .connecting: return TelescopeText.stateConnecting
        case .connected(let mount): return TelescopeText.stateConnected(mount.equatorialSystem)
        case .unsupported: return TelescopeText.stateUnsupported
        case .failed: return TelescopeText.stateFailed
        }
    }
}
