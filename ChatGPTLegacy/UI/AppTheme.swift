import SwiftUI
import UIKit

enum LegacyTheme {
    static let canvas = adaptive(light: 0xEEF2F1, dark: 0x101614)
    static let paper = adaptive(light: 0xFBFCFB, dark: 0x18201E)
    static let elevated = adaptive(light: 0xFFFFFF, dark: 0x202A27)
    static let ink = adaptive(light: 0x17201E, dark: 0xEDF5F2)
    static let muted = adaptive(light: 0x56635F, dark: 0xA7B8B2)
    static let faint = adaptive(light: 0x5E6B66, dark: 0x8B9C96)
    static let hairline = adaptive(light: 0xCFD9D5, dark: 0x31403B)
    static let signal = adaptive(light: 0x06715F, dark: 0x4ACCB0)
    static let signalSoft = adaptive(light: 0xDCEFEA, dark: 0x153B32)
    static let userBubble = adaptive(light: 0x18332D, dark: 0xCDE9E1)
    static let userText = adaptive(light: 0xF5FBF9, dark: 0x12221E)
    static let warning = adaptive(light: 0xA34334, dark: 0xF29B88)

    static let display = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let title = Font.system(.title3, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let utility = Font.caption.weight(.semibold)
    static let authorizationCode = Font.system(.title, design: .monospaced).weight(.semibold)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct LegacyMark: View {
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 8 : 11, style: .continuous)
                .fill(LegacyTheme.ink)
            Path { path in
                let inset: CGFloat = compact ? 6 : 8
                path.move(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset, y: compact ? 22 : 30))
                path.addLine(to: CGPoint(x: compact ? 22 : 30, y: compact ? 22 : 30))
            }
            .stroke(
                LegacyTheme.signal,
                style: StrokeStyle(lineWidth: compact ? 2.5 : 3, lineCap: .round)
            )
            Circle()
                .fill(LegacyTheme.signal)
                .frame(width: compact ? 5 : 7, height: compact ? 5 : 7)
                .offset(x: compact ? 8 : 11, y: compact ? -8 : -11)
        }
        .frame(width: compact ? 32 : 44, height: compact ? 32 : 44)
        .accessibilityHidden(true)
    }
}

struct IconButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(emphasized ? LegacyTheme.userText : LegacyTheme.ink)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(emphasized ? LegacyTheme.signal : LegacyTheme.paper)
            )
            .overlay(
                Circle()
                    .stroke(
                        emphasized ? Color.clear : LegacyTheme.hairline,
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundColor(LegacyTheme.userText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LegacyTheme.userBubble)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct LegacyCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LegacyTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(LegacyTheme.hairline, lineWidth: 1)
            )
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LegacyTheme.utility)
            .tracking(0.35)
            .foregroundColor(LegacyTheme.muted)
            .layoutPriority(1)
            .fixedSize(horizontal: false, vertical: true)
    }
}
