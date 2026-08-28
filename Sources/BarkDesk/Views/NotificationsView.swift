import BarkCore
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            List(selection: $model.selectedRecordID) {
                ForEach(groupedRecords, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.records) { record in
                            HistoryRow(record: record).tag(record.id)
                                .contextMenu {
                                    Button("Copy Message") { model.copy(record.body) }
                                    if let url = record.url { Button("Copy URL") { model.copy(url) } }
                                    Button("Resend") { Task { await model.resend(record) } }
                                    Divider()
                                    Button("Delete", role: .destructive) { Task { await model.delete(record) } }
                                }
                        }
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340)
            .searchable(text: $model.searchText, prompt: "Search history")
            .onSubmit(of: .search) { Task { await model.refreshHistory() } }
            .onChange(of: model.searchText) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    await model.refreshHistory()
                }
            }

            Group {
                if let record = model.selectedRecord {
                    HistoryDetail(record: record)
                } else {
                    ContentUnavailableView("No Notification Selected", systemImage: "bell")
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Notifications")
        .toolbar {
            Button { Task { await model.refreshHistory() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
    }

    private var groupedRecords: [(title: String, records: [NotificationRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: model.records) { record -> String in
            if calendar.isDateInToday(record.createdAt) { return "Today" }
            if calendar.isDateInYesterday(record.createdAt) { return "Yesterday" }
            return "Earlier"
        }
        return ["Today", "Yesterday", "Earlier"].compactMap { title in
            groups[title].map { (title, $0) }
        }
    }
}

private struct HistoryRow: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.deliveryStatus == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.deliveryStatus == .success ? .green : .red)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title?.nilIfEmpty ?? "Notification").fontWeight(.medium).lineLimit(1)
                Text(record.body).foregroundStyle(.secondary).lineLimit(2)
                Text(record.createdAt, style: .time).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct HistoryDetail: View {
    @EnvironmentObject private var model: AppModel
    let record: NotificationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.title?.nilIfEmpty ?? "Notification").font(.largeTitle).fontWeight(.semibold)
                        if let subtitle = record.subtitle { Text(subtitle).font(.title3).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Label(record.deliveryStatus.rawValue.capitalized,
                          systemImage: record.deliveryStatus == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(record.deliveryStatus == .success ? .green : .red)
                }
                Text(record.body).font(.body).textSelection(.enabled)
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 10) {
                    detailRow("Sent", record.createdAt.formatted(date: .abbreviated, time: .standard))
                    detailRow("Source", record.source.rawValue.capitalized)
                    detailRow("Group", record.group ?? "—")
                    detailRow("Level", record.level?.displayName ?? "—")
                    detailRow("Sound", record.sound ?? "Default")
                    if let code = record.httpStatusCode { detailRow("HTTP", String(code)) }
                    if let error = record.errorMessage { detailRow("Error", error) }
                    if let command = record.metadata?.command { detailRow("Command", command) }
                    if let duration = record.metadata?.duration { detailRow("Duration", duration.formatted(.number.precision(.fractionLength(1))) + " s") }
                }
                HStack {
                    Button("Resend") { Task { await model.resend(record) } }.buttonStyle(.borderedProminent)
                    Button("Copy Message") { model.copy(record.body) }
                    if let raw = record.url, let url = URL(string: raw) {
                        Link("Open URL", destination: url)
                    }
                    Spacer()
                    Button("Delete", role: .destructive) { Task { await model.delete(record) } }
                }
            }
            .padding(28)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }
}
