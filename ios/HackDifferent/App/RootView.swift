//
//  RootView.swift
//  HackDifferent
//

import AudienceKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch appModel.session.state {
            case .restoring:
                LaunchLoadingView()
            case .signedOut, .signingIn:
                LoginScreen()
            case .signedIn:
                MainTabView()
                    .task {
                        if appModel.venues.isEmpty && appModel.events.isEmpty {
                            await appModel.refreshCatalog()
                        }
                    }
            }
        }
        .tint(appModel.brand.accentColor(for: colorScheme))
        .environment(\.onAccent, appModel.brand.onAccentColor(for: colorScheme))
    }
}

extension EnvironmentValues {
    /// The readable color for text on the brand accent (the app's `.tint`). Set by ``RootView``.
    @Entry var onAccent: Color = .white
}

/// `.borderedProminent` on the brand accent, with text that reads on it. SwiftUI's prominent style always draws a
/// white label, which disappears on Hack Different's lime.
private struct AccentProminentButtonStyle: ViewModifier {
    @Environment(\.onAccent) private var onAccent

    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .foregroundStyle(onAccent)
    }
}

extension View {
    /// A prominent button filled with the brand accent and labelled in ``EnvironmentValues/onAccent``.
    func accentProminentButtonStyle() -> some View {
        modifier(AccentProminentButtonStyle())
    }
}

private struct LaunchLoadingView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundStyle(.tint)
            Text(appModel.brand.audienceName)
                .font(.title2.bold())
            ProgressView()
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct MainTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var bindableApp = appModel

        TabView(selection: $bindableApp.selectedTab) {
            Tab("Events", systemImage: "calendar.badge.clock", value: AppModel.Tab.events) {
                EventsScreen()
            }

            Tab("Spaces", systemImage: "cpu.fill", value: AppModel.Tab.spaces) {
                VenuesScreen()
            }

            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: AppModel.Tab.chat) {
                ChatHubScreen()
            }

            if appModel.gitHub != nil {
                Tab(GitHubCopy.projects, systemImage: "square.stack.3d.up.fill", value: AppModel.Tab.gitHub) {
                    GitHubScreen()
                }
            }

            if AppFeatures.inAppPasses {
                Tab("Passes", systemImage: "qrcode.viewfinder", value: AppModel.Tab.passes) {
                    PassesScreen()
                }
            }

            Tab("Profile", systemImage: "person.crop.circle", value: AppModel.Tab.profile) {
                ProfileScreen()
            }
        }
    }
}
