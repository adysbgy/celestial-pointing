import SwiftUI
import CelestialEngine
import PointingKit

/// Tab pertama iPhone (ADR-013): padanan alur jam yang baru.
///
/// Jam adalah alat penunjuk; iPhone adalah tempat melihat hasilnya dengan
/// lega. Tiga hal, dari atas: benda yang terakhir dikonfirmasi di jam (besar,
/// dengan arah sekarang), lalu langit — "Masih siang" + kapan gelap + malam
/// ini, atau "Terlihat sekarang" dengan arah dan ketinggian tiap benda — lalu
/// sakelar langit kota/gelap yang sama dengan jam.
struct SkyHomeView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var stellarium: StellariumBridge

    @StateObject private var guide = SkyGuideModel()
    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSky = false
    @AppStorage(StellariumBridge.enabledKey) private var stellariumOn = false
    @AppStorage(StellariumBridge.addressKey) private var stellariumAddress = String()

    var body: some View {
        NavigationStack {
            List {
                Section(IdentificationText.phoneConfirmedTitle) { confirmedCard }
                if guide.isDark {
                    Section(WatchHomeText.visibleNow) {
                        ForEach(guide.visible) { targetRow($0) }
                    }
                } else {
                    Section {
                        dayHeader
                        ForEach(guide.tonight) { targetRow($0) }
                    } header: {
                        Text(WatchHomeText.tonight)
                    }
                }
                if !guide.phenomena.isEmpty {
                    Section(PhenomenonText.sectionTitle) {
                        ForEach(guide.phenomena.prefix(8)) { phenomenonRow($0) }
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
                            .foregroundStyle(stellarium.status == .connected
                                             ? PointingTone.success.color : Color.nightAwareSecondary)
                    }
                } header: {
                    Text(StellariumText.title)
                } footer: {
                    Text(StellariumText.hint)
                }
                Section {
                    Toggle(isOn: $darkSky) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WatchHomeText.darkSky)
                            Text(WatchHomeText.darkSkyHint)
                                .font(.footnote)
                                .foregroundStyle(Color.nightAwareSecondary)
                        }
                    }
                }
            }
            .fontDesign(.rounded)
            .navigationTitle(WatchHomeText.skyTab)
            .scrollContentBackground(.hidden)
            .task {
                while !Task.isCancelled {
                    guide.refresh(engine: engine)
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .onChange(of: darkSky) { _, dark in
                engine.setSkyQuality(SkyQualityStorage.quality(darkSky: dark))
                guide.refresh(engine: engine, force: true)
            }
            .onChange(of: engine.location) { _, _ in
                guide.refresh(engine: engine, force: true)
                // Lokasi sungguhan datang belakangan: Stellarium harus ikut.
                stellarium.updateLocation(engine.controller.observer)
            }
            .onChange(of: stellariumOn) { _, _ in applyStellarium() }
            .onAppear {
                engine.setSkyQuality(SkyQualityStorage.quality(darkSky: darkSky))
                applyStellarium()
                #if DEBUG
                link.injectDebugConfirmationIfRequested()
                #endif
            }
        }
        .appBackground()
        .forceDarkScheme()
    }

    // MARK: Stellarium

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

    // MARK: Kartu dikonfirmasi

    @ViewBuilder
    private var confirmedCard: some View {
        if let confirmed = link.lastConfirmed, let id = confirmed.message.objectID,
           let object = engine.controller.resolver.object(forID: id, observer: engine.controller.observer,
                                                         date: Date()) {
            HStack(spacing: 14) {
                CelestialVisualView(visual: CelestialVisual(object: object), diameter: 72, isConfirmed: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.name)
                        .font(.title.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(WatchHomeText.subtitle(object))
                        .font(.subheadline)
                        .foregroundStyle(Color.nightAwareSecondary)
                    if let h = engine.controller.resolver.horizontal(ofObjectID: id,
                                                                     observer: engine.controller.observer,
                                                                     date: Date()) {
                        Label(SkyRowText.whereToLook(h), systemImage: "safari")
                            .font(.footnote)
                    }
                    Text(verbatim: IdentificationText.phoneConfirmedTime(confirmed.message.sentAt,
                                                                         live: confirmed.live))
                        .font(.caption)
                        .foregroundStyle(Color.nightAwareSecondary)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(IdentificationText.phoneNothingConfirmed)
                    .font(.headline)
                Text(WatchHomeText.confirmHint)
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Langit

    private var dayHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.title)
                .symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(WatchHomeText.dayTitle).font(.headline)
                Text(guide.darkAt.map { WatchHomeText.darkAt($0) } ?? WatchHomeText.dayNoDark)
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func phenomenonRow(_ p: Phenomenon) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(PhenomenonText.title(p)).font(.body.weight(.semibold))
            Text(PhenomenonText.when(p.date))
                .font(.footnote)
                .foregroundStyle(Color.nightAwareSecondary)
            HStack(spacing: 6) {
                Label(PhenomenonText.visibility(p), systemImage: p.visibilitySymbol)
                if let detail = PhenomenonText.detail(p) {
                    Text(detail)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.nightAwareSecondary)
            if p.requiresSolarFilter {
                Label(PhenomenonText.solarFilter, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(PointingTone.warning.color)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func targetRow(_ target: PointingTarget) -> some View {
        HStack(spacing: 12) {
            Image(systemName: target.kind.guideSymbol)
                .foregroundStyle(PointingTone.active.color)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(target.name).font(.body.weight(.semibold))
                Text(SkyRowText.whereToLook(target.direction))
                    .font(.footnote)
                    .foregroundStyle(Color.nightAwareSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
