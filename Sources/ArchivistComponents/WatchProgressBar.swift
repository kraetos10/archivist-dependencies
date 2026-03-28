import SwiftUI

public struct WatchProgressBar: View {
    public let progress: Double
    public var height: CGFloat = 4

    public init(
        progress: Double,
        height: CGFloat = 4
    ) {
        self.progress = progress
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.3))
                Rectangle()
                    .fill(.red)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: height)
    }
}
