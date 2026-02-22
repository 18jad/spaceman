import SwiftUI

struct AppCardView: View {
    let app: AppInfo
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 48, height: 48)

                if app.isRunning {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().stroke(.white, lineWidth: 1.5)
                        )
                        .offset(x: 2, y: -2)
                }
            }

            Text(app.name)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Divider()
                .padding(.horizontal, 8)

            VStack(spacing: 3) {
                HStack {
                    Text("App")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SizeFormatter.format(bytes: app.appSize))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Data")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SizeFormatter.format(bytes: app.totalRelatedSize))
                        .font(.caption2)
                        .foregroundStyle(app.totalRelatedSize > 0 ? .orange : .secondary)
                }
            }
            .padding(.horizontal, 8)

            Text(SizeFormatter.format(bytes: app.totalSize))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(minWidth: 140)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovered ? Color(.controlBackgroundColor) : Color(.windowBackgroundColor)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color(.separatorColor).opacity(0.5), lineWidth: isSelected ? 2 : 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}
