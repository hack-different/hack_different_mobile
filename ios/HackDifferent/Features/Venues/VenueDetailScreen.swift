//
//  VenueDetailScreen.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import SwiftUI

struct VenueDetailScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL

    let venueID: String
    let initialName: String
    var initialVenue: Venue?

    @State private var detail: SpaceDetail?
    @State private var isLoading = true
    @State private var isPurchasingCover = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            // Overview Section
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    let category = detail?.category ?? SpaceCategory.classify(tags: initialVenue?.tags, name: initialName)
                    HStack(spacing: 8) {
                        Label(
                            category == .conferenceVenue ? "Conference Venue" : "Hackerspace",
                            systemImage: category.systemImage
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(category == .conferenceVenue ? Color.indigo.opacity(0.18) : Color.teal.opacity(0.18))
                        )
                        .foregroundStyle(category == .conferenceVenue ? .indigo : .teal)

                        if let localeName = detail?.venue.locale.name ?? initialVenue?.locale.name {
                            Text(localeName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let distance = appModel.location.formattedDistance(
                            to: detail?.venue.location?.coordinate ?? initialVenue?.location?.coordinate
                        ) {
                            Label(distance, systemImage: "location.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.teal)
                        }
                    }

                    Text(detail?.name ?? initialName)
                        .font(.title2.bold())

                    if let address = detail?.address ?? initialVenue?.location?.address, !address.isEmpty {
                        Button {
                            openInMaps(address: address, coordinate: detail?.venue.location?.coordinate ?? initialVenue?.location?.coordinate)
                        } label: {
                            Label(address, systemImage: "map.fill")
                                .font(.subheadline)
                        }
                    }

                    if let description = detail?.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    if let tags = detail?.venue.tags ?? initialVenue?.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags) { tag in
                                    Text("#\(tag.name)")
                                        .font(.caption2.monospaced())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Calendar: every event here in the person's one calendar feed (AudienceKit calendar sync).
            Section {
                VenueCalendarButton(client: appModel.api.client, venueID: venueID,
                                    venueName: detail?.name ?? initialName)
            } footer: {
                Text("Adds every event here to your calendar, kept up to date as meetups are added, moved or canceled.")
            }

            // Venue / Con Chat & Discord Section
            Section("Live Chat & Discord") {
                NavigationLink {
                    RoomChatScreen(
                        room: .venue(
                            id: venueID,
                            name: detail?.name ?? initialName,
                            subtitle: detail?.category == .conferenceVenue ? "Conference Venue Chat" : "Hackerspace Chat",
                            discordLink: detail?.discordLink
                        )
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(detail?.name ?? initialName) Live Chat")
                                        .font(.subheadline.weight(.semibold))
                                    Text(detail?.chatOpen == true ? "Room open now" : "Real-time venue & conference room")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                                    .foregroundStyle(.tint)
                            }
                            Spacer()
                            if detail?.chatOpen == true {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        if let recent = detail?.recentMessages, !recent.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(recent.suffix(3)) { line in
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("\(line.senderName):")
                                            .font(.caption.weight(.semibold))
                                        Text(line.body)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let discord = detail?.discordLink {
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

                if let links = detail?.socialLinks.filter({ !$0.isDiscord }), !links.isEmpty {
                    ForEach(links) { link in
                        if let url = link.webURL {
                            Button {
                                openURL(url)
                            } label: {
                                HStack {
                                    Label(link.displayLabel, systemImage: link.systemImage)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Ticketing & Venue Cover Pass Section
            if let detail, (detail.viewerAdmission != nil || (AppFeatures.inAppPasses && detail.coverCharge != nil) || !detail.ticketOffers.isEmpty) {
                Section(AppFeatures.inAppPasses ? "Tickets & Venue Pass" : "Tickets") {
                    if let admission = detail.viewerAdmission {
                        NavigationLink {
                            PassQRCodeView(admission: admission)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Your Pass for \(detail.name)")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Night of \(admission.night) • \(admission.status.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "qrcode")
                                    .foregroundStyle(.green)
                            }
                        }
                    } else if AppFeatures.inAppPasses, let cover = detail.coverCharge {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Entry / Day Pass")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(cover.total.formattedAmount) • Night of \(cover.night)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if cover.payable {
                                Button {
                                    Task { await buyVenuePass() }
                                } label: {
                                    if isPurchasingCover {
                                        ProgressView()
                                    } else {
                                        Text("Get Pass")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .accentProminentButtonStyle()
                                .disabled(isPurchasingCover)
                            } else {
                                Text("At Door")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(detail.ticketOffers) { offer in
                        if let url = offer.webURL {
                            Button {
                                openURL(url)
                            } label: {
                                HStack {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Tickets via \(offer.seller.name)")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if let price = offer.price {
                                                Text(price.formattedAmount)
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
                    }
                }
            }

            // Upcoming Conferences & Meetups at this Space
            Section("Upcoming Conferences & Meetups") {
                let venueEvents: [ConferenceEvent] = {
                    if let loaded = detail?.upcomingEvents, !loaded.isEmpty {
                        return loaded
                    }
                    return appModel.events.filter { $0.venue?.id == venueID }
                }()

                if isLoading && detail == nil && venueEvents.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading schedule…")
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if !venueEvents.isEmpty {
                    ForEach(venueEvents) { event in
                        NavigationLink {
                            EventDetailScreen(event: event)
                        } label: {
                            EventRowView(event: event)
                        }
                    }
                } else {
                    Text("No upcoming conferences or meetups scheduled at this space yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .navigationTitle(detail?.name ?? initialName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .refreshable {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            detail = try await appModel.api.venueDetail(id: venueID)
        } catch let error as AudienceKitError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buyVenuePass() async {
        isPurchasingCover = true
        errorMessage = nil
        defer { isPurchasingCover = false }

        do {
            let purchase = try await appModel.api.buyCover(venueID: venueID)
            if purchase.admission.status != .paid {
                _ = try await appModel.api.confirmCover(admissionID: purchase.admission.id)
            }
            await appModel.refreshAdmissions()
            await loadDetail()
        } catch let error as AudienceKitError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openInMaps(address: String, coordinate: Coordinate?) {
        if let coordinate,
           let url = URL(string: "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            openURL(url)
        } else if let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            openURL(url)
        }
    }
}
