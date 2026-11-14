package com.hackdifferent.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.audiencekit.AdmissionOffer
import com.audiencekit.ChatMessage
import com.audiencekit.EventPerson
import com.audiencekit.Tag
import com.hackdifferent.core.ConferenceEvent
import com.hackdifferent.core.formatEventStart
import com.hackdifferent.core.formattedAmount
import com.hackdifferent.core.senderName
import com.hackdifferent.core.text

/** A detail sheet's section heading (iOS's `Section("…")`). */
@Composable
internal fun DetailHeading(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
        modifier = Modifier.padding(top = 4.dp),
    )
}

/** An event's or space's tags as `#name` chips. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun TagChips(tags: List<Tag>) {
    if (tags.isEmpty()) return
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        tags.forEach { tag ->
            AssistChip(onClick = {}, label = { Text("#${tag.name}", style = MaterialTheme.typography.labelSmall) })
        }
    }
}

/** Organizers and speakers (an event's hosts and lineup), each with their role underneath. */
@Composable
internal fun EventPeopleSection(hosts: List<EventPerson>, lineup: List<EventPerson>) {
    if (hosts.isEmpty() && lineup.isEmpty()) return
    DetailHeading("Organizers & Speakers")
    hosts.forEach { PersonRow(it, "Organizer / Host") }
    lineup.forEach { PersonRow(it, "Speaker / Lineup") }
}

@Composable
private fun PersonRow(person: EventPerson, role: String) {
    Column {
        Text(person.name ?: "To be announced", style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
        Text(role, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Ticket offers by seller ("Tickets via Eventbrite · From $25"), each opening the seller's page. */
@Composable
internal fun TicketOffers(offers: List<AdmissionOffer>, onOpen: (String) -> Unit) {
    offers.forEach { offer ->
        val url = offer.url
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .let { if (url != null) it.clickable { onOpen(url) } else it }
                .padding(vertical = 4.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Tickets via ${offer.seller.name}", style = MaterialTheme.typography.bodyMedium)
                Text(
                    text = offer.price?.let { "From ${it.formattedAmount}" } ?: "At Door",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (url != null) {
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

/** The last few lines of a space's chat ("Ada L.: hi"). */
@Composable
internal fun RecentMessages(messages: List<ChatMessage>) {
    if (messages.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        messages.takeLast(3).forEach { line ->
            Text(
                text = "${line.senderName}: ${line.text}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** A space's upcoming conferences and meetups; tapping one opens it. */
@Composable
internal fun UpcomingEvents(events: List<ConferenceEvent>, onSelect: (ConferenceEvent) -> Unit) {
    if (events.isEmpty()) return
    DetailHeading("Upcoming Conferences & Meetups")
    events.forEach { event ->
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onSelect(event) }
                .padding(vertical = 4.dp),
        ) {
            Text(event.name, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
            event.startAt?.let {
                Text(formatEventStart(it), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
