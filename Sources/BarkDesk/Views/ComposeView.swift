import AppKit
import BarkCore
import SwiftUI

struct ComposeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var optionsExpanded = false
    @FocusState private var messageFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                typePicker
                editorLayout
            }
            .frame(maxWidth: 1020)
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 38)
            .frame(maxWidth: .infinity)
        }
        .background(Color.barkCanvas)
        .navigationTitle("发送通知")
        .safeAreaInset(edge: .bottom) { sendBar }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 28) {
            PageHeader(
                eyebrow: "新通知",
                title: "这次想发送什么？",
                detail: "选择一种通知形式，填写内容，并在右侧确认最终效果。"
            )
            Spacer(minLength: 12)
            StatusPill(label: serverName, systemImage: "network", color: .green)
        }
    }

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(NotificationKind.allCases) { kind in
                    NotificationKindButton(kind: kind, selected: model.draft.kind == kind) {
                        withAnimation(.snappy(duration: 0.22)) { model.draft.select(kind) }
                        messageFocused = kind != .image
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var editorLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 20) {
                editor
                options
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            NotificationPreview(draft: model.draft)
                .frame(width: 260)
        }
    }

    private var editor: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label(model.draft.kind.title, systemImage: model.draft.kind.icon)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text(model.draft.kind.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldCaption(title: "标题", optional: true)
                    TextField("例如：构建已经完成", text: $model.draft.title)
                        .textFieldStyle(.barkDeskLarge)
                }
                kindFields
            }
        }
    }

    private var options: some View {
        SurfaceCard {
            DisclosureGroup(isExpanded: $optionsExpanded) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    TextField("副标题（选填）", text: $model.draft.subtitle)
                        .textFieldStyle(.barkDeskLarge)
                    TextField("分组（选填）", text: $model.draft.group)
                        .textFieldStyle(.barkDeskLarge)
                    if model.draft.kind != .critical {
                        VStack(alignment: .leading, spacing: 8) {
                            FieldCaption(title: "提醒方式")
                            Picker("提醒方式", selection: $model.draft.level) {
                                ForEach(BarkLevel.allCases.filter { $0 != .critical }, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .barkControlSurface()
                        }
                    }
                    TextField("提示音（使用默认值）", text: $model.draft.sound)
                        .textFieldStyle(.barkDeskLarge)
                }
                Toggle("保存在 Bark 历史记录中", isOn: $model.draft.archive)
                    .padding(.top, 14)
            } label: {
                HStack {
                    Label("更多发送选项", systemImage: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(optionsExpanded ? "收起" : "分组、提示音与提醒方式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sendBar: some View {
        HStack(spacing: 14) {
            if let hint = model.draft.validationHint {
                Label(hint, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Label("通知已经准备好", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            Spacer()
            if model.isWorking { ProgressView().controlSize(.small) }
            Button {
                Task { await model.sendDraft() }
            } label: {
                Label("发送通知", systemImage: "paperplane.fill").frame(minWidth: 96)
            }
            .buttonStyle(.barkPrimary)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model.isWorking || !model.draft.isValid)
        }
        .frame(maxWidth: 1020)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .barkPanelSurface(radius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var kindFields: some View {
        switch model.draft.kind {
        case .text:
            messageEditor(label: "通知内容", placeholder: "输入想要发送的内容…")
        case .image:
            imageFields
        case .link:
            messageEditor(label: "通知内容", placeholder: "告诉收件人这个链接是什么…")
            urlField(label: "点击后打开", text: $model.draft.url, placeholder: "https://example.com")
        case .critical:
            messageEditor(label: "警告内容", placeholder: "输入需要立即处理的内容…")
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("提醒音量").fontWeight(.medium); Spacer(); Text("\(Int(model.draft.volume))").monospacedDigit() }
                Slider(value: $model.draft.volume, in: 0...10, step: 1)
                Toggle("持续播放铃声 30 秒", isOn: $model.draft.call)
            }
        case .copy:
            messageEditor(label: "通知内容", placeholder: "例如：验证码已经生成")
            VStack(alignment: .leading, spacing: 8) {
                FieldCaption(title: "需要复制的文字")
                TextField("验证码、命令或其他文字", text: $model.draft.copy)
                    .textFieldStyle(.barkDeskLarge)
            }
        case .markdown:
            messageEditor(label: "Markdown 正文", placeholder: "## 构建结果\n\n**已完成**")
            Text("需要使用支持 Markdown 的较新版本 Bark 与 Bark Server。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var imageFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            urlField(label: "公开图片链接", text: $model.draft.image, placeholder: "https://example.com/image.jpg")
            HStack(alignment: .firstTextBaseline) {
                Text("Bark Server 不提供文件上传，请使用可以公开访问的图片链接。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("粘贴") {
                    if let value = NSPasteboard.general.string(forType: .string) { model.draft.image = value }
                }
            }
            if let url = model.draft.image.webURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: ContentUnavailableView("无法加载图片", systemImage: "photo.badge.exclamationmark")
                    default: ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 220)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            messageEditor(label: "图片说明（选填）", placeholder: "不填写时将发送“图片通知”")
        }
    }

    private func messageEditor(label: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldCaption(title: label)
            ZStack(alignment: .topLeading) {
                if model.draft.message.isEmpty {
                    Text(placeholder).foregroundStyle(.tertiary).padding(.horizontal, 9).padding(.vertical, 10)
                }
                TextEditor(text: $model.draft.message)
                    .focused($messageFocused)
                    .scrollContentBackground(.hidden)
                    .padding(5)
            }
            .font(.system(size: 15))
            .frame(minHeight: model.draft.kind == .markdown ? 178 : 124)
            .background(Color.barkField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(messageFocused ? Color.barkAccent : Color.barkBorder, lineWidth: messageFocused ? 2 : 1)
            }
            .shadow(color: messageFocused ? Color.barkAccent.opacity(0.12) : .clear, radius: 7)
        }
    }

    private func urlField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldCaption(title: label)
            TextField(placeholder, text: text).textFieldStyle(.barkDeskLarge)
        }
    }

    private var serverName: String {
        URL(string: model.configuration.serverURL)?.host ?? "Bark Server"
    }
}

private struct NotificationKindButton: View {
    let kind: NotificationKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(kind.title, systemImage: kind.icon)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(Color.barkInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(selected ? Color.barkSelection : Color.barkSurface, in: RoundedRectangle(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(selected ? Color.barkInk.opacity(0.18) : Color.barkBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationPreview: View {
    let draft: ComposeDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("实时预览").font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: draft.kind.icon).foregroundStyle(Color.barkAccent)
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.barkAccent)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(Color.barkAccentInk)
                        }
                    Text("BARK").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("现在").font(.caption2).foregroundStyle(.tertiary)
                }
                Text(draft.title.nilIfEmpty ?? "通知标题")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text(previewBody)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(draft.message.nilIfEmpty == nil ? .tertiary : .primary)
                    .lineLimit(5)
                if draft.kind == .image {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.barkAccentSoft)
                        .frame(height: 74)
                        .overlay { Image(systemName: "photo").font(.title2).foregroundStyle(Color.barkAccent) }
                }
            }
            .padding(16)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color.barkBorder.opacity(0.75)) }
            Spacer(minLength: 0)
            Text("实际显示由 iPhone 通知设置和 Bark 版本决定。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(minHeight: 300, alignment: .top)
        .background(Color.barkMist, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.barkBorder.opacity(0.65)) }
    }

    private var previewBody: String {
        if let message = draft.message.nilIfEmpty { return message }
        return draft.kind == .image ? "图片通知" : "通知内容会显示在这里"
    }
}
