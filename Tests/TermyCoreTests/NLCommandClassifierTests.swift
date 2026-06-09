import XCTest
@testable import TermyCore

/// Table-driven tests for the fully-offline NL-vs-command classifier (AI-S6).
///
/// The classifier MUST decide entirely from heuristics with zero network
/// traffic; the optional small-local-model tie-break is a separate injectable
/// async layer exercised here with a pure stub closure (never a real client).
final class NLCommandClassifierTests: XCTestCase {

    // MARK: - Unambiguous shell commands → run-as-command, high confidence

    func testUnambiguousCommandsClassifyAsCommand() {
        let inputs = [
            "git status",
            "ls -la",
            "cd ~/Projects/Termy",
            "swift build",
            "npm install",
            "cat README.md",
            "./script/build_and_run.sh",
            "/usr/bin/env python3",
            "echo hello | grep h",
            "git commit -m \"fix\"",
            "brew install ripgrep",
            "kubectl get pods",
            "docker ps -a"
        ]
        for input in inputs {
            let result = NLCommandClassifier.classify(input)
            XCTAssertEqual(result.kind, .command, "expected .command for \(input)")
            XCTAssertEqual(result.suggestedAction, .runAsCommand, "expected runAsCommand for \(input)")
            XCTAssertGreaterThanOrEqual(result.confidence, NLCommandClassifier.decisiveConfidence,
                                        "expected decisive confidence for \(input) — got \(result.confidence)")
        }
    }

    // MARK: - Unambiguous natural language → offer NL→command, high confidence

    func testUnambiguousNaturalLanguageClassifiesAsNL() {
        let inputs = [
            "how do I undo the last commit?",
            "what is the command to list all files including hidden ones",
            "show me every process using port 8080",
            "delete all the node_modules folders recursively",
            "please rename this branch to main",
            "can you find the largest files in this directory?",
            "I want to revert my changes",
            "create a new git branch called feature"
        ]
        for input in inputs {
            let result = NLCommandClassifier.classify(input)
            XCTAssertEqual(result.kind, .naturalLanguage, "expected .naturalLanguage for \(input)")
            XCTAssertEqual(result.suggestedAction, .offerNLToCommand, "expected offerNLToCommand for \(input)")
            XCTAssertGreaterThanOrEqual(result.confidence, NLCommandClassifier.decisiveConfidence,
                                        "expected decisive confidence for \(input) — got \(result.confidence)")
        }
    }

    // MARK: - Signals

    func testQuestionMarkIsAStrongNLSignal() {
        XCTAssertEqual(NLCommandClassifier.classify("git status?").kind, .naturalLanguage)
    }

    func testKnownBinaryAsFirstTokenLeansCommand() {
        // "find" / "open" / "make" are both English verbs and real binaries.
        // Used in a clearly shell-shaped form they should read as commands.
        XCTAssertEqual(NLCommandClassifier.classify("find . -name '*.swift'").kind, .command)
        XCTAssertEqual(NLCommandClassifier.classify("make -j8").kind, .command)
        XCTAssertEqual(NLCommandClassifier.classify("open .").kind, .command)
    }

    func testShellOperatorsForceCommand() {
        // A pipe / redirection / && is a near-certain command signal even with
        // an otherwise English-looking lead.
        XCTAssertEqual(NLCommandClassifier.classify("list files | sort").kind, .command)
        XCTAssertEqual(NLCommandClassifier.classify("foo > out.txt").kind, .command)
        XCTAssertEqual(NLCommandClassifier.classify("a && b").kind, .command)
    }

    func testAbsoluteAndRelativePathsLeanCommand() {
        XCTAssertEqual(NLCommandClassifier.classify("/usr/local/bin/foo").kind, .command)
        XCTAssertEqual(NLCommandClassifier.classify("./run.sh --fast").kind, .command)
    }

    func testEnvVarAssignmentPrefixIsACommand() {
        XCTAssertEqual(NLCommandClassifier.classify("FOO=bar ./run").kind, .command)
    }

    // MARK: - Empty / whitespace

    func testEmptyInputIsUnknownAndPassesThrough() {
        let result = NLCommandClassifier.classify("   ")
        XCTAssertEqual(result.kind, .unknown)
        // Empty defaults to pass-through (never interrupt with an offer).
        XCTAssertEqual(result.suggestedAction, .runAsCommand)
    }

    // MARK: - Asymmetry: bias toward pass-through

    func testAmbiguousButLeaningCommandDefaultsToPassThrough() {
        // A single bare English verb that is also a binary, with no strong NL
        // structure, must NOT interrupt with an offer (B4 + low-friction bias).
        let result = NLCommandClassifier.classify("test foo")
        XCTAssertEqual(result.suggestedAction, .runAsCommand,
                       "ambiguous-but-leaning-command must pass through, not offer")
    }

    func testAmbiguityFlagIsSetInTheMiddleBand() {
        // A multi-word English phrase that begins with a verb-binary collision
        // and has no decisive shell shape should be flagged ambiguous.
        let result = NLCommandClassifier.classify("make the build faster")
        XCTAssertTrue(result.isAmbiguous, "expected ambiguous for a verb-led English phrase")
    }

    // MARK: - Optional local-model tie-break (offline; injected stub)

    func testTieBreakOverridesOnlyWhenAmbiguous() async {
        let ambiguous = NLCommandClassifier.classify("make the build faster")
        XCTAssertTrue(ambiguous.isAmbiguous)

        // The stub stands in for a loopback-only local model. It is consulted
        // ONLY because the deterministic decision is ambiguous.
        var consulted = false
        let refined = await NLCommandClassifier.classify("make the build faster") { _ in
            consulted = true
            return .naturalLanguage
        }
        XCTAssertTrue(consulted, "tie-break must be consulted for an ambiguous input")
        XCTAssertEqual(refined.kind, .naturalLanguage)
        XCTAssertEqual(refined.suggestedAction, .offerNLToCommand)
    }

    func testTieBreakNotConsultedWhenDecisive() async {
        var consulted = false
        let refined = await NLCommandClassifier.classify("git status") { _ in
            consulted = true
            return .naturalLanguage
        }
        XCTAssertFalse(consulted, "tie-break must NOT run when the heuristic is decisive")
        // Decisive command verdict stands regardless of what a tie-break would say.
        XCTAssertEqual(refined.kind, .command)
    }

    func testTieBreakNilFallsBackToHeuristic() async {
        let heuristic = NLCommandClassifier.classify("make the build faster")
        let refined = await NLCommandClassifier.classify("make the build faster") { _ in nil }
        XCTAssertEqual(refined.kind, heuristic.kind,
                       "a nil tie-break must preserve the heuristic verdict")
    }
}
