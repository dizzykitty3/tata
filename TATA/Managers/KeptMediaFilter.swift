import Combine
import Foundation

enum KeptMediaFilter {
    static let enabledKey = "excludeKeptMediaFromTimelineAndCategories"

    static var excludedIdentifiers: Set<String> {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "rememberKeptMedia") else { return [] }
        guard defaults.object(forKey: enabledKey) as? Bool ?? true else { return [] }
        return Set(defaults.stringArray(forKey: "keptMediaIdentifiers") ?? [])
    }

    static var changes: AnyPublisher<Set<String>, Never> {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .map { _ in excludedIdentifiers }
            .prepend(excludedIdentifiers)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
