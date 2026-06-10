import Foundation
import Observation
import TermyCore

/// Git-domain state, extracted from the `TermyStore` god-object as part of
/// the strangler-facade decomposition (M2c-1). `@Observable` + `@MainActor`:
/// the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
@MainActor
@Observable
final class GitModel {
    var gitStatus = "Run Git Status to inspect the current repository."
    var gitCommitMessage = ""
    var gitDiff = ""
    /// Header label for the diff sheet so a per-commit `git show` isn't mislabeled
    /// as the working-tree diff. Set by refreshGitDiff / loadDiff(forCommit:).
    var gitDiffTitle = "Diff"
    var gitConflictExplanation = ""
    var gitBranchDraft = ""
    var selectedGitBranch: String?
    var gitDivergence: GitDivergence?
    var gitBranches: [String] = []
    var gitRecentCommits: [GitLogEntry] = []
    var gitChanges: [GitChange] = []
    /// false → the working root is not a git repo; the UI shows a calm empty state
    /// instead of a raw error string.
    var gitIsRepository = true

    /// EDITOR-CESE Slice 5: per-line blame for the editor's ACTIVE file, fed FROM
    /// the Git module (one capability, one home — the editor never shells out).
    /// Keyed by absolute file path so a stale fetch for a now-closed file is
    /// ignored. `nil` blame = no provenance to show (scratch / untracked / outside
    /// a repo / dirty buffer). Transient; recomputed on demand, never persisted.
    var editorBlame: GitBlame?
    /// The absolute path the cached `editorBlame` belongs to. The gutter only
    /// renders blame when this matches the active buffer's path.
    var editorBlamePath: String?
    /// HEAD sha at the time `editorBlame` was fetched, so the cache is invalidated
    /// when the repo advances (commit/checkout) under the same file.
    var editorBlameHeadSHA: String?

    init() {}
}
