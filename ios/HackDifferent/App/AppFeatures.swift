//
//  AppFeatures.swift
//  HackDifferent
//

import Foundation

/// Switches for features that aren't ready to ship, plus the legal links shown in the app.
enum AppFeatures {
    /// Buying a venue or event pass in the app (the Passes tab and "Get Pass"). Off for 1.0: the app has no payment
    /// step yet (Hot Mess takes the card with Square's SDK between `buyCover` and `confirmCover`), so the button
    /// would start a purchase it can't finish. Tickets sold by organizers still open their own sites.
    static let inAppPasses = false

    static let termsURL = URL(string: "https://audiencekit.com/terms/")!
    static let privacyURL = URL(string: "https://audiencekit.com/privacy/")!
}
