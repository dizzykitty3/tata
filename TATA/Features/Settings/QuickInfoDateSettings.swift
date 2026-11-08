import SwiftUI

private enum DateOrder: String, CaseIterable {
    case yearFirst = "Year, Month, Day"
    case monthFirst = "Month, Day, Year"
    case dayFirst = "Day, Month, Year"

    func fields(includeYear: Bool, month: String) -> [String] {
        let fields: [String]
        switch self {
        case .yearFirst: fields = ["yyyy", month, "dd"]
        case .monthFirst: fields = [month, "dd", "yyyy"]
        case .dayFirst: fields = ["dd", month, "yyyy"]
        }
        return fields.filter { includeYear || $0 != "yyyy" }
    }
}

struct QuickInfoDatePreferences: DynamicProperty {
    static func initializeFromSystem() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "quickInfoDateOrder") == nil else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let fields = (formatter.dateFormat ?? "").replacingOccurrences(
            of: "'[^']*'", with: "", options: .regularExpression)
        let order: DateOrder
        switch fields.first(where: { "yYMLd".contains($0) }) {
        case "d": order = .dayFirst
        case "M", "L": order = .monthFirst
        default: order = .yearFirst
        }
        let separator = ["-", "/", "."].first(where: { fields.contains($0) }) ?? "-"
        defaults.set(separator, forKey: "quickInfoDateSeparator")
        defaults.set(order.rawValue, forKey: "quickInfoDateOrder")
        defaults.set(formatter.dateFormat, forKey: "quickInfoInitialPattern")
        defaults.set(order.rawValue, forKey: "quickInfoInitialOrder")
        defaults.set(separator, forKey: "quickInfoInitialSeparator")
    }

    @AppStorage("quickInfoDateOrder") fileprivate var order = DateOrder.yearFirst
    @AppStorage("quickInfoDateSeparator") var separator = "-"
    @AppStorage("quickInfoAbbreviateMonth") var abbreviateMonth = false
    @AppStorage("quickInfoShowCurrentYear") var showCurrentYear = true

    func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        if abbreviateMonth {
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
        }
        let includeYear = showCurrentYear || !formatter.calendar.isDate(date, equalTo: .now, toGranularity: .year)
        if abbreviateMonth {
            formatter.dateFormat = includeYear ? "MMM d, yyyy" : "MMM d"
            return formatter.string(from: date)
        }
        let defaults = UserDefaults.standard
        if order.rawValue == defaults.string(forKey: "quickInfoInitialOrder"),
           separator == defaults.string(forKey: "quickInfoInitialSeparator"),
           let pattern = defaults.string(forKey: "quickInfoInitialPattern") {
            formatter.dateFormat = includeYear ? pattern : pattern.replacingOccurrences(
                of: #"^[^MdL]*[yY]+[^MdL]*|[^MdL]*[yY]+[^MdL]*$"#, with: "", options: .regularExpression)
            return formatter.string(from: date)
        }
        formatter.dateFormat = order.fields(includeYear: includeYear, month: "MM").joined(separator: separator)
        return formatter.string(from: date)
    }
}

struct QuickInfoSettings: View {
    @AppStorage(MediaInfoOverlay.preferenceKey) private var showQuickInfo = true
    private var visibility = QuickInfoVisibility()

    var body: some View {
        Form {
            Section {
                Toggle("Show Quick Info", isOn: $showQuickInfo)
            }
            if showQuickInfo {
                Section("Visible Information") {
                    Toggle("Date", isOn: visibility.$date)
                    Toggle("File Size and Format", isOn: visibility.$fileDetails)
                    Toggle("Muted Status", isOn: visibility.$mutedStatus)
                    Toggle("Albums", isOn: visibility.$albums)
                }
                if visibility.date {
                    QuickInfoDateFormatSection()
                }
            }
        }
        .navigationTitle("Quick Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickInfoDateFormatSection: View {
    private var preferences = QuickInfoDatePreferences()

    var body: some View {
        Section("Date Format") {
            Toggle("Use Abbreviated Month Names", isOn: preferences.$abbreviateMonth)
            if !preferences.abbreviateMonth {
                Picker("Date Order", selection: preferences.$order) {
                    ForEach(DateOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Separator", selection: preferences.$separator) {
                    ForEach(["-", "/", "."], id: \.self) { Text($0).tag($0) }
                }
            }
            Toggle("Show Current Year", isOn: preferences.$showCurrentYear)
            LabeledContent("Preview") {
                ViewThatFits(in: .horizontal) {
                    HStack { previewBadges }
                    VStack(alignment: .trailing) { previewBadges }
                }
            }
        }
    }

    private var previewBadges: some View {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: .now)
        return ForEach([year, year + 1], id: \.self) { year in
            if let date = calendar.date(from: DateComponents(year: year, month: 11, day: 4)) {
                Text(preferences.display(date))
                    .font(.caption)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
