import XCTest
@testable import TermyCore

/// AD-3: the pure unified-diff parser. Git-free — exercises the header/hunk/line
/// classification against hand-built fixtures, including the easy misses
/// (new file, deleted file, rename, "\ No newline at end of file").
final class UnifiedDiffParserTests: XCTestCase {

    func testModifiedFileSplitsAddedRemovedContext() {
        let raw = """
        diff --git a/src/main.swift b/src/main.swift
        index 1111111..2222222 100644
        --- a/src/main.swift
        +++ b/src/main.swift
        @@ -1,3 +1,3 @@ func main()
         let a = 1
        -let b = 2
        +let b = 3
         let c = 4
        """
        let files = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(files.count, 1)
        let f = files[0]
        XCTAssertEqual(f.path, "src/main.swift")
        XCTAssertEqual(f.status, .modified)
        XCTAssertFalse(f.untracked)
        XCTAssertEqual(f.addedCount, 1)
        XCTAssertEqual(f.removedCount, 1)
        XCTAssertEqual(f.lines.first?.kind, .hunkHeader)
        // Content strips the leading marker so the highlighter sees clean code.
        let added = f.lines.first { $0.kind == .added }
        XCTAssertEqual(added?.content, "let b = 3")
        let context = f.lines.first { $0.kind == .context }
        XCTAssertEqual(context?.content, "let a = 1")
    }

    func testNewFileMode() {
        let raw = """
        diff --git a/new.txt b/new.txt
        new file mode 100644
        index 0000000..89b24ec
        --- /dev/null
        +++ b/new.txt
        @@ -0,0 +1,2 @@
        +hello
        +world
        """
        let f = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f[0].status, .added)
        XCTAssertEqual(f[0].path, "new.txt")
        XCTAssertEqual(f[0].addedCount, 2)
        XCTAssertEqual(f[0].removedCount, 0)
    }

    func testDeletedFileMode() {
        let raw = """
        diff --git a/gone.txt b/gone.txt
        deleted file mode 100644
        index 89b24ec..0000000
        --- a/gone.txt
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -hello
        -world
        """
        let f = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f[0].status, .deleted)
        // newPath defaults to b/gone.txt from the diff --git header; +++ is /dev/null (ignored).
        XCTAssertEqual(f[0].path, "gone.txt")
        XCTAssertEqual(f[0].removedCount, 2)
    }

    func testRenameFromTo() {
        let raw = """
        diff --git a/old/name.swift b/new/name.swift
        similarity index 92%
        rename from old/name.swift
        rename to new/name.swift
        index 1111111..2222222 100644
        --- a/old/name.swift
        +++ b/new/name.swift
        @@ -1,1 +1,1 @@
        -let x = 1
        +let x = 2
        """
        let f = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(f.count, 1)
        XCTAssertEqual(f[0].status, .renamed)
        XCTAssertEqual(f[0].oldPath, "old/name.swift")
        XCTAssertEqual(f[0].path, "new/name.swift")
    }

    func testNoNewlineAtEndOfFileIsMeta() {
        let raw = """
        diff --git a/a.txt b/a.txt
        index 1111111..2222222 100644
        --- a/a.txt
        +++ b/a.txt
        @@ -1 +1 @@
        -old
        \\ No newline at end of file
        +new
        \\ No newline at end of file
        """
        let f = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(f.count, 1)
        let metas = f[0].lines.filter { $0.kind == .meta }
        XCTAssertEqual(metas.count, 2)
        // The marker rows don't inflate the ± counts.
        XCTAssertEqual(f[0].addedCount, 1)
        XCTAssertEqual(f[0].removedCount, 1)
    }

    func testMultipleFilesSplitOnDiffGit() {
        let raw = """
        diff --git a/one.txt b/one.txt
        index 1..2 100644
        --- a/one.txt
        +++ b/one.txt
        @@ -1 +1 @@
        -a
        +b
        diff --git a/two.txt b/two.txt
        index 3..4 100644
        --- a/two.txt
        +++ b/two.txt
        @@ -1 +1 @@
        -c
        +d
        """
        let files = UnifiedDiffParser.parse(raw)
        XCTAssertEqual(files.map(\.path), ["one.txt", "two.txt"])
    }

    func testEmptyInputYieldsNoFiles() {
        XCTAssertTrue(UnifiedDiffParser.parse("").isEmpty)
        XCTAssertTrue(UnifiedDiffParser.parse("   \n  ").isEmpty)
    }

    func testContentStripsOnlyTheMarkerNotIndentation() {
        let raw = """
        diff --git a/x.swift b/x.swift
        index 1..2 100644
        --- a/x.swift
        +++ b/x.swift
        @@ -1 +1,2 @@
         func f() {
        +    let indented = true
        """
        let f = UnifiedDiffParser.parse(raw)[0]
        let added = f.lines.first { $0.kind == .added }
        XCTAssertEqual(added?.content, "    let indented = true")
    }
}
