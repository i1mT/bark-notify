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
                editor
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 38)
            .padding(.top, 30)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("发送通知")
        .toolbar {
            if model.isWorking { ProgressView().controlSize(.small) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("发送一条 Bark 通知")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("先选择通知用途，只填写这次发送真正需要的信息。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择类型").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 10)], spacing: 10) {
                ForEach(NotificationKind.allCases) { kind in
                    NotificationKindButton(kind: kind, selected: model.draft.kind == kind) {
                        withAnimation(.snappy(duration: 0.22)) { model.draft.select(kind) }
                        messageFocused = kind != .image
                    }
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(model.draft.kind.title, systemImage: model.draft.kind.icon)
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("标题（选填）").font(.subheadline.weight(.medium))
                TextField("例如：构建已经完成", text: $model.draft.title)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }

            kindFields

            DisclosureGroup("发送选项", isExpanded: $optionsExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("副标题（选填）", text: $model.draft.subtitle)
                    TextField("分组（选填）", text: $model.draft.group)
                    if model.draft.kind != .critical {
                        Picker("提醒方式", selection: $model.draft.level) {
                            ForEach(BarkLevel.allCases.filter { $0 != .critical }, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                    }
                    TextField("提示音（留空使用默认值）", text: $model.draft.sound)
                    Toggle("保存在 Bark 历史记录中", isOn: $model.draft.archive)
                }
                .padding(.top, 12)
            }

            Divider()
            HStack(alignment: .center) {
                if let hint = model.draft.validationHint {
                    Label(hint, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Label("内容已经准备好", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }
                Spacer()
                Button {
                    Task { await model.sendDraft() }
                } label: {
                    Label("发送通知", systemImage: "paperplane.fill")
                        .frame(minWidth: 96)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.isWorking || !model.draft.isValid)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.separator) }
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
            urlField(label: "打开链接", text: $model.draft.url, placeholder: "https://example.com")
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
                Text("需要复制的文字").font(.subheadline.weight(.medium))
                TextField("验证码、命令或其他文字", text: $model.draft.copy)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
            }
        case .markdown:
            messageEditor(label: "Markdown 正文", placeholder: "## 构建结果\n\n**已完成**")
            Text("需要使用支持 Markdown 的较新版本 Bark 与 Bark Server。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var imageFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            urlField(label: "图片链接", text: $model.draft.image, placeholder: "https://example.com/image.jpg")
            HStack {
                Text("Bark Server 不提供文件上传，请使用可以公开访问的图片链接。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("粘贴链接") {
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
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 240)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            messageEditor(label: "图片说明（选填）", placeholder: "不填写时将发送“图片通知”")
        }
    }

    private func messageEditor(label: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            ZStack(alignment: .topLeading) {
                if model.draft.message.isEmpty {
                    Text(placeholder).foregroundStyle(.tertiary).padding(.horizontal, 7).padding(.vertical, 9)
                }
                TextEditor(text: $model.draft.message)
                    .focused($messageFocused)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .frame(minHeight: model.draft.kind == .markdown ? 180 : 110)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
        }
    }

    private func urlField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.medium))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }
}

private struct NotificationKindButton: View {
    let kind: NotificationKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: kind.icon)
                    .font(.title3)
                    .frame(width: 26)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).fontWeight(.semibold)
                    Text(kind.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                selected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.55) : Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
