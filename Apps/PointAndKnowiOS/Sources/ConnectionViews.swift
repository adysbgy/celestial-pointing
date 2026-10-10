import SwiftUI
import PointingKit

/// Pil status sambungan di atas tab Langit (ADR-020): satu baris yang selalu
/// menjawab "apakah jam saya tersambung?". Ketuk untuk detail.
struct ConnectionPill: View {
    @ObservedObject var link: PhoneLinkService
    let action: () -> Void

    var body: some View {
        let state = link.connectionState
        Button(action: action) {
            HStack(spacing: 10) {
                ConnectionGlyph(isLive: state.isLive, isReady: state.isReady)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title).font(.subheadline.weight(.semibold))
                    Text(state.detail())
                        .font(.caption)
                        .foregroundStyle(DK.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(DK.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(DK.card))
            .overlay(Capsule().stroke(DK.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(ConnectionText.title)
    }
}

/// Jam ⇄ iPhone dengan titik yang berdenyut saat data mengalir langsung.
struct ConnectionGlyph: View {
    let isLive: Bool
    let isReady: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "applewatch")
            Image(systemName: isLive ? "dot.radiowaves.left.and.right" : (isReady ? "ellipsis" : "xmark"))
                .font(.caption2)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isLive && !reduceMotion)
            Image(systemName: "iphone")
        }
        .foregroundStyle(isLive ? Color.green : (isReady ? Color.orange : DK.secondaryText))
        .accessibilityHidden(true)
    }
}

/// Lembar detail sambungan: keadaan besar, daftar langkah, yang tersinkron,
/// dan cara menyambungkan (ADR-020).
struct ConnectionSheet: View {
    @ObservedObject var link: PhoneLinkService

    var body: some View {
        let state = link.connectionState
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        ConnectionGlyph(isLive: state.isLive, isReady: state.isReady)
                            .font(.largeTitle)
                            .padding(.top, 8)
                        Text(state.title).font(.title2.bold())
                        Text(state.detail())
                            .font(.subheadline)
                            .foregroundStyle(DK.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    step(ConnectionText.stepPaired, done: link.isPaired)
                    step(ConnectionText.stepInstalled, done: link.isWatchAppInstalled)
                    step(ConnectionText.stepOpen, done: link.isReachable)
                    HStack {
                        Label(ConnectionText.stepData, systemImage: "clock")
                        Spacer()
                        Text(link.lastContact.map { WatchConnectionState.relative($0, now: Date()) }
                             ?? ConnectionText.neverYet())
                            .foregroundStyle(DK.secondaryText)
                    }
                }
                Section(ConnectionText.whatSyncs) {
                    Label(ConnectionText.syncConfirmations, systemImage: "book")
                    Label(ConnectionText.syncSettings, systemImage: "slider.horizontal.3")
                    Label(ConnectionText.syncPointing, systemImage: "location.north.line")
                }
                if !state.isLive {
                    Section(ConnectionText.howTo) {
                        Text(ConnectionText.howToSteps).font(.subheadline)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(ConnectionText.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { link.activate() }
        }
        .fontDesign(.rounded)
        .appBackground()
        .forceDarkScheme()
    }

    private func step(_ title: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : DK.secondaryText)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Langsung dari jam" (ADR-021): apa yang sedang dilakukan jam, saat itu
/// juga — arah tunjuk, panah ke benda terdekat, atau benda yang terkunci.
/// Inilah sinkron yang **terasa**: gerakkan tangan, iPhone ikut bergerak.
struct LiveWatchCard: View {
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var engine: PointingEngine
    @ObservedObject var guide: SkyGuideModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let fresh = link.liveSample.map { context.date.timeIntervalSince($0.sentAt) < ConnectionText.liveFreshSeconds } ?? false
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ConnectionGlyph(isLive: fresh, isReady: link.connectionState.isReady)
                    Text(ConnectionText.liveTitle).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                if fresh, let sample = link.liveSample {
                    content(sample)
                } else {
                    Text(link.connectionState.isLive ? ConnectionText.liveWaiting : link.connectionState.detail())
                        .font(.subheadline)
                        .foregroundStyle(DK.secondaryText)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(DK.card))
        }
    }

    @ViewBuilder
    private func content(_ sample: MirrorSample) -> some View {
        if let id = sample.lockedObjectID,
           let object = engine.controller.resolver.object(forID: id, observer: engine.controller.observer, date: Date()) {
            HStack(spacing: 14) {
                CelestialVisualView(visual: CelestialVisual(object: object), diameter: 56, isConfirmed: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.name).font(.title2.bold())
                    StatusChip(text: DesignText.obLocked)
                }
            }
        } else {
            let hint = guide.hint(for: sample.pointing)
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(DK.hairline, lineWidth: 2).frame(width: 64, height: 64)
                    Image(systemName: "location.north.fill")
                        .foregroundStyle(DK.accent)
                        .offset(y: -28)
                        .rotationEffect(.degrees(hint?.arrowDeg ?? 0))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: hint?.arrowDeg)
                    if let hint {
                        Text(verbatim: WatchHomeText.degrees(hint.separationDeg))
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    if let hint {
                        Text(WatchHomeText.guideTitle(hint.name)).font(.headline)
                    }
                    Text(ConnectionText.livePointingAt).font(.caption).foregroundStyle(DK.secondaryText)
                    MonoCaption(text: WatchHomeText.altAz(sample.pointing))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
