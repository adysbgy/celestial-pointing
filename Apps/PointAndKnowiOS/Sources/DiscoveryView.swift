import SwiftUI
import CelestialEngine
import PointingKit

/// Halaman "Penemuan" (Figma: iPhone 12 — First Discovery Reward, ADR-019).
///
/// Visual besar di atas adalah adegan 3D yang dihitung dari efemeris (fase,
/// arah cahaya, cincin) — bukan foto stok — lalu nama, jenis, deskripsi, dan
/// "Yang akan kamu lihat" dengan mata telanjang, binokuler, dan teleskop.
struct DiscoveryView: View {
    let objectID: String
    @ObservedObject var engine: PointingEngine
    @ObservedObject var journal: ObservationJournal
    var isVisibleNow: Bool
    var onExplore: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var savedNow = false
    /// Dihitung sekali saat halaman dibuka: "pertama" berarti belum pernah
    /// disimpan sebelum halaman ini muncul.
    @State private var isFirst: Bool?

    private var object: CelestialObject? {
        engine.controller.resolver.object(forID: objectID, observer: engine.controller.observer, date: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 14) {
                hero
                    .frame(height: 340)
                    .frame(maxWidth: .infinity)
                if let object {
                    StatusChip(text: (isFirst ?? true) ? DesignText.discFirst : DesignText.discAgain)
                    Text(object.name)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(verbatim: DesignText.kindLine(object.kind,
                                                       isVisibleNow ? DesignText.discVisibleNow : DesignText.discNotVisibleNow))
                        .font(.subheadline)
                        .foregroundStyle(DK.secondaryText)
                    let guide = ObjectGuideContent.content(for: object)
                    Text(guide.description)
                        .font(.body)
                        .foregroundStyle(DK.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    whatYoullSee(guide)
                        .padding(.top, 8)
                    PrimaryButton(title: savedNow ? DesignText.discSaved : DesignText.discSave,
                                  systemImage: savedNow ? "checkmark" : "bookmark") {
                        guard !savedNow else { return }
                        journal.save(object, at: Date(), observer: engine.controller.observer)
                        savedNow = true
                    }
                    .disabled(savedNow)
                    .padding(.top, 6)
                    SecondaryLink(title: DesignText.discExplore) {
                        dismiss()
                        onExplore()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .fontDesign(.rounded)
        .forceDarkScheme()
        .onAppear {
            if isFirst == nil { isFirst = !journal.contains(objectID: objectID) }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if let content = Sky3DFactory.object(objectID, engine: engine) {
            ZStack {
                StarfieldBackground(seed: 5, count: 120)
                Sky3DCanvas(content: content, interactive: true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else {
            // Objek langit dalam: tidak ada model 3D, pakai ikon 2D yang sama dengan jam.
            ZStack {
                StarfieldBackground(seed: 5, count: 160)
                if let object {
                    CelestialVisualView(visual: CelestialVisual(object: object), diameter: 160, isConfirmed: true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private func whatYoullSee(_ guide: ObjectGuideContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DesignText.discWhatYoullSee)
                .font(.headline)
                .padding(.bottom, 8)
            row(Label(DesignText.discEye, systemImage: "eye"), guide.nakedEye)
            Divider().overlay(DK.hairline)
            row(Label(DesignText.discBinoculars, systemImage: "binoculars"), guide.binoculars)
            Divider().overlay(DK.hairline)
            row(Label(DesignText.discTelescope, systemImage: "scope"), guide.telescope)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DK.card))
    }

    private func row(_ label: Label<Text, Image>, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            label
                .font(.subheadline)
                .foregroundStyle(DK.secondaryText)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
