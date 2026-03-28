import SwiftUI

public struct VideoInfoRow: View {
    let pills: [String]
    let duration: String?

    public init(
        qualityLabel: String?,
        fileSize: String?,
        videoCodec: String?,
        duration: String?
    ) {
        self.pills = [qualityLabel, fileSize, videoCodec].compactMap { $0 }
        self.duration = duration
    }

    public var body: some View {
        let hasPills = !pills.isEmpty
        let hasDuration = duration != nil
        if hasPills || hasDuration {
            HStack(spacing: 8) {
                ForEach(pills, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.Surface.highlight)
                        .clipShape(Capsule())
                }

                if hasPills, let duration {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                } else if let duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
        }
    }
}
