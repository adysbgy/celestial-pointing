import SwiftUI
import WatchKit
import CelestialEngine
import PointingKit

/// Layar utama jam (ADR-010, Docs/WATCH_UX_SPEC.md).
///
/// Satu layar, satu tugas: **tunjuk → nama objek besar → "Ya, itu dia"**.
/// Semua yang teknis (σ, laju °/dtk, kerangka, keadaan tautan, Lab) pindah ke
/// Pengaturan. Stop teleskop tetap paling atas bila slew mungkin berjalan.
struct HomeView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var link: WatchLinkService
    @ObservedObject var location: LocationProvider
    @ObservedObject var telescope: TelescopeControlStore

    @State private var confirmation: WatchConfirmation?
    @State private var showResult = false

    private var outcome: IdentificationOutcome { .from(engine.snapshot) }

    var body: some View {
        NightAwareContainer {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 8) {
                        TelescopeStopBar(store: telescope)
                        hero
                        if engine.location.isFallback {
                            Label(WatchHomeText.approxLocation, systemImage: "location.slash")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            WatchSettingsView(engine: engine, motion: motion, link: link,
                                              location: location, telescope: telescope)
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(WatchHomeText.settings)
                    }
                }
                .navigationDestination(isPresented: $showResult) {
                    if confirmation != nil {
                        ResultView(engine: engine, link: link, telescope: telescope,
                                   confirmation: $confirmation) {
                            showResult = false
                        }
                    }
                }
            }
        } reduced: {
            ReducedLuminanceView(engine: engine)
        }
    }

    // MARK: Pahlawan per keadaan

    @ViewBuilder
    private var hero: some View {
        switch outcome {
        case .unavailable:
            StateHero(symbol: "sensor.tag.radiowaves.forward", title: WatchHomeText.unavailable, hint: nil)
        case .holdSteady:
            if engine.snapshot.state == .idle {
                StateHero(symbol: "scope", title: WatchHomeText.aimTitle, hint: WatchHomeText.aimHint)
            } else {
                StateHero(symbol: "hand.raised", title: WatchHomeText.holdStill, hint: nil)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        case .notSure:
            // Alasan yang sebenarnya bila engine tahu (mis. langit masih
            // terang), bukan saran umum "tunjuk lebih tepat".
            StateHero(symbol: engine.snapshot.searchHint == .daylight ? "sun.max" : "questionmark.circle",
                      title: WatchHomeText.notSureTitle,
                      hint: engine.snapshot.searchHint?.message ?? WatchHomeText.notSureHint)
        case .single(let object):
            VStack(spacing: 4) {
                if let visual = engine.visualForDisplayedObject {
                    CelestialVisualView(visual: visual, diameter: 44, isConfirmed: true)
                        .accessibilityHidden(true)
                }
                Text(object.name)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(WatchHomeText.subtitle(object))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    confirm(object)
                } label: {
                    Text(WatchHomeText.confirmShort)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PointingTone.success.color)
                .foregroundStyle(.black)
                // Ketuk dua kali mengonfirmasi tanpa menurunkan lengan.
                .handGestureShortcut(.primaryAction)
                .accessibilityLabel(IdentificationText.confirm(object.name))
            }
            .accessibilityElement(children: .contain)
        case .possibleMatches(let objects):
            VStack(spacing: 4) {
                Text(WatchHomeText.possibleTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                ForEach(objects, id: \.id) { object in
                    Button {
                        confirm(object)
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(object.name).font(.body.bold()).lineLimit(1)
                            Text(object.kind.displayName).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityLabel(IdentificationText.confirm(object.name))
                }
            }
        }
    }

    // MARK: Konfirmasi

    private func confirm(_ object: CelestialObject) {
        confirmation = WatchConfirmation(object: object, delivery: .sending)
        showResult = true
        // Konfirmasi sudah terjadi di jam (pencocokan lokal, luring): haptic
        // sekarang, bukan menunggu iPhone.
        WKInterfaceDevice.current().play(.success)
        link.live.confirm(objectID: object.id, name: object.name) { result in
            let delivery: WatchConfirmation.Delivery
            switch result {
            case .replied(let reply): delivery = reply.accepted ? .live : .failed
            case .recordedOnly: delivery = .recordedOnly
            case .failed: delivery = .failed
            }
            DispatchQueue.main.async {
                guard confirmation?.object == object else { return }
                confirmation?.delivery = delivery
                // GoTo hanya untuk objek yang diterima iPhone lewat kanal langsung.
                if delivery == .live { telescope.confirm(objectID: object.id) }
            }
        }
    }
}

/// Objek yang dikonfirmasi dan status kirimnya ke iPhone.
struct WatchConfirmation: Equatable {
    enum Delivery: Equatable { case sending, live, recordedOnly, failed }
    let object: CelestialObject
    var delivery: Delivery
}

/// Ikon besar + satu judul + satu baris petunjuk. Tanpa angka.
struct StateHero: View {
    let symbol: String
    let title: String
    let hint: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(PointingTone.active.color)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Setelah konfirmasi: nama, 2 fakta sederhana, status kirim, teleskop.
struct ResultView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var link: WatchLinkService
    @ObservedObject var telescope: TelescopeControlStore
    @Binding var confirmation: WatchConfirmation?
    let onPointAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                TelescopeStopBar(store: telescope)
                if let c = confirmation {
                    CelestialVisualView(visual: CelestialVisual(object: c.object), diameter: 52, isConfirmed: true)
                        .accessibilityHidden(true)
                    Text(c.object.name)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(WatchHomeText.subtitle(c.object))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let h = engine.controller.resolver.horizontal(ofObjectID: c.object.id,
                                                                      observer: engine.controller.observer,
                                                                      date: Date()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(WatchHomeText.altitude(h.altitudeDeg), systemImage: "arrow.up.forward")
                            Label(WatchHomeText.direction(azimuthDeg: h.azimuthDeg), systemImage: "safari")
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Label(deliveryText(c.delivery), systemImage: deliverySymbol(c.delivery))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TelescopeControlSection(store: telescope, objectName: c.object.name)
                }
                Button(IdentificationText.pointAgain) {
                    telescope.clearConfirmation()
                    confirmation = nil
                    onPointAgain()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func deliveryText(_ d: WatchConfirmation.Delivery) -> String {
        switch d {
        case .sending: return IdentificationText.sending
        case .live: return IdentificationText.deliveredLive
        case .recordedOnly: return IdentificationText.deliveredRecorded
        case .failed: return IdentificationText.deliveryFailed
        }
    }

    private func deliverySymbol(_ d: WatchConfirmation.Delivery) -> String {
        switch d {
        case .sending: return "arrow.up.circle"
        case .live: return "iphone"
        case .recordedOnly: return "tray.and.arrow.down"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

/// Pengaturan: semua yang tidak dibutuhkan untuk menunjuk dan mengenali.
struct WatchSettingsView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var motion: MotionLogger
    @ObservedObject var link: WatchLinkService
    @ObservedObject var location: LocationProvider
    @ObservedObject var telescope: TelescopeControlStore

    @AppStorage(NightModeStorage.key) private var nightMode = false
    @AppStorage(AudioCueStorage.key) private var audioCueEnabled = true
    private var linkSymbol: String { link.isReachable ? Self.symbolPhone : Self.symbolPhoneSlash }
    private static let symbolPhone = "iphone"
    private static let symbolPhoneSlash = "iphone.slash"

    /// Layar lama (lengkap, teknis) punya `NavigationStack` sendiri, jadi
    /// dibuka sebagai sheet, bukan didorong ke tumpukan ini.
    @State private var showTechnical = false

    var body: some View {
        List {
            Section {
                Toggle(WatchHomeText.nightMode, isOn: $nightMode)
                Toggle(WatchHomeText.soundOnLock, isOn: $audioCueEnabled)
                NavigationLink(TextLocalization.text(.calibrationTitle)) {
                    CalibrationView(engine: engine, motion: motion, link: link)
                }
                NavigationLink(WatchHomeText.skyAndLocation) {
                    SkyContextView(engine: engine)
                }
            }
            Section(WatchHomeText.phoneLink) {
                Label(link.isReachable
                      ? TextLocalization.text(.pointingLinkConnected)
                      : TextLocalization.text(.pointingLinkDisconnected),
                      systemImage: linkSymbol)
            }
            Section(WatchHomeText.developerSection) {
                Button(WatchHomeText.technicalDetails) { showTechnical = true }
                NavigationLink {
                    PointingLabView(engine: engine, motion: motion, link: link)
                } label: {
                    Text("Lab Pointing")
                }
                Text(verbatim: IdentificationText.sigmaLine(engine.controller.resolver.confidencePolicy))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(WatchHomeText.settings)
        .sheet(isPresented: $showTechnical) {
            PointingView(engine: engine, motion: motion, link: link,
                         location: location, telescope: telescope)
        }
    }
}
