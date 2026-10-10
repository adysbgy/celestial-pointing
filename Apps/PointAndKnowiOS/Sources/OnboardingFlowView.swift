import SwiftUI
import CelestialEngine
import PointingKit

/// Onboarding iPhone mengikuti Figma "Point&Know" (ADR-019), dirapikan
/// sesuai HIG: satu gagasan per layar, satu tombol utama, izin diminta
/// tepat saat alasannya dijelaskan (lokasi di layar lokasi, bukan saat app
/// dibuka), dan semua bisa dilewati.
///
/// Angka di layar adalah data sungguhan: benda terang malam ini dengan arah
/// dan ketinggiannya, dan status jam dari WatchConnectivity. Klaim "0.1°
/// Precision" di Figma sengaja tidak dipakai — akurasi tunjuk belum terukur.
struct OnboardingFlowView: View {
    @ObservedObject var engine: PointingEngine
    @ObservedObject var link: PhoneLinkService
    @ObservedObject var location: LocationProvider
    let onDone: () -> Void

    enum Page: Int, CaseIterable { case discover, world, watch, location, point, lookUp }

    @State private var page: Page = .discover
    @StateObject private var guide = SkyGuideModel()
    @AppStorage("wear.rightWrist") private var rightWrist = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, 20)
                .padding(.top, 8)
            ZStack {
                switch page {
                case .discover: discover
                case .world: world
                case .watch: watchReady
                case .location: locationPage
                case .point: pointPage
                case .lookUp: lookUpPage
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: page)
        .background(Color.black.ignoresSafeArea())
        .fontDesign(.rounded)
        .forceDarkScheme()
        .onAppear {
            guide.refresh(engine: engine, force: true)
            #if DEBUG
            // Tangkapan layar: `-debugOnboardingPage 3` membuka layar ke-3.
            let n = UserDefaults.standard.integer(forKey: "debugOnboardingPage")
            if n > 0, let p = Page(rawValue: n - 1) { page = p }
            #endif
        }
    }

    private func go(_ next: Page) { page = next }

    // MARK: Kerangka layar

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Page.allCases, id: \.self) { p in
                Capsule()
                    .fill(p.rawValue <= page.rawValue ? Color.white : Color.white.opacity(0.18))
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    /// Visual di atas, teks dan tombol di bawah — tata letak semua layar Figma.
    private func screen<Hero: View, Extra: View>(
        title: String, body: String,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder extra: () -> Extra = { EmptyView() },
        primary: String, primaryAction: @escaping () -> Void,
        secondary: String? = nil, secondaryAction: (() -> Void)? = nil,
        footnote: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            hero()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 14)
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .font(.body)
                    .foregroundStyle(DK.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 22)
            VStack(spacing: 4) {
                PrimaryButton(title: primary, action: primaryAction)
                if let secondary, let secondaryAction {
                    SecondaryLink(title: secondary, action: secondaryAction)
                }
                if let footnote {
                    MonoCaption(text: footnote).padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: 1. Tunjuk untuk menemukan

    private var discover: some View {
        let target = guide.tonight.first ?? guide.visible.first
        return screen(title: DesignText.obDiscoverTitle, body: DesignText.obDiscoverBody, hero: {
            ZStack {
                StarfieldBackground(seed: 7)
                if let target {
                    ReticleOverlay(label: target.name.uppercased() + " · "
                                   + NumberFormat.decimal(target.magnitude, fractionDigits: 1) + " mag",
                                   coordinates: WatchHomeText.altAz(target.direction))
                } else {
                    GlowingPoint()
                }
                VStack {
                    HStack {
                        Spacer()
                        StatusChip(text: DesignText.obReady, dot: DK.accent)
                    }
                    Spacer()
                }
                .padding(14)
            }
        }, primary: DesignText.obContinue, primaryAction: { go(.world) },
           secondary: DesignText.obHowItWorks, secondaryAction: { go(.point) })
    }

    // MARK: 2. Dari titik cahaya menjadi dunia

    private var world: some View {
        screen(title: DesignText.obWorldTitle, body: DesignText.obWorldBody, hero: {
            ZStack {
                StarfieldBackground(seed: 9, count: 120)
                WatchMockup { lockedPreview }
            }
        }, extra: {
            HStack(spacing: 10) {
                feature("hand.tap", DesignText.obWorldTap)
                feature("wifi.slash", DesignText.obWorldOffline)
                feature("iphone.gen3", DesignText.obWorldSync)
            }
            .padding(.top, 6)
        }, primary: DesignText.obWorldSetup, primaryAction: { go(.watch) },
           secondary: DesignText.obWorldSkip, secondaryAction: { go(.location) })
    }

    /// Isi layar jam pada mockup: benda terang malam ini, terkunci.
    @ViewBuilder
    private var lockedPreview: some View {
        let target = guide.tonight.first ?? guide.visible.first
        VStack(spacing: 6) {
            if let target, let object = engine.controller.resolver.object(
                forID: target.id, observer: engine.controller.observer, date: Date()) {
                CelestialVisualView(visual: CelestialVisual(object: object), diameter: 70, isConfirmed: true)
                Text(object.name).font(.headline)
                MonoCaption(text: WatchHomeText.altAz(target.direction))
                StatusChip(text: DesignText.obLocked)
            } else {
                GlowingPoint()
            }
        }
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(DK.accent)
            Text(text).font(.caption).multilineTextAlignment(.center).foregroundStyle(DK.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(DK.card))
        .accessibilityElement(children: .combine)
    }

    // MARK: 3. Jam siap

    private var watchReady: some View {
        let ready = link.isPaired && link.isWatchAppInstalled
        return screen(title: ready ? DesignText.obWatchTitle : DesignText.obWatchNotReady,
                      body: ready ? DesignText.obWatchBody : DesignText.obWatchNotReadyBody, hero: {
            ZStack(alignment: .top) {
                StarfieldBackground(seed: 13, count: 90)
                WatchMockup {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().stroke(DK.hairline, lineWidth: 1).frame(width: 96, height: 96)
                            Circle().stroke(DK.hairline, lineWidth: 1).frame(width: 56, height: 56)
                            Image(systemName: "location.north.fill").foregroundStyle(DK.accent)
                        }
                        MonoCaption(text: "POINT & KNOW")
                    }
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: 6) {
                    StatusChip(text: DesignText.obChipWatch, dot: link.isPaired ? .green : .orange)
                    StatusChip(text: link.isReachable ? DesignText.obChipConnected
                               : (link.isWatchAppInstalled ? DesignText.obChipAppInstalled
                                  : (link.isPaired ? DesignText.obChipNotInstalled : DesignText.obChipNotPaired)),
                               dot: link.isReachable ? .green : .orange)
                }
                .padding(.top, 14)
            }
        }, extra: {
            VStack(spacing: 0) {
                checkRow("gyroscope", DesignText.obWatchMotion, DesignText.obWatchMotionDetail, ok: ready)
                Divider().overlay(DK.hairline)
                checkRow("location.north.line", DesignText.obWatchCompass, DesignText.obWatchCompassDetail, ok: ready)
            }
            .padding(.top, 4)
        }, primary: DesignText.obContinue, primaryAction: { go(.location) },
           footnote: DesignText.obOnDevice)
    }

    private func checkRow(_ symbol: String, _ title: String, _ detail: String, ok: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(DK.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(DK.secondaryText)
            }
            Spacer()
            Image(systemName: ok ? "checkmark" : "minus")
                .foregroundStyle(ok ? Color.green : DK.secondaryText)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: 4. Lokasi

    private var locationPage: some View {
        screen(title: DesignText.obLocationTitle, body: DesignText.obLocationBody, hero: {
            EarthLimbHero()
        }, extra: {
            Label(DesignText.obLocationPrivacy, systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(DK.secondaryText)
                .padding(.top, 2)
        }, primary: DesignText.obLocationUse, primaryAction: {
            // Izin diminta di sini, saat alasannya sedang dibaca (HIG).
            location.start()
            go(.point)
        }, secondary: DesignText.obNotNow, secondaryAction: { go(.point) })
    }

    // MARK: 5. Tunjuk dengan wajar

    private var pointPage: some View {
        screen(title: DesignText.obPointTitle, body: DesignText.obPointBody, hero: {
            PointingHandHero(rightWrist: rightWrist)
        }, extra: {
            VStack(alignment: .leading, spacing: 6) {
                Picker(selection: $rightWrist) {
                    Text(DesignText.obPointLeft).tag(false)
                    Text(DesignText.obPointRight).tag(true)
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                Text(DesignText.obPointWristNote)
                    .font(.caption)
                    .foregroundStyle(DK.secondaryText)
            }
            .padding(.top, 4)
        }, primary: DesignText.obPointTry, primaryAction: { go(.lookUp) })
    }

    // MARK: 6. Lihat ke atas

    private var lookUpPage: some View {
        screen(title: DesignText.obLookupTitle, body: DesignText.obLookupBody, hero: {
            ZStack {
                StarfieldBackground(seed: 17, count: 60)
                GlowingPoint(diameter: 18)
            }
        }, primary: DesignText.obContinue, primaryAction: onDone,
           footnote: DesignText.obLookupHint)
    }
}
