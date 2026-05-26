import Foundation
import TermyCore

/// Pure, view-free helpers for the v3 Desktop scene (DESIGN.md §3). Unit-tested
/// directly; the SwiftUI views stay thin and call into these.
enum DesktopModel {

    // MARK: §3.1 — time-of-day greeting.
    static func greeting(at date: Date, name: String,
                         calendar: Calendar = .current) -> (lead: String, name: String) {
        let hour = calendar.component(.hour, from: date)
        let lead: String
        switch hour {
        case ..<12:   lead = "Good morning"
        case 12..<18: lead = "Good afternoon"
        default:      lead = "Good evening"
        }
        return (lead, name)
    }

    // MARK: §3.2 — orb placement: start at top (-π/2), clockwise.
    static func radialOrbPosition(index: Int, count: Int, radius: CGFloat) -> CGPoint {
        let a = -Double.pi / 2 + (Double(index) / Double(count)) * Double.pi * 2
        return CGPoint(x: CGFloat(cos(a)) * radius, y: CGFloat(sin(a)) * radius)
    }

    // MARK: §3.2 center / Agents badge — highest-priority attention signal.
    enum AttentionSignal: Equatable {
        case waiting(name: String)
        case running(count: Int)
        case calm
    }

    static func attentionSignal(_ vitals: [AgentSessionVitals]) -> AttentionSignal {
        let grouped = groupAgentVitals(vitals)
        if let first = grouped.waiting.first { return .waiting(name: first.name) }
        if !grouped.running.isEmpty { return .running(count: grouped.running.count) }
        return .calm
    }

    // MARK: §3.1 — hero sub-text composed from real state.
    enum HeroAccent: Equatable { case agent, git, plain }
    struct HeroSubTextSpan: Equatable { let text: String; let accent: HeroAccent }

    static func heroSubText(vitals: [AgentSessionVitals], gitDirty: Int,
                            branch: String?) -> [HeroSubTextSpan] {
        let waiting = groupAgentVitals(vitals).waiting.count
        var spans: [HeroSubTextSpan] = []
        if waiting > 0 {
            spans.append(.init(text: "You have ", accent: .plain))
            let n = waiting == 1 ? "1 agent waiting for input"
                                 : "\(waiting) agents waiting for input"
            spans.append(.init(text: n, accent: .agent))
        }
        if gitDirty > 0 {
            spans.append(.init(text: spans.isEmpty ? "You have " : ", ", accent: .plain))
            let files = gitDirty == 1 ? "1 dirty file" : "\(gitDirty) dirty files"
            spans.append(.init(text: files, accent: .git))
            if let branch, !branch.isEmpty {
                spans.append(.init(text: " on \(branch)", accent: .git))
            }
        }
        guard !spans.isEmpty else {
            return [.init(text: "All clear — pick a module below, or press ⌘K to jump.",
                          accent: .plain)]
        }
        spans.append(.init(text: ".", accent: .plain))
        return spans
    }

    // MARK: §3.3 git card / Git badge — porcelain parsing (pure).
    struct GitMiniRow: Equatable { let code: String; let path: String }

    /// `git status --short` status-code alphabet (the XY field). `TermyStore.gitStatus`
    /// is a shared *display* string — it can hold the sentinel "Run Git Status…",
    /// "Working tree clean.", a commit summary, or error text — so every line is gated
    /// on a real porcelain shape before it counts as a dirty entry (no fabrication).
    private static let porcelainCodeChars: Set<Character> = ["M", "A", "D", "R", "C", "U", "T", "?", "!"]

    private static func porcelainRow(_ rawLine: Substring) -> GitMiniRow? {
        let trimmed = String(rawLine).trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 2, let space = trimmed.firstIndex(of: " ") else { return nil }
        let code = String(trimmed[trimmed.startIndex..<space])
        guard (1...2).contains(code.count), code.allSatisfy(porcelainCodeChars.contains) else { return nil }
        let path = String(trimmed[space...]).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        return GitMiniRow(code: code, path: path)
    }

    static func gitMiniRows(from status: String, limit: Int = 3) -> [GitMiniRow] {
        Array(status.split(whereSeparator: \.isNewline).compactMap(porcelainRow).prefix(limit))
    }

    static func gitDirtyCount(_ status: String) -> Int {
        status.split(whereSeparator: \.isNewline).compactMap(porcelainRow).count
    }

    static func gitHasConflict(_ status: String) -> Bool {
        status.split(whereSeparator: \.isNewline).compactMap(porcelainRow).contains { row in
            row.code.contains("U") || row.code == "AA" || row.code == "DD"
        }
    }

    // MARK: shared — compact relative age ("24s" / "3m" / "2h").
    static func relativeAge(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}
