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
    var gitConflictExplanation = ""
    var gitBranchDraft = ""
    var selectedGitBranch: String?
    var gitDivergence: GitDivergence?
    var gitBranches: [String] = []

    init() {}
}
