import SwiftUI

struct DashboardView: View {
    @Binding var appMode: AppMode
    var namespace: Namespace.ID
    let totalDiskSpace: Int64
    let freeDiskSpace: Int64

    @State private var showContent = false

    private var usedDiskSpace: Int64 { totalDiskSpace - freeDiskSpace }
    private var usagePercent: Double {
        guard totalDiskSpace > 0 else { return 0 }
        return Double(usedDiskSpace) / Double(totalDiskSpace) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 8)

                // Title — icon + title use hero animation, subtitle fades in separately
                VStack(spacing: 8) {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                        .matchedGeometryEffect(id: "heroIcon", in: namespace)

                    Text("SpaceMan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .matchedGeometryEffect(id: "heroTitle", in: namespace)

                    Text("Disk space analyzer & app manager")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(showContent ? 1 : 0)
                }

                // Storage bar
                VStack(spacing: 6) {
                    HStack {
                        Text("\(SizeFormatter.format(bytes: usedDiskSpace)) used of \(SizeFormatter.format(bytes: totalDiskSpace))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%% used", usagePercent))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.separatorColor).opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.gradient)
                                .frame(width: geometry.size.width * CGFloat(usagePercent / 100))
                        }
                    }
                    .frame(height: 16)
                }
                .frame(maxWidth: 700)
                .opacity(showContent ? 1 : 0)

                // Feature cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 12)], spacing: 12) {
                    FeatureCard(
                        icon: "internaldrive.fill",
                        title: "Disk Scanner",
                        description: "Visualize disk usage with an interactive treemap",
                        color: .blue
                    ) {
                        appMode = .diskScanner
                    }

                    FeatureCard(
                        icon: "app.badge.checkmark",
                        title: "App Manager",
                        description: "Find and remove apps with all their related files",
                        color: .orange
                    ) {
                        appMode = .appManager
                    }

                    FeatureCard(
                        icon: "doc.on.doc.fill",
                        title: "Duplicates",
                        description: "Find and remove duplicate files to reclaim space",
                        color: .purple
                    ) {
                        appMode = .duplicates
                    }

                    FeatureCard(
                        icon: "sparkles",
                        title: "Smart Clean",
                        description: "One-click cleanup of caches, downloads, and duplicates",
                        color: .teal
                    ) {
                        appMode = .smartClean
                    }

                    FeatureCard(
                        icon: "hourglass",
                        title: "Forgotten Files",
                        description: "Find old files you haven't opened in months or years",
                        color: .indigo
                    ) {
                        appMode = .forgottenFiles
                    }
                }
                .frame(maxWidth: 700)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)

                Spacer().frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Delay so cards appear after the hero transition lands
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                showContent = true
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 3) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.semibold)

                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color.opacity(0.4) : Color(.separatorColor).opacity(0.5), lineWidth: isHovered ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(isHovered ? 0.10 : 0.03), radius: isHovered ? 8 : 3, y: isHovered ? 3 : 1)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
