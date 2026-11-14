package com.hackdifferent.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.audiencekit.GitHubCopy
import com.audiencekit.GitHubProject
import com.audiencekit.GitHubProjectItem
import com.hackdifferent.app.HackDifferentAppState

// The community's GitHub: what's assigned to you, its public GitHub Projects and its repositories. Everything comes
// from the AudienceKit SDK (gitHubCommunity, gitHubProject, myGitHubItems); this file only lays it out.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GitHubScreen(appState: HackDifferentAppState) {
    var openProject by remember { mutableStateOf<Pair<Int, String>?>(null) }
    LaunchedEffect(Unit) { appState.refreshGitHub() }

    openProject?.let { (number, title) ->
        GitHubProjectScreen(appState, number, title, onBack = { openProject = null })
        return
    }

    val context = LocalContext.current
    val community = appState.gitHub
    Scaffold(topBar = { TopAppBar(title = { Text(GitHubCopy.TITLE) }) }) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            community?.organization?.let { organization ->
                item {
                    Column {
                        Text(organization.displayName, style = MaterialTheme.typography.titleLarge)
                        organization.description?.let {
                            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text(
                            GitHubCopy.OPEN_ON_GITHUB,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.clickable { appState.openExternalUrl(context, organization.url) },
                        )
                    }
                }
            }

            item { SectionTitle(GitHubCopy.MY_WORK) }
            when {
                community?.viewerLogin == null -> item { Hint(GitHubCopy.CONNECT_TO_SEE_YOUR_WORK) }
                appState.myGitHubItems.isEmpty() -> item { Hint(GitHubCopy.NOTHING_ASSIGNED) }
                else -> items(appState.myGitHubItems, key = { "mine-${it.id}" }) { item ->
                    GitHubItemCard(item, showsStatus = true) { url -> appState.openExternalUrl(context, url) }
                }
            }

            val projects = community?.projects.orEmpty()
            if (projects.isNotEmpty()) {
                item { SectionTitle(GitHubCopy.PROJECTS) }
                items(projects, key = { "project-${it.number}" }) { project ->
                    Card(modifier = Modifier.fillMaxWidth().clickable { openProject = project.number to project.title }) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text(project.title, style = MaterialTheme.typography.titleMedium)
                            project.shortDescription?.let {
                                Text(it, style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            }
                            Text("${project.itemCount} items", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }

            val repositories = community?.repositories.orEmpty()
            if (repositories.isNotEmpty()) {
                item { SectionTitle(GitHubCopy.REPOSITORIES) }
                items(repositories, key = { "repo-${it.nameWithOwner}" }) { repository ->
                    Card(modifier = Modifier.fillMaxWidth().clickable { appState.openExternalUrl(context, repository.url) }) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Text(repository.name, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold)
                            repository.description?.let {
                                Text(it, style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            }
                            Text(
                                listOfNotNull(repository.language, "★ ${repository.stars}", "${repository.openIssues} open issues")
                                    .joinToString("  ·  "),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}

/** A project as a board: one group per Status column, in the project's order. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GitHubProjectScreen(appState: HackDifferentAppState, number: Int, title: String, onBack: () -> Unit) {
    val context = LocalContext.current
    var project by remember(number) { mutableStateOf<GitHubProject?>(null) }
    var loading by remember(number) { mutableStateOf(true) }
    LaunchedEffect(number) {
        project = appState.loadGitHubProject(number)
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
                },
            )
        },
    ) { innerPadding ->
        val board = project
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            when {
                board != null -> {
                    board.shortDescription?.let { item { Hint(it) } }
                    board.columns.forEach { column ->
                        item(key = "column-${column.status}") { SectionTitle("${column.status} (${column.items.size})") }
                        items(column.items, key = { it.id }) { item ->
                            GitHubItemCard(item) { url -> appState.openExternalUrl(context, url) }
                        }
                    }
                    item {
                        Text(
                            GitHubCopy.OPEN_ON_GITHUB,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.clickable { appState.openExternalUrl(context, board.url) },
                        )
                    }
                }
                loading -> item { CircularProgressIndicator() }
                else -> item { Hint("This project isn't available.") }
            }
        }
    }
}

@Composable
private fun GitHubItemCard(item: GitHubProjectItem, showsStatus: Boolean = false, open: (String) -> Unit) {
    val url = item.url
    Card(modifier = Modifier.fillMaxWidth().let { if (url != null) it.clickable { open(url) } else it }) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(
                item.title,
                fontWeight = FontWeight.SemiBold,
                textDecoration = if (item.isDone) TextDecoration.LineThrough else null,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(item.reference ?: GitHubCopy.type(item.type), fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.labelSmall)
                if (showsStatus) item.status?.let { Text(it, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold) }
                item.labels.take(3).forEach { Text(it.name, style = MaterialTheme.typography.labelSmall) }
                if (item.assignees.isNotEmpty()) {
                    Text(
                        item.assignees.joinToString(" ") { "@${it.login}" },
                        style = MaterialTheme.typography.labelSmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
}

@Composable
private fun Hint(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}
