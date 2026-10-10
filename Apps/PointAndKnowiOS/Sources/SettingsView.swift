import SwiftUI
import CelestialEngine
import PointingKit

/// Tab Pengaturan (ADR-019). Alat riset (Diagnostik, Experiment 1, Tautan,
/// Lab) tidak lagi menjadi tab utama — HIG: tab untuk tugas pengguna — tetapi
/// tetap ada di bagian Pengembang.
struct SettingsView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var location: LocationProvider
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var trace: ConfidenceTraceStore
    @ObservedObject var stellarium: StellariumBridge

    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSky = false
    @AppStorage(StellariumBridge.enabledKey) private var stellariumOn = false
    @AppStorage(StellariumBridge.addressKey) private var stellariumAddress = String()
    @AppStorage(OnboardingStorage.key) private var onboardingSeen = false
    @State private var tool: DeveloperTool?

    enum DeveloperTool: String, Identifiable { case diagnostics, experiment, link, lab; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            Form {
                Section(DesignText.settingsSky) {
                    Toggle(isOn: $darkSky) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WatchHomeText.darkSky)
                            Text(WatchHomeText.darkSkyHint).font(.footnote).foregroundStyle(DK.secondaryText)
                        }
                    }
                }
                Section {
                    Toggle(StellariumText.toggle, isOn: $stellariumOn)
                    if stellariumOn {
                        TextField(StellariumText.address, text: $stellariumAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .onSubmit(applyStellarium)
                        Text(stellariumStatus)
                            .font(.footnote)
                            .foregroundStyle(stellarium.status == .connected ? Color.green : DK.secondaryText)
                    }
                } header: {
                    Text(StellariumText.title)
                } footer: {
                    Text(StellariumText.hint)
                }
                Section(WatchHomeText.developerSection) {
                    Button { tool = .diagnostics } label: { Label("Diagnostik", systemImage: "chart.xyaxis.line") }
                    Button { tool = .experiment } label: { Label("Experiment 1", systemImage: "target") }
                    Button { tool = .link } label: { Label("Tautan", systemImage: "iphone.gen3.radiowaves.left.and.right") }
                    Button { tool = .lab } label: { Label("Lab", systemImage: "flask") }
                    Button(DesignText.obReplay) { onboardingSeen = false }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(WatchHomeText.settings)
            .onChange(of: darkSky) { _, dark in engine.setSkyQuality(SkyQualityStorage.quality(darkSky: dark)) }
            .onChange(of: stellariumOn) { _, _ in applyStellarium() }
            .sheet(item: $tool) { tool in
                switch tool {
                case .diagnostics:
                    DiagnosticsView(engine: engine, motion: motion, location: location, link: link, trace: trace)
                case .experiment:
                    Experiment1View(engine: engine, link: link)
                case .link:
                    LinkView(link: link, trace: trace)
                case .lab:
                    PointingLabPhoneView(link: link)
                }
            }
        }
        .fontDesign(.rounded)
        .appBackground()
        .forceDarkScheme()
    }

    private func applyStellarium() {
        stellarium.apply(enabled: stellariumOn, address: stellariumAddress, engine: engine)
    }

    private var stellariumStatus: String {
        switch stellarium.status {
        case .off: return StellariumText.hint
        case .connecting: return StellariumText.connecting
        case .connected: return StellariumText.connected
        case .failed(let reason): return StellariumText.failed(reason)
        }
    }
}
