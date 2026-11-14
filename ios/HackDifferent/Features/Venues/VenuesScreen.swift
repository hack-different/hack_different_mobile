//
//  VenuesScreen.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct VenuesScreen: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedCategory: SpaceCategory = .all
    @State private var selectedRegion: RegionFilterSelection = .all
    @State private var searchText = ""

    private var baseFilteredVenues: [Venue] {
        appModel.venues.filter { venue in
            let category = SpaceCategory.classify(tags: venue.tags, name: venue.name)
            if selectedCategory != .all && category != selectedCategory {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesName = venue.name.lowercased().contains(query)
                let matchesLocale = (venue.locale.name ?? venue.locale.label ?? "").lowercased().contains(query)
                let matchesAddress = (venue.location?.address ?? "").lowercased().contains(query)
                let matchesTag = (venue.tags ?? []).contains { $0.name.lowercased().contains(query) }
                if !matchesName && !matchesLocale && !matchesAddress && !matchesTag {
                    return false
                }
            }
            return true
        }
    }

    private var nearbyVenues: [Venue] {
        guard appModel.location.isAuthorized else { return [] }
        return baseFilteredVenues
            .filter { appModel.location.isVenueNearby($0) }
            .sorted { lhs, rhs in
                let lhsDist = appModel.location.distanceInMeters(to: lhs.location?.coordinate) ?? .greatestFiniteMagnitude
                let rhsDist = appModel.location.distanceInMeters(to: rhs.location?.coordinate) ?? .greatestFiniteMagnitude
                if lhsDist != rhsDist {
                    return lhsDist < rhsDist
                }
                return lhs.order < rhs.order
            }
    }

    private var displayedVenues: [Venue] {
        switch selectedRegion {
        case .all:
            return baseFilteredVenues
        case .nearMe:
            return nearbyVenues
        case .locale(let localeID):
            return baseFilteredVenues.filter { $0.locale.id == localeID }
        }
    }

    private var nearMeChipTitle: String {
        if appModel.location.isAuthorized,
           let localeName = appModel.location.closestLocale?.name ?? appModel.location.closestLocale?.label {
            return "Near Me • \(localeName)"
        }
        return "Near Me"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Space Category", selection: $selectedCategory) {
                        ForEach(SpaceCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All Spaces",
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

                if !appModel.location.isAuthorized && !appModel.location.isDenied {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Spaces Near You")
                                    .font(.subheadline.weight(.semibold))
                                Text("Opt in to location to see nearby hackerspaces and conference venues with distances.")
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

                if appModel.isLoadingCatalog && appModel.venues.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading hackerspaces & conference venues…")
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if selectedRegion == .nearMe && !appModel.location.isAuthorized {
                    Section {
                        ContentUnavailableView {
                            Label("Location Opt-In Required", systemImage: "location.circle")
                        } description: {
                            Text("Enable location access to filter to hackerspaces and conference venues near you, or view All Spaces.")
                        } actions: {
                            HStack(spacing: 12) {
                                if !appModel.location.isDenied {
                                    Button("Enable Location") {
                                        appModel.location.requestOptIn()
                                    }
                                    .accentProminentButtonStyle()
                                }
                                Button("Show All Spaces") {
                                    selectedRegion = .all
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                } else if displayedVenues.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label(
                                selectedRegion == .nearMe ? "No Local Spaces Nearby" : "No Spaces Found",
                                systemImage: selectedCategory.systemImage
                            )
                        } description: {
                            Text(
                                selectedRegion == .nearMe
                                    ? "No hackerspaces or conference venues matched your immediate area. Switch to All Spaces to browse all locations."
                                    : "Pull to refresh or adjust your search filter."
                            )
                        } actions: {
                            if selectedRegion != .all {
                                Button("Show All Spaces") {
                                    selectedRegion = .all
                                }
                                .accentProminentButtonStyle()
                            }
                        }
                        .padding(.vertical, 24)
                    }
                } else {
                    if selectedRegion == .all && appModel.location.isAuthorized && !nearbyVenues.isEmpty {
                        let regionTitle = appModel.location.closestLocale?.name
                            ?? appModel.location.closestLocale?.label
                            ?? "Near You"
                        Section {
                            ForEach(nearbyVenues) { venue in
                                NavigationLink(value: venue) {
                                    VenueRowView(
                                        venue: venue,
                                        distanceLabel: appModel.location.formattedDistance(to: venue.location?.coordinate),
                                        eventCount: appModel.events.filter { $0.venue?.id == venue.id }.count
                                    )
                                }
                                .accessibilityIdentifier("space.row")
                            }
                        } header: {
                            Label("Near You • \(regionTitle)", systemImage: "location.fill")
                        }
                    }

                    let sectionTitle: String = {
                        switch selectedRegion {
                        case .all:
                            return "All Spaces & Venues (\(displayedVenues.count))"
                        case .nearMe:
                            return "Near You (\(displayedVenues.count))"
                        case .locale(let id):
                            let name = appModel.locales.first(where: { $0.id == id })?.name ?? "Regional"
                            return "\(name) (\(displayedVenues.count))"
                        }
                    }()

                    Section(sectionTitle) {
                        ForEach(displayedVenues) { venue in
                            NavigationLink(value: venue) {
                                VenueRowView(
                                    venue: venue,
                                    distanceLabel: appModel.location.formattedDistance(to: venue.location?.coordinate),
                                    eventCount: appModel.events.filter { $0.venue?.id == venue.id }.count
                                )
                            }
                            .accessibilityIdentifier("space.row")
                        }
                    }
                }
            }
            .navigationTitle("Spaces")
            .searchable(text: $searchText, prompt: "Search hackerspaces, con venues, cities…")
            .refreshable {
                await appModel.refreshCatalog()
            }
            .navigationDestination(for: Venue.self) { venue in
                VenueDetailScreen(venueID: venue.id, initialName: venue.name, initialVenue: venue)
            }
        }
    }
}

struct VenueRowView: View {
    let venue: Venue
    var distanceLabel: String? = nil
    var eventCount: Int = 0

    private var category: SpaceCategory {
        SpaceCategory.classify(tags: venue.tags, name: venue.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(
                    category == .conferenceVenue ? "Con Venue" : "Hackerspace",
                    systemImage: category.systemImage
                )
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(category == .conferenceVenue ? Color.indigo.opacity(0.16) : Color.teal.opacity(0.16))
                )
                .foregroundStyle(category == .conferenceVenue ? .indigo : .teal)

                if let localeName = venue.locale.name ?? venue.locale.label {
                    Text(localeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let distanceLabel {
                    Label(distanceLabel, systemImage: "location.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.teal)
                }

                Spacer()

                if eventCount > 0 {
                    Label("\(eventCount) \(eventCount == 1 ? "event" : "events")", systemImage: "calendar")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }

            Text(venue.name)
                .font(.headline)

            if let address = venue.location?.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let tags = venue.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in
                            Text("#\(tag.name)")
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
