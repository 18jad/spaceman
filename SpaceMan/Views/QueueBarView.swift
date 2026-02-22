import SwiftUI

struct QueueBarView: View {
    var cleanupQueue: CleanupQueue
    let onReview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text("\(cleanupQueue.count) item\(cleanupQueue.count == 1 ? "" : "s") queued")
                .font(.callout)
                .fontWeight(.medium)

            Text("(\(SizeFormatter.format(bytes: cleanupQueue.totalSize)))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                cleanupQueue.clear()
            } label: {
                Text("Clear")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                onReview()
            } label: {
                Text("Review & Clean Up")
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
