import Foundation

public enum TextDiffPreview {
    public static func makeDiff(original: String, proposed: String) -> String {
        let oldLines = original.split(separator: "\n", omittingEmptySubsequences: false)
        let newLines = proposed.split(separator: "\n", omittingEmptySubsequences: false)
        var rows: [String] = []
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldLines.count || newIndex < newLines.count {
            if oldIndex < oldLines.count,
               newIndex < newLines.count,
               oldLines[oldIndex] == newLines[newIndex] {
                rows.append(" \(oldLines[oldIndex])")
                oldIndex += 1
                newIndex += 1
            } else {
                if oldIndex < oldLines.count, !oldLines[oldIndex].isEmpty {
                    rows.append("-\(oldLines[oldIndex])")
                }
                if newIndex < newLines.count, !newLines[newIndex].isEmpty {
                    rows.append("+\(newLines[newIndex])")
                }
                oldIndex += oldIndex < oldLines.count ? 1 : 0
                newIndex += newIndex < newLines.count ? 1 : 0
            }
        }

        return rows.joined(separator: "\n")
    }
}
