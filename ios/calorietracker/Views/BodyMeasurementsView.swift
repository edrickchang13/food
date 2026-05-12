import SwiftUI

/// Two-screen flow: a list of every measurement site with the latest value, and a per-site
/// detail screen with history + add-new. Uses the user's preferred unit (metric/imperial)
/// from AppStorage so values render in cm or inches consistently.
struct BodyMeasurementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MeasurementStore.self) private var measurementStore
    @AppStorage("useMetric") private var useMetric = false

    var body: some View {
        List {
            ForEach(BodyMeasurementSite.allCases) { site in
                NavigationLink(value: site) {
                    HStack {
                        Image(systemName: site.icon)
                            .foregroundStyle(AppColors.calorie)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.displayName)
                                .font(.system(.body, design: .rounded, weight: .medium))
                            if let latest = measurementStore.latest(for: site) {
                                Text(formatted(latest.valueCm))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No measurements")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Body measurements")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: BodyMeasurementSite.self) { site in
            BodyMeasurementSiteDetailView(site: site)
        }
    }

    private func formatted(_ cm: Double) -> String {
        if useMetric {
            return String(format: "%.1f cm", cm)
        }
        return String(format: "%.1f in", cm / 2.54)
    }
}

private struct BodyMeasurementSiteDetailView: View {
    let site: BodyMeasurementSite
    @Environment(MeasurementStore.self) private var measurementStore
    @AppStorage("useMetric") private var useMetric = false
    @State private var showAddSheet = false

    private var siteEntries: [BodyMeasurementEntry] {
        measurementStore.entries(for: site)
    }

    var body: some View {
        List {
            Section {
                if siteEntries.isEmpty {
                    Text("No measurements logged yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(siteEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatted(entry.valueCm))
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Text(entry.date, style: .date)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            measurementStore.delete(siteEntries[i])
                        }
                    }
                }
            }
        }
        .navigationTitle(site.displayName)
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
            AddMeasurementSheet(site: site)
        }
    }

    private func formatted(_ cm: Double) -> String {
        if useMetric {
            return String(format: "%.1f cm", cm)
        }
        return String(format: "%.1f in", cm / 2.54)
    }
}

private struct AddMeasurementSheet: View {
    let site: BodyMeasurementSite
    @Environment(\.dismiss) private var dismiss
    @Environment(MeasurementStore.self) private var measurementStore
    @AppStorage("useMetric") private var useMetric = false

    @State private var value: Double = 0
    @State private var note: String = ""
    @State private var date: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement") {
                    HStack {
                        Text(site.displayName)
                        Spacer()
                        TextField("0", value: $value, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(useMetric ? "cm" : "in")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Date") {
                    DatePicker("Logged on", selection: $date, displayedComponents: .date)
                }
                Section("Note (optional)") {
                    TextField("e.g., morning, post-shower", text: $note)
                }
            }
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let cm = useMetric ? value : value * 2.54
                        let entry = BodyMeasurementEntry(
                            date: date,
                            site: site,
                            valueCm: cm,
                            note: note.isEmpty ? nil : note
                        )
                        measurementStore.add(entry)
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .disabled(value <= 0)
                }
            }
        }
    }
}
