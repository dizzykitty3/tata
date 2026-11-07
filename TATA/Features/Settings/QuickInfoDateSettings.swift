import SwiftUI

private enum DateOrder: String, CaseIterable {
    case yearFirst = "Year, Month, Day"
    case monthFirst = "Month, Day, Year"
    case dayFirst = "Day, Month, Year"

    func fields(includeYear: Bool) -> [String] {
        let fields: [String]
        switch self {
        case .yearFirst: fields = ["yyyy", "MM", "dd"]
        case .monthFirst: fields = ["MM", "dd", "yyyy"]
        case .dayFirst: fields = ["dd", "MM", "yyyy"]
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
    @AppStorage("quickInfoShowCurrentYear") var showCurrentYear = true

    func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        let includeYear = showCurrentYear || !formatter.calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let defaults = UserDefaults.standard
        if includeYear, order.rawValue == defaults.string(forKey: "quickInfoInitialOrder"),
           separator == defaults.string(forKey: "quickInfoInitialSeparator"),
           let pattern = defaults.string(forKey: "quickInfoInitialPattern") {
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
        formatter.dateFormat = order.fields(includeYear: includeYear).joined(separator: separator)
        return formatter.string(from: date)
    }
}

struct QuickInfoDateSettings: View {
    private var preferences = QuickInfoDatePreferences()

    var body: some View {
        Form {
            Section {
                Picker("Date Order", selection: preferences.$order) {
                    ForEach(DateOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Separator", selection: preferences.$separator) {
                    ForEach(["-", "/", "."], id: \.self) { Text($0).tag($0) }
                }
                Toggle("Show Current Year", isOn: preferences.$showCurrentYear)
            }
            LabeledContent("Preview", value: preferences.display(.now))
        }
        .navigationTitle("Quick Info Date Format")
        .navigationBarTitleDisplayMode(.inline)
    }
}
