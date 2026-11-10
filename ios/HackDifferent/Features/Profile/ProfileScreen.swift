//
//  ProfileScreen.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import SwiftUI

struct ProfileScreen: View {
    @Environment(AppModel.self) private var appModel

    private var attendingEvents: [ConferenceEvent] {
        appModel.events.filter { $0.rsvpState == .attending || $0.rsvpState == .maybe }
    }

    var body: some View {
        NavigationStack {
            List {
                // Signed-In Hacker Profile
                Section("Account") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.18))
                                .frame(width: 52, height: 52)
                            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appModel.session.currentUser?.name ?? "Hack Different Member")
                                .font(.headline)
                            if let email = appModel.session.currentUser?.emailAddress {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if appModel.session.currentUser?.isAdmin == true {
                                Text("Audience Admin")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.teal.opacity(0.2)))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // My RSVPs
                Section("My RSVPs (\(attendingEvents.count))") {
                    if attendingEvents.isEmpty {
                        Text("You haven't RSVPed to any upcoming conferences or meetups yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attendingEvents) { event in
                            NavigationLink {
                                EventDetailScreen(event: event)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(event.venueDisplayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(event.rsvpState == .attending ? "Going" : "Interested")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(event.rsvpState == .attending ? .green : .orange)
                                }
                            }
                        }
                    }
                }

                // Connect Discord, for people who signed in with Apple: the Discord bridge then knows them as the
                // same person and shows them the server's channels as themselves. Once connected it shows the
                // Discord username.
                Section {
                    ConnectDiscordButton(client: appModel.client,
                                         device: appModel.configuration.currentDeviceDescription()) { _ in
                        await appModel.session.refreshProfile()
                    }
                } footer: {
                    Text(ConnectDiscordCopy.explanation)
                }

                Section("About") {
                    Link(destination: AppFeatures.termsURL) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: AppFeatures.privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    LabeledContent("Version", value: "\(appModel.configuration.marketingVersion) (\(appModel.configuration.buildNumber))")
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await appModel.session.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // App Store 5.1.1(v): deleting the account from inside the app. The SDK signs out on success,
                // and SessionStore shows sign-in on that event.
                Section {
                    DeleteAccountButton(client: appModel.client, appName: "Hack Different")
                } footer: {
                    Text("Deletes your profile, messages, RSVPs and passes for good.")
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await appModel.session.refreshProfile()
                await appModel.refreshCatalog()
            }
        }
    }
}
