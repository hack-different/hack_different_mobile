package com.hackdifferent.app.ui

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
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.Manifest
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.audiencekit.Venue
import com.hackdifferent.app.AppFeatures
import com.hackdifferent.app.HackDifferentAppState
import com.hackdifferent.core.ConferenceEvent
import com.hackdifferent.core.ChatRoomTarget
import com.hackdifferent.core.SpaceCategory
import com.hackdifferent.core.SpaceDetail
import com.hackdifferent.core.formattedAmount

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SpacesScreen(appState: HackDifferentAppState) {
    var selectedCategory by remember { mutableStateOf(SpaceCategory.ALL) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedVenue by remember { mutableStateOf<Venue?>(null) }
    var nearMeOnly by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        appState.refreshLocationIfPermitted()
    }

    val filteredVenues = remember(
        appState.venues,
        selectedCategory,
        searchQuery,
        nearMeOnly,
        appState.hasLocationOptIn,
        appState.closestLocale,
        appState.userCoordinate,
    ) {
        appState.venues.filter { venue ->
            val category = SpaceCategory.classify(venue.tags, venue.name)
            val matchesCategory = selectedCategory == SpaceCategory.ALL || category == selectedCategory
            val matchesSearch = searchQuery.isBlank() ||
                venue.name.contains(searchQuery, ignoreCase = true) ||
                venue.locale.name?.contains(searchQuery, ignoreCase = true) == true ||
                venue.location?.address?.contains(searchQuery, ignoreCase = true) == true
            val matchesLocation = !nearMeOnly || appState.isVenueNearby(venue)
            matchesSearch && matchesCategory && matchesLocation
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Spaces") },
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
                placeholder = { Text("Search hackerspaces, con venues, cities…") },
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
                SpaceCategory.entries.forEach { category ->
                    FilterChip(
                        selected = selectedCategory == category,
                        onClick = { selectedCategory = category },
                        label = { Text(category.label) },
                    )
                }
                FilterChip(
                    selected = nearMeOnly,
                    onClick = {
                        if (!appState.hasLocationOptIn) {
                            nearMeOnly = true
                            permissionLauncher.launch(
                                arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
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

            PullToRefreshBox(
                isRefreshing = appState.isLoadingDirectory,
                onRefresh = { appState.refreshAll() },
                modifier = Modifier.fillMaxSize(),
            ) {

            if (filteredVenues.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = if (appState.isLoadingDirectory) "Loading spaces…" else "No spaces found.",
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(filteredVenues, key = { it.id }) { venue ->
                        SpaceCard(
                            venue = venue,
                            onClick = { selectedVenue = venue },
                        )
                    }
                }
            }
            }
        }
    }

    selectedVenue?.let { venue ->
        VenueDetailSheet(
            venue = venue,
            appState = appState,
            onDismiss = { selectedVenue = null },
        )
    }
}

@Composable
private fun SpaceCard(
    venue: Venue,
    onClick: () -> Unit,
) {
    val category = SpaceCategory.classify(venue.tags, venue.name)
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
                    label = { Text(category.label) },
                )
                venue.locale.name?.let { region ->
                    Text(
                        text = region,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Text(
                text = venue.name,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )

            venue.location?.address?.let { address ->
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
                        text = address,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VenueDetailSheet(
    venue: Venue,
    appState: HackDifferentAppState,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var detail by remember { mutableStateOf<SpaceDetail?>(null) }
    var selectedEvent by remember { mutableStateOf<ConferenceEvent?>(null) }

    LaunchedEffect(venue.id) {
        detail = appState.loadVenueDetail(venue.id)
    }

    selectedEvent?.let { event ->
        EventDetailSheet(
            event = event,
            appState = appState,
            onDismiss = { selectedEvent = null },
            onEventUpdated = { updated -> selectedEvent = updated },
        )
        return
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = SpaceCategory.classify(venue.tags, venue.name).label.uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = venue.name,
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
            )

            val address = detail?.address ?: venue.location?.address
            address?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            detail?.description?.takeIf { it.isNotBlank() }?.let { desc ->
                Text(text = desc, style = MaterialTheme.typography.bodyMedium)
            }

            TagChips(venue.tags)

            detail?.coverCharge?.takeIf { AppFeatures.IN_APP_PASSES }?.let { cover ->
                Text(
                    text = "Admission / Pass: ${cover.total.formattedAmount}",
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Button(
                onClick = {
                    onDismiss()
                    appState.openChatRoom(
                        ChatRoomTarget.VenueRoom(
                            recordId = venue.id,
                            displayName = venue.name,
                            subtitle = address,
                            discordLink = detail?.discordLink,
                        ),
                    )
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Default.Forum, contentDescription = null)
                Spacer(modifier = Modifier.padding(4.dp))
                Text("Join ${venue.name} Live Chat")
            }

            RecentMessages(detail?.recentMessages.orEmpty())

            VenueCalendarButton(client = appState.client, venueId = venue.id, venueName = venue.name)

            detail?.discordLink?.let { discord ->
                OutlinedButton(
                    onClick = { appState.openExternalUrl(context, discord.webUrl) },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null)
                    Spacer(modifier = Modifier.padding(4.dp))
                    Text("Open Discord (${discord.subtitle})")
                }
            }

            detail?.ticketOffers?.takeIf { it.isNotEmpty() }?.let { offers ->
                DetailHeading("Tickets")
                TicketOffers(offers) { appState.openExternalUrl(context, it) }
            }

            UpcomingEvents(detail?.upcomingEvents.orEmpty()) { selectedEvent = it }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
