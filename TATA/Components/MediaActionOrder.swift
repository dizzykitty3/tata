import SwiftUI

enum MediaAction: String, CaseIterable, Identifiable {
    case playback, favorite, share, undo, delete, pendingDeletions

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
        return result + allCases.filter { !result.contains($0) }
    }
}

struct MediaActionOrderView: View {
    @AppStorage(MediaAction.storageKey) private var storedOrder = MediaAction.defaultOrder

    @AppStorage(MediaAction.hiddenStorageKey) private var hiddenActions = ""

    @State private var isConfirmingRestoreDefaults = false

    var body: some View {
        List {
            Section {
                ForEach(MediaAction.ordered(storedOrder)) { action in
                    Toggle(isOn: Binding(
                        get: { action.isVisible(hidden: hiddenActions) },
                        set: { isVisible in
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
                    var actions = MediaAction.ordered(storedOrder)
                    actions.move(fromOffsets: source, toOffset: destination)
                    storedOrder = actions.map(\.rawValue).joined(separator: ",")
                }
            } footer: {
                Text("Touch and hold a row to reorder, or use the switches to choose which buttons appear. Play / Pause and View Pending Deletions are always enabled. Buttons appear only when their actions are available.")
            }

            Section {
                Button("Restore Defaults") {
                    isConfirmingRestoreDefaults = true
                }
                .foregroundStyle(.blue)
                .confirmationDialog(
                    "Restore Default Action Buttons?",
                    isPresented: $isConfirmingRestoreDefaults,
                    titleVisibility: .visible
                ) {
                    Button("Restore Defaults", role: .destructive) {
                        storedOrder = MediaAction.defaultOrder
                        hiddenActions = ""
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will enable all action buttons and restore their default order.")
                }
            }
        }
        .navigationTitle("Action Buttons")
        .navigationBarTitleDisplayMode(.inline)
    }
}
