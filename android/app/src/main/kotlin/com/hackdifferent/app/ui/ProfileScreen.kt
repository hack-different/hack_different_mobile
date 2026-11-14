package com.hackdifferent.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import com.audiencekit.RSVPState
import com.hackdifferent.core.ConferenceEvent
import com.hackdifferent.core.formatEventStart
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.AudienceKitSDK
import com.audiencekit.ConnectDiscordCopy
import com.audiencekit.DeleteAccountCopy
import com.hackdifferent.app.HackDifferentAppState
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(appState: HackDifferentAppState) {
    var confirmingDelete by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    LaunchedEffect(Unit) { appState.refreshConnectedDiscord() }
    val user = appState.currentUser
    var selectedEvent by remember { mutableStateOf<ConferenceEvent?>(null) }
    val attendingEvents = appState.events.filter { it.rsvpState == RSVPState.ATTENDING || it.rsvpState == RSVPState.MAYBE }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Profile & Community") })
        },
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = appState.isLoadingDirectory,
            onRefresh = {
                appState.refreshAll()
                appState.refreshConnectedDiscord()
            },
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = user?.name ?: listOfNotNull(user?.firstName, user?.lastName).joinToString(" ").ifBlank { "Hack Different Member" },
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    )
                    user?.emailAddress?.let { email ->
                        Text(
                            text = email,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (user?.isAdmin == true) {
                        Text(
                            text = "Audience Admin",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }

            // My RSVPs: the upcoming events they're going to or interested in (iOS's Profile section).
            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = "My RSVPs (${attendingEvents.size})",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    )
                    if (attendingEvents.isEmpty()) {
                        Text(
                            text = "You haven't RSVPed to any upcoming conferences or meetups yet.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    attendingEvents.forEach { event ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedEvent = event }
                                .padding(vertical = 4.dp),
                        ) {
                            Text(event.name, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
                            Text(
                                text = listOfNotNull(
                                    if (event.rsvpState == RSVPState.ATTENDING) "Going" else "Interested",
                                    event.startAt?.let { formatEventStart(it) },
                                ).joinToString(" · "),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            // Connect Discord, for people who signed in with Apple: the Discord bridge then knows them as the same
            // person. Once connected it shows the Discord username.
            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    val discord = appState.connectedDiscord
                    if (discord != null) {
                        InfoRow(ConnectDiscordCopy.CONNECTED_LABEL, discord.username?.let { "@$it" } ?: ConnectDiscordCopy.CONNECTED)
                    } else {
                        OutlinedButton(
                            onClick = { appState.startDiscordConnect(context) },
                            enabled = !appState.isConnectingDiscord,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(if (appState.isConnectingDiscord) "Connecting…" else ConnectDiscordCopy.CONNECT)
                        }
                    }
                    Text(
                        text = ConnectDiscordCopy.EXPLANATION,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        text = "Community Links",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    )
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://hackdiffe.rent") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Hack Different Website (hackdiffe.rent)")
                    }
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://discord.gg/nUZC4aCM9r") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Hack Different Discord")
                    }
                    OutlinedButton(
                        onClick = { appState.openExternalUrl(context, "https://github.com/hack-different") },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("GitHub (github.com/hack-different)")
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        TextButton(onClick = { appState.openExternalUrl(context, TERMS_URL) }) { Text("Terms of Use") }
                        TextButton(onClick = { appState.openExternalUrl(context, PRIVACY_URL) }) { Text("Privacy Policy") }
                    }
                }
            }

            Card(
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    InfoRow("App Version", "${appState.config.versionName} (${appState.config.versionCode})")
                    InfoRow("AudienceKit SDK", AudienceKitSDK.VERSION)
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            OutlinedButton(
                onClick = { appState.signOut() },
                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
            ) {
                Text("Sign Out")
            }

            // Google Play / App Store: delete the account from inside the app.
            TextButton(
                onClick = { confirmingDelete = true },
                enabled = !deleting,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (deleting) "Deleting…" else "Delete Account")
            }
        }
        }
    }

    selectedEvent?.let { event ->
        EventDetailSheet(
            event = event,
            appState = appState,
            onDismiss = { selectedEvent = null },
            onEventUpdated = { updated -> selectedEvent = updated },
        )
    }

    if (confirmingDelete) {
        AlertDialog(
            onDismissRequest = { confirmingDelete = false },
            title = { Text(DeleteAccountCopy.TITLE) },
            text = { Text(DeleteAccountCopy.WARNING) },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmingDelete = false
                        deleting = true
                        scope.launch {
                            deleteError = appState.deleteAccount()
                            deleting = false
                        }
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                ) { Text("Delete Account") }
            },
            dismissButton = { TextButton(onClick = { confirmingDelete = false }) { Text("Cancel") } },
        )
    }

    appState.discordError?.let { message ->
        AlertDialog(
            onDismissRequest = { appState.dismissDiscordError() },
            title = { Text(ConnectDiscordCopy.FAILED_TITLE) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { appState.dismissDiscordError() }) { Text("OK") } },
        )
    }

    deleteError?.let { message ->
        AlertDialog(
            onDismissRequest = { deleteError = null },
            title = { Text("Couldn't delete your account") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { deleteError = null }) { Text("OK") } },
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
        )
    }
}
