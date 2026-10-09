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

    @StateObject private var guide = SkyGuideModel()
    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSky = false

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
            .onChange(of: engine.location) { _, _ in guide.refresh(engine: engine, force: true) }
            .onAppear {
                engine.setSkyQuality(SkyQualityStorage.quality(darkSky: darkSky))
                #if DEBUG
                link.injectDebugConfirmationIfRequested()
                #endif
            }
        }
        .appBackground()
        .forceDarkScheme()
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
