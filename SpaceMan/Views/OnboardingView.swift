import SwiftUI

struct OnboardingView: View {
    @Binding var appMode: AppMode

    @State private var showContent = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .symbolRenderingMode(.hierarchical)

                // Title & description
                VStack(spacing: 10) {
                    Text("Full Disk Access")
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    Text("SpaceMan needs Full Disk Access to scan all your files and folders without interruption.\n\nWithout it, macOS will ask for permission on every protected folder.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                // Steps
                VStack(alignment: .leading, spacing: 12) {
                    StepRow(number: 1, text: "Click **Open System Settings** below")
                    StepRow(number: 2, text: "Find **SpaceMan** in the list")
                    StepRow(number: 3, text: "Toggle it **on** and restart the app")
                }
                .frame(maxWidth: 360, alignment: .leading)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open System Settings", systemImage: "gear")
                            .frame(maxWidth: 240)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)

                    Button {
                        UserDefaults.standard.set(true, forKey: AppSettings.Key.hasCompletedOnboarding)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appMode = .dashboard
                        }
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: 240)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showContent = true
            }
        }
    }
}

private struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.callout)
        }
    }
}
