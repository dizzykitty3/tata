import SwiftUI

struct SettingsView: View {
    @AppStorage(MediaPlaybackMuteController.defaultMuteKey)
    private var muteMediaByDefault = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Mute videos and Live Photos by default",
                        isOn: $muteMediaByDefault
                    )
                }

                Section {
                    Button("Open App Settings") {
                        openSettings()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
}
