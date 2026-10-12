//
//  OnboardingView.swift
//  TATA
//
//  Created by Theo on 8/2/26.
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasGrantedPhotoAccess")
    private var hasGrantedPhotoAccess = false

    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(descriptionText)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                handlePhotoPermission()
            } label: {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(height: ActionButtonLayout.height)
            .disabled(photoAuthorizationStatus == .restricted)
        }
        .padding(24)
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
            return "Continue"
        }
    }

    private var descriptionText: String {
        switch photoAuthorizationStatus {
        case .denied:
            return "Photo access is required.\nEnable it in Settings to continue."

        case .restricted:
            return "Photo access is restricted.\nPlease check your device settings."

        default:
            return "Allow access to your photo library\nso we can organize your memories."
        }
    }

    private func handlePhotoPermission() {
        switch photoAuthorizationStatus {

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    updateStatus(status)
                }
            }

        case .denied:
            openSettings()

        case .authorized, .limited:
            hasGrantedPhotoAccess = true

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

        switch status {
        case .authorized, .limited:
            hasGrantedPhotoAccess = true

        default:
            break
        }
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("User Guide")
                        .font(.largeTitle.weight(.bold))

                    VStack(alignment: .leading, spacing: 24) {
                        GuideStep(
                            systemImage: "arrow.up",
                            text: "Swipe up to delete."
                        )

                        GuideStep(
                            systemImage: "arrow.left.arrow.right",
                            text: "Swipe left or right to browse."
                        )

                        GuideStep(
                            systemImage: "arrow.uturn.backward",
                            text: "Undo to cancel your last action."
                        )
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("OK")
                        .padding(.horizontal, 28)
                        .frame(height: ActionButtonLayout.height)
                }
                .font(.body.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
                .buttonBorderShape(.capsule)
                .padding(.vertical, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct GuideStep: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingView()
}
