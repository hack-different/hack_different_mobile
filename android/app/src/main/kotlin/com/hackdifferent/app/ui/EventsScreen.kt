package com.hackdifferent.app.ui

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.RSVPState
import com.hackdifferent.app.HackDifferentAppState
import com.hackdifferent.core.ChatRoomTarget
import com.hackdifferent.core.ConferenceEvent
import com.hackdifferent.core.EventKind
import com.hackdifferent.core.formatEventStart
import com.hackdifferent.core.formattedAmount

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun EventsScreen(appState: HackDifferentAppState) {
    var selectedKind by remember { mutableStateOf(EventKind.ALL) }
    var nearMeOnly by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedEvent by remember { mutableStateOf<ConferenceEvent?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        appState.refreshLocationIfPermitted()
    }

    val filteredEvents = remember(
        appState.events,
        selectedKind,
        nearMeOnly,
        searchQuery,
        appState.hasLocationOptIn,
        appState.closestLocale,
        appState.userCoordinate,
    ) {
        appState.events.filter { event ->
            val matchesKind = selectedKind == EventKind.ALL || event.kind == selectedKind
            val matchesLocation = !nearMeOnly || appState.isEventNearby(event)
            val matchesQuery = searchQuery.isBlank() ||
                event.name.contains(searchQuery, ignoreCase = true) ||
                event.venueDisplayName.contains(searchQuery, ignoreCase = true) ||
                event.description?.contains(searchQuery, ignoreCase = true) == true
            matchesKind && matchesLocation && matchesQuery
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Events") },
                actions = {
                    IconButton(onClick = { appState.refreshAll() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
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
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("Search conferences, meetups, cities…") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp),
            )

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            ) {
                EventKind.entries.forEach { kind ->
                    FilterChip(
                        selected = selectedKind == kind,
                        onClick = { selectedKind = kind },
                        label = { Text(kind.label) },
                    )
                }
                FilterChip(
                    selected = nearMeOnly,
                    onClick = {
                        if (!appState.hasLocationOptIn) {
                            nearMeOnly = true
                            permissionLauncher.launch(
                                arrayOf(
                                    Manifest.permission.ACCESS_COARSE_LOCATION,
                                    Manifest.permission.ACCESS_FINE_LOCATION,
                                ),
                            )
                        } else {
                            nearMeOnly = !nearMeOnly
                        }
                    },
                    label = {
                        val region = appState.closestLocale?.name ?: appState.closestLocale?.label
                        Text(if (appState.hasLocationOptIn && region != null) "Near Me • $region" else "Near Me")
                    },
                )
            }

            if (filteredEvents.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = if (appState.isLoadingDirectory) "Loading schedule…" else "No upcoming events match your filter.",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "Pull or tap refresh to sync upcoming hacker conferences and meetups.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(filteredEvents, key = { it.id }) { event ->
                        EventCard(
                            event = event,
                            onClick = { selectedEvent = event },
                        )
                    }
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
}

@Composable
private fun EventCard(
    event: ConferenceEvent,
    onClick: () -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                AssistChip(
                    onClick = onClick,
                    label = { Text(event.kind.badgeLabel) },
                )
                event.lowestTicketPrice?.let { price ->
                    Text(
                        text = price.formattedAmount,
                        style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            Text(
                text = event.name,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = event.venueDisplayName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            event.startAt?.let { start ->
                Text(
                    text = formatEventStart(start),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            if (event.rsvpState == RSVPState.ATTENDING || event.rsvpState == RSVPState.MAYBE) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        text = if (event.rsvpState == RSVPState.ATTENDING) "Going" else "Interested",
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun EventDetailSheet(
    event: ConferenceEvent,
    appState: HackDifferentAppState,
    onDismiss: () -> Unit,
    onEventUpdated: (ConferenceEvent) -> Unit,
) {
    val context = LocalContext.current

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = event.kind.badgeLabel.uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = event.name,
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
            )
            Text(
                text = event.venueDisplayName,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            event.description?.takeIf { it.isNotBlank() }?.let { desc ->
                Text(
                    text = desc,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            // RSVP Selector
            Text(
                text = "Your RSVP (${event.rsvpCount} attending)",
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
            )
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    RSVPState.ATTENDING to "Going",
                    RSVPState.MAYBE to "Interested",
                    RSVPState.DECLINED to "Not Going",
                ).forEach { (state, label) ->
                    FilterChip(
                        selected = event.rsvpState == state,
                        onClick = {
                            appState.updateEventRsvp(event.id, state) { updated ->
                                if (updated != null) {
                                    onEventUpdated(event.copy(rsvpState = updated))
                                }
                            }
                        },
                        label = { Text(label) },
                    )
                }
            }

            // Ticket link or Venue Chat / Discord
            event.primaryTicketUrl?.let { ticketUrl ->
                Button(
                    onClick = { appState.openExternalUrl(context, ticketUrl) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.ConfirmationNumber, contentDescription = null)
                    Spacer(modifier = Modifier.padding(4.dp))
                    Text("Get Tickets")
                }
            }

            event.venue?.let { venueSummary ->
                OutlinedButton(
                    onClick = {
                        onDismiss()
                        appState.openChatRoom(
                            ChatRoomTarget.VenueRoom(
                                recordId = venueSummary.id,
                                displayName = venueSummary.name,
                                subtitle = event.name,
                                discordLink = event.discordLink,
                            ),
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.Forum, contentDescription = null)
                    Spacer(modifier = Modifier.padding(4.dp))
                    Text("Open ${venueSummary.name} Chat")
                }
            }

            event.discordLink?.let { discord ->
                OutlinedButton(
                    onClick = { appState.openExternalUrl(context, discord.webUrl) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null)
                    Spacer(modifier = Modifier.padding(4.dp))
                    Text("Join Discord (${discord.subtitle})")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
