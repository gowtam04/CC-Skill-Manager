import SwiftUI

struct DropOverlayView: View {
    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.12)

            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(Color.accentColor)
                .padding(8)

            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("Drop to import")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
