import SwiftUI

struct SettingsView: View {
    @ObservedObject var deletionManager: DeletionManager

    @AppStorage(TimelineGrouping.storageKey)
    private var timelineGrouping = TimelineGrouping.date.rawValue

    @AppStorage(MediaPlaybackMuteController.defaultMuteKey)
    private var muteMediaByDefault = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timeline span")

                        Text("Choose how media is grouped in Timeline.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Timeline span", selection: $timelineGrouping) {
                            ForEach(TimelineGrouping.allCases) { grouping in
                                Text(grouping.title).tag(grouping.rawValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    Toggle(
                        "Mute videos and Live Photos by default",
                        isOn: $muteMediaByDefault
                    )
                }

                Section {
                    LabeledContent("Deleted Media") {
                        Text(deletionManager.deletedMediaCount, format: .number)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Version", value: versionString)

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
    SettingsView(deletionManager: DeletionManager())
}
