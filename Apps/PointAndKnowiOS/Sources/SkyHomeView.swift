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
    @ObservedObject var journal: ObservationJournal

    @StateObject private var guide = SkyGuideModel()
    @State private var scene3D: Scene3DSheet?
    @State private var discovery: Ident?
    @State private var showConnection = false
    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSky = false
    @AppStorage(StellariumBridge.enabledKey) private var stellariumOn = false
    @AppStorage(StellariumBridge.addressKey) private var stellariumAddress = String()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ConnectionPill(link: link) { showConnection = true }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if link.connectionState.isReady {
                    Section {
                        LiveWatchCard(link: link, engine: engine, guide: guide)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    discoveryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
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
            }
            .fontDesign(.rounded)
            .navigationTitle(WatchHomeText.skyTab)
            .sheet(item: $scene3D) { sheet in Sky3DView(content: sheet.content, title: sheet.title) }
            .sheet(isPresented: $showConnection) { ConnectionSheet(link: link).presentationDetents([.medium, .large]) }
            .sheet(item: $discovery) { item in
                DiscoveryView(objectID: item.id, engine: engine, journal: journal,
                              isVisibleNow: guide.visible.contains { $0.id == item.id }, onExplore: {})
            }
            .scrollContentBackground(.hidden)
            .task {
                while !Task.isCancelled {
                    guide.refresh(engine: engine)
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .onChange(of: darkSky) { _, _ in guide.refresh(engine: engine, force: true) }
            .onChange(of: engine.location) { _, _ in
                guide.refresh(engine: engine, force: true)
                // Lokasi sungguhan datang belakangan: Stellarium harus ikut.
                stellarium.updateLocation(engine.controller.observer)
            }
            // Kartu langsung butuh aliran arah tunjuk dari jam selama tab ini tampil.
            .onDisappear { link.setMirrorDemand("live", false) }
            .onAppear {
                link.setMirrorDemand("live", true)
                engine.setSkyQuality(SkyQualityStorage.quality(darkSky: darkSky))
                stellarium.apply(enabled: stellariumOn, address: stellariumAddress, engine: engine)
                #if DEBUG
                link.injectDebugConfirmationIfRequested()
                if let id = UserDefaults.standard.string(forKey: "debugOpen3D"), scene3D == nil {
                    // Setelah peluncuran selesai: sheet yang diminta saat
                    // TabView baru tampil diabaikan diam-diam.
                    Task { try? await Task.sleep(for: .seconds(1.5)); open3D(id) }
                }
                if UserDefaults.standard.bool(forKey: "debugConnectionSheet") {
                    Task { try? await Task.sleep(for: .seconds(1.5)); showConnection = true }
                }
                if let id = UserDefaults.standard.string(forKey: "debugDiscovery"), discovery == nil {
                    Task { try? await Task.sleep(for: .seconds(1.5)); discovery = Ident(id: id) }
                }
                #endif
            }
        }
        .appBackground()
        .forceDarkScheme()
    }

    // MARK: Kartu penemuan (Figma: First Discovery, ADR-019)

    @ViewBuilder
    private var discoveryCard: some View {
        if let confirmed = link.lastConfirmed, let id = confirmed.message.objectID,
           let object = engine.controller.resolver.object(forID: id, observer: engine.controller.observer,
                                                         date: Date()) {
            Button { discovery = Ident(id: id) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        StarfieldBackground(seed: 5, count: 90)
                        if let content = Sky3DFactory.object(id, engine: engine) {
                            Sky3DCanvas(content: content, interactive: false)
                        } else {
                            CelestialVisualView(visual: CelestialVisual(object: object), diameter: 110, isConfirmed: true)
                        }
                    }
                    .frame(height: 220)
                    VStack(alignment: .leading, spacing: 6) {
                        StatusChip(text: journal.contains(objectID: id) ? DesignText.discAgain : DesignText.discFirst)
                        Text(object.name).font(.title.bold())
                        Text(verbatim: DesignText.kindLine(object.kind,
                             IdentificationText.phoneConfirmedTime(confirmed.message.sentAt, live: confirmed.live)))
                            .font(.subheadline)
                            .foregroundStyle(DK.secondaryText)
                        if let h = engine.controller.resolver.horizontal(ofObjectID: id,
                                                                         observer: engine.controller.observer,
                                                                         date: Date()) {
                            MonoCaption(text: WatchHomeText.altAz(h))
                        }
                        Label(DesignText.discDetails, systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DK.accent)
                            .padding(.top, 4)
                    }
                    .padding(16)
                }
                .background(DK.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 10) {
                ZStack {
                    StarfieldBackground(seed: 17, count: 70)
                    GlowingPoint(diameter: 16)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(DesignText.discLookUpTitle).font(.title3.bold())
                Text(DesignText.discLookUpBody)
                    .font(.subheadline)
                    .foregroundStyle(DK.secondaryText)
                    .multilineTextAlignment(.center)
                MonoCaption(text: DesignText.obLookupHint).padding(.bottom, 6)
            }
            .padding(12)
            .background(DK.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    // MARK: 3D (ADR-017)

    func open3D(_ id: String) {
        guard let content = Sky3DFactory.object(id, engine: engine),
              case .object(let spec) = content else { return }
        scene3D = Scene3DSheet(content: content, title: spec.name)
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
            if let content = Sky3DFactory.content(for: p, engine: engine) {
                Button(Scene3DText.view3D, systemImage: "cube.transparent") {
                    scene3D = Scene3DSheet(content: content, title: PhenomenonText.title(p))
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
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

/// Isi lembar 3D (ADR-017).
struct Scene3DSheet: Identifiable {
    let id = UUID()
    let content: Sky3DView.Content
    let title: String
}
