import SwiftUI
import CelestialEngine
import PointingKit

/// Tab Jurnal (ADR-019): pengamatan yang disimpan dari kartu Penemuan.
struct JournalView: View {
    @ObservedObject var journal: ObservationJournal
    @ObservedObject var engine: PointingEngine
    @State private var open: String?

    var body: some View {
        NavigationStack {
            Group {
                if journal.entries.isEmpty {
                    ContentUnavailableView {
                        Label(DesignText.discJournal, systemImage: "book.closed")
                    } description: {
                        Text(DesignText.journalEmpty)
                    }
                } else {
                    List {
                        ForEach(journal.entries) { entry in
                            Button { open = entry.objectID } label: { row(entry) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: journal.delete)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(DesignText.tabJournal)
            .sheet(item: Binding(get: { open.map(Ident.init) }, set: { open = $0?.id })) { item in
                DiscoveryView(objectID: item.id, engine: engine, journal: journal,
                              isVisibleNow: false, onExplore: {})
            }
        }
        .fontDesign(.rounded)
        .appBackground()
        .forceDarkScheme()
    }

    private func row(_ entry: ObservationJournal.JournalEntry) -> some View {
        HStack(spacing: 14) {
            if let object = engine.controller.resolver.object(forID: entry.objectID,
                                                             observer: engine.controller.observer, date: entry.date) {
                CelestialVisualView(visual: CelestialVisual(object: object), diameter: 44, isConfirmed: true)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).font(.headline)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(DK.secondaryText)
                if entry.fromWatch == true {
                    Label(ConnectionText.fromWatch, systemImage: "applewatch")
                        .font(.caption)
                        .foregroundStyle(DK.accent)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(DK.secondaryText)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Pembungkus id untuk `.sheet(item:)`.
struct Ident: Identifiable { let id: String }
