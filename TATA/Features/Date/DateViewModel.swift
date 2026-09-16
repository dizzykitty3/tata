import Combine
import Foundation
import Photos

struct DateMediaDay: Identifiable {
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

struct DateMediaMonth: Identifiable {
    let date: Date
    let days: [DateMediaDay]

    var id: Date {
        date
    }
}

@MainActor
final class DateViewModel: ObservableObject {
    @Published private(set) var months: [DateMediaMonth] = []

    private let calendar = Calendar.autoupdatingCurrent

    init() {
        reload()
    }

    func reload() {
        let assets = PhotoService.shared.fetchAssets()
        let datedAssets = (0..<assets.count).compactMap { index -> (Date, PHAsset)? in
            let asset = assets.object(at: index)

            guard let creationDate = asset.creationDate else {
                return nil
            }

            return (calendar.startOfDay(for: creationDate), asset)
        }
        let assetsByDay = Dictionary(grouping: datedAssets, by: \.0)
        let days = assetsByDay.map { date, assets in
            DateMediaDay(date: date, assets: assets.map(\.1))
        }
        let daysByMonth = Dictionary(
            grouping: days,
            by: { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date))! }
        )

        months = daysByMonth.map { date, days in
            DateMediaMonth(
                date: date,
                days: days.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.date > $1.date }
    }
}
