//
//  BrandStore.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import Observation
import SwiftUI

/// Fetches and caches public audience branding from `/v1/branding` for Hack Different.
@MainActor
@Observable
public final class BrandStore {
    public private(set) var branding: Branding?
    public private(set) var isLoading = false

    private let client: AudienceKitClient

    public init(client: AudienceKitClient) {
        self.client = client
    }

    public var audienceName: String {
        branding?.audience.name ?? "Hack Different"
    }

    public var tagline: String {
        branding?.theme.tagline ?? "Hackerspaces, Conferences, Meetups & Community"
    }

    public var preset: String {
        branding?.theme.preset ?? "default"
    }

    public func accentColor(for colorScheme: ColorScheme) -> Color {
        if let token = branding?.theme.color("accent", dark: colorScheme == .dark) {
            return Color(token)
        }
        return Color.accentColor
    }

    /// Text and icons on accent fills (prominent buttons). Hack Different's lime needs dark text: white on it is
    /// 1.3:1. Uses the theme's `on-accent` when it passes WCAG AA, otherwise whichever of near-black or white reads.
    public func onAccentColor(for colorScheme: ColorScheme) -> Color {
        if let token = branding?.theme.onAccent(dark: colorScheme == .dark) {
            return Color(token)
        }
        return Color(Self.fallbackAccent.readableForeground)
    }

    /// The asset catalog's AccentColor, used until branding loads.
    private static let fallbackAccent = RGBAColor(red: 0.345, green: 0.396, blue: 0.949)

    public func loadBranding() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            branding = try await client.branding(app: Bundle.main.bundleIdentifier)
        } catch {
            // Keep default Hack Different branding when offline
        }
    }
}
