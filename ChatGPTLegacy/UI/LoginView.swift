import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brandHeader
                    Spacer(minLength: geometry.size.height < 650 ? 28 : 54)
                    signInContent
                    Spacer(minLength: 34)
                    trustRail
                    Spacer(minLength: 24)
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, max(20, geometry.safeAreaInsets.top + 8))
                .padding(.bottom, max(20, geometry.safeAreaInsets.bottom + 12))
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .background(LegacyTheme.canvas.ignoresSafeArea())
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            LegacyMark(compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("CHATGPT LEGACY")
                    .font(LegacyTheme.utility)
                    .tracking(1.5)
                    .foregroundColor(LegacyTheme.ink)
                Text("NATIVE CLIENT · iOS 15")
                    .font(.caption.weight(.medium))
                    .tracking(0.7)
                    .foregroundColor(LegacyTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var signInContent: some View {
        switch model.authPhase {
        case .requestingCode:
            LegacyCard {
                HStack(spacing: 14) {
                    ProgressView()
                        .tint(LegacyTheme.signal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creating a secure sign-in")
                            .font(LegacyTheme.title)
                            .foregroundColor(LegacyTheme.ink)
                        Text("Contacting OpenAI…")
                            .font(.subheadline)
                            .foregroundColor(LegacyTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("login.requesting")

        case .waitingForBrowser(let authorization):
            codePanel(authorization)

        default:
            welcomePanel
        }
    }

    private var welcomePanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A thoughtful client\nfor the phone you kept.")
                    .font(LegacyTheme.display)
                    .foregroundColor(LegacyTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Stream conversations, analyze images, dictate ideas, and keep every thread local to this device.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(LegacyTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: model.beginSignIn) {
                HStack(spacing: 10) {
                    Text("Continue with ChatGPT")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("login.continue")

            Text("Uses OpenAI's browser-based Codex device authorization. Your password never enters this app.")
                .font(.footnote)
                .foregroundColor(LegacyTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func codePanel(_ authorization: DeviceAuthorization) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "One-time code")
                Text(authorization.userCode)
                    .font(LegacyTheme.authorizationCode)
                    .tracking(2.2)
                    .foregroundColor(LegacyTheme.ink)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .accessibilityIdentifier("login.code")
            }

            Text("Open the secure OpenAI page, sign in, and enter this code. This screen will continue automatically.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(LegacyTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIPasteboard.general.string = authorization.userCode
                openURL(authorization.verificationURL)
            } label: {
                HStack {
                    Text("Copy code and open OpenAI")
                    Spacer()
                    Image(systemName: "safari")
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("login.open")

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(LegacyTheme.signal)
                    .accessibilityHidden(true)
                Text("Waiting for browser sign-in")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(LegacyTheme.muted)
                Spacer()
                Button("Cancel", action: model.cancelSignIn)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(LegacyTheme.warning)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("login.cancel")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LegacyTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LegacyTheme.signal.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var trustRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            trustItem(
                icon: "safari",
                title: "Browser sign-in",
                detail: "Credentials stay with OpenAI",
                isLast: false
            )
            trustItem(
                icon: "key.fill",
                title: "Keychain protected",
                detail: "OAuth tokens stay on this phone",
                isLast: false
            )
            trustItem(
                icon: "key.slash",
                title: "No API key",
                detail: "Uses your eligible ChatGPT plan",
                isLast: true
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("login.trustRail")
    }

    private func trustItem(
        icon: String,
        title: String,
        detail: String,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(LegacyTheme.signalSoft)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(LegacyTheme.signal)
                        .accessibilityHidden(true)
                }
                if !isLast {
                    Rectangle()
                        .fill(LegacyTheme.hairline)
                        .frame(width: 1, height: 24)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(LegacyTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(LegacyTheme.muted)
            }
            .padding(.top, 2)
            Spacer()
        }
    }

    private var footer: some View {
        Text("UNOFFICIAL · OPEN SOURCE · 1.0")
            .font(.caption.weight(.medium))
            .tracking(0.6)
            .foregroundColor(LegacyTheme.faint)
            .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("Unofficial open-source client, version 1.0")
    }
}
