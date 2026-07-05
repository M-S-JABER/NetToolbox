import SwiftUI
import Observation

/// Unix epoch ↔ human date conversion (seconds or milliseconds auto-detected).
enum TimestampTools {
    static func date(fromEpoch text: String) -> Date? {
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        let seconds = abs(value) > 1_000_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }

    static func utcString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter.string(from: date)
    }

    static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

@MainActor
@Observable
final class TimestampViewModel {
    var epochText = ""
    var pickedDate = Date(timeIntervalSince1970: 0)

    var parsed: Date? { TimestampTools.date(fromEpoch: epochText) }
}

struct TimestampTool: NetworkTool {
    let id = "timestamp"
    let titleKey = L10n("tool.timestamp.title")
    let subtitleKey = L10n("tool.timestamp.subtitle")
    let systemImage = "clock"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(TimestampView()) }
}

struct TimestampView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = TimestampViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                epochSection
                dateSection
                Text(L10n("timestamp.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.timestamp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var epochSection: some View {
        SectionCard(title: L10n("timestamp.section.fromEpoch"), systemImage: "clock.arrow.circlepath") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("timestamp.input.epoch"), text: $viewModel.epochText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .environment(\.layoutDirection, .leftToRight)
                Button(L10nString("timestamp.now")) {
                    viewModel.epochText = String(Int(Date().timeIntervalSince1970))
                }
                .buttonStyle(.bordered)
            }
            if let date = viewModel.parsed {
                labeled(L10n("timestamp.utc"), TimestampTools.utcString(date))
                labeled(L10n("timestamp.local"), date.formatted(date: .abbreviated, time: .standard))
                labeled(L10n("timestamp.iso"), TimestampTools.iso8601(date))
            } else if !viewModel.epochText.isEmpty {
                Text(L10n("timestamp.invalid")).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var dateSection: some View {
        SectionCard(title: L10n("timestamp.section.toEpoch"), systemImage: "calendar") {
            DatePicker(L10nString("timestamp.pick"), selection: $viewModel.pickedDate)
                .datePickerStyle(.compact)
            labeled(L10n("timestamp.epochSeconds"), String(Int(viewModel.pickedDate.timeIntervalSince1970)))
            labeled(L10n("timestamp.epochMillis"), String(Int(viewModel.pickedDate.timeIntervalSince1970 * 1000)))
        }
    }

    private func labeled(_ label: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            CopyableValue(value: value)
        }
    }
}
