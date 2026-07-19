import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.authPhase {
            case .restoring:
                LaunchView()
            case .signedOut, .requestingCode, .waitingForBrowser(_):
                LoginView()
            case .signedIn:
                ChatView()
            }
        }
        .tint(LegacyTheme.signal)
        .preferredColorScheme(forcedUITestColorScheme)
        .task {
            await model.bootstrap()
        }
        .alert(
            "Something needs attention",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.dismissError() } }
            ),
            actions: {
                Button("OK", role: .cancel) { model.dismissError() }
            },
            message: {
                Text(model.errorMessage ?? "")
            }
        )
    }

    private var forcedUITestColorScheme: ColorScheme? {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return nil }
        switch ProcessInfo.processInfo.environment["UITEST_COLOR_SCHEME"] {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            LegacyTheme.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                LegacyMark()
                ProgressView()
                    .tint(LegacyTheme.signal)
                Text("RESTORING SESSION")
                    .font(LegacyTheme.utility)
                    .tracking(1.4)
                    .foregroundColor(LegacyTheme.muted)
            }
        }
    }
}
