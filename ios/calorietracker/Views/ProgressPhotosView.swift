import SwiftUI
import PhotosUI

/// Two-screen flow: a filterable grid of progress photos, and a full-screen viewer
/// when one is tapped. Photos are stored encrypted-at-rest by ProgressPhotoStore;
/// this view only deals with display + adding new entries.
struct ProgressPhotosView: View {
    @Environment(ProgressPhotoStore.self) private var photoStore
    @Environment(WeightStore.self) private var weightStore
    @State private var sideFilter: ProgressPhotoSide? = nil
    @State private var showAddSheet = false
    @State private var viewingPhoto: ProgressPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var filteredPhotos: [ProgressPhoto] {
        if let sideFilter {
            return photoStore.photos(for: sideFilter)
        }
        return photoStore.sortedNewestFirst
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterBar
                if filteredPhotos.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filteredPhotos) { photo in
                            Button {
                                viewingPhoto = photo
                            } label: {
                                photoThumbnail(photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(BulkAITheme.Color.background)
        .navigationTitle("Progress photos")
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
            AddProgressPhotoSheet(weightStore: weightStore)
        }
        .sheet(item: $viewingPhoto) { photo in
            ProgressPhotoViewer(photo: photo)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", isSelected: sideFilter == nil) { sideFilter = nil }
                ForEach(ProgressPhotoSide.allCases) { side in
                    filterChip(
                        label: side.displayName,
                        isSelected: sideFilter == side
                    ) { sideFilter = (sideFilter == side ? nil : side) }
                }
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? BulkAITheme.Color.accent : BulkAITheme.Color.surface)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        if let image = photoStore.loadImage(for: photo) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(photo.side.displayName)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
            }
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BulkAITheme.Color.surface)
                .frame(height: 120)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No photos yet")
                .font(.system(.headline, design: .rounded))
            Text("Photos are stored encrypted on this device and never uploaded.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct AddProgressPhotoSheet: View {
    let weightStore: WeightStore
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressPhotoStore.self) private var photoStore

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var side: ProgressPhotoSide = .front
    @State private var notes: String = ""
    @State private var date: Date = .now
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let imageData, let ui = UIImage(data: imageData) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Label("Pick a photo", systemImage: "photo.fill.on.rectangle.fill")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        }
                    }
                }
                Section("Angle") {
                    Picker("Side", selection: $side) {
                        ForEach(ProgressPhotoSide.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Date") {
                    DatePicker("Taken on", selection: $date, displayedComponents: .date)
                }
                Section("Notes (optional)") {
                    TextField("Anything to remember", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("New photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .disabled(imageData == nil || isLoading)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    isLoading = true
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                    isLoading = false
                }
            }
        }
    }

    private func save() {
        guard let imageData else { return }
        let weightAtTime = weightStore.latestEntry?.weightKg
        photoStore.add(
            imageData: imageData,
            side: side,
            date: date,
            weightKgAtTime: weightAtTime,
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

private struct ProgressPhotoViewer: View {
    let photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressPhotoStore.self) private var photoStore
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image = photoStore.loadImage(for: photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("Image not available")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.side.displayName)
                                .font(.system(.headline, design: .rounded))
                            Text(photo.date, style: .date)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                            if let w = photo.weightKgAtTime {
                                Text(String(format: "%.1f kg at the time", w))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            if let n = photo.notes {
                                Text(n)
                                    .font(.system(.subheadline, design: .rounded))
                                    .padding(.top, 4)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog(
                "Delete this photo?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete photo", role: .destructive) {
                    photoStore.delete(photo)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
