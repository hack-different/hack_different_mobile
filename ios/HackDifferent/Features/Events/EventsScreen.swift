//
//  EventsScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

enum RegionFilterSelection: Hashable {
    case all
    case nearMe
    case locale(String)
}

struct EventsScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedKind: EventKind = .all
    @State private var selectedRegion: RegionFilterSelection = .all
    @State private var searchText = ""

    private var baseFilteredEvents: [ConferenceEvent] {
        appModel.events.filter { event in
            if selectedKind != .all && event.kind != selectedKind {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesName = event.name.lowercased().contains(query)
                let matchesDesc = (event.description ?? "").lowercased().contains(query)
                let matchesVenue = event.venueDisplayName.lowercased().contains(query)
                let matchesLocale = (event.locale?.name ?? event.locale?.label ?? "").lowercased().contains(query)
                let matchesTag = event.tags.contains { $0.name.lowercased().contains(query) }
                if !matchesName && !matchesDesc && !matchesVenue && !matchesLocale && !matchesTag {
                    return false
                }
            }
            return true
        }
    }

    private var nearbyEvents: [ConferenceEvent] {
        guard appModel.location.isAuthorized else { return [] }
        return baseFilteredEvents
            .filter { appModel.location.isEventNearby($0, venues: appModel.venues) }
            .sorted { lhs, rhs in
                let lhsDist = distanceForEvent(lhs) ?? .greatestFiniteMagnitude
                let rhsDist = distanceForEvent(rhs) ?? .greatestFiniteMagnitude
                if lhsDist != rhsDist {
                    return lhsDist < rhsDist
                }
                return (lhs.startAt ?? .distantFuture) < (rhs.startAt ?? .distantFuture)
            }
    }

    private var displayedEvents: [ConferenceEvent] {
        switch selectedRegion {
        case .all:
            return baseFilteredEvents
        case .nearMe:
            return nearbyEvents
        case .locale(let localeID):
            return baseFilteredEvents.filter { $0.locale?.id == localeID }
        }
    }

    private var nearMeChipTitle: String {
        if appModel.location.isAuthorized,
           let localeName = appModel.location.closestLocale?.name ?? appModel.location.closestLocale?.label {
            return "Near Me • \(localeName)"
        }
        return "Near Me"
    }

    private func distanceForEvent(_ event: ConferenceEvent) -> Double? {
        let coord = event.venue?.coordinate
            ?? appModel.venues.first(where: { $0.id == event.venue?.id })?.location?.coordinate
        return appModel.location.distanceInMeters(to: coord)
    }

    private func formattedDistanceForEvent(_ event: ConferenceEvent) -> String? {
        let coord = event.venue?.coordinate
            ?? appModel.venues.first(where: { $0.id == event.venue?.id })?.location?.coordinate
        return appModel.location.formattedDistance(to: coord)
    }

    var body: some View {
        NavigationStack {
            List {
                // Filter Header Section
                Section {
                    Picker("Event Type", selection: $selectedKind) {
                        ForEach(EventKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All Events",
                                systemImage: "globe",
                                isSelected: selectedRegion == .all
                            ) {
                                selectedRegion = .all
                            }

                            FilterChip(
                                title: nearMeChipTitle,
                                systemImage: appModel.location.isAuthorized ? "location.fill" : "location",
                                isSelected: selectedRegion == .nearMe
                            ) {
                                selectedRegion = .nearMe
                                if !appModel.location.isAuthorized {
                                    appModel.location.requestOptIn()
                                } else {
                                    appModel.location.refreshIfAuthorized()
                                }
                            }

                            ForEach(appModel.locales) { locale in
                                FilterChip(
                                    title: locale.name ?? locale.label ?? "Region",
                                    isSelected: selectedRegion == .locale(locale.id)
                                ) {
                                    selectedRegion = .locale(locale.id)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                // Opt-in Location Banner (non-blocking) when not yet opted in
                if !appModel.location.isAuthorized && !appModel.location.isDenied {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local Events Near You")
                                    .font(.subheadline.weight(.semibold))
                                Text("Opt in to location to highlight nearby meetups and conferences alongside all global events.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Enable") {
                                appModel.location.requestOptIn()
                            }
                            .accentProminentButtonStyle()
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Error Banner if catalog failed
                if let catalogError = appModel.catalogError {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Couldn't Refresh Events")
                                    .font(.subheadline.weight(.semibold))
                                Text(catalogError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Retry") {
                                Task { await appModel.refreshCatalog() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                if appModel.isLoadingCatalog && appModel.events.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading conferences & meetups…")
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if selectedRegion == .nearMe && !appModel.location.isAuthorized {
                    Section {
                        ContentUnavailableView {
                            Label("Location Opt-In Required", systemImage: "location.circle")
                        } description: {
                            Text("Enable location access to filter to conferences and meetups near your current location, or view All Events.")
                        } actions: {
                            HStack(spacing: 12) {
                                if !appModel.location.isDenied {
                                    Button("Enable Location") {
                                        appModel.location.requestOptIn()
                                    }
                                    .accentProminentButtonStyle()
                                }
                                Button("Show All Events") {
                                    selectedRegion = .all
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                } else if displayedEvents.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label(
                                selectedRegion == .nearMe ? "No Local Events Nearby" : "No Events Found",
                                systemImage: selectedKind.systemImage
                            )
                        } description: {
                            Text(
                                selectedRegion == .nearMe
                                    ? "No location-specific events matched your immediate area. Switch to All Events to browse every conference and meetup."
                                    : "Pull to refresh or adjust your filters to see upcoming Hack Different events."
                            )
                        } actions: {
                            if selectedRegion != .all {
                                Button("Show All Events") {
                                    selectedRegion = .all
                                }
                                .accentProminentButtonStyle()
                            }
                        }
                        .padding(.vertical, 24)
                    }
                } else {
                    // When viewing "All Events" and opted into location, show location-specific events first!
                    if selectedRegion == .all && appModel.location.isAuthorized && !nearbyEvents.isEmpty {
                        let regionTitle = appModel.location.closestLocale?.name
                            ?? appModel.location.closestLocale?.label
                            ?? "Near You"
                        Section {
                            ForEach(nearbyEvents) { event in
                                NavigationLink(value: event) {
                                    EventRowView(
                                        event: event,
                                        distanceLabel: formattedDistanceForEvent(event)
                                    )
                                }
                                .accessibilityIdentifier("event.row")
                            }
                        } header: {
                            Label("Near You • \(regionTitle)", systemImage: "location.fill")
                        }
                    }

                    // All (or filtered) Events Section
                    let sectionTitle: String = {
                        switch selectedRegion {
                        case .all:
                            return "All Events (\(displayedEvents.count))"
                        case .nearMe:
                            return "Near You (\(displayedEvents.count))"
                        case .locale(let id):
                            let name = appModel.locales.first(where: { $0.id == id })?.name ?? "Regional"
                            return "\(name) (\(displayedEvents.count))"
                        }
                    }()

                    Section(sectionTitle) {
                        ForEach(displayedEvents) { event in
                            NavigationLink(value: event) {
                                EventRowView(
                                    event: event,
                                    distanceLabel: formattedDistanceForEvent(event)
                                )
                            }
                            .accessibilityIdentifier("event.row")
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .searchable(text: $searchText, prompt: "Search cons, meetups, venues, tags…")
            .refreshable {
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: ConferenceEvent.self) { event in
                EventDetailScreen(event: event)
            }
        }
    }
}

struct EventRowView: View {
    let event: ConferenceEvent
    var distanceLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(event.kind.badgeLabel, systemImage: event.kind.systemImage)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(event.kind == .conference ? Color.purple.opacity(0.16) : Color.blue.opacity(0.16))
                    )
                    .foregroundStyle(event.kind == .conference ? .purple : .blue)

                if let localeName = event.locale?.name ?? event.locale?.label {
                    Text(localeName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let distanceLabel {
                    Label(distanceLabel, systemImage: "location.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.teal)
                }

                if event.isFeatured {
                    Label("Featured", systemImage: "star.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer()

                if event.rsvpState == .attending {
                    Label("Going", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else if event.rsvpState == .maybe {
                    Label("Interested", systemImage: "star.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            Text(event.name)
                .font(.headline)

            if let description = event.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let startAt = event.startAt {
                    Label(
                        startAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let recurrenceText = event.recurrenceText, !recurrenceText.isEmpty {
                    Label(recurrenceText, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label(event.venueDisplayName, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if event.lowestTicketPrice != nil || event.rsvpCount > 0 || event.discordLink != nil || !event.tags.isEmpty {
                HStack(spacing: 8) {
                    if let lowestPrice = event.lowestTicketPrice {
                        Label("Tickets: \(lowestPrice.formattedAmount)", systemImage: "ticket.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tint)
                    }

                    if event.rsvpCount > 0 {
                        Label("\(event.rsvpCount) going", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if event.discordLink != nil {
                        Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }

                    ForEach(event.tags.prefix(3)) { tag in
                        Text("#\(tag.name)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
