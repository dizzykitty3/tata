import SwiftUI

struct SettingsView: View {
    @ObservedObject var deletionManager: DeletionManager
    let presentUserGuide: () -> Void
    let clearKeptMediaAndReturnToLatest: () async -> Void
    @EnvironmentObject private var blockingAction: BlockingActionController

    @AppStorage(TimelineGrouping.storageKey)
    private var timelineGrouping = TimelineGrouping.date.rawValue

    @ObservedObject private var muteController = MediaPlaybackMuteController.shared

    @AppStorage("autoplayLivePhotos")
    private var autoplayLivePhotos = true

    @AppStorage("autoplayVideos")
    private var autoplayVideos = true

    @AppStorage(FavoriteDeletionConfirmation.settingKey)
    private var confirmBeforeDeletingFavorites = true

    @AppStorage(SwipeViewModel.rememberKeptMediaKey)
    private var rememberKeptMedia = false

    @AppStorage("tapToHideMediaUI") private var tapToHideMediaUI = true

    @State private var isConfirmingClearKeptMedia = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Media") {
                    Toggle("Autoplay Live Photos", isOn: $autoplayLivePhotos)

                    Toggle("Autoplay Videos", isOn: $autoplayVideos)

                    Toggle("Mute Built-in Audio by Default", isOn: $muteController.muteBuiltInByDefault)
                    Toggle("Mute External Audio by Default", isOn: $muteController.muteExternalByDefault)

                    Toggle("Confirm Before Deleting Favorites", isOn: $confirmBeforeDeletingFavorites)

                    Picker("Timeline Span", selection: $timelineGrouping) {
                        ForEach(TimelineGrouping.allCases) { grouping in
                            Text(grouping.title).tag(grouping.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Toggle("Remember Kept Media", isOn: $rememberKeptMedia)

                    if !rememberKeptMedia {
                        Button("Clear Kept Media & Return to Latest") {
                            ActionFeedback.light()
                            isConfirmingClearKeptMedia = true
                        }
                        .confirmationDialog(
                            "Clear Kept Media & Return to Latest?",
                            isPresented: $isConfirmingClearKeptMedia,
                            titleVisibility: .hidden
                        ) {
                            Button("Clear History & Return to Latest", role: .destructive) {
                                ActionFeedback.light()
                                blockingAction.run(message: "Clearing Kept Media…") {
                                    await clearKeptMediaAndReturnToLatest()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will clear your kept media history and return Swipe to the newest available media. This cannot be undone. No photos or videos will be deleted.")
                        }
                    }
                } header: {
                    Text("Browsing History")
                } footer: {
                    Text("Remember media you swipe left to keep, so you can focus on unreviewed items next time.")
                }

                Section("Interface") {
                    Toggle("Tap to Hide UI", isOn: $tapToHideMediaUI)

                    NavigationLink("Action Buttons") {
                        MediaActionOrderView()
                    }

                    Button("Show User Guide") {
                        ActionFeedback.light()
                        presentUserGuide()
                    }
                }

                Section("Stats & About") {
                    LabeledContent("Deleted Media") {
                        CrossfadeText(text: deletionManager.deletedMediaCount.formatted())
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Storage Saved") {
                        CrossfadeText(text: MediaFileFormatting.size(deletionManager.deletedMediaBytes))
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Version", value: versionString)

                    Link(
                        "GitHub Repository",
                        destination: URL(string: "https://github.com/dizzykitty3/tata")!
                    )

                    Button("Open App Settings") {
                        ActionFeedback.light()
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
        presentUserGuide: {},
        clearKeptMediaAndReturnToLatest: {}
    )
    .environmentObject(BlockingActionController())
}
