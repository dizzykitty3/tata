import SwiftUI
import Photos

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var photoAuthorizationStatus =
        PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        Group {
            switch photoAuthorizationStatus {
            case .authorized, .limited:
                ContentView()

            default:
                PhotoAccessWelcomeView(photoAuthorizationStatus: $photoAuthorizationStatus)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                updateAuthorizationStatus()
            }
        }
    }

    private func updateAuthorizationStatus() {
        photoAuthorizationStatus =
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
}

/// Keep a usable entry point behind the first-launch sheet if access is deferred.
private struct PhotoAccessWelcomeView: View {
    @Binding var photoAuthorizationStatus: PHAuthorizationStatus
    @State private var showsOnboarding = true

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to TATA")
                .font(.largeTitle.bold())
            Text("Connect your photo library to start reviewing your media.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get Started") { showsOnboarding = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showsOnboarding) {
            OnboardingView(photoAuthorizationStatus: $photoAuthorizationStatus)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}
