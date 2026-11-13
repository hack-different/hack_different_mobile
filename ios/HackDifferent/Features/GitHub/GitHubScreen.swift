//
//  GitHubScreen.swift
//  HackDifferent
//
//  The community's GitHub: what's assigned to you, its public GitHub Projects and its repositories. Everything comes
//  from the AudienceKit SDK (gitHubCommunity, gitHubProject, myGitHubItems); this file only lays it out.
//

import AudienceKit
import SwiftUI

struct GitHubScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var myItems: [GitHubProjectItem] = []
    @State private var community: GitHubCommunity?

    private var shown: GitHubCommunity? { community ?? appModel.gitHub }

    var body: some View {
        NavigationStack {
            List {
                if let organization = shown?.organization {
                    Section {
                        OrganizationHeader(organization: organization)
                    }
                }

                Section(GitHubCopy.myWork) {
                    if shown?.viewerLogin == nil {
                        Text(GitHubCopy.connectToSeeYourWork)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if myItems.isEmpty {
                        Text(GitHubCopy.nothingAssigned)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(myItems) { item in
                            GitHubItemRow(item: item, showsStatus: true)
                        }
                    }
                }

                let projects = shown?.projects ?? []
                if !projects.isEmpty {
                    Section(GitHubCopy.projects) {
                        ForEach(projects) { project in
                            NavigationLink {
                                GitHubProjectScreen(number: project.number, title: project.title)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title).font(.headline)
                                    if let summary = project.shortDescription {
                                        Text(summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Text("\(project.itemCount) items")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                let repositories = shown?.repositories ?? []
                if !repositories.isEmpty {
                    Section(GitHubCopy.repositories) {
                        ForEach(repositories) { repository in
                            RepositoryRow(repository: repository)
                        }
                    }
                }
            }
            .navigationTitle(GitHubCopy.title)
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        async let refreshed = try? appModel.client.gitHubCommunity()
        async let mine = try? appModel.client.myGitHubItems()
        if let refreshed = await refreshed { community = refreshed }
        myItems = await mine ?? []
    }
}

private struct OrganizationHeader: View {
    let organization: GitHubOrganization

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: organization.avatarUrl.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.tint)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(organization.displayName).font(.headline)
                if let description = organization.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let url = URL(string: organization.url) {
                    Link(GitHubCopy.openOnGitHub, destination: url).font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RepositoryRow: View {
    let repository: GitHubRepository

    var body: some View {
        if let url = URL(string: repository.url) {
            Link(destination: url) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name)
                        .font(.body.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)
                    if let description = repository.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 12) {
                        if let language = repository.language {
                            Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        Label("\(repository.stars)", systemImage: "star")
                        Label("\(repository.openIssues)", systemImage: "smallcircle.filled.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// An issue, pull request or draft from a project.
struct GitHubItemRow: View {
    let item: GitHubProjectItem
    var showsStatus = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isDone ? .secondary : .primary)
                .strikethrough(item.isDone)
            HStack(spacing: 8) {
                Text(item.reference ?? GitHubCopy.type(item.type))
                    .font(.caption.monospaced())
                if showsStatus, let status = item.status {
                    Text(status)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                }
                ForEach(item.labels.prefix(3), id: \.name) { label in
                    Text(label.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(gitHubHex: label.color).opacity(0.25)))
                }
                Spacer(minLength: 0)
                if !item.assignees.isEmpty {
                    Text(item.assignees.map { "@\($0.login)" }.joined(separator: " "))
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)

        if let url = item.url.flatMap(URL.init(string:)) {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}

/// A project as a board: one section per Status column, in the project's order.
struct GitHubProjectScreen: View {
    @Environment(AppModel.self) private var appModel
    let number: Int
    let title: String
    @State private var project: GitHubProject?
    @State private var isLoading = true

    var body: some View {
        List {
            if let project {
                if let summary = project.shortDescription {
                    Section { Text(summary).foregroundStyle(.secondary) }
                }
                ForEach(project.columns, id: \.status) { column in
                    Section("\(column.status) (\(column.items.count))") {
                        ForEach(column.items) { item in
                            GitHubItemRow(item: item)
                        }
                    }
                }
                if let url = URL(string: project.url) {
                    Section { Link(GitHubCopy.openOnGitHub, destination: url) }
                }
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("This project isn't available.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        project = try? await appModel.client.gitHubProject(number: number)
    }
}

private extension Color {
    /// A GitHub label color: six hex digits without `#`.
    init(gitHubHex hex: String?) {
        let value = UInt32(hex ?? "", radix: 16) ?? 0x8E8E93
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
