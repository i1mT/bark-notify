import BarkCore
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if model.records.isEmpty { emptyState } else { historyBrowser }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("通知记录")
        .toolbar {
            Button { Task { await model.refreshHistory() } } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("通知记录")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                Text("这台 Mac 发送过的成功与失败记录。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.selection = .compose
            } label: {
                Label("发送新通知", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.searchText.isEmpty {
            VStack(spacing: 17) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.barkRed)
                    .frame(width: 72, height: 72)
                    .background(Color.barkRedSoft, in: RoundedRectangle(cornerRadius: 22))
                VStack(spacing: 6) {
                    Text("还没有发送记录").font(.title2.weight(.semibold))
                    Text("从 BarkDesk 发送的通知会保存在这里，方便搜索和再次发送。")
                        .foregroundStyle(.secondary)
                }
                Button("发送第一条通知") { model.selection = .compose }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
        } else {
            ContentUnavailableView.search(text: model.searchText)
        }
    }

    private var historyBrowser: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索标题、内容或分组", text: $model.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .padding(12)
                List(selection: $model.selectedRecordID) {
                    ForEach(groupedRecords, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.records) { record in
                                HistoryRow(record: record)
                                    .tag(record.id)
                                    .contextMenu { rowMenu(record) }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 270, idealWidth: 315, maxWidth: 390)
            .onSubmit(of: .text) { Task { await model.refreshHistory() } }
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
                    ContentUnavailableView("选择一条通知查看详情", systemImage: "bell")
                }
            }
            .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func rowMenu(_ record: NotificationRecord) -> some View {
        Button("复制内容") { model.copy(record.body) }
        if let url = record.url { Button("复制链接") { model.copy(url) } }
        Button("重新发送") { Task { await model.resend(record) } }
        Divider()
        Button("删除", role: .destructive) { Task { await model.delete(record) } }
    }

    private var groupedRecords: [(title: String, records: [NotificationRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: model.records) { record -> String in
            if calendar.isDateInToday(record.createdAt) { return "今天" }
            if calendar.isDateInYesterday(record.createdAt) { return "昨天" }
            return "更早"
        }
        return ["今天", "昨天", "更早"].compactMap { title in groups[title].map { (title, $0) } }
    }
}

private struct HistoryRow: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: record.deliveryStatus == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.deliveryStatus == .success ? .green : .red)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.title?.nilIfEmpty ?? "无标题通知")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer(minLength: 5)
                    Text(record.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(record.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let group = record.group {
                    Text(group).font(.caption2).foregroundStyle(Color.barkRed)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

private struct HistoryDetail: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmDelete = false
    let record: NotificationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("通知内容").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(record.body).font(.body).textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("发送信息").font(.headline)
                        detailRow("发送时间", record.createdAt.formatted(date: .abbreviated, time: .standard))
                        detailRow("来源", sourceName(record.source))
                        detailRow("分组", record.group ?? "—")
                        detailRow("提醒方式", record.level?.displayName ?? "—")
                        detailRow("提示音", record.sound ?? "默认")
                        if let code = record.httpStatusCode { detailRow("HTTP", String(code)) }
                        if let error = record.errorMessage { detailRow("错误", error) }
                        if let command = record.metadata?.command { detailRow("命令", command) }
                        if let duration = record.metadata?.duration {
                            detailRow("耗时", duration.formatted(.number.precision(.fractionLength(1))) + " 秒")
                        }
                    }
                }
                Button("删除这条记录", role: .destructive) { confirmDelete = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: 660, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .confirmationDialog("确定删除这条通知记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { Task { await model.delete(record) } }
        } message: {
            Text("删除后无法恢复，但不会删除 iPhone Bark 中的通知。")
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.title?.nilIfEmpty ?? "无标题通知")
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                    if let subtitle = record.subtitle {
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 10)
                StatusPill(
                    label: record.deliveryStatus == .success ? "发送成功" : "发送失败",
                    systemImage: record.deliveryStatus == .success ? "checkmark.circle.fill" : "xmark.circle.fill",
                    color: record.deliveryStatus == .success ? .green : .red
                )
            }
            HStack(spacing: 9) {
                Button("重新发送") { Task { await model.resend(record) } }
                    .buttonStyle(.borderedProminent)
                Button("复制内容") { model.copy(record.body) }
                if let raw = record.url, let url = URL(string: raw) { Link("打开链接", destination: url) }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).foregroundStyle(.secondary).frame(width: 68, alignment: .leading)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }

    private func sourceName(_ source: NotificationSource) -> String {
        switch source {
        case .gui: "BarkDesk"
        case .cli: "notify CLI"
        case .command: "命令结束提醒"
        }
    }
}
