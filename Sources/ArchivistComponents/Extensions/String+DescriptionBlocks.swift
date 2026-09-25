import Foundation

public extension String {
    /// This text cut into blocks for a tvOS full-text view. Each block takes
    /// focus in turn, which is what scrolls the view — a single long `Text`
    /// can't be scrolled with the remote — so no block may be taller than
    /// the screen. Blank lines end a block; long runs and long lines are
    /// broken at word boundaries.
    func descriptionBlocks(
        maxLines: Int = 6,
        maxCharacters: Int = 500
    ) -> [String] {
        var blocks: [String] = []
        var lines: [String] = []
        var length = 0

        func flush() {
            if !lines.isEmpty {
                blocks.append(lines.joined(separator: "\n"))
            }
            lines = []
            length = 0
        }

        for rawLine in components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else {
                flush()
                continue
            }
            for piece in Self.splitLongLine(line, limit: maxCharacters) {
                if lines.count >= maxLines || length + piece.count > maxCharacters {
                    flush()
                }
                lines.append(piece)
                length += piece.count
            }
        }
        flush()
        return blocks
    }

    /// Breaks a line longer than `limit` at word boundaries.
    private static func splitLongLine(
        _ line: String,
        limit: Int
    ) -> [String] {
        guard line.count > limit else { return [line] }
        var pieces: [String] = []
        var current = ""
        for word in line.split(separator: " ") {
            if !current.isEmpty && current.count + word.count + 1 > limit {
                pieces.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces
    }
}
