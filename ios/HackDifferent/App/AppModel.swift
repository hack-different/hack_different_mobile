//
//  AppModel.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import Foundation
import Observation

/// Composition root for Hack Different.
/// Holds the `AudienceKitClient`, `AudienceCable`, `BrandStore`, `SessionStore`, `LocationService`, and shared data state.
@MainActor
@Observable
public final class AppModel {
    public enum Tab: Hashable, Sendable {
        case events
        case spaces
        case chat
        case gitHub
        case passes
        case profile
    }

    public let configuration: AppConfiguration
    public let client: AudienceKitClient
    public let cable: AudienceCable
    public let api: HackDifferentAPI
    public let brand: BrandStore
    public let session: SessionStore
    public let location: LocationService

    public var selectedTab: Tab = .events

    public private(set) var venues: [Venue] = []
    public private(set) var events: [ConferenceEvent] = []
    public private(set) var locales: [AudienceLocale] = []
    public private(set) var admissions: [Admission] = []
    /// The community's GitHub organization, repositories and projects; nil until the audience has a GitHub App.
    public private(set) var gitHub: GitHubCommunity?
    public private(set) var isLoadingCatalog = false
    public private(set) var catalogError: String?

    public init(
        configuration: AppConfiguration = .fromBundle(),
        credentialStore: any CredentialStore = SessionStore.credentialStore
    ) {
        self.configuration = configuration
        let client = AudienceKitClient(
            configuration: configuration.audienceKitConfiguration,
            credentialStore: credentialStore
        )
        self.client = client
        self.cable = client.makeCable()
        let api = HackDifferentAPI(client: client, configuration: configuration)
        self.api = api
        self.brand = BrandStore(client: client)
        self.session = SessionStore(client: client, api: api, configuration: configuration)
        self.location = LocationService(client: client)

        AudienceUpdates.configure(session: client, appName: "Hack Different")
    }

    public func start() async {
        location.refreshIfAuthorized()

        async let brandingTask: Void = brand.loadBranding()
        async let sessionTask: Void = session.start()
        _ = await (brandingTask, sessionTask)

        if session.isSignedIn {
            await refreshCatalog()
        }
    }

    public func refreshCatalog() async {
        guard !isLoadingCatalog else { return }
        isLoadingCatalog = true
        catalogError = nil
        defer { isLoadingCatalog = false }

        location.refreshIfAuthorized()

        async let venuesResult: Result<[Venue], any Error> = {
            do { return .success(try await client.venues()) }
            catch { return .failure(error) }
        }()
        async let eventsResult: Result<[ConferenceEvent], any Error> = {
            do { return .success(try await api.upcomingEvents()) }
            catch { return .failure(error) }
        }()
        async let localesResult: Result<[AudienceLocale], any Error> = {
            do { return .success(try await client.locales()) }
            catch { return .failure(error) }
        }()
        async let admissionsResult: [Admission]? = try? api.admissions()
        async let gitHubResult: GitHubCommunity? = try? client.gitHubCommunity()

        let (vRes, eRes, lRes, aRes) = await (venuesResult, eventsResult, localesResult, admissionsResult)
        gitHub = await gitHubResult

        var errors: [String] = []

        switch vRes {
        case .success(let v):
            venues = v.filter { !$0.hidden }
        case .failure(let error):
            errors.append((error as? AudienceKitError)?.message ?? error.localizedDescription)
        }

        switch eRes {
        case .success(let e):
            events = e.filter { !$0.isCanceled }
        case .failure(let error):
            errors.append((error as? AudienceKitError)?.message ?? error.localizedDescription)
        }

        switch lRes {
        case .success(let l) where !l.isEmpty:
            locales = l
        case .success, .failure:
            var derived: [AudienceLocale] = []
            var seen = Set<String>()
            for venue in venues where !seen.contains(venue.locale.id) {
                seen.insert(venue.locale.id)
                derived.append(venue.locale)
            }
            for event in events {
                if let locale = event.locale, !seen.contains(locale.id) {
                    seen.insert(locale.id)
                    derived.append(locale)
                }
            }
            if !derived.isEmpty {
                locales = derived
            }
        }

        if let aRes {
            admissions = aRes
        }

        location.updateFallbackClosestLocale(venues: venues, locales: locales)

        if venues.isEmpty && events.isEmpty, let firstError = errors.first {
            catalogError = firstError
        }
    }

    public func refreshAdmissions() async {
        if let updated = try? await api.admissions() {
            admissions = updated
        }
    }

    public func updateEventRSVP(_ state: RSVPState, for eventID: String) async throws {
        let confirmed = try await api.setRSVP(state, forEvent: eventID)
        if let index = events.firstIndex(where: { $0.id == eventID }) {
            let previous = events[index].rsvpState
            events[index].rsvpState = confirmed
            if previous != .attending && confirmed == .attending {
                events[index].rsvpCount += 1
            } else if previous == .attending && confirmed != .attending {
                events[index].rsvpCount = max(0, events[index].rsvpCount - 1)
            }
        }
    }
}
