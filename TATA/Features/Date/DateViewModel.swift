import Combine
import Foundation
import Photos

enum TimelineGrouping: String, CaseIterable, Identifiable {
    case date
    case week
    case month

    static let storageKey = "timelineGrouping"

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }
}

struct TimelineMediaPeriod: Identifiable {
    let date: Date
    let assets: [PHAsset]

    var id: Date {
        date
    }

    var photoCount: Int {
        assets.filter { $0.mediaType == .image }.count
    }

    var videoCount: Int {
        assets.filter { $0.mediaType == .video }.count
    }
}

struct TimelineMediaSection: Identifiable {
    let date: Date
    let periods: [TimelineMediaPeriod]

    var id: Date {
        date
    }
}

@MainActor
final class DateViewModel: ObservableObject {
    @Published private(set) var sections: [TimelineMediaSection] = []

    private let calendar = Calendar.autoupdatingCurrent

    init() {
        reload(grouping: .date)
    }

    func reload(grouping: TimelineGrouping) {
        let assets = PhotoService.shared.fetchAssets()
        let datedAssets = (0..<assets.count).compactMap { index -> (Date, PHAsset)? in
            let asset = assets.object(at: index)

            guard let creationDate = asset.creationDate else {
                return nil
            }

            return (periodStart(for: creationDate, grouping: grouping), asset)
        }
        let assetsByPeriod = Dictionary(grouping: datedAssets, by: \.0)
        let periods = assetsByPeriod.map { date, assets in
            TimelineMediaPeriod(date: date, assets: assets.map(\.1))
        }
        let periodsBySection = Dictionary(
            grouping: periods,
            by: { sectionStart(for: $0.date, grouping: grouping) }
        )

        sections = periodsBySection.map { date, periods in
            TimelineMediaSection(
                date: date,
                periods: periods.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func periodStart(
        for date: Date,
        grouping: TimelineGrouping
    ) -> Date {
        switch grouping {
        case .date:
            calendar.startOfDay(for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }

    private func sectionStart(
        for date: Date,
        grouping: TimelineGrouping
    ) -> Date {
        switch grouping {
        case .date, .week:
            calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .month:
            calendar.dateInterval(of: .year, for: date)?.start ?? date
        }
    }
}
