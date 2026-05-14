import SwiftUI

struct PeriodTrackingView: View {
    @Environment(PeriodStore.self) private var periodStore
    @State private var showAddSheet = false
    @State private var editingEntry: PeriodEntry?

    var body: some View {
        List {
            if periodStore.entries.isEmpty {
                Section {
                    Text("Track your cycle to contextualize short-term weight changes. The trend weight algorithm already handles natural fluctuations, but seeing them next to your cycle helps explain spikes.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                if let avg = periodStore.averageCycleLengthDays() {
                    Section("Stats") {
                        HStack {
                            Text("Average cycle length")
                            Spacer()
                            Text("\(avg) days")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section("Cycles") {
                    ForEach(periodStore.sortedNewestFirst) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.startDate, style: .date)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .foregroundStyle(.primary)
                                    if let end = entry.endDate {
                                        Text("ended \(end.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("in progress")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(BulkAITheme.Color.accent)
                                    }
                                }
                                Spacer()
                                if let len = entry.periodLengthDays {
                                    Text("\(len) d")
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                    .onDelete { idx in
                        let sorted = periodStore.sortedNewestFirst
                        for i in idx { periodStore.delete(sorted[i]) }
                    }
                }
            }
        }
        .navigationTitle("Period tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PeriodEntryEditor(entry: nil) { newEntry in
                periodStore.add(newEntry)
            }
        }
        .sheet(item: $editingEntry) { entry in
            PeriodEntryEditor(entry: entry) { updated in
                periodStore.update(updated)
            }
        }
    }
}

private struct PeriodEntryEditor: View {
    let entry: PeriodEntry?
    let onSave: (PeriodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String

    init(entry: PeriodEntry?, onSave: @escaping (PeriodEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _startDate = State(initialValue: entry?.startDate ?? .now)
        _hasEndDate = State(initialValue: entry?.endDate != nil)
        _endDate = State(initialValue: entry?.endDate ?? .now)
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Start") {
                    DatePicker("First day", selection: $startDate, displayedComponents: .date)
                }
                Section {
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Last day", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section("Notes (optional)") {
                    TextField("Symptoms, mood, anything to remember", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(entry == nil ? "New cycle" : "Edit cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let result = PeriodEntry(
                            id: entry?.id ?? UUID(),
                            startDate: startDate,
                            endDate: hasEndDate ? endDate : nil,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(result)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }
}
