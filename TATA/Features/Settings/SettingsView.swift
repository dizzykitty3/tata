import SwiftUI

struct SettingsView: View {
    @ObservedObject var deletionManager: DeletionManager
    let refreshMediaLibrary: () -> Void
    let isRefreshing: Bool
    let presentUserGuide: () -> Void

    @AppStorage(TimelineGrouping.storageKey)
    private var timelineGrouping = TimelineGrouping.date.rawValue

    @AppStorage(MediaPlaybackMuteController.defaultMuteKey)
    private var muteMediaByDefault = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Timeline span", selection: $timelineGrouping) {
                        ForEach(TimelineGrouping.allCases) { grouping in
                            Text(grouping.title).tag(grouping.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Toggle(
                        "Mute by default",
                        isOn: $muteMediaByDefault
                    )
                }

                Section {
                    Button("Refresh Media Library", action: refreshMediaLibrary)
                        .disabled(isRefreshing)
                } footer: {
                    Text(
                        "Check for additions and removals in Photos. This clears your Pending Deletions list."
                    )
                }

                Section {
                    Button("Show User Guide", action: presentUserGuide)
                }

                Section {
                    LabeledContent("Deleted media") {
                        Text(deletionManager.deletedMediaCount, format: .number)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Version", value: versionString)

                    Link(
                        "GitHub Repository",
                        destination: URL(string: "https://github.com/dizzykitty3/tata")!
                    )

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

    private var versionString: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView(
        deletionManager: DeletionManager(),
        refreshMediaLibrary: {},
        isRefreshing: false,
        presentUserGuide: {}
    )
}
