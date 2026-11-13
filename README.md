# Hack Different (iOS & Android)

Official iOS and Android apps for the **Hack Different** community built on the [AudienceKit SDK](https://github.com/lwm-luminx/audience-kit-sdk.git).

- **Audience Console**: `https://hack-different.admin.audiencekit.com/audiences/2416ce6c-f28a-4460-8b6f-840f3c0027c9`
- **API Base URL (`SERVER_BASE`)**: `https://api.audiencekit.com`
- **Website**: `https://hackdiffe.rent`
- **Audience Host (`AUDIENCE_HOST`)**: `hack-different.admin.audiencekit.com`
- **Audience ID (`AUDIENCE_ID`)**: `2416ce6c-f28a-4460-8b6f-840f3c0027c9`
- **Bundle / Application ID**: `com.hackdifferent.app`

## Repository Layout

| Directory | Description |
| --- | --- |
| [`ios/`](ios/) | SwiftUI iOS application (`ios/HackDifferent.xcodeproj`), `.xcconfig` environment configurations, and Swift Testing unit tests |
| [`android/`](android/README.md) | Jetpack Compose Android application (`:app`) and Kotlin/JVM domain module (`:core`) |
| [`Design/`](Design/) | Shared app icon masters and design documentation |

## Features

- **Sign in with Apple**: Native Apple ID authentication on iOS (`AudienceSession.signIn(appleIdentityToken:...)`) and Custom Tab web authentication on Android (`AppleWebSignIn` + `AudienceKitClient.signInWithApple`), plus App Store / Play Review code sign-in (`/v1/token/review`).
- **Conferences & Meetups (`Events`)**: Browse upcoming conferences and local hacker meetups, filter by event kind, view speakers/organizers, and **RSVP** (`Going`, `Interested`, `Not Going`).
- **Hackerspaces & Conference Venues (`Spaces`)**: Browse community hackerspaces and conference venues, view addresses, upcoming schedules, and social links.
- **Ticketing & Live QR Passes (`Passes`)**: Support for external partner ticket offers (`tickets.offers`) and native AudienceKit admissions/passes (`buyCover`, `confirmCover`, `admissions`, `refundAdmission`) with offline-ready 30-second rotating HMAC-SHA256 QR codes (`CoverPass`).
- **GitHub Projects (`Projects`)**: The community's GitHub organization, its public repositories, and its public GitHub Projects as boards grouped by Status, plus what's assigned to you once you connect GitHub. All from the SDK (`gitHubCommunity`, `gitHubProject`, `myGitHubItems`); the tab only appears once the audience has a GitHub App (audience_kit_api `doc/GITHUB.md`).
- **Venue / Con Chat & Discord (`Chat`)**: Real-time chat rooms for every hackerspace, conference venue, and region over Action Cable (`AudienceCable` / `CableConnection`), paired with first-class Discord server & invite integration.

## Building & Testing

### iOS

```sh
xcodebuild build-for-testing \
  -project ios/HackDifferent.xcodeproj \
  -scheme HackDifferent \
  -destination 'generic/platform=iOS Simulator'
```

### Android

```sh
cd android
./gradlew :core:test assembleDebug
```
