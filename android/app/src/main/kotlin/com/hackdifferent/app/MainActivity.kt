package com.hackdifferent.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.ViewKanban
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.hackdifferent.app.ui.ChatScreen
import com.hackdifferent.app.ui.EventsScreen
import com.hackdifferent.app.ui.GitHubScreen
import com.hackdifferent.app.ui.HackDifferentTheme
import com.hackdifferent.app.ui.LoginScreen
import com.hackdifferent.app.ui.PassesScreen
import com.hackdifferent.app.ui.ProfileScreen
import com.hackdifferent.app.ui.SpacesScreen

class MainActivity : ComponentActivity() {
    private lateinit var appState: HackDifferentAppState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Dark-mode only: keep light status/nav bar icons regardless of the system theme.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )

        appState = HackDifferentAppState(applicationContext)
        appState.start()
        appState.handleIncomingIntent(intent)

        setContent {
            HackDifferentTheme(branding = appState.branding) {
                HackDifferentRoot(appState = appState)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (::appState.isInitialized) {
            appState.handleIncomingIntent(intent)
        }
    }
}

@Composable
private fun HackDifferentRoot(appState: HackDifferentAppState) {
    when (appState.authState) {
        AuthState.RESTORING -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        AuthState.SIGNED_OUT, AuthState.SIGNING_IN -> {
            LoginScreen(appState = appState)
        }
        AuthState.SIGNED_IN -> {
            Scaffold(
                bottomBar = {
                    NavigationBar {
                        AppTab.entries.filter { it != AppTab.GITHUB || appState.gitHub != null }.forEach { tab ->
                            NavigationBarItem(
                                selected = appState.selectedTab == tab,
                                onClick = { appState.selectedTab = tab },
                                icon = {
                                    Icon(
                                        imageVector = when (tab) {
                                            AppTab.EVENTS -> Icons.Default.CalendarMonth
                                            AppTab.SPACES -> Icons.Default.Memory
                                            AppTab.PASSES -> Icons.Default.QrCode2
                                            AppTab.CHAT -> Icons.Default.Forum
                                            AppTab.GITHUB -> Icons.Default.ViewKanban
                                            AppTab.PROFILE -> Icons.Default.Person
                                        },
                                        contentDescription = tab.label,
                                    )
                                },
                                label = { Text(tab.label) },
                            )
                        }
                    }
                },
            ) { innerPadding ->
                Box(modifier = Modifier.padding(innerPadding)) {
                    when (appState.selectedTab) {
                        AppTab.EVENTS -> EventsScreen(appState = appState)
                        AppTab.SPACES -> SpacesScreen(appState = appState)
                        AppTab.PASSES -> PassesScreen(appState = appState)
                        AppTab.CHAT -> ChatScreen(appState = appState)
                        AppTab.GITHUB -> GitHubScreen(appState = appState)
                        AppTab.PROFILE -> ProfileScreen(appState = appState)
                    }
                }
            }
        }
    }
}
