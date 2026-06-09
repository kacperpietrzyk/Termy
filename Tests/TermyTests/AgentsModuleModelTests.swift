import XCTest
@testable import Termy
import TermyCore

final class AgentsModuleModelTests: XCTestCase {
    private func vitals(id: UUID = UUID(), name: String = "a",
                        type: CLIAgent = .claudeCode, state: AgentActivityState,
                        cwd: String? = "~/.worktrees/a", branch: String? = "agent/a",
                        dirty: Int = 0, isolation: AgentIsolationKind = .worktree(path: "/x"),
                        started: Date = Date(), changed: Date = Date(),
                        plan: [AgentPlanStep] = [], touched: [String] = [],
                        usage: AgentTranscriptUsage? = nil) -> AgentSessionVitals {
        AgentSessionVitals(
            id: id, name: name, agentType: type, state: state, cwd: cwd, branch: branch,
            dirtyCount: dirty, ahead: 0, behind: 0, isolation: isolation, ports: [],
            startedAt: started, stateChangedAt: changed, plan: plan, touched: touched,
            usage: usage)
    }

    func testActiveAgentKeepsValidSelection() {
        let a = vitals(state: .idle), b = vitals(state: .working)
        XCTAssertEqual(AgentsModuleModel.activeAgentID(vitals: [a, b], selected: a.id), a.id)
    }
    func testActiveAgentFallsToPriorityWhenSelectionInvalid() {
        let run = vitals(state: .working), wait = vitals(state: .waitingForInput)
        XCTAssertEqual(
            AgentsModuleModel.activeAgentID(vitals: [run, wait], selected: UUID()), wait.id)
    }
    func testActiveAgentNilWhenEmpty() {
        XCTAssertNil(AgentsModuleModel.activeAgentID(vitals: [], selected: UUID()))
    }

    func testHeaderSubtitleComposesToolBranchStarted() {
        let v = vitals(type: .codex, state: .working, branch: "agent/x",
                       started: Date().addingTimeInterval(-120))
        let spans = AgentsModuleModel.headerSubtitle(v)
        let joined = spans.map(\.text).joined()
        XCTAssertTrue(joined.contains(CLIAgent.codex.displayName))
        XCTAssertTrue(joined.contains("your auth"))
        XCTAssertTrue(joined.contains("started"))
        XCTAssertTrue(spans.contains { $0.text == "agent/x" && $0.accent == .branch })
    }
    func testHeaderSubtitleOmitsBranchWhenNil() {
        let v = vitals(state: .idle, branch: nil)
        XCTAssertFalse(AgentsModuleModel.headerSubtitle(v).contains { $0.accent == .branch })
    }

    func testVitalsChipsDirtyVsClean() {
        let dirty = AgentsModuleModel.vitalsChips(vitals(state: .working, dirty: 3))
        XCTAssertTrue(dirty.contains { $0.value == "●3 dirty" && $0.hue == .agent })
        let clean = AgentsModuleModel.vitalsChips(vitals(state: .working, dirty: 0))
        XCTAssertTrue(clean.contains { $0.value == "clean" })
        XCTAssertFalse(clean.contains { $0.value.contains("dirty") })
    }
    func testVitalsChipsOmitBranchWhenNilAndAlwaysShowAuth() {
        let chips = AgentsModuleModel.vitalsChips(vitals(state: .idle, branch: nil))
        XCTAssertFalse(chips.contains { $0.icon == "arrow.triangle.branch" })
        XCTAssertTrue(chips.contains { $0.value == "your auth" })
    }
    func testVitalsChipsNeverFabricateModelOrPorts() {
        let chips = AgentsModuleModel.vitalsChips(vitals(state: .working))
        XCTAssertFalse(chips.contains { $0.key == "model" })
        XCTAssertFalse(chips.contains { $0.value.contains(":") })  // a port chip would render ":3000"
    }

    func testSignalRowsSourceTags() {
        let rows = AgentsModuleModel.signalRows(vitals(state: .waitingForInput))
        XCTAssertEqual(rows.first { $0.key == "tool" }?.tag, .proc)
        XCTAssertEqual(rows.first { $0.key == "touched" }?.tag, .hook)
        let stateRow = rows.first { $0.key == "state" }
        XCTAssertEqual(stateRow?.tag, .hook)                       // waiting → hook
        XCTAssertTrue(stateRow?.value.contains("awaiting-input") == true)
    }

    // MARK: AD-6 — context/token indicator + honest CC/Codex asymmetry.

    func testContextUsageCodexIsNotAvailable() {
        // Codex has no transcript → honest "n/a", never fabricated, regardless of
        // any (impossible) usage value.
        let v = vitals(type: .codex, state: .working)
        XCTAssertEqual(AgentsModuleModel.contextUsageLabel(v), "n/a")
        let rows = AgentsModuleModel.signalRows(v)
        XCTAssertEqual(rows.first { $0.key == "context" }?.value, "n/a")
        XCTAssertNil(rows.first { $0.key == "context" }?.tag)   // no source tag for n/a
    }

    func testContextUsageClaudeWithNoTranscriptShowsDash() {
        let v = vitals(type: .claudeCode, state: .working, usage: nil)
        XCTAssertEqual(AgentsModuleModel.contextUsageLabel(v), "—")
        XCTAssertNil(AgentsModuleModel.signalRows(v).first { $0.key == "context" }?.tag)
    }

    func testContextUsageClaudeWithWindowShowsPercent() {
        let usage = AgentTranscriptUsage(
            contextTokens: 57_609, model: "claude-opus-4-7", contextWindow: 200_000)
        let v = vitals(type: .claudeCode, state: .working, usage: usage)
        XCTAssertEqual(AgentsModuleModel.contextUsageLabel(v), "57.6k / 200k · 29%")
        XCTAssertEqual(
            AgentsModuleModel.signalRows(v).first { $0.key == "context" }?.tag, .transcript)
    }

    func testContextUsageUnknownModelShowsRawTokensNoDenominator() {
        let usage = AgentTranscriptUsage(
            contextTokens: 12_345, model: "local-llm", contextWindow: nil)
        let v = vitals(type: .claudeCode, state: .working, usage: usage)
        XCTAssertEqual(AgentsModuleModel.contextUsageLabel(v), "12.3k tokens")
    }

    func testCompactTokens() {
        XCTAssertEqual(AgentsModuleModel.compactTokens(950), "950")
        XCTAssertEqual(AgentsModuleModel.compactTokens(57_609), "57.6k")
        XCTAssertEqual(AgentsModuleModel.compactTokens(200_000), "200k")
        XCTAssertEqual(AgentsModuleModel.compactTokens(1_000_000), "1M")
        XCTAssertEqual(AgentsModuleModel.compactTokens(1_500_000), "1.5M")
    }

    func testSignalRowsTouchedSingularPlural() {
        let one = AgentsModuleModel.signalRows(vitals(state: .working, touched: ["a.swift"]))
        XCTAssertEqual(one.first { $0.key == "touched" }?.value, "1 file")
        let many = AgentsModuleModel.signalRows(vitals(state: .working, touched: ["a.swift", "b.swift"]))
        XCTAssertEqual(many.first { $0.key == "touched" }?.value, "2 files")
    }

    func testPlanProgress() {
        let plan = [
            AgentPlanStep(id: "1", text: "a", state: .done, sub: nil),
            AgentPlanStep(id: "2", text: "b", state: .active, sub: "now"),
            AgentPlanStep(id: "3", text: "c", state: .todo, sub: nil),
        ]
        let p = AgentsModuleModel.planProgress(plan)
        XCTAssertEqual(p.done, 1); XCTAssertEqual(p.total, 3)
    }

    func testChipKindAndStateLabel() {
        XCTAssertEqual(AgentsModuleModel.chipKind(.waitingForInput), .waiting)
        XCTAssertEqual(AgentsModuleModel.chipKind(.working), .running)
        XCTAssertEqual(AgentsModuleModel.chipKind(.idle), .idle)
        XCTAssertEqual(AgentsModuleModel.chipKind(.exited), .ended)
        XCTAssertEqual(AgentsModuleModel.stateLabel(.idle), "idle")
    }

    // MARK: M7 — resolvedLaunchTarget pre-launch visibility.

    func testResolvedLaunchTargetHereUsesSelectedCwd() {
        let r = AgentsModuleModel.resolvedLaunchTarget(
            selectedCwd: "/tmp/proj/sub", projectRoot: "/tmp/proj", isolation: .here)
        XCTAssertTrue(r.contains("sub"))
        XCTAssertEqual(r, "/tmp/proj/sub")
    }

    func testResolvedLaunchTargetHereFallsBackToProjectRoot() {
        let nilCwd = AgentsModuleModel.resolvedLaunchTarget(
            selectedCwd: nil, projectRoot: "/tmp/proj", isolation: .here)
        XCTAssertEqual(nilCwd, "/tmp/proj")
        let emptyCwd = AgentsModuleModel.resolvedLaunchTarget(
            selectedCwd: "", projectRoot: "/tmp/proj", isolation: .here)
        XCTAssertEqual(emptyCwd, "/tmp/proj")
    }

    func testResolvedLaunchTargetWorktreeNamesSourceNotFabricatedPath() {
        let r = AgentsModuleModel.resolvedLaunchTarget(
            selectedCwd: nil, projectRoot: "/tmp/proj", isolation: .worktree(path: "/whatever/agent-claudeCode-abc123"))
        XCTAssertTrue(r.contains("new worktree"))
        XCTAssertTrue(r.contains("/tmp/proj"))
        XCTAssertFalse(r.contains("agent-claudeCode-"))
        XCTAssertFalse(r.contains("abc123"))
    }

    func testResolvedLaunchTargetAbbreviatesHome() {
        let home = NSHomeDirectory()
        let r = AgentsModuleModel.resolvedLaunchTarget(
            selectedCwd: home + "/proj", projectRoot: home, isolation: .here)
        XCTAssertTrue(r.hasPrefix("~"))
        XCTAssertFalse(r.contains(home))
    }
}
