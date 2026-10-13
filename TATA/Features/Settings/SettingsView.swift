import SwiftUI

struct SettingsView: View {
    @ObservedObject var deletionManager: DeletionManager
    let presentUserGuide: () -> Void

    @AppStorage(TimelineGrouping.storageKey)
    private var timelineGrouping = TimelineGrouping.date.rawValue

    @AppStorage(MediaPlaybackMuteController.defaultMuteKey)
    private var muteMediaByDefault = false

    @AppStorage("autoplayLivePhotos")
    private var autoplayLivePhotos = true

    @AppStorage("autoplayVideos")
    private var autoplayVideos = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Autoplay Live Photos", isOn: $autoplayLivePhotos)

                    Toggle("Autoplay Videos", isOn: $autoplayVideos)

                    Toggle(
                        "Mute By Default",
                        isOn: $muteMediaByDefault
                    )

                    Picker("Timeline Span", selection: $timelineGrouping) {
                        ForEach(TimelineGrouping.allCases) { grouping in
                            Text(grouping.title).tag(grouping.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    NavigationLink("Action Button Order") {
                        MediaActionOrderView()
                    }
                }

                Section {
                    Button("Show User Guide", action: presentUserGuide)
                }

                Section {
                    LabeledContent("Deleted Media") {
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
        presentUserGuide: {}
    )
}
