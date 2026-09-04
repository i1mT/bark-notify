import BarkCore
import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var searchVisible = false
    var body: some View {
        VStack(spacing: 0) {
            header
            if model.records.isEmpty {
                emptyState
            } else {
                historyBrowser.padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .background(Color.barkCanvas)
        .onAppear {
            if model.selectedRecordID == nil { model.selectedRecordID = model.records.first?.id }
        }
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("通知记录")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(Color.barkInk)
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if searchVisible || !model.searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索标题、内容或分组", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !model.searchText.isEmpty {
                        Button {
                            model.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(width: 210, height: 42)
                .background(Color.barkField, in: RoundedRectangle(cornerRadius: 11))
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(Color.barkBorder) }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Button {
                withAnimation(.easeOut(duration: 0.18)) { searchVisible.toggle() }
                if searchVisible { searchFocused = true }
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .barkIconButtonSurface()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .help("搜索通知")
            Button {
                Task { await model.refreshHistory() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
                    .barkIconButtonSurface()
            }
            .buttonStyle(.plain)
            .help("刷新记录")
            .accessibilityLabel("刷新记录")
            Button { model.selection = .compose } label: {
                ViewThatFits(in: .horizontal) {
                    Label("新建通知", systemImage: "plus")
                    Image(systemName: "plus").frame(width: 18)
                }
            }
            .buttonStyle(.barkPrimary)
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .onChange(of: model.searchText) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                await model.refreshHistory()
            }
        }
    }
    @ViewBuilder
    private var emptyState: some View {
        if model.searchText.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text("00:00:00")
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.barkAccent.opacity(0.4))
                VStack(alignment: .leading, spacing: 7) {
                    Text("还没有发送记录").font(.title2.weight(.semibold))
                    Text("发送的成功与失败记录会按照时间出现在这里。")
                        .foregroundStyle(.secondary)
                }
                Button("发送第一条通知") { model.selection = .compose }
                    .buttonStyle(.barkPrimary)
            }
            .frame(maxWidth: 540, maxHeight: .infinity, alignment: .leading)
            .padding(46)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ContentUnavailableView.search(text: model.searchText)
        }
    }
    private var historyBrowser: some View {
        HStack(spacing: 14) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedRecords, id: \.day) { group in
                        Section {
                            ForEach(group.records) { record in
                                HistoryRow(record: record, selected: model.selectedRecordID == record.id) {
                                    model.selectedRecordID = record.id
                                }
                                .contextMenu { rowMenu(record) }
                            }
                        } header: {
                            DateSectionHeader(date: group.day)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
            .frame(width: 280)
            .barkPanelSurface(radius: 16)

            Group {
                if let record = model.selectedRecord {
                    HistoryDetail(record: record)
                        .id(record.id)
                        .transition(.opacity)
                } else {
                    ContentUnavailableView("选择一条通知查看详情", systemImage: "clock")
                }
            }
            .animation(.easeOut(duration: 0.12), value: model.selectedRecordID)
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .barkPanelSurface(radius: 16)
        }
        .clipped()
    }
    @ViewBuilder
    private func rowMenu(_ record: NotificationRecord) -> some View {
        Button("复制内容") { model.copy(record.body) }
        if let url = record.url { Button("复制链接") { model.copy(url) } }
        Button("重新发送") { Task { await model.resend(record) } }
        Divider()
        Button("删除", role: .destructive) { Task { await model.delete(record) } }
    }
    private var summary: String {
        let today = model.records.filter { Calendar.current.isDateInToday($0.createdAt) }
        let failures = today.filter { $0.deliveryStatus != .success }.count
        if today.isEmpty { return "今天还没有发送通知" }
        if failures == 0 { return "今天发送 " + String(today.count) + " 条，全部成功" }
        return "今天发送 " + String(today.count) + " 条，其中 " + String(failures) + " 条失败"
    }
    private var groupedRecords: [(day: Date, records: [NotificationRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: model.records) { calendar.startOfDay(for: $0.createdAt) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day, default: []].sorted { $0.createdAt > $1.createdAt })
        }
    }
}

private struct DateSectionHeader: View {
    let date: Date
    var body: some View {
        HStack {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 7)
        .background(Color.barkSurface)
    }
    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month(.wide).day().weekday(.wide))
    }
}

private struct HistoryRow: View {
    let record: NotificationRecord
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(record.createdAt.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.barkInk)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .frame(width: 72, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(record.deliveryStatus == .success ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(record.title?.nilIfEmpty ?? "无标题通知")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.barkInk)
                            .lineLimit(1)
                    }
                    Text(record.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(metadata)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(selected ? Color.barkSelection : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
    private var metadata: String {
        [record.group, record.source.historyLabel].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
    }
}

private struct HistoryDetail: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmDelete = false
    let record: NotificationRecord
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    timeHeader
                    notificationContent
                    sendingDetails
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            actionBar
        }
        .background(Color.barkSurface)
        .confirmationDialog("确定删除这条通知记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { Task { await model.delete(record) } }
        } message: {
            Text("删除后无法恢复，但不会删除 iPhone Bark 中的通知。")
        }
    }
    private var timeHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(record.createdAt.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .tracking(-1)
                    .foregroundStyle(Color.barkInk)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(record.createdAt.formatted(.dateTime.year().month(.abbreviated).day().weekday(.abbreviated)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Label(
                record.deliveryStatus == .success ? "发送成功" : "发送失败",
                systemImage: record.deliveryStatus == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(record.deliveryStatus == .success ? Color.green : Color.orange)
            .lineLimit(1)
            .fixedSize()
        }
    }
    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(record.title?.nilIfEmpty ?? "无标题通知")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(Color.barkInk)
            if let subtitle = record.subtitle?.nilIfEmpty {
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Text(record.body)
                .font(.system(size: 14))
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.barkBorder.opacity(0.75)) }
            if let rawImage = record.image, let url = URL(string: rawImage) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else if case .failure = phase {
                        Label("无法加载图片", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 260)
                .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var sendingDetails: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("发送信息")
                .font(.headline)
                .padding(.bottom, 12)
            detailRow("来源", record.source.historyLabel)
            detailRow("分组", record.group ?? "—")
            detailRow("提醒方式", record.level?.displayName ?? "—")
            detailRow("提示音", record.sound ?? "默认")
            if let code = record.httpStatusCode { detailRow("HTTP", String(code), monospaced: true) }
            if let error = record.errorMessage { detailRow("错误", error) }
            if let command = record.metadata?.command { detailRow("命令", command, monospaced: true) }
            if let duration = record.metadata?.duration {
                detailRow("耗时", duration.formatted(.number.precision(.fractionLength(1))) + " 秒", monospaced: true)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("重新发送") { Task { await model.resend(record) } }
                .buttonStyle(.barkPrimary)
            Button("复制内容") { model.copy(record.body) }
                .buttonStyle(.barkSecondary)
            if let raw = record.url, let url = URL(string: raw) { Link("打开链接", destination: url).buttonStyle(.barkSecondary) }
            Spacer()
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .barkIconButtonSurface()
            }
            .buttonStyle(.plain)
            .help("删除记录")
            .accessibilityLabel("删除记录")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 13)
        .barkPanelSurface(radius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(label).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            Text(value)
                .fontDesign(monospaced ? .monospaced : .default)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Divider().overlay(Color.barkBorder) }
    }
}

private extension NotificationSource {
    var historyLabel: String {
        switch self {
        case .gui: "BarkDesk"
        case .cli: "notify CLI"
        case .command: "命令结束提醒"
        case .agentHook: "Coding Agent"
        }
    }
}
