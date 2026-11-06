import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UserGuideSheet.hasCompletedStorageKey) private var hasCompletedUserGuide = false

    @Binding var photoAuthorizationStatus: PHAuthorizationStatus
    @State private var isRequestingAuthorization = false

    var body: some View {
        ScrollView {
            UserGuideContent(title: "Welcome to TATA")
        }
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Text(descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    ActionFeedback.light()
                    handlePhotoPermission()
                } label: {
                    HStack(spacing: 10) {
                        if isRequestingAuthorization { ProgressView().tint(.white) }
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .font(.headline)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: 340)
                .disabled(isRequestingAuthorization || photoAuthorizationStatus == .restricted)

                Button {
                    ActionFeedback.light()
                    hasCompletedUserGuide = true
                    dismiss()
                } label: {
                    Text("Not Now")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: 340)
                .disabled(isRequestingAuthorization)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .interactiveDismissDisabled(isRequestingAuthorization)
        .onAppear {
            updateAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                updateAuthorizationStatus()
            }
        }
    }

    private var buttonTitle: String {
        switch photoAuthorizationStatus {
        case .denied:
            return "Open Settings"

        case .restricted:
            return "Unavailable"

        default:
            return "Allow Photo Access"
        }
    }

    private var descriptionText: String {
        switch photoAuthorizationStatus {
        case .denied:
            return "Photo access is required. Enable it in Settings to continue."

        case .restricted:
            return "Photo access is restricted. Please check your device settings."

        default:
            return "Allow access to your photo library so we can organize your memories."
        }
    }

    private func handlePhotoPermission() {
        guard !isRequestingAuthorization else { return }

        switch photoAuthorizationStatus {

        case .notDetermined:
            hasCompletedUserGuide = true
            isRequestingAuthorization = true
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    isRequestingAuthorization = false
                    updateStatus(status)
                }
            }

        case .denied:
            hasCompletedUserGuide = true
            openSettings()

        case .authorized, .limited:
            updateAuthorizationStatus()

        case .restricted:
            break

        @unknown default:
            break
        }
    }

    private func updateAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        updateStatus(status)
    }

    private func updateStatus(_ status: PHAuthorizationStatus) {
        photoAuthorizationStatus = status
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

struct UserGuideSheet: View {
    static let hasCompletedStorageKey = "hasCompletedUserGuide"

    let onComplete: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        ScrollView {
            UserGuideContent(title: "User Guide")
        }
        .scrollEdgeEffectStyle(.hard, for: .bottom)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Button {
                ActionFeedback.light()
                onComplete()
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .font(.headline)
            .buttonBorderShape(.capsule)
            .frame(maxWidth: 340)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct UserGuideContent: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title.bold())
                Text("A simpler way to review your photos and videos.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 24) {
                OnboardingStep(symbol: "arrow.left.arrow.right", title: "Browse",
                               detail: "Swipe left or right to review your media.")
                OnboardingStep(symbol: "arrow.up", title: "Set Aside",
                               detail: "Swipe up to add media to Pending Deletions. Review it before confirming deletion.")
                OnboardingStep(symbol: "arrow.uturn.backward", title: "Undo",
                               detail: "Undo the last item you added to Pending Deletions in Swipe.")
                OnboardingStep(symbol: "hand.tap", title: "Take a Closer Look",
                               detail: "Tap to hide the controls, then pinch to zoom and drag to move. Tap again to show the controls.")
            }
        }
        .frame(maxWidth: 440)
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingView(photoAuthorizationStatus: .constant(.notDetermined))
}


private struct OnboardingStep: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
