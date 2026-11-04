import SwiftUI

enum MediaAction: String, CaseIterable, Identifiable {
    case playback, mute, favorite, share, undo, delete, pendingDeletions

    static let showUnavailableKey = "showUnavailableMediaActions"
    static let hiddenStorageKey = "hiddenMediaActions"

    var isRequired: Bool { self == .playback || self == .pendingDeletions }

    func isVisible(hidden: String) -> Bool {
        isRequired || !hidden.split(separator: ",").contains(Substring(rawValue))
    }

    static func visibleActions(order: String, hidden: String) -> [MediaAction] {
        ordered(order).filter { $0.isVisible(hidden: hidden) }
    }

    static let storageKey = "mediaActionOrder"
    static let defaultOrder = allCases.map(\.rawValue).joined(separator: ",")

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playback: "Play / Pause"
        case .mute: "Mute / Unmute"
        case .favorite: "Favorite"
        case .share: "Share"
        case .undo: "Undo"
        case .delete: "Delete"
        case .pendingDeletions: "View Pending Deletions"
        }
    }

    var symbol: String {
        switch self {
        case .playback: "playpause"
        case .mute: "speaker.slash"
        case .favorite: "heart"
        case .share: "square.and.arrow.up"
        case .undo: "arrow.uturn.backward"
        case .delete: "trash"
        case .pendingDeletions: "trash.circle"
        }
    }

    static func ordered(_ stored: String) -> [MediaAction] {
        var result: [MediaAction] = []
        for value in stored.split(separator: ",") {
            if let action = MediaAction(rawValue: String(value)), !result.contains(action) {
                result.append(action)
            }
        }
        if !result.contains(.mute), let playbackIndex = result.firstIndex(of: .playback) {
            result.insert(.mute, at: playbackIndex + 1)
        }
        return result + allCases.filter { !result.contains($0) }
    }
}

struct MediaActionOrderView: View {
    @EnvironmentObject private var blockingAction: BlockingActionController
    @AppStorage(MediaAction.storageKey) private var storedOrder = MediaAction.defaultOrder

    @AppStorage(MediaAction.hiddenStorageKey) private var hiddenActions = ""

    @AppStorage(MediaAction.showUnavailableKey) private var showUnavailable = false

    @State private var isConfirmingRestoreDefaults = false

    var body: some View {
        List {
            Section {
                ForEach(MediaAction.ordered(storedOrder)) { action in
                    Toggle(isOn: Binding(
                        get: { action.isVisible(hidden: hiddenActions) },
                        set: { isVisible in
                            ActionFeedback.light()
                            var hidden = Set(hiddenActions.split(separator: ",").map(String.init))
                            if isVisible || action.isRequired {
                                hidden.remove(action.rawValue)
                            } else {
                                hidden.insert(action.rawValue)
                            }
                            hiddenActions = hidden.sorted().joined(separator: ",")
                        }
                    )) {
                        Label(action.title, systemImage: action.symbol)
                    }
                    .disabled(action.isRequired)
                }
                .onMove { source, destination in
                    ActionFeedback.light()
                    var actions = MediaAction.ordered(storedOrder)
                    actions.move(fromOffsets: source, toOffset: destination)
                    storedOrder = actions.map(\.rawValue).joined(separator: ",")
                }
            } footer: {
                Text("Touch and hold a row to reorder.")
            }

            Section {
                Toggle("Show Unavailable Buttons", isOn: $showUnavailable)
            } footer: {
                Text("Keep selected buttons visible and dim them when their actions are unavailable.")
            }

            Section {
                Button("Restore Defaults") {
                    ActionFeedback.light()
                    isConfirmingRestoreDefaults = true
                }
                .foregroundStyle(.blue)
                .confirmationDialog(
                    "Restore Default Action Buttons?",
                    isPresented: $isConfirmingRestoreDefaults,
                    titleVisibility: .hidden
                ) {
                    Button("Restore Defaults", role: .destructive) {
                        ActionFeedback.light()
                        blockingAction.run(message: "Restoring Defaults…") {
                            storedOrder = MediaAction.defaultOrder
                            hiddenActions = ""
                            showUnavailable = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will enable all action buttons and restore their default order. Unavailable buttons will be hidden.")
                }
            }
        }
        .navigationTitle("Action Buttons")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UnavailableMediaActionButton: View {
    let action: MediaAction

    var body: some View {
        Button {} label: {
            if action == .pendingDeletions {
                PendingDeletionCountLabel(count: 0)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(height: ActionButtonLayout.height)
            } else {
                Image(systemName: action == .playback ? "play.fill" : action.symbol)
                    .font(.title3)
                    .frame(width: ActionButtonLayout.height, height: ActionButtonLayout.height)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(true)
        .accessibilityLabel(action.title)
    }
}
