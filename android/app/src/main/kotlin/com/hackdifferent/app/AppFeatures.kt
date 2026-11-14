package com.hackdifferent.app

/** Switches for features that aren't ready to ship (the same as iOS's `AppFeatures`). */
object AppFeatures {
    /**
     * Buying a venue or event pass in the app (the Passes tab, the pass rows and the sign-in feature row). Off: the app
     * has no payment step yet (Hot Mess takes the card with Square between `buyCover` and `confirmCover`), so it would
     * promise passes it can't sell. Tickets sold by organizers still open their own sites.
     */
    const val IN_APP_PASSES = false
}
