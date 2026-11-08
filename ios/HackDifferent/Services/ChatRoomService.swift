//
//  ChatRoomService.swift
//  HackDifferent
//

import AudienceKit
import Foundation
import Observation

/// Manages a live `AudienceCable` chat subscription for a Hackerspace, Conference Venue, or Locale chat room.
@MainActor
@Observable
public final class ChatRoomViewModel {
    public enum ConnectionStatus: Equatable, Sendable {
        case connecting
        case connected
        case outOfRange
        case notPresent(String)
        case disconnected(reconnecting: Bool)
    }

    public let room: ChatRoomTarget
    public private(set) var status: ConnectionStatus = .connecting
    public private(set) var messages: [ChatMessage] = []
    public private(set) var pinnedMessage: ChatMessage?
    public private(set) var participants: [ChatRosterPerson] = []
    public private(set) var isSending = false
    public private(set) var sendError: String?
    /// A short confirmation after a report or block, shown under the messages.
    public private(set) var notice: String?
    /// Members blocked from this screen: their messages are hidden at once, before the server stops sending them.
    public private(set) var blockedUserIDs: Set<String> = []

    /// The messages to show: everything except what blocked members sent.
    public var visibleMessages: [ChatMessage] {
        guard !blockedUserIDs.isEmpty else { return messages }
        return messages.filter { message in
            guard let userId = message.userId else { return true }
            return !blockedUserIDs.contains(userId)
        }
    }

    /// Whether the composer belongs on screen: not in a room the server turned away (one hosted on Discord, or one
    /// the member is out of range of), where a send can only fail.
    public var canPost: Bool {
        if case .notPresent = status { return false }
        return true
    }

    private let cable: AudienceCable
    private let client: AudienceKitClient
    @ObservationIgnored private var subscriptionTask: Task<Void, Never>?

    public init(room: ChatRoomTarget, cable: AudienceCable, client: AudienceKitClient) {
        self.room = room
        self.cable = cable
        self.client = client
    }

    public func connect(watch: Bool = false) {
        subscriptionTask?.cancel()
        status = .connecting

        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let audienceID = (try? await self.client.audienceID()) ?? AppConfiguration.defaultAudienceID
            let stream = await self.cable.chat(self.room.room, watch: watch, audienceID: audienceID)
            for await update in stream {
                guard !Task.isCancelled else { break }
                self.handle(update)
            }
        }
    }

    public func disconnect() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    public func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        sendError = nil
        defer { isSending = false }

        do {
            let sent = try await client.sendChatMessage(trimmed, in: room.room)
            appendOrUpdateMessage(sent)
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    public func deleteOwnMessage(_ message: ChatMessage) async {
        do {
            try await client.removeChatMessage(id: message.id.lowercased())
            messages.removeAll { $0.id == message.id }
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    /// Reports a message to the audience's admins (App Store guideline 1.2), optionally blocking its sender.
    public func report(_ message: ChatMessage, reason: String?, block: Bool) async {
        sendError = nil
        do {
            let result = try await client.reportContent(.message, id: message.id.lowercased(), reason: reason, block: block)
            if result.blocked, let userId = message.userId {
                blockedUserIDs.insert(userId)
            }
            notice = result.blocked ? "\(ReportCopy.reported) \(ReportCopy.blocked)" : ReportCopy.reported
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    /// Blocks a message's sender: neither sees the other's messages any more.
    public func blockSender(of message: ChatMessage) async {
        guard let userId = message.userId else { return }
        sendError = nil
        do {
            try await client.blockUser(userId)
            blockedUserIDs.insert(userId)
            notice = ReportCopy.blocked
        } catch let error as AudienceKitError {
            sendError = error.message
        } catch {
            sendError = error.localizedDescription
        }
    }

    private func handle(_ update: ChatRoomUpdate) {
        switch update {
        case .subscribed:
            break
        case let .refused(errors):
            status = .notPresent(
                errors.map(\.message).first
                    ?? "Check in at \(room.displayName) or join the Discord server to chat from anywhere."
            )
        case let .disconnected(_, reconnects):
            status = .disconnected(reconnecting: reconnects)
        case let .event(event):
            handle(event)
        }
    }

    private func handle(_ event: ChatRoomEvent) {
        switch event {
        case let .joined(people, history, pinned, outOfRange):
            status = outOfRange ? .outOfRange : .connected
            participants = people
            messages = history
            pinnedMessage = pinned
        case let .posted(message), let .updated(message):
            appendOrUpdateMessage(message)
        case let .removed(messageID):
            messages.removeAll { $0.id.caseInsensitiveCompare(messageID) == .orderedSame }
        case let .pinChanged(_, pinned, announcement):
            pinnedMessage = pinned ? announcement : nil
        case .cleared:
            messages.removeAll()
        case let .presenceChanged(userID, name, avatarUrl, presence):
            if presence.uppercased() == "ONLINE" {
                if !participants.contains(where: { $0.userId == userID }) {
                    participants.append(ChatRosterPerson(userId: userID, name: name, avatarUrl: avatarUrl))
                }
            } else {
                participants.removeAll { $0.userId == userID }
            }
        case let .rangeChanged(outOfRange):
            status = outOfRange ? .outOfRange : .connected
        case .left:
            status = .notPresent("You left the \(room.displayName) chat range.")
        case .unknown:
            break
        }
    }

    private func appendOrUpdateMessage(_ item: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id.caseInsensitiveCompare(item.id) == .orderedSame }) {
            messages[index] = item
        } else {
            messages.append(item)
        }
    }
}
