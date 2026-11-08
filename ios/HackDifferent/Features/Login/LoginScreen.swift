//
//  LoginScreen.swift
//  HackDifferent
//

import AudienceKit
import AuthenticationServices
import SwiftUI

struct LoginScreen: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingReviewSheet = false
    @State private var reviewCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                // Brand Header
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tint)
                    }

                    Text(appModel.brand.audienceName)
                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))

                    Text(appModel.brand.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Feature Highlights
                VStack(alignment: .leading, spacing: 14) {
                    FeatureRow(
                        icon: "cpu.fill",
                        title: "Hackerspaces & Con Venues",
                        subtitle: "Explore community hackerspaces and conference venues near you."
                    )
                    FeatureRow(
                        icon: "calendar.badge.checkmark",
                        title: "Conferences & Meetups",
                        subtitle: "RSVP for local meetups, talks, workshops, and security conferences."
                    )
                    if AppFeatures.inAppPasses {
                        FeatureRow(
                            icon: "qrcode.viewfinder",
                            title: "Tickets & Live QR Passes",
                            subtitle: "Get event tickets and offline-ready rotating QR admission passes."
                        )
                    }
                    FeatureRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Venue Chat & Discord",
                        subtitle: "Join real-time con and hackerspace chat rooms or jump into Discord."
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)

                Spacer()

                // Status / Error Notices
                if let banner = appModel.session.sessionEndedBanner {
                    Label(banner, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 24)
                }

                if let errorMessage = appModel.session.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Sign in with Apple
                VStack(spacing: 12) {
                    if appModel.session.state == .signingIn {
                        ProgressView("Signing in to Hack Different…")
                            .padding(.vertical, 14)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            appModel.session.handleSignInWithApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if appModel.session.isReviewSignInAvailable {
                        Button("Have an App Review code?") {
                            showingReviewSheet = true
                        }
                        .font(.footnote.weight(.medium))
                    }

                    // App Store guideline 1.2: chat is user-generated content, so signing in means agreeing to the terms.
                    // The links are literal so SwiftUI parses them as Markdown (same URLs as AppFeatures).
                    Text("By signing in you agree to the [Terms of Use](https://audiencekit.com/terms/) and [Privacy Policy](https://audiencekit.com/privacy/). Hack Different has no tolerance for abusive or objectionable content.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showingReviewSheet) {
                NavigationStack {
                    Form {
                        Section("App Store Review Code") {
                            TextField("Enter review code", text: $reviewCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .navigationTitle("App Review Sign-In")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingReviewSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sign In") {
                                let code = reviewCode
                                showingReviewSheet = false
                                Task {
                                    await appModel.session.signInWithReviewCode(code)
                                }
                            }
                            .disabled(reviewCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
