import PhotosUI
import SwiftUI
import UIKit

private struct PendingCapture: Identifiable {
    let id = UUID()
    let image: UIImage
    let subject: SubjectMode
}

private struct HomeAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Lumen home screen: pick a subject, then capture or choose an image.
struct HomeView: View {
    @State private var selectedSubject: SubjectMode = .universal
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingCapture: PendingCapture?
    @State private var isCameraPresented = false
    @State private var alert: HomeAlert?

    private let subjectColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        subjectGrid
                        actionPanel
                        privacyLine
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(item: $pendingCapture) { capture in
                AnalysisView(image: capture.image, subject: capture.subject) {
                    pendingCapture = nil
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraCaptureView { image in
                    isCameraPresented = false
                    pendingCapture = PendingCapture(image: image, subject: selectedSubject)
                } onCancel: {
                    isCameraPresented = false
                }
                .ignoresSafeArea()
            }
            .alert(item: $alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                LumenBrand.surfaceTint
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(LumenBrand.primary)
                Text(LumenBrand.appName)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(LumenBrand.secondary)
            }
            Text(LumenBrand.tagline)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subjectGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a subject")
                .font(.headline)
                .foregroundStyle(LumenBrand.secondary)

            LazyVGrid(columns: subjectColumns, spacing: 10) {
                ForEach(SubjectMode.allCases) { subject in
                    SubjectTile(
                        subject: subject,
                        isSelected: subject == selectedSubject
                    ) {
                        selectedSubject = subject
                    }
                }
            }
        }
    }

    private var actionPanel: some View {
        VStack(spacing: 12) {
            Button {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    alert = HomeAlert(
                        title: "Camera unavailable",
                        message: "Run on a physical iPhone to capture a new photo."
                    )
                    return
                }
                isCameraPresented = true
            } label: {
                Label("Take Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(LumenBrand.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(LumenBrand.secondary)
                    .background(
                        Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var privacyLine: some View {
        Label(LumenBrand.privacyReceipt, systemImage: "lock.shield.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                alert = HomeAlert(
                    title: "Image unavailable",
                    message: "The selected item could not be loaded as an image."
                )
                return
            }
            pendingCapture = PendingCapture(image: image, subject: selectedSubject)
            self.selectedPhotoItem = nil
        } catch {
            alert = HomeAlert(
                title: "Image unavailable",
                message: error.localizedDescription
            )
        }
    }
}

private struct SubjectTile: View {
    let subject: SubjectMode
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        Color(red: subject.accentRGB.r, green: subject.accentRGB.g, blue: subject.accentRGB.b)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: subject.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : accent)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                }
                Text(subject.title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : LumenBrand.secondary)
                Text(subject.subtitle)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(
                isSelected ? accent : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("SubjectTile_\(subject.rawValue)")
    }
}

#Preview {
    HomeView()
}
