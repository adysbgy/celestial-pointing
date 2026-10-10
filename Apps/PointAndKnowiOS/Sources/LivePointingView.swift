import SwiftUI
import CelestialEngine
import PointingKit

/// Mode menunjuk di iPhone (ADR-022).
///
/// **Kenapa.** Ady: "Tangan saya di atas, masa saya harus lihat jamnya?"
/// Saat lengan menunjuk langit, layar jam berpaling dari wajah. Jadi iPhone —
/// dipegang tangan satunya — menjadi layar utama: panah besar, arah gerak
/// dalam kata ("Naik · Ke kanan"), sisa derajat, dan saat terkunci tombol
/// besar "Ya, itu dia" yang bisa ditekan di iPhone (tidak perlu menggulir
/// jam). Layar iPhone dijaga tetap menyala selama mode ini terbuka.
struct LivePointingView: View {
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var engine: PointingEngine
    @ObservedObject var guide: SkyGuideModel
    @ObservedObject var journal: ObservationJournal
    let onConfirmed: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let sample = link.liveSample.flatMap {
                context.date.timeIntervalSince($0.sentAt) < ConnectionText.liveFreshSeconds ? $0 : nil
            }
            VStack(spacing: 0) {
                header(isLive: sample != nil)
                Spacer(minLength: 12)
                if let sample {
                    if let id = sample.lockedObjectID, let object = engine.controller.resolver.object(
                        forID: id, observer: engine.controller.observer, date: Date()) {
                        locked(object)
                    } else {
                        guiding(sample)
                    }
                } else {
                    waiting
                }
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .fontDesign(.rounded)
        .forceDarkScheme()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func header(isLive: Bool) -> some View {
        HStack(spacing: 10) {
            ConnectionGlyph(isLive: isLive, isReady: link.connectionState.isReady)
            Text(TextLocalization.text(.livePointingTitle)).font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DK.secondaryText)
            }
            .accessibilityLabel(TextLocalization.text(.liveClose))
        }
        .padding(.top, 12)
    }

    // MARK: Memandu

    private func guiding(_ sample: MirrorSample) -> some View {
        let hint = guide.hint(for: sample.pointing)
        return VStack(spacing: 18) {
            ZStack {
                Circle().stroke(DK.hairline, lineWidth: 3)
                Circle().trim(from: 0, to: hint.map { 1 - min(1, $0.separationDeg / 60) } ?? 0)
                    .stroke(DK.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth, value: hint?.separationDeg)
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(.largeTitle))
                    .foregroundStyle(DK.accent)
                    .offset(y: -128)
                    .rotationEffect(.degrees(hint?.arrowDeg ?? 0))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: hint?.arrowDeg)
                VStack(spacing: 2) {
                    if let hint {
                        Text(verbatim: WatchHomeText.degrees(hint.separationDeg))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Image(systemName: hint.kind.guideSymbol).foregroundStyle(DK.secondaryText)
                    }
                }
            }
            .frame(width: 256, height: 256)
            .accessibilityHidden(true)
            if let hint {
                Text(WatchHomeText.guideTitle(hint.name)).font(.title.bold())
                Text(GuideDirections.words(hint))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DK.accent)
            }
            MonoCaption(text: WatchHomeText.altAz(sample.pointing))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Terkunci

    private func locked(_ object: CelestialObject) -> some View {
        VStack(spacing: 16) {
            ObjectHeroVisual(object: object, engine: engine, diameter: 140)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            StatusChip(text: DesignText.obLocked)
            Text(object.name).font(.largeTitle.bold())
            PrimaryButton(title: TextLocalization.text(.liveConfirmOnPhone), systemImage: "checkmark") {
                journal.save(object, at: Date(), observer: engine.controller.observer)
                onConfirmed(object.id)
                dismiss()
            }
            Text(TextLocalization.text(.liveKeepLooking))
                .font(.footnote)
                .foregroundStyle(DK.secondaryText)
        }
    }

    private var waiting: some View {
        VStack(spacing: 16) {
            GlowingPoint(diameter: 18)
            Text(TextLocalization.text(.liveWaitingWatch))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(DK.secondaryText)
        }
    }
}
