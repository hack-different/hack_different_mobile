package com.hackdifferent.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.RadioButton
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.ChatMessage
import com.audiencekit.ReportCopy
import com.hackdifferent.app.ChatConnectionStatus
import com.hackdifferent.app.ChatRoomController
import com.hackdifferent.app.HackDifferentAppState
import com.hackdifferent.core.ChatRoomTarget
import com.hackdifferent.core.SpaceCategory
import com.hackdifferent.core.senderName
import com.hackdifferent.core.text

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(appState: HackDifferentAppState) {
    val activeRoom = appState.activeChatRoom
    if (activeRoom != null) {
        RoomChatView(
            room = activeRoom,
            appState = appState,
            onBack = { appState.activeChatRoom = null },
        )
        return
    }

    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Chat") })
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "Hack Different Discord",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        )
                        Text(
                            text = "Connect with reverse engineers, open-source builders, and local chapters on Discord.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        OutlinedButton(
                            onClick = { appState.openExternalUrl(context, "https://discord.gg/nUZC4aCM9r") },
                        ) {
                            Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null)
                            Spacer(modifier = Modifier.padding(4.dp))
                            Text("Join Hack Different Discord")
                        }
                    }
                }
            }

            if (appState.locales.isNotEmpty()) {
                item {
                    Text(
                        text = "Regional Hacker Chats",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                items(appState.locales, key = { "locale-${it.id}" }) { locale ->
                    val name = locale.name ?: locale.label ?: "Regional Chat"
                    ChatRoomRow(
                        title = name,
                        subtitle = "Regional Hacker Chat",
                        onClick = {
                            appState.activeChatRoom = ChatRoomTarget.LocaleRoom(
                                recordId = locale.id,
                                displayName = name,
                            )
                        },
                    )
                }
            }

            if (appState.venues.isNotEmpty()) {
                item {
                    Text(
                        text = "Hackerspace & Con Venue Rooms",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
                items(appState.venues, key = { "venue-${it.id}" }) { venue ->
                    val category = SpaceCategory.classify(venue.tags, venue.name)
                    ChatRoomRow(
                        title = venue.name,
                        subtitle = "${category.label}${venue.locale.name?.let { " • $it" }.orEmpty()}",
                        onClick = {
                            appState.activeChatRoom = ChatRoomTarget.VenueRoom(
                                recordId = venue.id,
                                displayName = venue.name,
                                subtitle = venue.location?.address,
                            )
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatRoomRow(
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = Icons.Default.Forum,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RoomChatView(
    room: ChatRoomTarget,
    appState: HackDifferentAppState,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val controller = remember(room.id) {
        ChatRoomController(
            room = room,
            cable = appState.cable,
            client = appState.client,
            scope = appState.scope,
        )
    }
    var draft by remember { mutableStateOf("") }
    var reporting by remember { mutableStateOf<ChatMessage?>(null) }
    var blocking by remember { mutableStateOf<ChatMessage?>(null) }

    DisposableEffect(room.id) {
        controller.connect(watch = true)
        onDispose { controller.disconnect() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(room.displayName, style = MaterialTheme.typography.titleMedium)
                        Text(
                            text = when (val st = controller.status) {
                                ChatConnectionStatus.Connecting -> "Connecting…"
                                ChatConnectionStatus.Connected -> "${controller.participants.size} online"
                                ChatConnectionStatus.OutOfRange -> "Watching (out of range)"
                                is ChatConnectionStatus.NotPresent -> "Presence required"
                                is ChatConnectionStatus.Disconnected -> if (st.reconnecting) "Reconnecting…" else "Disconnected"
                            },
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    room.discordLink?.let { discord ->
                        IconButton(onClick = { appState.openExternalUrl(context, discord.webUrl) }) {
                            Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = "Discord")
                        }
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            controller.pinnedMessage?.let { pinned ->
                Surface(
                    tonalElevation = 3.dp,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Default.PushPin,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Text(
                            text = pinned.text,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }

            (controller.status as? ChatConnectionStatus.NotPresent)?.let { notPresent ->
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = notPresent.message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier.padding(12.dp),
                    )
                }
            }

            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(controller.messages, key = { it.id }) { msg ->
                    val isMine = msg.userId != null && msg.userId == appState.currentUser?.id
                    Card(
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.Top,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = msg.senderName,
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                                    color = MaterialTheme.colorScheme.primary,
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = msg.text,
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                            }
                            if (isMine) {
                                IconButton(onClick = { controller.deleteOwnMessage(msg) }) {
                                    Icon(Icons.Default.Delete, contentDescription = "Delete message")
                                }
                            } else {
                                MessageActions(
                                    canBlock = msg.userId != null,
                                    onReport = { reporting = msg },
                                    onBlock = { blocking = msg },
                                )
                            }
                        }
                    }
                }
            }

            controller.notice?.let { notice ->
                Text(
                    text = notice,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .padding(horizontal = 16.dp, vertical = 4.dp)
                        .clickable { controller.notice = null },
                )
            }

            controller.sendError?.let { err ->
                Text(
                    text = err,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text("Message ${room.displayName}…") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        val toSend = draft
                        draft = ""
                        controller.sendMessage(toSend)
                    },
                    enabled = draft.isNotBlank() && !controller.isSending,
                ) {
                    Icon(Icons.AutoMirrored.Filled.Send, contentDescription = "Send")
                }
            }
        }
    }

    reporting?.let { message ->
        ReportMessageDialog(
            canBlock = message.userId != null,
            onDismiss = { reporting = null },
            onReport = { reason, block ->
                reporting = null
                controller.reportMessage(message, reason, block)
            },
        )
    }

    blocking?.let { message ->
        AlertDialog(
            onDismissRequest = { blocking = null },
            title = { Text(ReportCopy.BLOCK_TITLE) },
            text = { Text(ReportCopy.BLOCK_DETAIL) },
            confirmButton = {
                TextButton(onClick = {
                    blocking = null
                    controller.blockSender(message)
                }) { Text(ReportCopy.BLOCK_PERSON) }
            },
            dismissButton = { TextButton(onClick = { blocking = null }) { Text("Cancel") } },
        )
    }
}

/** Report and block for someone else's message (Google Play's user-generated content policy). */
@Composable
private fun MessageActions(canBlock: Boolean, onReport: () -> Unit, onBlock: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    androidx.compose.foundation.layout.Box {
        IconButton(onClick = { expanded = true }) {
            Icon(Icons.Default.MoreVert, contentDescription = "Message options")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text(ReportCopy.REPORT_MESSAGE) },
                onClick = {
                    expanded = false
                    onReport()
                },
            )
            if (canBlock) {
                DropdownMenuItem(
                    text = { Text(ReportCopy.BLOCK_PERSON) },
                    onClick = {
                        expanded = false
                        onBlock()
                    },
                )
            }
        }
    }
}

@Composable
private fun ReportMessageDialog(canBlock: Boolean, onDismiss: () -> Unit, onReport: (String?, Boolean) -> Unit) {
    var reason by remember { mutableStateOf<String?>(null) }
    var alsoBlock by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(ReportCopy.REPORT_TITLE) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(ReportCopy.REPORT_DETAIL, style = MaterialTheme.typography.bodyMedium)
                ReportCopy.REASONS.forEach { option ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { reason = option },
                    ) {
                        RadioButton(selected = reason == option, onClick = { reason = option })
                        Text(option)
                    }
                }
                if (canBlock) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { alsoBlock = !alsoBlock },
                    ) {
                        Checkbox(checked = alsoBlock, onCheckedChange = { alsoBlock = it })
                        Text(ReportCopy.ALSO_BLOCK)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onReport(reason, alsoBlock) }) { Text("Report") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
