package com.hackdifferent.app

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.audiencekit.AudienceKitClient
import com.audiencekit.AudienceKitException
import com.audiencekit.CableConnection
import com.audiencekit.ChatMessage
import com.audiencekit.ChatRoomEvent
import com.audiencekit.ChatRoomUpdate
import com.audiencekit.ChatRosterPerson
import com.audiencekit.ReportCopy
import com.audiencekit.ReportTarget
import com.audiencekit.blockUser
import com.audiencekit.chat
import com.audiencekit.removeChatMessage
import com.audiencekit.reportContent
import com.audiencekit.sendChatMessage
import com.hackdifferent.core.AppConfig
import com.hackdifferent.core.ChatRoomTarget
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

sealed interface ChatConnectionStatus {
    data object Connecting : ChatConnectionStatus
    data object Connected : ChatConnectionStatus
    data object OutOfRange : ChatConnectionStatus
    data class NotPresent(val message: String) : ChatConnectionStatus
    data class Disconnected(val reconnecting: Boolean) : ChatConnectionStatus
}

class ChatRoomController(
    val room: ChatRoomTarget,
    private val cable: CableConnection,
    private val client: AudienceKitClient,
    private val scope: CoroutineScope,
) {
    var status by mutableStateOf<ChatConnectionStatus>(ChatConnectionStatus.Connecting)
        private set
    var messages by mutableStateOf<List<ChatMessage>>(emptyList())
        private set
    var pinnedMessage by mutableStateOf<ChatMessage?>(null)
        private set
    var participants by mutableStateOf<List<ChatRosterPerson>>(emptyList())
        private set
    var isSending by mutableStateOf(false)
        private set
    var sendError by mutableStateOf<String?>(null)
        private set

    /** A short confirmation after a report or block ("Thanks. The admins will look at it."). */
    var notice by mutableStateOf<String?>(null)

    /** Members blocked from this room this session: their messages are hidden right away. */
    private var blockedUserIds by mutableStateOf<Set<String>>(emptySet())

    private var subscriptionJob: Job? = null

    fun connect(watch: Boolean = false) {
        subscriptionJob?.cancel()
        status = ChatConnectionStatus.Connecting

        subscriptionJob = scope.launch {
            val audienceId = runCatching { client.audienceId() }.getOrDefault(AppConfig.DEFAULT_AUDIENCE_ID)
            cable.chat(audienceId, room.room, watch).collect(::handleUpdate)
        }
    }

    fun disconnect() {
        subscriptionJob?.cancel()
        subscriptionJob = null
    }

    fun sendMessage(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || isSending) return
        isSending = true
        sendError = null

        scope.launch {
            try {
                val sent = client.sendChatMessage(trimmed, room.room)
                appendOrUpdateMessage(sent)
            } catch (e: AudienceKitException) {
                sendError = e.message ?: "Failed to send message."
            } catch (e: Exception) {
                sendError = e.localizedMessage ?: "Failed to send message."
            } finally {
                isSending = false
            }
        }
    }

    fun deleteOwnMessage(message: ChatMessage) {
        scope.launch {
            try {
                client.removeChatMessage(message.id.lowercase())
                messages = messages.filterNot { it.id.equals(message.id, ignoreCase = true) }
            } catch (e: AudienceKitException) {
                sendError = e.message
            } catch (e: Exception) {
                sendError = e.localizedMessage
            }
        }
    }

    /** Reports a message to the audience's admins (Play UGC policy, App Store 1.2), optionally blocking its sender. */
    fun reportMessage(message: ChatMessage, reason: String?, block: Boolean) {
        scope.launch {
            try {
                val result = client.reportContent(ReportTarget.MESSAGE, message.id.lowercase(), reason, block)
                if (result.blocked) message.userId?.let(::hideSender)
                notice = if (result.blocked) "${ReportCopy.REPORTED} ${ReportCopy.BLOCKED}" else ReportCopy.REPORTED
            } catch (e: Exception) {
                sendError = e.message ?: "Couldn't send the report."
            }
        }
    }

    /** Blocks a message's sender, so they and the viewer stop seeing each other's messages. */
    fun blockSender(message: ChatMessage) {
        val userId = message.userId ?: return
        scope.launch {
            try {
                client.blockUser(userId)
                hideSender(userId)
                notice = ReportCopy.BLOCKED
            } catch (e: Exception) {
                sendError = e.message ?: "Couldn't block them."
            }
        }
    }

    private fun hideSender(userId: String) {
        blockedUserIds = blockedUserIds + userId
        messages = messages.filterNot { it.userId == userId }
    }

    private fun handleUpdate(update: ChatRoomUpdate) {
        when (update) {
            ChatRoomUpdate.Subscribed -> Unit
            is ChatRoomUpdate.Refused -> {
                val firstError = (update.errors.firstOrNull() as? JsonObject)
                    ?.get("message")
                    ?.let { (it as? JsonPrimitive)?.contentOrNull }
                status = ChatConnectionStatus.NotPresent(
                    firstError ?: "Check in at ${room.displayName} or join the Discord server to chat from anywhere.",
                )
            }
            is ChatRoomUpdate.Disconnected -> {
                status = ChatConnectionStatus.Disconnected(reconnecting = update.reconnects)
            }
            is ChatRoomUpdate.Event -> handleEvent(update.event)
        }
    }

    private fun handleEvent(event: ChatRoomEvent) {
        when (event) {
            is ChatRoomEvent.Joined -> {
                status = if (event.outOfRange) ChatConnectionStatus.OutOfRange else ChatConnectionStatus.Connected
                participants = event.people
                messages = event.history.filterNot { it.userId in blockedUserIds }
                pinnedMessage = event.pinned
            }
            is ChatRoomEvent.Posted -> appendOrUpdateMessage(event.message)
            is ChatRoomEvent.Updated -> appendOrUpdateMessage(event.message)
            is ChatRoomEvent.Removed -> {
                messages = messages.filterNot { it.id.equals(event.messageId, ignoreCase = true) }
            }
            is ChatRoomEvent.PinChanged -> {
                pinnedMessage = if (event.pinned) event.announcement else null
            }
            is ChatRoomEvent.Cleared -> messages = emptyList()
            is ChatRoomEvent.PresenceChanged -> {
                if (event.presence.equals("ONLINE", ignoreCase = true)) {
                    if (participants.none { it.userId == event.userId }) {
                        participants = participants + ChatRosterPerson(
                            userId = event.userId,
                            name = event.name,
                            avatarUrl = event.avatarUrl,
                        )
                    }
                } else {
                    participants = participants.filterNot { it.userId == event.userId }
                }
            }
            is ChatRoomEvent.RangeChanged -> {
                status = if (event.outOfRange) ChatConnectionStatus.OutOfRange else ChatConnectionStatus.Connected
            }
            is ChatRoomEvent.Left -> {
                status = ChatConnectionStatus.NotPresent("You left the ${room.displayName} chat range.")
            }
            is ChatRoomEvent.Unknown -> Unit
        }
    }

    private fun appendOrUpdateMessage(item: ChatMessage) {
        if (item.userId != null && item.userId in blockedUserIds) return
        val index = messages.indexOfFirst { it.id.equals(item.id, ignoreCase = true) }
        messages = if (index >= 0) {
            messages.toMutableList().also { it[index] = item }
        } else {
            messages + item
        }
    }
}
