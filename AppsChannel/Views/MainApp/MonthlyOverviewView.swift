import SwiftUI
import AppKit

struct MonthlyOverviewView: View {
    @ObservedObject private var usageTracker = AppUsageTracker.shared

    @State private var selectedMonthKey: String = AppUsageTracker.currentMonthKey()
    @State private var selectedKindFilter: UsageItemKind? = nil
    @State private var isShowingResetAlert: Bool = false

    private var availableMonths: [String] {
        var months = usageTracker.availableMonthKeys()
        if !months.contains("all_time") {
            months.append("all_time")
        }
        return months
    }

    private var summary: MonthSummary {
        usageTracker.summary(for: selectedMonthKey)
    }

    private var filteredItems: [UsageEventRecord] {
        if let kind = selectedKindFilter {
            return summary.items.filter { $0.kind == kind }
        }
        return summary.items
    }

    private var maxCount: Int {
        summary.items.first?.count ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Header & Month Selector
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.cyan)

                        Text("Activity & Monthly Overview")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Text("Private, on-device insights into what you use AppsChannel for most.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Month Switcher Menu & Navigation
                monthSwitcher
            }
            .padding(.bottom, 2)

            // MARK: - Metric Highlight Cards
            highlightsGrid

            // MARK: - Category Proportional Distribution Bar
            if summary.totalActions > 0 {
                distributionSection
            }

            // MARK: - Category Filter Pills
            categoryFilterPills

            // MARK: - Ranked Leaderboard
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                leaderboardList
            }

            // MARK: - Privacy Banner & Reset
            footerPrivacyBanner
        }
        .padding(.horizontal, 4)
        .onAppear {
            if !availableMonths.contains(selectedMonthKey) {
                selectedMonthKey = availableMonths.first ?? AppUsageTracker.currentMonthKey()
            }
        }
        .alert("Clear Usage Analytics?", isPresented: $isShowingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All Data", role: .destructive) {
                usageTracker.resetAnalytics()
                SoundEffectsManager.shared.playAction()
            }
        } message: {
            Text("This will permanently reset all locally stored launch and action history across all months. This action cannot be undone.")
        }
    }

    // MARK: - Month Switcher Controls
    private var monthSwitcher: some View {
        HStack(spacing: 6) {
            // Previous Month Button
            Button(action: stepMonth(direction: 1)) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canStep(direction: 1))
            .opacity(canStep(direction: 1) ? 1.0 : 0.3)

            // Month Picker Menu
            Menu {
                ForEach(availableMonths, id: \.self) { monthKey in
                    Button(action: {
                        selectedMonthKey = monthKey
                        SoundEffectsManager.shared.playNavigation()
                    }) {
                        HStack {
                            Text(AppUsageTracker.monthDisplayTitle(from: monthKey))
                            if selectedMonthKey == monthKey {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)

                    Text(summary.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Next Month Button
            Button(action: stepMonth(direction: -1)) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canStep(direction: -1))
            .opacity(canStep(direction: -1) ? 1.0 : 0.3)
        }
    }

    private func canStep(direction: Int) -> Bool {
        guard let idx = availableMonths.firstIndex(of: selectedMonthKey) else { return false }
        let nextIdx = idx + direction
        return nextIdx >= 0 && nextIdx < availableMonths.count
    }

    private func stepMonth(direction: Int) -> () -> Void {
        return {
            guard let idx = availableMonths.firstIndex(of: selectedMonthKey) else { return }
            let nextIdx = idx + direction
            if nextIdx >= 0 && nextIdx < availableMonths.count {
                selectedMonthKey = availableMonths[nextIdx]
                SoundEffectsManager.shared.playNavigation()
            }
        }
    }

    // MARK: - Highlights Grid (3 Metric Cards)
    private var highlightsGrid: some View {
        HStack(spacing: 12) {
            // Card 1: Total Volume
            metricCard(
                title: "Total Actions",
                value: "\(summary.totalActions)",
                subtitle: summary.totalActions == 1 ? "1 action recorded" : "\(summary.items.count) distinct items",
                icon: "bolt.fill",
                accentColor: .cyan
            )

            // Card 2: #1 Top Feature
            metricCard(
                title: "Most Used Overall",
                value: summary.topItem?.name ?? "None",
                subtitle: summary.topItem != nil ? "\(summary.topItem!.count) times (\(summary.topItem!.kind.rawValue))" : "No usage recorded yet",
                icon: summary.topItem?.kind.iconName ?? "star.fill",
                accentColor: summary.topItem?.kind.accentColor ?? .orange
            )

            // Card 3: Window Snapping Actions
            let snapCount = summary.byKind[.windowAction] ?? 0
            metricCard(
                title: "Window Management",
                value: "\(snapCount)",
                subtitle: summary.topWindowAction != nil ? "Top: \(summary.topWindowAction!.name) (\(summary.topWindowAction!.count))" : "No snapping actions yet",
                icon: "macwindow.on.rectangle",
                accentColor: Color(red: 0.05, green: 0.52, blue: 1.0)
            )

            // Card 4: Top Application
            let appCount = summary.byKind[.application] ?? 0
            metricCard(
                title: "Apps Launched",
                value: "\(appCount)",
                subtitle: summary.topApp != nil ? "Top: \(summary.topApp!.name) (\(summary.topApp!.count))" : "No apps launched yet",
                icon: "app.fill",
                accentColor: .green
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Category Distribution Bar
    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Category Distribution")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("\(summary.totalActions) total")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Proportional Multi-Segment Bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(UsageItemKind.allCases, id: \.self) { kind in
                        let count = summary.byKind[kind] ?? 0
                        if count > 0 {
                            let width = max(4.0, (CGFloat(count) / CGFloat(max(1, summary.totalActions))) * geo.size.width)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(kind.accentColor)
                                .frame(width: width, height: 8)
                        }
                    }
                }
            }
            .frame(height: 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Filter Pills
    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // All Filter
                filterPill(
                    title: "All Items",
                    count: summary.items.count,
                    isSelected: selectedKindFilter == nil,
                    color: .cyan
                ) {
                    selectedKindFilter = nil
                    SoundEffectsManager.shared.playNavigation()
                }

                // Per-Kind Filters
                ForEach(UsageItemKind.allCases, id: \.self) { kind in
                    let count = summary.byKind[kind] ?? 0
                    filterPill(
                        title: kind.rawValue,
                        count: count,
                        isSelected: selectedKindFilter == kind,
                        color: kind.accentColor
                    ) {
                        selectedKindFilter = kind
                        SoundEffectsManager.shared.playNavigation()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(
        title: String,
        count: Int,
        isSelected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                Text("\(count)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(isSelected ? color.opacity(0.25) : Color.white.opacity(0.10), in: Capsule())
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.22) : Color.white.opacity(0.05))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leaderboard List
    private var leaderboardList: some View {
        VStack(spacing: 6) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                itemRow(item: item, rank: index + 1)
            }
        }
    }

    private func itemRow(item: UsageEventRecord, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank Badge
            rankBadge(rank: rank)

            // Kind Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.kind.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(item.kind.accentColor.opacity(0.3), lineWidth: 1))

                Image(systemName: item.kind.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.kind.accentColor)
            }

            // Name & Kind Tag
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(item.kind.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(item.kind.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(item.kind.accentColor.opacity(0.12), in: Capsule())
                }

                // Volume Progress Bar relative to #1 item
                GeometryReader { barProxy in
                    let ratio = CGFloat(item.count) / CGFloat(max(1, maxCount))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [item.kind.accentColor.opacity(0.7), item.kind.accentColor.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4.0, barProxy.size.width * ratio), height: 3.5)
                }
                .frame(height: 3.5)
            }

            Spacer(minLength: 16)

            // Count Badge & Last Active
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(item.count) \(item.count == 1 ? "time" : "times")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(relativeDateString(for: item.lastUsedAt))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func rankBadge(rank: Int) -> some View {
        let badgeColor: Color
        if rank == 1 {
            badgeColor = Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        } else if rank == 2 {
            badgeColor = Color(red: 0.85, green: 0.85, blue: 0.88) // Silver
        } else if rank == 3 {
            badgeColor = Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        } else {
            badgeColor = Color.white.opacity(0.4)
        }

        return Text("#\(rank)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(badgeColor)
            .frame(width: 28, alignment: .leading)
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))

            Text("No Activity Recorded for this Period")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            Text("Usage of apps, custom web channels, and window snapping actions will appear here automatically.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Privacy Banner & Reset
    private var footerPrivacyBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("100% Local & Private")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Analytics are stored on your device only in Application Support. No data is ever collected or shared.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button(action: {
                isShowingResetAlert = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear Analytics")
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Reset all locally tracked activity data")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.top, 6)
    }
}
