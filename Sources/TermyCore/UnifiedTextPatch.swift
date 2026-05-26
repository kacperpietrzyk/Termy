import Foundation

public enum UnifiedTextPatchError: Error, Equatable {
    case missingHunk
    case malformedHunk
    case contextMismatch
    case missingFilePath
}

public enum UnifiedTextPatch {
    public static func apply(_ patch: String, to original: String) throws -> String {
        let patchLines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var hunks: [UnifiedTextPatchHunk] = []
        var index = 0

        while index < patchLines.count {
            let line = patchLines[index]
            guard line.hasPrefix("@@") else {
                index += 1
                continue
            }

            index += 1
            var hunkLines: [String] = []
            while index < patchLines.count, !patchLines[index].hasPrefix("@@") {
                let hunkLine = patchLines[index]
                if hunkLine.hasPrefix("--- ") || hunkLine.hasPrefix("+++ ") {
                    throw UnifiedTextPatchError.malformedHunk
                }
                if hunkLine == "\\ No newline at end of file" || (hunkLine.isEmpty && index == patchLines.count - 1) {
                    index += 1
                    continue
                }
                hunkLines.append(hunkLine)
                index += 1
            }
            hunks.append(try UnifiedTextPatchHunk(lines: hunkLines))
        }

        guard !hunks.isEmpty else {
            throw UnifiedTextPatchError.missingHunk
        }

        var lines = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var searchStart = 0
        for hunk in hunks {
            guard let range = find(hunk.originalLines, in: lines, startingAt: searchStart) else {
                throw UnifiedTextPatchError.contextMismatch
            }
            lines.replaceSubrange(range, with: hunk.replacementLines)
            searchStart = range.lowerBound + hunk.replacementLines.count
        }

        return lines.joined(separator: "\n")
    }

    private static func find(_ needle: [String], in haystack: [String], startingAt startIndex: Int) -> Range<Int>? {
        guard !needle.isEmpty else {
            let insertionIndex = min(max(0, startIndex), haystack.count)
            return insertionIndex..<insertionIndex
        }
        guard needle.count <= haystack.count else { return nil }

        let maxStart = haystack.count - needle.count
        guard startIndex <= maxStart else { return nil }
        for candidate in startIndex...maxStart where Array(haystack[candidate..<(candidate + needle.count)]) == needle {
            return candidate..<(candidate + needle.count)
        }
        return nil
    }
}

public enum EditorAIResolvedProposal: Equatable, Sendable {
    case bufferReplacement(String)
    case multiFilePatch(patch: String, changedPaths: [String])
}

public enum EditorAIProposalResolver {
    public static func resolvedProposal(from proposal: String, original: String) -> EditorAIResolvedProposal {
        if let changedPaths = try? MultiFileUnifiedPatch.changedPaths(in: proposal), !changedPaths.isEmpty {
            return .multiFilePatch(patch: proposal, changedPaths: changedPaths)
        }
        return .bufferReplacement(resolvedBuffer(from: proposal, original: original))
    }

    public static func resolvedBuffer(from proposal: String, original: String) -> String {
        guard looksLikeUnifiedDiff(proposal),
              let patched = try? UnifiedTextPatch.apply(proposal, to: original) else {
            return proposal
        }
        return patched
    }

    private static func looksLikeUnifiedDiff(_ proposal: String) -> Bool {
        proposal.contains("\n@@ ") || proposal.hasPrefix("@@ ")
    }
}

public struct MultiFileUnifiedPatchResult: Equatable, Sendable {
    public let changedPaths: [String]

    public init(changedPaths: [String]) {
        self.changedPaths = changedPaths
    }
}

public enum MultiFileUnifiedPatch {
    public static func changedPaths(in patch: String) throws -> [String] {
        try splitFilePatches(patch).map(\.path)
    }

    public static func apply(_ patch: String, using fileService: LocalFileService) throws -> MultiFileUnifiedPatchResult {
        let filePatches = try splitFilePatches(patch)
        var changedPaths: [String] = []

        for filePatch in filePatches {
            let original = try fileService.readText(filePatch.path)
            let patched = try UnifiedTextPatch.apply(filePatch.patch, to: original)
            try fileService.writeText(patched, to: filePatch.path)
            changedPaths.append(filePatch.path)
        }

        return MultiFileUnifiedPatchResult(changedPaths: changedPaths)
    }

    private static func splitFilePatches(_ patch: String) throws -> [FileUnifiedPatch] {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var patches: [FileUnifiedPatch] = []
        var index = 0

        while index < lines.count {
            guard lines[index].hasPrefix("diff --git ") || lines[index].hasPrefix("--- ") else {
                index += 1
                continue
            }

            let start = index
            var destinationPath: String?
            while index < lines.count {
                let line = lines[index]
                if index > start, line.hasPrefix("diff --git ") {
                    break
                }
                if line.hasPrefix("+++ ") {
                    destinationPath = normalizedPatchPath(String(line.dropFirst(4)))
                }
                index += 1
            }

            guard let destinationPath else {
                throw UnifiedTextPatchError.missingFilePath
            }
            patches.append(
                FileUnifiedPatch(
                    path: destinationPath,
                    patch: lines[start..<index].joined(separator: "\n")
                )
            )
        }

        guard !patches.isEmpty else {
            throw UnifiedTextPatchError.missingFilePath
        }
        return patches
    }

    private static func normalizedPatchPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("a/") || trimmed.hasPrefix("b/") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }
}

private struct FileUnifiedPatch: Equatable {
    let path: String
    let patch: String
}

private struct UnifiedTextPatchHunk: Equatable {
    let originalLines: [String]
    let replacementLines: [String]

    init(lines: [String]) throws {
        var originalLines: [String] = []
        var replacementLines: [String] = []

        for line in lines {
            guard let marker = line.first else {
                throw UnifiedTextPatchError.malformedHunk
            }
            let text = String(line.dropFirst())
            switch marker {
            case " ":
                originalLines.append(text)
                replacementLines.append(text)
            case "-":
                originalLines.append(text)
            case "+":
                replacementLines.append(text)
            default:
                throw UnifiedTextPatchError.malformedHunk
            }
        }

        self.originalLines = originalLines
        self.replacementLines = replacementLines
    }
}
