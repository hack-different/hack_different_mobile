package com.hackdifferent.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.hackdifferent.app.AuthState
import com.hackdifferent.app.HackDifferentAppState

internal const val TERMS_URL = "https://audiencekit.com/terms/"
internal const val PRIVACY_URL = "https://audiencekit.com/privacy/"

@Composable
fun LoginScreen(appState: HackDifferentAppState) {
    val context = LocalContext.current
    var showingReviewDialog by remember { mutableStateOf(false) }
    var reviewCode by remember { mutableStateOf("") }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Spacer(modifier = Modifier.height(8.dp))

            // Brand Header
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(
                    modifier = Modifier
                        .size(84.dp)
                        .background(
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.16f),
                            shape = RoundedCornerShape(22.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Code,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(42.dp),
                    )
                }
                Spacer(modifier = Modifier.height(14.dp))
                Text(
                    text = appState.audienceName,
                    style = MaterialTheme.typography.headlineLarge.copy(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = appState.tagline,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            // Feature Highlights
            Surface(
                shape = RoundedCornerShape(18.dp),
                tonalElevation = 2.dp,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    FeatureRow(
                        icon = Icons.Default.Memory,
                        title = "Hackerspaces & Con Venues",
                        subtitle = "Explore community hackerspaces and conference venues near you.",
                    )
                    FeatureRow(
                        icon = Icons.Default.CalendarMonth,
                        title = "Conferences & Meetups",
                        subtitle = "RSVP for local meetups, talks, workshops, and security conferences.",
                    )
                    FeatureRow(
                        icon = Icons.Default.QrCodeScanner,
                        title = "Tickets & Live QR Passes",
                        subtitle = "Get event tickets and offline-ready rotating QR admission passes.",
                    )
                    FeatureRow(
                        icon = Icons.Default.Forum,
                        title = "Venue Chat & Discord",
                        subtitle = "Join real-time con and hackerspace chat rooms or jump into Discord.",
                    )
                }
            }

            // Sign-In Controls
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                appState.sessionEndedBanner?.let { banner ->
                    Text(
                        text = banner,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.tertiary,
                        textAlign = TextAlign.Center,
                    )
                }

                appState.errorMessage?.let { err ->
                    Text(
                        text = err,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        textAlign = TextAlign.Center,
                    )
                }

                if (appState.authState == AuthState.SIGNING_IN) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(vertical = 12.dp),
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
                        Text("Signing in to Hack Different…", style = MaterialTheme.typography.bodyMedium)
                    }
                } else {
                    Button(
                        onClick = { appState.startAppleSignIn(context) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                    ) {
                        Text(
                            text = "Sign in with Apple",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                        )
                    }
                }

                if (appState.isReviewSignInAvailable) {
                    TextButton(onClick = { showingReviewDialog = true }) {
                        Text("Have an App Review code?")
                    }
                }

                // Google Play UGC policy / App Store 1.2: members agree to the terms before they can post.
                Text(
                    text = "By signing in you agree to the Terms of Use and Privacy Policy. " +
                        "There's no tolerance for objectionable content or abusive members.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { appState.openExternalUrl(context, TERMS_URL) }) { Text("Terms of Use") }
                    TextButton(onClick = { appState.openExternalUrl(context, PRIVACY_URL) }) { Text("Privacy Policy") }
                }
            }
        }
    }

    if (showingReviewDialog) {
        AlertDialog(
            onDismissRequest = { showingReviewDialog = false },
            title = { Text("App Review Sign-In") },
            text = {
                OutlinedTextField(
                    value = reviewCode,
                    onValueChange = { reviewCode = it },
                    label = { Text("Enter review code") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val code = reviewCode
                        showingReviewDialog = false
                        appState.signInWithReviewCode(code)
                    },
                    enabled = reviewCode.isNotBlank(),
                ) {
                    Text("Sign In")
                }
            },
            dismissButton = {
                TextButton(onClick = { showingReviewDialog = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun FeatureRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(24.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
