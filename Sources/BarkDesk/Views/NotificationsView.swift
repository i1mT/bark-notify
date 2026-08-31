import BarkCore
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.records.isEmpty {
                if model.searchText.isEmpty {
                    ContentUnavailableView {
                        Label("还没有发送记录", systemImage: "bell.slash")
                    } description: {
                        Text("从这台 Mac 的 BarkDesk App 发送的通知会显示在这里。")
                    } actions: {
                        Button("发送第一条通知") { model.selection = .compose }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView.search(text: model.searchText)
                }
            } else {
                historyBrowser
            }
        }
        .navigationTitle("通知记录")
        .toolbar {
            Button { Task { await model.refreshHistory() } } label: { Label("刷新", systemImage: "arrow.clockwise") }
        }
    }

    private var historyBrowser: some View {
        HSplitView {
            List(selection: $model.selectedRecordID) {
                ForEach(groupedRecords, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.records) { record in
                            HistoryRow(record: record).tag(record.id)
                                .contextMenu {
                                    Button("复制内容") { model.copy(record.body) }
                                    if let url = record.url { Button("复制链接") { model.copy(url) } }
                                    Button("重新发送") { Task { await model.resend(record) } }
                                    Divider()
                                    Button("删除", role: .destructive) { Task { await model.delete(record) } }
                                }
                        }
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 330, maxWidth: 420)
            .searchable(text: $model.searchText, prompt: "搜索标题、内容或分组")
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
                    ContentUnavailableView("请选择一条通知", systemImage: "bell")
                }
            }
            .frame(minWidth: 340, idealWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var groupedRecords: [(title: String, records: [NotificationRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: model.records) { record -> String in
            if calendar.isDateInToday(record.createdAt) { return "今天" }
            if calendar.isDateInYesterday(record.createdAt) { return "昨天" }
            return "更早"
        }
        return ["今天", "昨天", "更早"].compactMap { title in
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
                Text(record.title?.nilIfEmpty ?? "无标题通知").fontWeight(.medium).lineLimit(1)
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
                detailHeader
                Text(record.body).font(.body).textSelection(.enabled)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    detailRow("发送时间", record.createdAt.formatted(date: .abbreviated, time: .standard))
                    detailRow("来源", sourceName(record.source))
                    detailRow("分组", record.group ?? "—")
                    detailRow("提醒方式", record.level?.displayName ?? "—")
                    detailRow("提示音", record.sound ?? "默认")
                    if let code = record.httpStatusCode { detailRow("HTTP", String(code)) }
                    if let error = record.errorMessage { detailRow("错误", error) }
                    if let command = record.metadata?.command { detailRow("命令", command) }
                    if let duration = record.metadata?.duration { detailRow("耗时", duration.formatted(.number.precision(.fractionLength(1))) + " 秒") }
                }
                detailActions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            title
                .layoutPriority(1)
            Spacer(minLength: 12)
            deliveryStatus
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(record.title?.nilIfEmpty ?? "无标题通知")
                .font(.largeTitle)
                .fontWeight(.semibold)
            if let subtitle = record.subtitle {
                Text(subtitle).font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    private var deliveryStatus: some View {
        Label(
            record.deliveryStatus == .success ? "发送成功" : "发送失败",
            systemImage: record.deliveryStatus == .success ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .foregroundStyle(record.deliveryStatus == .success ? .green : .red)
        .fixedSize()
    }

    private var detailActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            primaryActions
            deleteButton
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            Button("重新发送") { Task { await model.resend(record) } }
                .buttonStyle(.borderedProminent)
            Button("复制内容") { model.copy(record.body) }
            if let raw = record.url, let url = URL(string: raw) {
                Link("打开链接", destination: url)
            }
        }
    }

    private var deleteButton: some View {
        Button("删除", role: .destructive) { Task { await model.delete(record) } }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sourceName(_ source: NotificationSource) -> String {
        switch source {
        case .gui: "BarkDesk"
        case .cli: "notify CLI"
        case .command: "命令结束提醒"
        }
    }
}
