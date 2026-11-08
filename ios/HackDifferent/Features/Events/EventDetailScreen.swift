//
//  EventDetailScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct EventDetailScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL

    @State var event: ConferenceEvent
    @State private var isUpdatingRSVP = false
    @State private var isPurchasingCover = false
    @State private var purchasedPass: Admission?
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Label(event.kind.badgeLabel, systemImage: event.kind.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(event.kind == .conference ? Color.purple.opacity(0.18) : Color.blue.opacity(0.18))
                            )
                            .foregroundStyle(event.kind == .conference ? .purple : .blue)

                        if let localeName = event.locale?.name ?? event.locale?.label {
                            Text(localeName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let distance = appModel.location.formattedDistance(
                            to: event.venue?.coordinate
                                ?? appModel.venues.first(where: { $0.id == event.venue?.id })?.location?.coordinate
                        ) {
                            Label(distance, systemImage: "location.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.teal)
                        }
                    }

                    Text(event.name)
                        .font(.title2.bold())

                    if let startAt = event.startAt {
                        Label {
                            if let endAt = event.endAt {
                                Text("\(startAt.formatted(date: .abbreviated, time: .shortened)) – \(endAt.formatted(date: .abbreviated, time: .shortened))")
                            } else {
                                Text(startAt.formatted(date: .complete, time: .shortened))
                            }
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.tint)
                        }
                        .font(.subheadline)
                    }

                    if let recurrenceText = event.recurrenceText, !recurrenceText.isEmpty {
                        Label(recurrenceText, systemImage: "repeat")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let venue = event.venue {
                        NavigationLink {
                            VenueDetailScreen(venueID: venue.id, initialName: venue.name)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(venue.name)
                                        .font(.subheadline.weight(.semibold))
                                    if let address = venue.address {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    } else {
                        Label(event.venueDisplayName, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !event.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(event.tags) { tag in
                                    Text("#\(tag.name)")
                                        .font(.caption2.monospaced())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(Color(.tertiarySystemFill))
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Meetup & Conference RSVP Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("RSVP for this \(event.kind.badgeLabel)", systemImage: "person.badge.plus")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if event.rsvpCount > 0 {
                            Text("\(event.rsvpCount) attending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        RSVPButton(
                            title: "Going",
                            systemImage: "checkmark.circle.fill",
                            isSelected: event.rsvpState == .attending,
                            tint: .green
                        ) {
                            await selectRSVP(.attending)
                        }

                        RSVPButton(
                            title: "Interested",
                            systemImage: "star.circle.fill",
                            isSelected: event.rsvpState == .maybe,
                            tint: .orange
                        ) {
                            await selectRSVP(.maybe)
                        }

                        RSVPButton(
                            title: "Not Going",
                            systemImage: "xmark.circle",
                            isSelected: event.rsvpState == .declined,
                            tint: .secondary
                        ) {
                            await selectRSVP(.declined)
                        }
                    }
                    .disabled(isUpdatingRSVP)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Attendance")
            }

            // Ticketing & Passes Section
            if showsTicketing {
                Section(AppFeatures.inAppPasses ? "Tickets & Passes" : "Tickets") {
                    if let pass = purchasedPass {
                        NavigationLink {
                            PassQRCodeView(admission: pass)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View Your Admission Pass")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Night of \(pass.night) • \(pass.status.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "qrcode")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    if AppFeatures.inAppPasses, let cover = event.coverCharge {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Admission / Door Pass")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(cover.total.formattedAmount) (\(appModel.configuration.feeLabel): \(cover.fee.formattedAmount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if cover.payable, let venueID = event.venue?.id {
                                Button {
                                    Task { await purchaseVenuePass(venueID: venueID) }
                                } label: {
                                    if isPurchasingCover {
                                        ProgressView()
                                    } else {
                                        Text("Get Pass")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isPurchasingCover)
                            } else {
                                Text("At Door")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(event.ticketOffers) { offer in
                        Button {
                            if let url = offer.webURL ?? event.ticketURL {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Tickets via \(offer.seller.name)")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                        if let price = offer.price {
                                            Text("From \(price.formattedAmount)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "ticket.fill")
                                        .foregroundStyle(.tint)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if event.ticketOffers.isEmpty, let ticketURL = event.ticketURL {
                        Button {
                            openURL(ticketURL)
                        } label: {
                            HStack {
                                Label("Buy Conference / Event Tickets", systemImage: "ticket.fill")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                }
            }

            // Con / Venue Chat & Discord Section
            Section("Chat & Community") {
                if let venue = event.venue {
                    NavigationLink {
                        RoomChatScreen(
                            room: .venue(
                                id: venue.id,
                                name: venue.name,
                                subtitle: event.name,
                                discordLink: event.discordLink
                            )
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(event.name) / \(venue.name) Live Chat")
                                    .font(.subheadline.weight(.semibold))
                                Text("Real-time room for attendees & speakers")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }

                if let discord = event.discordLink {
                    Button {
                        openURL(discord.webURL)
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(discord.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(discord.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundStyle(.indigo)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Speakers / Hosts / Lineup
            if !event.hosts.isEmpty || !event.lineup.isEmpty {
                Section("Organizers & Speakers") {
                    ForEach(event.hosts) { host in
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(host.name ?? "Organizer")
                                    .font(.subheadline.weight(.medium))
                                Text("Organizer / Host")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    ForEach(event.lineup.filter { speaker in !event.hosts.contains(where: { $0.id == speaker.id }) }) { speaker in
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(speaker.name ?? "Speaker")
                                    .font(.subheadline.weight(.medium))
                                Text("Speaker / Lineup")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Description
            if let description = event.description, !description.isEmpty {
                Section("About") {
                    Text(description)
                        .font(.body)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(event.kind.badgeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let latest = try? await appModel.api.eventDetail(id: event.id) {
                event = latest
            }
        }
    }

    private func selectRSVP(_ newState: RSVPState) async {
        isUpdatingRSVP = true
        errorMessage = nil
        defer { isUpdatingRSVP = false }

        do {
            try await appModel.updateEventRSVP(newState, for: event.id)
            if event.rsvpState != .attending && newState == .attending {
                event.rsvpCount += 1
            } else if event.rsvpState == .attending && newState != .attending {
                event.rsvpCount = max(0, event.rsvpCount - 1)
            }
            event.rsvpState = newState
        } catch let error as AudienceKitError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Organizer ticket links always show; the cover row only while in-app passes are on (see ``AppFeatures``).
    private var showsTicketing: Bool {
        purchasedPass != nil || event.ticketURL != nil || !event.ticketOffers.isEmpty
            || (AppFeatures.inAppPasses && event.coverCharge != nil)
    }

    private func purchaseVenuePass(venueID: String) async {
        isPurchasingCover = true
        errorMessage = nil
        defer { isPurchasingCover = false }

        do {
            let purchase = try await appModel.api.buyCover(venueID: venueID)
            if purchase.admission.status == .paid {
                purchasedPass = purchase.admission
            } else {
                purchasedPass = try await appModel.api.confirmCover(admissionID: purchase.admission.id)
            }
            await appModel.refreshAdmissions()
        } catch let error as AudienceKitError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RSVPButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let tint: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.2) : Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? tint : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? tint : .primary)
        }
        .buttonStyle(.plain)
    }
}
