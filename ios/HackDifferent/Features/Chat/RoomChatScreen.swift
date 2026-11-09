//
//  RoomChatScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct RoomChatScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL

    let room: ChatRoomTarget

    @State private var viewModel: ChatRoomViewModel?
    @State private var draftMessage = ""
    @State private var showingRoster = false
    @State private var reporting: ChatMessage?
    @State private var blocking: ChatMessage?

    var body: some View {
        VStack(spacing: 0) {
            if let viewModel {
                // Status & Pinned Banner
                StatusBannerView(viewModel: viewModel, onOpenDiscord: {
                    if let discord = room.discordLink {
                        openURL(discord.webURL)
                    }
                })

                if let pinned = viewModel.pinnedMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            if let title = pinned.title, !title.isEmpty {
                                Text(title)
                                    .font(.caption.weight(.bold))
                            }
                            Text(pinned.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                }

                // Message List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if viewModel.visibleMessages.isEmpty && viewModel.canPost {
                                ContentUnavailableView(
                                    "No Messages Yet",
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text("Start the conversation in \(room.displayName).")
                                )
                                .padding(.top, 48)
                            } else {
                                ForEach(viewModel.visibleMessages) { message in
                                    ChatMessageBubble(
                                        message: message,
                                        isMine: message.userId == appModel.session.currentUser?.id,
                                        onDelete: {
                                            Task {
                                                await viewModel.deleteOwnMessage(message)
                                            }
                                        },
                                        onReport: { reporting = message },
                                        onBlock: { blocking = message }
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(14)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastID = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                if let notice = viewModel.notice, viewModel.sendError == nil {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                }

                if let sendError = viewModel.sendError {
                    Text(sendError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                }

                if viewModel.canPost {
                    Divider()
                    composer(viewModel)
                } else if viewModel.isReadOnly {
                    Divider()
                    replyOnDiscord(viewModel)
                }
            } else {
                Spacer()
                ProgressView("Connecting to \(room.displayName)…")
                Spacer()
            }
        }
        .navigationTitle(room.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let discord = room.discordLink {
                    Button {
                        openURL(discord.webURL)
                    } label: {
                        Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }

                if let viewModel {
                    Button {
                        showingRoster = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(viewModel.participants.count)")
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            ReportCopy.reportTitle,
            isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
            titleVisibility: .visible,
            presenting: reporting
        ) { message in
            ForEach(ReportCopy.reasons, id: \.self) { reason in
                Button(reason) {
                    Task { await viewModel?.report(message, reason: reason, block: false) }
                }
            }
            if message.userId != nil {
                Button("\(ReportCopy.reportMessage) and block sender", role: .destructive) {
                    Task { await viewModel?.report(message, reason: nil, block: true) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(ReportCopy.reportDetail)
        }
        .confirmationDialog(
            ReportCopy.blockTitle,
            isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } }),
            titleVisibility: .visible,
            presenting: blocking
        ) { message in
            Button(ReportCopy.blockPerson, role: .destructive) {
                Task { await viewModel?.blockSender(of: message) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            // The SDK's copy promises unblocking later, which this app has no screen for yet.
            Text("You'll stop seeing each other's messages.")
        }
        .sheet(isPresented: $showingRoster) {
            NavigationStack {
                List {
                    if let participants = viewModel?.participants, !participants.isEmpty {
                        Section("In Room Now (\(participants.count))") {
                            ForEach(participants) { person in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(person.displayName)
                                        .font(.subheadline.weight(.medium))
                                    if person.friend {
                                        Spacer()
                                        Text("Friend")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "No Active Roster",
                            systemImage: "person.2.slash",
                            description: Text("No one else is currently visible in this room.")
                        )
                    }
                }
                .navigationTitle("Room Roster")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingRoster = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            let vm = ChatRoomViewModel(
                room: room,
                cable: appModel.cable,
                client: appModel.client
            )
            viewModel = vm
            vm.connect()
        }
        .onDisappear {
            viewModel?.disconnect()
        }
    }

    /// In a room that mirrors Discord: where to reply, since sending from here can't work.
    private func replyOnDiscord(_ viewModel: ChatRoomViewModel) -> some View {
        VStack(spacing: 6) {
            if let url = viewModel.replyURL ?? room.discordLink?.webURL {
                Button {
                    openURL(url)
                } label: {
                    Label("Reply on Discord", systemImage: "arrowshape.turn.up.left.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Text("This room mirrors \(room.displayName)'s Discord channel. Read and report here; replies happen on Discord.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func composer(_ viewModel: ChatRoomViewModel) -> some View {
        HStack(spacing: 10) {
            TextField("Message \(room.displayName)…", text: $draftMessage, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Button {
                let text = draftMessage
                draftMessage = ""
                Task {
                    await viewModel.sendMessage(text)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }
}

private struct StatusBannerView: View {
    let viewModel: ChatRoomViewModel
    let onOpenDiscord: () -> Void

    var body: some View {
        switch viewModel.status {
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting via AudienceCable…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
        case .connected:
            EmptyView()
        case .outOfRange:
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption)
                Text("Connected remotely (Admin / Staff access)")
                    .font(.caption)
            }
            .foregroundStyle(.teal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.teal.opacity(0.12))
        case let .notPresent(reason):
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash.fill")
                        .font(.caption)
                    Text(reason)
                        .font(.caption)
                }
                if viewModel.room.discordLink != nil {
                    Button("Continue Chat on Discord", action: onOpenDiscord)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.12))
        case let .disconnected(reconnecting):
            HStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.caption)
                Text(reconnecting ? "Connection dropped — reconnecting…" : "Disconnected from chat.")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
        }
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.senderName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let role = message.role, !role.isEmpty {
                        Text(role.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                            .foregroundStyle(.tint)
                    }
                    if let sentAt = message.sentAt {
                        Text(sentAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let title = message.title, !title.isEmpty {
                        Text(title)
                            .font(.caption.weight(.bold))
                    }
                    Text(message.body)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isMine ? Color.accentColor : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isMine ? Color.white : Color.primary)
                .contextMenu {
                    if isMine {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Message", systemImage: "trash")
                        }
                    } else {
                        Button(action: onReport) {
                            Label(ReportCopy.reportMessage, systemImage: "exclamationmark.bubble")
                        }
                        if message.userId != nil {
                            Button(role: .destructive, action: onBlock) {
                                Label(ReportCopy.blockPerson, systemImage: "hand.raised")
                            }
                        }
                    }
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }
}
