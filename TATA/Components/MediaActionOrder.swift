import SwiftUI

enum MediaAction: String, CaseIterable, Identifiable {
    case playback, favorite, share, undo, delete, pendingDeletions

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

    var body: some View {
        List {
            Section {
                ForEach(MediaAction.ordered(storedOrder)) { action in
                    Label(action.title, systemImage: action.symbol)
                }
                .onMove { source, destination in
                    var actions = MediaAction.ordered(storedOrder)
                    actions.move(fromOffsets: source, toOffset: destination)
                    storedOrder = actions.map(\.rawValue).joined(separator: ",")
                }
            } footer: {
                Text("Touch and hold a row to reorder. Only actions available for the current media are shown.")
            }

            Section {
                Button("Restore Default Order") {
                    storedOrder = MediaAction.defaultOrder
                }
                .foregroundStyle(.blue)
            }
        }
        .navigationTitle("Action Button Order")
        .navigationBarTitleDisplayMode(.inline)
    }
}
