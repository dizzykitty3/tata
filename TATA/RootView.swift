//
//  RootView.swift
//  TATA
//
//  Created by Theo on 8/2/26.
//

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
                OnboardingView(photoAuthorizationStatus: $photoAuthorizationStatus)
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
