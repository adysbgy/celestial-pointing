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

    @StateObject private var guide = SkyGuideModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSkyHome = false
    @AppStorage(HotColdTicker.enabledKey) private var hotColdEnabled = true
    @StateObject private var ticker = HotColdTicker()
    /// Posisi Digital Crown di antara kandidat (ADR-014).
    @State private var crown = 0.0
    @State private var showPhenomena = false
    private var phoneSymbol: String { link.isReachable ? Self.symbolPhone : Self.symbolPhoneAway }
    private static let symbolPhone = "iphone"
    private static let symbolPhoneAway = "iphone.slash"
    @State private var confirmation: WatchConfirmation?
    @State private var showResult = false

    /// Hasil engine apa adanya.
    private var liveOutcome: IdentificationOutcome { .from(engine.snapshot) }

    /// Kunci terakhir, ditahan sebentar (ADR-022): lengan yang goyah sedikit
    /// tidak boleh membuat nama benda berkedip hilang-muncul.
    @State private var stickyLock: (object: CelestialObject, until: Date)?

    /// Yang ditampilkan: kunci sungguhan, atau kunci yang baru saja lepas
    /// karena gerak kecil / ragu pada benda yang **sama** (≤ 1,5 dtk).
    private var outcome: IdentificationOutcome {
        let live = liveOutcome
        if case .single = live { return live }
        guard let sticky = stickyLock, Date() < sticky.until else { return live }
        switch live {
        case .holdSteady where engine.snapshot.state == .pointing:
            return .single(sticky.object)
        case .possibleMatches(let list) where list.first == sticky.object:
            return .single(sticky.object)
        default:
            return live
        }
    }

    var body: some View {
        NightAwareContainer {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 8) {
                        TelescopeStopBar(store: telescope)
                        hero
                            .id(heroKey)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        // Status iPhone, hanya di layar tenang (siap/siang) supaya
                        // tidak mengganggu saat menunjuk (ADR-020).
                        if heroKey == "idle" || heroKey == "day" {
                            Label(link.isReachable ? ConnectionText.phoneLive : ConnectionText.phoneAway,
                                  systemImage: phoneSymbol)
                                .font(.caption2)
                                .foregroundStyle(link.isReachable ? PointingTone.success.color : .secondary)
                        }
                        if let pinned = guide.pinned {
                            Button {
                                guide.pin(nil)
                            } label: {
                                Label(PhenomenonText.guiding(PhenomenonText.title(pinned)), systemImage: "xmark.circle.fill")
                                    .font(.footnote)
                                    .lineLimit(2)
                            }
                            .accessibilityHint(PhenomenonText.stopGuiding)
                        }
                        if needsCalibration {
                            NavigationLink {
                                CalibrationView(engine: engine, motion: motion, link: link)
                            } label: {
                                Label(WatchHomeText.calibrateFirst, systemImage: "location.north.line")
                                    .font(.footnote)
                            }
                            .tint(PointingTone.warning.color)
                        }
                        if engine.location.isFallback {
                            Label(WatchHomeText.approxLocation, systemImage: "location.slash")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 2)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: heroKey)
                }
                .onChange(of: engine.snapshot.state) { _, _ in
                    if case .single(let object) = liveOutcome {
                        stickyLock = (object, Date().addingTimeInterval(1.5))
                    }
                }
                .onChange(of: heroKey) { _, key in
                    crown = 0
                    #if DEBUG
                    // Uji Jurnal (ADR-020): `-debugAutoConfirm YES` menekan
                    // "Ya, itu dia" sendiri begitu terkunci.
                    if key.hasPrefix("single-"), UserDefaults.standard.bool(forKey: "debugAutoConfirm"),
                       case .single(let object) = outcome, confirmation == nil {
                        confirm(object)
                    }
                    #endif
                }
                .fontDesign(.rounded)
                .task {
                    // Langit bergeser pelan; sekali per menit cukup.
                    while !Task.isCancelled {
                        guide.refresh(engine: engine)
                        try? await Task.sleep(for: .seconds(30))
                    }
                }
                .onChange(of: engine.location) { _, _ in guide.refresh(engine: engine, force: true) }
                .onChange(of: darkSkyHome) { _, _ in guide.refresh(engine: engine, force: true) }
                .sheet(isPresented: $showPhenomena) { PhenomenaView(guide: guide) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPhenomena = true } label: {
                            Image(systemName: "sparkles")
                        }
                        .accessibilityLabel(PhenomenonText.sectionTitle)
                    }
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
            ReducedLuminanceView(engine: engine, hint: activeGuideHint)
        }
        // Di luar wadah layar redup: saat lengan menunjuk langit layar
        // meredup dan isi utama diganti, tapi getaran panas–dingin justru
        // harus terus berjalan (ADR-018).
        .onChange(of: tickerSeparation) { _, sep in ticker.update(separationDeg: sep) }
        .onDisappear { ticker.update(separationDeg: nil) }
    }

    // MARK: Pahlawan per keadaan

    /// Kerangka tanpa utara dan belum dikalibrasi: azimut acak (ADR-011).
    private var needsCalibration: Bool {
        engine.snapshot.hasSensor
            && !engine.controller.config.frame.hasAbsoluteHeading
            && !engine.snapshot.isCalibrated
    }

    /// Siang dan tidak ada yang bisa dikenali: tampilkan kapan gelap, bukan
    /// "Belum yakin" tanpa ujung.
    private var showsDaylight: Bool {
        guard !guide.isDark else { return false }
        switch outcome {
        case .single, .possibleMatches, .unavailable: return false
        case .holdSteady, .notSure: return guide.visible.isEmpty
        }
    }

    private var currentHint: GuideHint? { guide.hint(for: engine.snapshot.calibratedPointing) }

    /// Jarak untuk getaran panas–dingin: saat cincin petunjuk berlaku dan
    /// pengguna tidak mematikannya — **termasuk** saat layar redup karena
    /// lengan menunjuk langit (ADR-018). Dibulatkan ke derajat
    /// supaya `onChange` tidak berbunyi 50 kali per detik.
    private var tickerSeparation: Int? {
        guard hotColdEnabled, let hint = activeGuideHint else { return nil }
        return Int(hint.separationDeg.rounded())
    }

    /// Petunjuk yang sedang dipakai cincin (untuk layar redup dan getaran).
    private var activeGuideHint: GuideHint? {
        guard heroKey == "guide" || heroKey == "moving-guide" || heroKey == "pinned"
                || heroKey.hasPrefix("guide-one-") else { return nil }
        return currentHint
    }

    /// Identitas pahlawan untuk animasi peralihan (bukan per sampel sensor).
    private var heroKey: String {
        if showsPinnedGuide { return "pinned" }
        if showsDaylight { return "day" }
        switch outcome {
        case .unavailable: return "unavailable"
        case .holdSteady:
            if engine.snapshot.state == .idle { return "idle" }
            if let hint = currentHint, hint.separationDeg > engine.controller.config.coneDeg { return "moving-guide" }
            return "moving"
        case .notSure: return "guide"
        case .single(let o): return "single-" + o.id
        case .possibleMatches(let list):
            return list.count == 1 ? "guide-one-" + list[0].id
                : "possible-" + list.map(\.id).sorted().joined(separator: ",")
        }
    }

    /// Sedang memandu ke fenomena dan belum terkunci pada sasarannya.
    private var showsPinnedGuide: Bool {
        guard guide.pinned != nil else { return false }
        // Benda apa pun yang terkunci menang atas pemandu (ADR-022): pengguna
        // sudah menemukan sesuatu — jangan terus bergetar mencari yang lain.
        if case .single = outcome { return false }
        return outcome != .unavailable
    }

    @ViewBuilder
    private var hero: some View {
        if showsPinnedGuide, let pinned = guide.pinned {
            if let hint = currentHint {
                GuideHero(hint: hint)
            } else {
                StateHero(symbol: pinned.kind.symbol,
                          title: PhenomenonText.title(pinned),
                          hint: PhenomenonText.notUpYet(PhenomenonText.targetName(pinned)))
            }
        } else if showsDaylight {
            DayHero(darkAt: guide.darkAt, tonight: guide.tonight)
        } else {
            switch outcome {
            case .unavailable:
                StateHero(symbol: "sensor.tag.radiowaves.forward", title: WatchHomeText.unavailable, hint: nil)
            case .holdSteady:
                if engine.snapshot.state == .idle {
                    StateHero(symbol: "scope", title: WatchHomeText.aimTitle, hint: WatchHomeText.aimHint)
                } else if let hint = currentHint, hint.separationDeg > engine.controller.config.coneDeg {
                    // Bergerak dan jauh dari benda mana pun: tunjukkan arahnya
                    // langsung, jangan hanya "tahan diam".
                    GuideHero(hint: hint)
                } else {
                    StateHero(symbol: "hand.raised", title: WatchHomeText.holdStill, hint: nil)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            case .notSure:
                if let hint = currentHint {
                    GuideHero(hint: hint)
                } else {
                    StateHero(symbol: "questionmark.circle",
                              title: WatchHomeText.nothingHere,
                              hint: engine.snapshot.searchHint?.message ?? WatchHomeText.notSureHint)
                }
            case .single(let object):
                // Ringkas supaya "Ya, itu dia" terlihat tanpa menggulir (ADR-022).
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        if let visual = engine.visualForDisplayedObject {
                            CelestialVisualView(visual: visual, diameter: 44, isConfirmed: true)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(object.name)
                                .font(.title3.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            HStack(spacing: 4) {
                                Circle().fill(PointingTone.success.color).frame(width: 5, height: 5)
                                Text(DesignText.obLocked)
                                    .font(.caption2.monospaced().weight(.semibold))
                                    .foregroundStyle(PointingTone.success.color)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Spacer(minLength: 0)
                    }
                    if let h = engine.controller.resolver.horizontal(ofObjectID: object.id,
                                                                     observer: engine.controller.observer,
                                                                     date: Date()) {
                        Text(verbatim: WatchHomeText.altAz(h))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        confirm(object)
                    } label: {
                        Text(WatchHomeText.confirmShort)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PointingTone.success.color)
                    .foregroundStyle(.black)
                    // Ketuk dua kali (Double Tap) mengonfirmasi tanpa menurunkan lengan.
                    .handGestureShortcut(.primaryAction)
                    .accessibilityLabel(IdentificationText.confirm(object.name))
                }
                .accessibilityElement(children: .contain)
            case .possibleMatches(let objects):
                if objects.count == 1, let only = objects.first,
                   let hint = currentHint, hint.objectID == only.id {
                    // Satu kandidat, tapi belum cukup dekat untuk yakin:
                    // tunjukkan arahnya, bukan daftar berisi satu baris.
                    VStack(spacing: 6) {
                        GuideHero(hint: hint)
                        Button {
                            confirm(only)
                        } label: {
                            Text(IdentificationText.confirm(only.name))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    oneAtATime(OneAtATime(candidates: engine.snapshot.intent?.candidates ?? []),
                               fallback: objects)
                }
            }
        }
    }

    /// Satu jawaban besar; crown berpindah ke kandidat berikutnya (ADR-014).
    /// Hasil `.uncertain` tetap berlabel "Belum pasti" dan visualnya samar.
    @ViewBuilder
    private func oneAtATime(_ list: OneAtATime, fallback: [CelestialObject]) -> some View {
        let index = Int(crown.rounded())
        if let entry = list.entry(at: index) {
            let object = entry.object
            VStack(spacing: 4) {
                CelestialVisualView(visual: CelestialVisual(object: object), diameter: 56, isConfirmed: false)
                    .accessibilityHidden(true)
                Text(WatchHomeText.notCertain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PointingTone.warning.color)
                    .textCase(.uppercase)
                Text(object.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                if let n = list.closeNeighbour(of: index, withinDeg: engine.controller.config.coneDeg) {
                    Text(WatchHomeText.alsoClose(n.object.name, distanceDeg: n.distanceDeg))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if list.count > 1 {
                    Text(WatchHomeText.crownNext)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    confirm(object)
                } label: {
                    Text(WatchHomeText.confirmShort)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .handGestureShortcut(.primaryAction)
                .accessibilityLabel(IdentificationText.confirm(object.name))
                if list.count > 1 {
                    Text(WatchHomeText.position(((index % list.count) + list.count) % list.count, of: list.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .focusable()
            .digitalCrownRotation($crown, from: -1000, through: 1000, by: 1,
                                  sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .accessibilityElement(children: .contain)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: crown += 1
                case .decrement: crown -= 1
                @unknown default: break
                }
            }
        } else if let first = fallback.first {
            StateHero(symbol: "questionmark.circle", title: first.name, hint: WatchHomeText.notCertain)
        }
    }

    // MARK: Konfirmasi

    private func confirm(_ object: CelestialObject) {
        // Sasaran fenomena sudah ditemukan: pemandu selesai tugasnya.
        if guide.pinned?.targetIDs.contains(object.id) == true { guide.pin(nil) }
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

/// Petunjuk arah hidup: cincin kompas dengan penanda yang berputar ke benda
/// terlihat terdekat, jaraknya di tengah. Selalu memberi langkah berikutnya.
struct GuideHero: View {
    let hint: GuideHint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 = dingin (biru), 1 = panas (oranye) — ADR-014.
    private var heat: Double { HotCold.heat(separationDeg: hint.separationDeg) }
    /// Pita warna, bukan campuran: campuran biru–oranye di tengah jalan
    /// menjadi abu-abu kehijauan yang kusam. Dingin = biru, hangat (≤30°) = oranye.
    private var ringColor: Color { heat >= 0.5 ? PointingTone.warning.color : PointingTone.active.color }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.35 + 0.45 * heat), lineWidth: 3 + 2 * heat)
                ForEach(0..<12) { i in
                    Capsule()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 2, height: i % 3 == 0 ? 8 : 4)
                        .offset(y: -42)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                Image(systemName: "location.north.fill")
                    .font(.title3)
                    .foregroundStyle(ringColor)
                    .offset(y: -42)
                    .rotationEffect(.degrees(hint.arrowDeg))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: hint.arrowDeg)
                VStack(spacing: 0) {
                    Image(systemName: hint.kind.guideSymbol)
                        .font(.title3)
                        .foregroundStyle(PointingTone.active.color)
                    Text(verbatim: WatchHomeText.degrees(hint.separationDeg))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .smooth, value: Int(hint.separationDeg))
                }
            }
            .frame(width: 96, height: 96)
            .accessibilityHidden(true)
            Text(WatchHomeText.guideTitle(hint.name))
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WatchHomeText.guideTitle(hint.name))
        .accessibilityValue(WatchHomeText.guideDistance(hint.separationDeg))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Siang hari: jujur bahwa langit masih terang, kapan gelap, dan apa yang
/// akan terlihat malam ini — bukan "Belum yakin" tanpa ujung.
struct DayHero: View {
    let darkAt: Date?
    let tonight: [PointingTarget]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.pulse, options: .repeating.speed(0.3), isActive: !reduceMotion)
                .accessibilityHidden(true)
            Text(WatchHomeText.dayTitle)
                .font(.title3.weight(.bold))
            Text(darkAt.map { WatchHomeText.darkAt($0) } ?? WatchHomeText.dayNoDark)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !tonight.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WatchHomeText.tonight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(tonight) { target in
                        HStack(spacing: 6) {
                            Image(systemName: target.kind.guideSymbol)
                                .foregroundStyle(PointingTone.active.color)
                                .frame(width: 18)
                                .accessibilityHidden(true)
                            Text(target.name).font(.body.weight(.medium))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 4)
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
                    // "Yang akan kamu lihat" versi jam (Figma: First Discovery, ADR-019).
                    let guide = ObjectGuideContent.content(for: c.object)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DesignText.discWhatYoullSee).font(.footnote.weight(.semibold))
                        Label(guide.nakedEye, systemImage: "eye")
                        Label(guide.binoculars, systemImage: "binoculars")
                        Label(guide.telescope, systemImage: "scope")
                    }
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.08)))
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
        // "Lihat 3D di iPhone" lewat Handoff (ADR-017): iPhone menampilkan
        // ikon app di layar kunci/dock; ketuk untuk membuka 3D benda ini.
        .userActivity(ViewObjectActivity.type, isActive: confirmation.map { $0.object.kind != .deepSky } ?? false) { activity in
            guard let c = confirmation else { return }
            activity.title = Scene3DText.openOnPhone + ": " + c.object.name
            activity.addUserInfoEntries(from: [ViewObjectActivity.objectIDKey: c.object.id])
            activity.isEligibleForHandoff = true
        }
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
    @AppStorage(SkyQualityStorage.darkSkyKey) private var darkSky = false
    @AppStorage(HotColdTicker.enabledKey) private var hotColdOn = true
    private var linkSymbol: String { link.isReachable ? Self.symbolPhone : Self.symbolPhoneSlash }
    private static let symbolPhone = "iphone"
    private static let symbolPhoneSlash = "iphone.slash"

    /// Layar lama (lengkap, teknis) punya `NavigationStack` sendiri, jadi
    /// dibuka sebagai sheet, bukan didorong ke tumpukan ini.
    @State private var showTechnical = false

    /// Sakelar yang ikut tersinkron ke iPhone (ADR-020): perubahan oleh
    /// pengguna diberi stempel waktu lalu dikirim.
    private func synced(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue }, set: { value in
            binding.wrappedValue = value
            link.push(settings: SettingsSyncStore.userChanged())
        })
    }

    var body: some View {
        List {
            Section {
                Toggle(WatchHomeText.nightMode, isOn: $nightMode)
                Toggle(WatchHomeText.soundOnLock, isOn: $audioCueEnabled)
                Toggle(WatchHomeText.hotColdHaptics, isOn: synced($hotColdOn))
                Toggle(isOn: synced($darkSky)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WatchHomeText.darkSky)
                        Text(WatchHomeText.darkSkyHint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink(TextLocalization.text(.calibrationTitle)) {
                    CalibrationView(engine: engine, motion: motion, link: link)
                }
                NavigationLink(WatchHomeText.skyAndLocation) {
                    SkyContextView(engine: engine)
                }
            }
            Section(ConnectionText.title) {
                Label(link.isReachable ? ConnectionText.phoneLive : ConnectionText.phoneAway,
                      systemImage: linkSymbol)
                    .foregroundStyle(link.isReachable ? PointingTone.success.color : .secondary)
            }
            Section(WatchHomeText.developerSection) {
                NavigationLink(WatchHomeText.whyNotSure) {
                    WhyNotSureView(engine: engine)
                }
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

/// Pengembang: alasan mentah di balik "Belum yakin", untuk difoto dari jam
/// sungguhan saat log perangkat tidak terjangkau (ADR-011).
struct WhyNotSureView: View {
    @ObservedObject var engine: PointingEngine
    @StateObject private var guide = SkyGuideModel()

    var body: some View {
        let rows = WhyNotSureReport.rows(snapshot: engine.snapshot,
                                         frame: engine.controller.config.frame,
                                         locationIsFallback: engine.location.isFallback,
                                         sunAltitudeDeg: guide.sunAltitudeDeg,
                                         visibleCount: guide.visible.count,
                                         nearest: guide.hint(for: engine.snapshot.calibratedPointing))
        List(rows) { row in
            HStack {
                Text(verbatim: row.id).foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: row.value).multilineTextAlignment(.trailing)
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .navigationTitle(WatchHomeText.whyNotSure)
        .onAppear { guide.refresh(engine: engine, force: true) }
    }
}
