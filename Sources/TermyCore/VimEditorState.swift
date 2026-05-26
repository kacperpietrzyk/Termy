import Foundation

public enum VimEditorMode: Equatable, Sendable {
    case normal
    case insert
    case visual
}

public enum VimEditorOperator: Equatable, Sendable {
    case delete
    case change
    case yank
}

public enum VimEditorCommand: Equatable, Sendable {
    case countDigit(Int)
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case moveLineStart
    case moveFirstNonBlankInLine
    case moveFirstNonBlankLine
    case moveFirstNonBlankLineDown
    case moveFirstNonBlankLineUp
    case moveLastNonBlankLine
    case moveLineEnd
    case moveToColumn
    case moveDocumentStart
    case moveDocumentEnd
    case moveMatchingBracket
    case joinLineBelow
    case moveWordForward
    case moveWordBackward
    case moveWordEnd
    case moveWordEndBackward
    case moveBigWordForward
    case moveBigWordBackward
    case moveBigWordEnd
    case moveBigWordEndBackward
    case findCharacterForward(Character)
    case findCharacterBackward(Character)
    case tillCharacterForward(Character)
    case tillCharacterBackward(Character)
    case repeatLastCharacterSearch
    case repeatLastCharacterSearchReversed
    case deleteOperator
    case changeOperator
    case yankOperator
    case deleteToLineEnd
    case changeToLineEnd
    case yankToLineEnd
    case deleteCharacter
    case deleteCharacterBeforeCursor
    case replaceCharacter(Character)
    case substituteCharacter
    case substituteLine
    case toggleCharacterCase
    case undoLastChange
    case redoLastUndo
    case pasteBefore
    case pasteAfter
    case enterInsertMode
    case enterInsertLineStartMode
    case enterAppendMode
    case enterAppendLineMode
    case openLineBelow
    case openLineAbove
    case enterNormalMode
    case enterVisualMode
}

public struct VimEditorState: Equatable, Sendable {
    private struct UndoSnapshot: Equatable, Sendable {
        var buffer: String
        var cursorOffset: Int
        var yankRegister: String
        var yankRegisterIsLinewise: Bool
    }

    private enum CharacterSearchKind: Equatable, Sendable {
        case find
        case till
    }

    private struct CharacterSearch: Equatable, Sendable {
        var character: Character
        var direction: CharacterFindDirection
        var kind: CharacterSearchKind

        var reversed: CharacterSearch {
            CharacterSearch(character: character, direction: direction.reversed, kind: kind)
        }
    }

    public private(set) var buffer: String
    public private(set) var cursorOffset: Int
    public private(set) var mode: VimEditorMode
    public private(set) var pendingCount: Int?
    public private(set) var pendingOperator: VimEditorOperator?
    public private(set) var visualSelectionRange: Range<Int>?
    public private(set) var yankRegister: String
    private var visualAnchorOffset: Int?
    private var yankRegisterIsLinewise: Bool
    private var undoStack: [UndoSnapshot]
    private var redoStack: [UndoSnapshot]
    private var lastCharacterSearch: CharacterSearch?

    public init(
        buffer: String,
        cursorOffset: Int = 0,
        mode: VimEditorMode = .normal,
        pendingCount: Int? = nil,
        pendingOperator: VimEditorOperator? = nil,
        visualSelectionRange: Range<Int>? = nil,
        visualAnchorOffset: Int? = nil,
        yankRegister: String = "",
        yankRegisterIsLinewise: Bool = false
    ) {
        self.buffer = buffer
        self.cursorOffset = min(max(0, cursorOffset), buffer.count)
        self.mode = mode
        self.pendingCount = pendingCount
        self.pendingOperator = pendingOperator
        self.visualSelectionRange = visualSelectionRange
        self.visualAnchorOffset = visualAnchorOffset
        self.yankRegister = yankRegister
        self.yankRegisterIsLinewise = yankRegisterIsLinewise
        self.undoStack = []
        self.redoStack = []
        self.lastCharacterSearch = nil
    }

    public mutating func apply(_ command: VimEditorCommand) {
        if case .countDigit(let digit) = command {
            appendCountDigit(digit)
            return
        }
        if mode == .visual {
            applyVisual(command)
            return
        }
        if command == .deleteOperator || command == .changeOperator || command == .yankOperator {
            guard mode == .normal else { return }
            let nextOperator: VimEditorOperator
            switch command {
            case .deleteOperator:
                nextOperator = .delete
            case .changeOperator:
                nextOperator = .change
            case .yankOperator:
                nextOperator = .yank
            default:
                return
            }
            if pendingOperator == nextOperator {
                let repeatCount = consumeCount()
                pendingOperator = nil
                switch nextOperator {
                case .delete:
                    deleteLines(count: repeatCount)
                case .change:
                    changeLines(count: repeatCount)
                case .yank:
                    yankLines(count: repeatCount)
                }
                return
            }
            pendingOperator = nextOperator
            return
        }

        let repeatCount = consumeCount()
        if let pendingOperator {
            apply(pendingOperator, motion: command, count: repeatCount)
            return
        }

        switch command {
        case .countDigit:
            return
        case .deleteOperator:
            return
        case .changeOperator:
            return
        case .yankOperator:
            return
        case .deleteToLineEnd:
            applyToLineEnd(.delete, count: repeatCount)
        case .changeToLineEnd:
            applyToLineEnd(.change, count: repeatCount)
        case .yankToLineEnd:
            applyToLineEnd(.yank, count: repeatCount)
        case .undoLastChange:
            for _ in 0..<repeatCount {
                undoLastChange()
            }
        case .redoLastUndo:
            for _ in 0..<repeatCount {
                redoLastUndo()
            }
        case .pasteBefore:
            pasteRegister(beforeCursor: true, count: repeatCount)
        case .pasteAfter:
            pasteRegister(beforeCursor: false, count: repeatCount)
        case .moveLeft:
            cursorOffset = max(0, cursorOffset - repeatCount)
        case .moveRight:
            cursorOffset = min(buffer.count, cursorOffset + repeatCount)
        case .moveUp:
            cursorOffset = verticalMove(delta: -repeatCount)
        case .moveDown:
            cursorOffset = verticalMove(delta: repeatCount)
        case .moveLineStart:
            cursorOffset = currentLine().start
        case .moveFirstNonBlankInLine:
            cursorOffset = firstNonBlankOffsetInCurrentLine()
        case .moveFirstNonBlankLine:
            cursorOffset = firstNonBlankLineOffset(count: repeatCount)
        case .moveFirstNonBlankLineDown:
            cursorOffset = adjacentFirstNonBlankLineOffset(delta: repeatCount)
        case .moveFirstNonBlankLineUp:
            cursorOffset = adjacentFirstNonBlankLineOffset(delta: -repeatCount)
        case .moveLastNonBlankLine:
            cursorOffset = lastNonBlankLineOffset(count: repeatCount)
        case .moveLineEnd:
            cursorOffset = lineEndOffset(count: repeatCount)
        case .moveToColumn:
            cursorOffset = columnOffsetInCurrentLine(column: repeatCount)
        case .moveDocumentStart:
            cursorOffset = repeatCount > 1 ? documentLineOffset(count: repeatCount) : 0
        case .moveDocumentEnd:
            cursorOffset = repeatCount > 1 ? documentLineOffset(count: repeatCount) : buffer.count
        case .moveMatchingBracket:
            cursorOffset = matchingBracketOffset() ?? cursorOffset
        case .joinLineBelow:
            joinLineBelow(count: repeatCount)
        case .moveWordForward:
            for _ in 0..<repeatCount {
                cursorOffset = wordForwardOffset(from: cursorOffset)
            }
        case .moveWordBackward:
            for _ in 0..<repeatCount {
                cursorOffset = wordBackwardOffset(from: cursorOffset)
            }
        case .moveWordEnd:
            for _ in 0..<repeatCount {
                cursorOffset = wordEndOffset(from: cursorOffset)
            }
        case .moveWordEndBackward:
            for _ in 0..<repeatCount {
                cursorOffset = wordEndBackwardOffset(from: cursorOffset)
            }
        case .moveBigWordForward:
            for _ in 0..<repeatCount {
                cursorOffset = bigWordForwardOffset(from: cursorOffset)
            }
        case .moveBigWordBackward:
            for _ in 0..<repeatCount {
                cursorOffset = bigWordBackwardOffset(from: cursorOffset)
            }
        case .moveBigWordEnd:
            for _ in 0..<repeatCount {
                cursorOffset = bigWordEndOffset(from: cursorOffset)
            }
        case .moveBigWordEndBackward:
            for _ in 0..<repeatCount {
                cursorOffset = bigWordEndBackwardOffset(from: cursorOffset)
            }
        case .findCharacterForward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .forward, kind: .find), count: repeatCount, remember: true)
        case .findCharacterBackward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .backward, kind: .find), count: repeatCount, remember: true)
        case .tillCharacterForward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .forward, kind: .till), count: repeatCount, remember: true)
        case .tillCharacterBackward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .backward, kind: .till), count: repeatCount, remember: true)
        case .repeatLastCharacterSearch:
            if let lastCharacterSearch {
                applyCharacterSearch(lastCharacterSearch, count: repeatCount, remember: false, skipAdjacentTillMatch: true)
            }
        case .repeatLastCharacterSearchReversed:
            if let lastCharacterSearch {
                applyCharacterSearch(lastCharacterSearch.reversed, count: repeatCount, remember: false, skipAdjacentTillMatch: true)
            }
        case .deleteCharacter:
            deleteCharacters(count: repeatCount)
        case .deleteCharacterBeforeCursor:
            deleteCharactersBeforeCursor(count: repeatCount)
        case .replaceCharacter(let character):
            replaceCharacters(with: character, count: repeatCount)
        case .substituteCharacter:
            substituteCharacters(count: repeatCount)
        case .substituteLine:
            changeLines(count: repeatCount)
        case .toggleCharacterCase:
            toggleCharacterCase(count: repeatCount)
        case .enterInsertMode:
            pendingOperator = nil
            clearVisualSelection()
            mode = .insert
        case .enterInsertLineStartMode:
            pendingOperator = nil
            clearVisualSelection()
            cursorOffset = currentLine().start
            mode = .insert
        case .enterAppendMode:
            pendingOperator = nil
            clearVisualSelection()
            cursorOffset = min(cursorOffset + 1, buffer.count)
            mode = .insert
        case .enterAppendLineMode:
            pendingOperator = nil
            clearVisualSelection()
            cursorOffset = currentLine().end
            mode = .insert
        case .openLineBelow:
            pendingOperator = nil
            clearVisualSelection()
            openLine(relativeToCurrentLine: .below)
        case .openLineAbove:
            pendingOperator = nil
            clearVisualSelection()
            openLine(relativeToCurrentLine: .above)
        case .enterNormalMode:
            pendingOperator = nil
            clearVisualSelection()
            mode = .normal
        case .enterVisualMode:
            pendingOperator = nil
            mode = .visual
            visualAnchorOffset = cursorOffset
            visualSelectionRange = cursorOffset..<min(cursorOffset + 1, buffer.count)
        }
    }

    public mutating func insert(_ text: String) {
        guard mode == .insert, !text.isEmpty else { return }
        recordUndoSnapshot()
        let index = buffer.index(buffer.startIndex, offsetBy: cursorOffset)
        buffer.insert(contentsOf: text, at: index)
        cursorOffset += text.count
    }

    private mutating func applyVisual(_ command: VimEditorCommand) {
        switch command {
        case .enterNormalMode:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        case .deleteOperator, .deleteCharacter, .deleteCharacterBeforeCursor, .deleteToLineEnd:
            pendingCount = nil
            deleteVisualSelection()
        case .changeOperator, .changeToLineEnd, .substituteCharacter, .substituteLine:
            pendingCount = nil
            deleteVisualSelection()
            mode = .insert
        case .yankOperator, .yankToLineEnd:
            pendingCount = nil
            yankVisualSelection()
        case .moveLeft, .moveRight, .moveUp, .moveDown, .moveLineStart, .moveFirstNonBlankInLine, .moveFirstNonBlankLine, .moveFirstNonBlankLineDown, .moveFirstNonBlankLineUp, .moveLastNonBlankLine, .moveLineEnd, .moveToColumn, .moveDocumentStart, .moveDocumentEnd, .moveMatchingBracket, .moveWordForward, .moveWordBackward, .moveWordEnd, .moveWordEndBackward, .moveBigWordForward, .moveBigWordBackward, .moveBigWordEnd, .moveBigWordEndBackward, .findCharacterForward, .findCharacterBackward, .tillCharacterForward, .tillCharacterBackward, .repeatLastCharacterSearch, .repeatLastCharacterSearchReversed:
            let repeatCount = consumeCount()
            applyVisualMotion(command, count: repeatCount)
        case .enterInsertMode, .enterInsertLineStartMode, .enterAppendMode, .enterAppendLineMode, .openLineBelow, .openLineAbove:
            pendingCount = nil
            clearVisualSelection()
            mode = .insert
        case .enterVisualMode:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        case .countDigit:
            return
        case .pasteBefore, .pasteAfter:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        case .undoLastChange:
            pendingCount = nil
            undoLastChange()
        case .redoLastUndo:
            pendingCount = nil
            redoLastUndo()
        case .joinLineBelow:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        case .toggleCharacterCase:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        case .replaceCharacter:
            pendingCount = nil
            clearVisualSelection()
            mode = .normal
        }
    }

    private mutating func appendCountDigit(_ digit: Int) {
        guard mode == .normal || mode == .visual, (0...9).contains(digit) else { return }
        if pendingCount == nil, digit == 0 { return }
        pendingCount = min(((pendingCount ?? 0) * 10) + digit, 999)
    }

    private mutating func consumeCount() -> Int {
        let count = pendingCount ?? 1
        pendingCount = nil
        return max(1, count)
    }

    private mutating func deleteCharacters(count: Int) {
        guard mode == .normal, cursorOffset < buffer.count else { return }
        let startIndex = buffer.index(buffer.startIndex, offsetBy: cursorOffset)
        let deleteCount = min(count, buffer.count - cursorOffset)
        guard deleteCount > 0 else { return }
        recordUndoSnapshot()
        let endIndex = buffer.index(startIndex, offsetBy: deleteCount)
        buffer.removeSubrange(startIndex..<endIndex)
        cursorOffset = min(cursorOffset, buffer.count)
    }

    private mutating func deleteCharactersBeforeCursor(count: Int) {
        guard mode == .normal, cursorOffset > 0 else { return }
        let deleteCount = min(count, cursorOffset)
        let lowerBound = cursorOffset - deleteCount
        let startIndex = buffer.index(buffer.startIndex, offsetBy: lowerBound)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: cursorOffset)
        recordUndoSnapshot()
        buffer.removeSubrange(startIndex..<endIndex)
        cursorOffset = lowerBound
    }

    private mutating func replaceCharacters(with character: Character, count: Int) {
        guard mode == .normal, cursorOffset < buffer.count else { return }
        let replaceCount = min(count, buffer.count - cursorOffset)
        guard replaceCount > 0 else { return }

        let startIndex = buffer.index(buffer.startIndex, offsetBy: cursorOffset)
        let endIndex = buffer.index(startIndex, offsetBy: replaceCount)
        recordUndoSnapshot()
        buffer.replaceSubrange(startIndex..<endIndex, with: String(repeating: String(character), count: replaceCount))
        cursorOffset = min(cursorOffset + replaceCount, buffer.count)
    }

    private mutating func substituteCharacters(count: Int) {
        guard mode == .normal, cursorOffset < buffer.count else { return }
        deleteCharacters(count: count)
        mode = .insert
    }

    private mutating func toggleCharacterCase(count: Int) {
        guard mode == .normal, cursorOffset < buffer.count else { return }
        let toggleCount = min(count, buffer.count - cursorOffset)
        guard toggleCount > 0 else { return }

        let startIndex = buffer.index(buffer.startIndex, offsetBy: cursorOffset)
        let endIndex = buffer.index(startIndex, offsetBy: toggleCount)
        let replacement = buffer[startIndex..<endIndex].map { character in
            if character.isLowercase {
                Character(String(character).uppercased())
            } else if character.isUppercase {
                Character(String(character).lowercased())
            } else {
                character
            }
        }
        recordUndoSnapshot()
        buffer.replaceSubrange(startIndex..<endIndex, with: String(replacement))
        cursorOffset = min(cursorOffset + toggleCount, buffer.count)
    }

    private mutating func deleteVisualSelection() {
        guard let selection = visualSelectionRange,
              selection.lowerBound < selection.upperBound else {
            clearVisualSelection()
            mode = .normal
            return
        }
        let lowerBound = min(selection.lowerBound, buffer.count)
        let upperBound = min(selection.upperBound, buffer.count)
        recordUndoSnapshot()
        let startIndex = buffer.index(buffer.startIndex, offsetBy: lowerBound)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: upperBound)
        buffer.removeSubrange(startIndex..<endIndex)
        cursorOffset = min(lowerBound, buffer.count)
        clearVisualSelection()
        mode = .normal
    }

    private mutating func yankVisualSelection() {
        guard let selection = visualSelectionRange,
              selection.lowerBound < selection.upperBound else {
            clearVisualSelection()
            mode = .normal
            return
        }
        yankRegister = substring(from: selection.lowerBound, to: selection.upperBound)
        yankRegisterIsLinewise = false
        cursorOffset = min(selection.lowerBound, buffer.count)
        clearVisualSelection()
        mode = .normal
    }

    private mutating func applyVisualMotion(_ command: VimEditorCommand, count: Int) {
        let anchor = visualAnchorOffset ?? cursorOffset
        switch command {
        case .moveLeft:
            cursorOffset = max(0, cursorOffset - count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveRight:
            cursorOffset = min(buffer.count, cursorOffset + count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveUp:
            cursorOffset = verticalMove(delta: -count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveDown:
            cursorOffset = verticalMove(delta: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveLineStart:
            cursorOffset = currentLine().start
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveFirstNonBlankInLine:
            cursorOffset = firstNonBlankOffsetInCurrentLine()
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveFirstNonBlankLine:
            cursorOffset = firstNonBlankLineOffset(count: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveFirstNonBlankLineDown:
            cursorOffset = adjacentFirstNonBlankLineOffset(delta: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveFirstNonBlankLineUp:
            cursorOffset = adjacentFirstNonBlankLineOffset(delta: -count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveLastNonBlankLine:
            cursorOffset = lastNonBlankLineOffset(count: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveLineEnd:
            cursorOffset = lineEndOffset(count: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveToColumn:
            cursorOffset = columnOffsetInCurrentLine(column: count)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveDocumentStart:
            cursorOffset = count > 1 ? documentLineOffset(count: count) : 0
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveDocumentEnd:
            cursorOffset = count > 1 ? documentLineOffset(count: count) : buffer.count
            updateVisualSelection(anchor: anchor, includesCursor: count > 1)
        case .moveMatchingBracket:
            cursorOffset = matchingBracketOffset() ?? cursorOffset
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveWordForward:
            for _ in 0..<count {
                cursorOffset = wordForwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: false)
        case .moveWordBackward:
            for _ in 0..<count {
                cursorOffset = wordBackwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveWordEnd:
            for _ in 0..<count {
                cursorOffset = wordEndOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveWordEndBackward:
            for _ in 0..<count {
                cursorOffset = wordEndBackwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveBigWordForward:
            for _ in 0..<count {
                cursorOffset = bigWordForwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: false)
        case .moveBigWordBackward:
            for _ in 0..<count {
                cursorOffset = bigWordBackwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveBigWordEnd:
            for _ in 0..<count {
                cursorOffset = bigWordEndOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .moveBigWordEndBackward:
            for _ in 0..<count {
                cursorOffset = bigWordEndBackwardOffset(from: cursorOffset)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .findCharacterForward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .forward, kind: .find), count: count, remember: true)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .findCharacterBackward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .backward, kind: .find), count: count, remember: true)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .tillCharacterForward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .forward, kind: .till), count: count, remember: true)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .tillCharacterBackward(let character):
            applyCharacterSearch(CharacterSearch(character: character, direction: .backward, kind: .till), count: count, remember: true)
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .repeatLastCharacterSearch:
            if let lastCharacterSearch {
                applyCharacterSearch(lastCharacterSearch, count: count, remember: false, skipAdjacentTillMatch: true)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        case .repeatLastCharacterSearchReversed:
            if let lastCharacterSearch {
                applyCharacterSearch(lastCharacterSearch.reversed, count: count, remember: false, skipAdjacentTillMatch: true)
            }
            updateVisualSelection(anchor: anchor, includesCursor: true)
        default:
            return
        }
    }

    private mutating func updateVisualSelection(anchor: Int, includesCursor: Bool) {
        visualAnchorOffset = anchor
        if cursorOffset >= anchor {
            let upperBound = min(cursorOffset + (includesCursor ? 1 : 0), buffer.count)
            visualSelectionRange = anchor..<max(anchor, upperBound)
        } else {
            let upperBound = min(anchor + 1, buffer.count)
            visualSelectionRange = cursorOffset..<max(cursorOffset, upperBound)
        }
    }

    private mutating func clearVisualSelection() {
        visualSelectionRange = nil
        visualAnchorOffset = nil
    }

    private enum OpenLinePosition {
        case above
        case below
    }

    private mutating func openLine(relativeToCurrentLine position: OpenLinePosition) {
        let line = currentLine()
        let insertionOffset: Int
        let insertedText: String
        switch position {
        case .above:
            insertionOffset = line.start
            insertedText = "\n"
        case .below:
            insertionOffset = line.end
            insertedText = "\n"
        }
        let index = buffer.index(buffer.startIndex, offsetBy: insertionOffset)
        recordUndoSnapshot()
        buffer.insert(contentsOf: insertedText, at: index)
        cursorOffset = position == .above ? insertionOffset : insertionOffset + 1
        mode = .insert
    }

    private mutating func joinLineBelow(count: Int) {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }),
              lines.indices.contains(currentLineIndex + 1) else {
            return
        }
        let linesToJoin = max(2, count)
        let targetLineIndex = min(currentLineIndex + linesToJoin - 1, lines.index(before: lines.endIndex))
        let line = lines[currentLineIndex]
        let replacement = (currentLineIndex + 1...targetLineIndex)
            .map { index in
                let nextLine = lines[index]
                return " " + substring(from: nextLine.start, to: nextLine.end).trimmingCharacters(in: .whitespaces)
            }
            .joined()
        let startIndex = buffer.index(buffer.startIndex, offsetBy: line.end)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: lines[targetLineIndex].end)
        recordUndoSnapshot()
        buffer.replaceSubrange(startIndex..<endIndex, with: replacement)
        cursorOffset = line.end
    }

    private mutating func deleteLines(count: Int) {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return
        }
        let deleteStart = lines[currentLineIndex].start
        let lastDeletedLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        let deleteEnd = lines.indices.contains(lastDeletedLineIndex + 1)
            ? lines[lastDeletedLineIndex + 1].start
            : buffer.count
        guard deleteStart < deleteEnd else { return }

        let startIndex = buffer.index(buffer.startIndex, offsetBy: deleteStart)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: deleteEnd)
        recordUndoSnapshot()
        buffer.removeSubrange(startIndex..<endIndex)
        cursorOffset = min(deleteStart, buffer.count)
    }

    private mutating func changeLines(count: Int) {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return
        }
        let changeStart = lines[currentLineIndex].start
        let lastChangedLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        let changeEnd = lines[lastChangedLineIndex].end

        let startIndex = buffer.index(buffer.startIndex, offsetBy: changeStart)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: changeEnd)
        recordUndoSnapshot()
        buffer.removeSubrange(startIndex..<endIndex)
        cursorOffset = min(changeStart, buffer.count)
        mode = .insert
    }

    private mutating func yankLines(count: Int) {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return
        }
        let yankStart = lines[currentLineIndex].start
        let lastYankedLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        let yankEnd = lines.indices.contains(lastYankedLineIndex + 1)
            ? lines[lastYankedLineIndex + 1].start
            : buffer.count
        yankRegister = substring(from: yankStart, to: yankEnd)
        if !yankRegister.hasSuffix("\n") {
            yankRegister.append("\n")
        }
        yankRegisterIsLinewise = true
        cursorOffset = min(yankStart, buffer.count)
    }

    private mutating func apply(_ operation: VimEditorOperator, motion command: VimEditorCommand, count: Int) {
        pendingOperator = nil
        guard mode == .normal,
              let motion = motionRange(for: command, count: count) else {
            return
        }
        let lowerBound = min(motion.start, motion.end)
        let upperBound = max(motion.start, motion.end)
        guard lowerBound < upperBound else { return }

        switch operation {
        case .delete, .change:
            let startIndex = buffer.index(buffer.startIndex, offsetBy: lowerBound)
            let endIndex = buffer.index(buffer.startIndex, offsetBy: upperBound)
            recordUndoSnapshot()
            buffer.removeSubrange(startIndex..<endIndex)
            cursorOffset = min(lowerBound, buffer.count)
        case .yank:
            yankRegister = substring(from: lowerBound, to: upperBound)
            yankRegisterIsLinewise = false
        }
        if operation == .change {
            mode = .insert
        }
    }

    private mutating func applyToLineEnd(_ operation: VimEditorOperator, count: Int) {
        pendingOperator = nil
        guard mode == .normal else { return }
        let lowerBound = cursorOffset
        let upperBound = lineEndOffset(count: count)
        guard lowerBound < upperBound else { return }

        switch operation {
        case .delete, .change:
            let startIndex = buffer.index(buffer.startIndex, offsetBy: lowerBound)
            let endIndex = buffer.index(buffer.startIndex, offsetBy: upperBound)
            recordUndoSnapshot()
            buffer.removeSubrange(startIndex..<endIndex)
            cursorOffset = min(lowerBound, buffer.count)
        case .yank:
            yankRegister = substring(from: lowerBound, to: upperBound)
            yankRegisterIsLinewise = false
        }
        if operation == .change {
            mode = .insert
        }
    }

    private mutating func pasteRegister(beforeCursor: Bool, count: Int) {
        guard !yankRegister.isEmpty else { return }
        let repeatCount = max(1, count)
        let repeatedRegister = String(repeating: yankRegister, count: repeatCount)
        let insertionOffset: Int
        let insertedText: String
        if yankRegisterIsLinewise {
            let lines = lineRanges()
            let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) ?? lines.startIndex
            if beforeCursor {
                insertionOffset = lines[currentLineIndex].start
                insertedText = repeatedRegister
            } else if lines.indices.contains(currentLineIndex + 1) {
                insertionOffset = lines[currentLineIndex + 1].start
                insertedText = repeatedRegister
            } else {
                insertionOffset = buffer.count
                insertedText = buffer.hasSuffix("\n") ? repeatedRegister : "\n" + repeatedRegister
            }
        } else {
            insertionOffset = beforeCursor ? cursorOffset : min(cursorOffset + 1, buffer.count)
            insertedText = repeatedRegister
        }

        let index = buffer.index(buffer.startIndex, offsetBy: insertionOffset)
        recordUndoSnapshot()
        buffer.insert(contentsOf: insertedText, at: index)
        if yankRegisterIsLinewise {
            cursorOffset = insertionOffset + (insertedText.hasPrefix("\n") ? 1 : 0)
        } else {
            cursorOffset = insertionOffset + insertedText.count
        }
    }

    private func substring(from lowerBound: Int, to upperBound: Int) -> String {
        let safeLowerBound = min(max(0, lowerBound), buffer.count)
        let safeUpperBound = min(max(safeLowerBound, upperBound), buffer.count)
        let startIndex = buffer.index(buffer.startIndex, offsetBy: safeLowerBound)
        let endIndex = buffer.index(buffer.startIndex, offsetBy: safeUpperBound)
        return String(buffer[startIndex..<endIndex])
    }

    private mutating func motionRange(for command: VimEditorCommand, count: Int) -> (start: Int, end: Int)? {
        let start = cursorOffset
        var target = cursorOffset

        switch command {
        case .moveWordForward:
            for _ in 0..<count {
                target = wordForwardOffset(from: target)
            }
            return (start, target)
        case .moveWordBackward:
            for _ in 0..<count {
                target = wordBackwardOffset(from: target)
            }
            return (start, target)
        case .moveWordEnd:
            for _ in 0..<count {
                target = wordEndOffset(from: target)
            }
            return (start, min(target + 1, buffer.count))
        case .moveWordEndBackward:
            for _ in 0..<count {
                target = wordEndBackwardOffset(from: target)
            }
            return (start, min(target + 1, buffer.count))
        case .moveBigWordForward:
            for _ in 0..<count {
                target = bigWordForwardOffset(from: target)
            }
            return (start, target)
        case .moveBigWordBackward:
            for _ in 0..<count {
                target = bigWordBackwardOffset(from: target)
            }
            return (start, target)
        case .moveBigWordEnd:
            for _ in 0..<count {
                target = bigWordEndOffset(from: target)
            }
            return (start, min(target + 1, buffer.count))
        case .moveBigWordEndBackward:
            for _ in 0..<count {
                target = bigWordEndBackwardOffset(from: target)
            }
            return (start, min(target + 1, buffer.count))
        case .moveRight:
            return (start, min(start + count, buffer.count))
        case .moveLeft:
            return (start, max(start - count, 0))
        case .moveLineStart:
            return (start, currentLine().start)
        case .moveFirstNonBlankInLine:
            return (start, firstNonBlankOffsetInCurrentLine())
        case .moveFirstNonBlankLine:
            return (start, firstNonBlankLineOffset(count: count))
        case .moveFirstNonBlankLineDown:
            return (start, adjacentFirstNonBlankLineOffset(delta: count))
        case .moveFirstNonBlankLineUp:
            return (start, adjacentFirstNonBlankLineOffset(delta: -count))
        case .moveLastNonBlankLine:
            return (start, min(lastNonBlankLineOffset(count: count) + 1, buffer.count))
        case .moveLineEnd:
            return (start, lineEndOffset(count: count))
        case .moveToColumn:
            return (start, columnOffsetInCurrentLine(column: count))
        case .moveDocumentStart:
            return (start, count > 1 ? documentLineOffset(count: count) : 0)
        case .moveDocumentEnd:
            return (start, count > 1 ? documentLineOffset(count: count) : buffer.count)
        case .moveMatchingBracket:
            guard let target = matchingBracketOffset() else { return nil }
            return (start, target)
        case .findCharacterForward(let character):
            return motionRange(for: CharacterSearch(character: character, direction: .forward, kind: .find), from: start, count: count, remember: true)
        case .findCharacterBackward(let character):
            return motionRange(for: CharacterSearch(character: character, direction: .backward, kind: .find), from: start, count: count, remember: true)
        case .tillCharacterForward(let character):
            return motionRange(for: CharacterSearch(character: character, direction: .forward, kind: .till), from: start, count: count, remember: true)
        case .tillCharacterBackward(let character):
            return motionRange(for: CharacterSearch(character: character, direction: .backward, kind: .till), from: start, count: count, remember: true)
        case .repeatLastCharacterSearch:
            guard let lastCharacterSearch else { return nil }
            return motionRange(for: lastCharacterSearch, from: start, count: count, remember: false, skipAdjacentTillMatch: true)
        case .repeatLastCharacterSearchReversed:
            guard let lastCharacterSearch else { return nil }
            return motionRange(for: lastCharacterSearch.reversed, from: start, count: count, remember: false, skipAdjacentTillMatch: true)
        default:
            return nil
        }
    }

    private enum CharacterFindDirection {
        case forward
        case backward

        var reversed: CharacterFindDirection {
            switch self {
            case .forward:
                .backward
            case .backward:
                .forward
            }
        }
    }

    private mutating func applyCharacterSearch(
        _ search: CharacterSearch,
        count: Int,
        remember: Bool,
        skipAdjacentTillMatch: Bool = false
    ) {
        guard let target = characterSearchTarget(
            for: search,
            from: cursorOffset,
            count: count,
            skipAdjacentTillMatch: skipAdjacentTillMatch
        ) else { return }
        cursorOffset = target
        if remember {
            lastCharacterSearch = search
        }
    }

    private mutating func motionRange(
        for search: CharacterSearch,
        from start: Int,
        count: Int,
        remember: Bool,
        skipAdjacentTillMatch: Bool = false
    ) -> (start: Int, end: Int)? {
        guard let target = characterSearchTarget(
            for: search,
            from: start,
            count: count,
            skipAdjacentTillMatch: skipAdjacentTillMatch
        ) else { return nil }
        if remember {
            lastCharacterSearch = search
        }
        switch (search.kind, search.direction) {
        case (.find, .forward):
            return (start, min(target + 1, buffer.count))
        case (.find, .backward):
            return (start, target)
        case (.till, .forward):
            return (start, min(target + 1, buffer.count))
        case (.till, .backward):
            return (start, target)
        }
    }

    private func characterSearchTarget(
        for search: CharacterSearch,
        from offset: Int,
        count: Int,
        skipAdjacentTillMatch: Bool = false
    ) -> Int? {
        var effectiveCount = count
        if skipAdjacentTillMatch,
           search.kind == .till,
           tillCharacter(search.character, from: offset, direction: search.direction, count: 1) == offset {
            effectiveCount += 1
        }
        switch search.kind {
        case .find:
            return findCharacter(search.character, from: offset, direction: search.direction, count: effectiveCount)
        case .till:
            return tillCharacter(search.character, from: offset, direction: search.direction, count: effectiveCount)
        }
    }

    private func findCharacter(
        _ character: Character,
        from offset: Int,
        direction: CharacterFindDirection,
        count: Int
    ) -> Int? {
        let characters = Array(buffer)
        guard !characters.isEmpty else { return nil }
        var remaining = max(1, count)

        switch direction {
        case .forward:
            guard offset + 1 < characters.count else { return nil }
            for index in (offset + 1)..<characters.count where characters[index] == character {
                remaining -= 1
                if remaining == 0 {
                    return index
                }
            }
        case .backward:
            guard offset > 0 else { return nil }
            for index in stride(from: offset - 1, through: 0, by: -1) where characters[index] == character {
                remaining -= 1
                if remaining == 0 {
                    return index
                }
            }
        }
        return nil
    }

    private func tillCharacter(
        _ character: Character,
        from offset: Int,
        direction: CharacterFindDirection,
        count: Int
    ) -> Int? {
        guard let target = findCharacter(character, from: offset, direction: direction, count: count) else {
            return nil
        }
        switch direction {
        case .forward:
            return max(offset, target - 1)
        case .backward:
            return min(buffer.count, target + 1)
        }
    }

    private func matchingBracketOffset() -> Int? {
        let characters = Array(buffer)
        guard cursorOffset >= 0, cursorOffset < characters.count else { return nil }
        let character = characters[cursorOffset]
        let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
        let reversePairs = Dictionary(uniqueKeysWithValues: pairs.map { ($0.value, $0.key) })

        if let closing = pairs[character] {
            var depth = 0
            for index in cursorOffset..<characters.count {
                if characters[index] == character {
                    depth += 1
                } else if characters[index] == closing {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
        } else if let opening = reversePairs[character] {
            var depth = 0
            for index in stride(from: cursorOffset, through: 0, by: -1) {
                if characters[index] == character {
                    depth += 1
                } else if characters[index] == opening {
                    depth -= 1
                    if depth == 0 {
                        return index
                    }
                }
            }
        }
        return nil
    }

    private mutating func recordUndoSnapshot() {
        let snapshot = UndoSnapshot(
            buffer: buffer,
            cursorOffset: cursorOffset,
            yankRegister: yankRegister,
            yankRegisterIsLinewise: yankRegisterIsLinewise
        )
        guard undoStack.last != snapshot else { return }
        undoStack.append(snapshot)
        redoStack = []
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
    }

    private mutating func undoLastChange() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(currentUndoSnapshot())
        if redoStack.count > 100 {
            redoStack.removeFirst(redoStack.count - 100)
        }
        restore(snapshot)
    }

    private mutating func redoLastUndo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(currentUndoSnapshot())
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
        restore(snapshot)
    }

    private func currentUndoSnapshot() -> UndoSnapshot {
        UndoSnapshot(
            buffer: buffer,
            cursorOffset: cursorOffset,
            yankRegister: yankRegister,
            yankRegisterIsLinewise: yankRegisterIsLinewise
        )
    }

    private mutating func restore(_ snapshot: UndoSnapshot) {
        buffer = snapshot.buffer
        cursorOffset = min(max(0, snapshot.cursorOffset), buffer.count)
        yankRegister = snapshot.yankRegister
        yankRegisterIsLinewise = snapshot.yankRegisterIsLinewise
        pendingCount = nil
        pendingOperator = nil
        clearVisualSelection()
        mode = .normal
    }

    private func verticalMove(delta: Int) -> Int {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return cursorOffset
        }
        let column = cursorOffset - lines[currentLineIndex].start
        let unclampedTargetLineIndex = currentLineIndex + delta
        let targetLineIndex = min(max(lines.startIndex, unclampedTargetLineIndex), lines.index(before: lines.endIndex))
        let target = lines[targetLineIndex]
        return target.start + min(column, target.end - target.start)
    }

    private func currentLine() -> (start: Int, end: Int) {
        lineRanges().first { cursorOffset >= $0.start && cursorOffset <= $0.end } ?? (start: 0, end: buffer.count)
    }

    private func lineEndOffset(count: Int) -> Int {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return cursorOffset
        }
        let targetLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        return lines[targetLineIndex].end
    }

    private func firstNonBlankOffsetInCurrentLine() -> Int {
        firstNonBlankOffset(in: currentLine())
    }

    private func firstNonBlankLineOffset(count: Int) -> Int {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return cursorOffset
        }
        let targetLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        return firstNonBlankOffset(in: lines[targetLineIndex])
    }

    private func lastNonBlankLineOffset(count: Int) -> Int {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return cursorOffset
        }
        let targetLineIndex = min(currentLineIndex + max(1, count) - 1, lines.index(before: lines.endIndex))
        return lastNonBlankOffset(in: lines[targetLineIndex])
    }

    private func adjacentFirstNonBlankLineOffset(delta: Int) -> Int {
        let lines = lineRanges()
        guard let currentLineIndex = lines.firstIndex(where: { cursorOffset >= $0.start && cursorOffset <= $0.end }) else {
            return cursorOffset
        }
        let targetLineIndex = min(max(lines.startIndex, currentLineIndex + delta), lines.index(before: lines.endIndex))
        return firstNonBlankOffset(in: lines[targetLineIndex])
    }

    private func firstNonBlankOffset(in line: (start: Int, end: Int)) -> Int {
        let characters = Array(buffer)
        guard line.start < line.end else { return line.start }
        for offset in line.start..<line.end where !characters[offset].isWhitespace {
            return offset
        }
        return line.end
    }

    private func lastNonBlankOffset(in line: (start: Int, end: Int)) -> Int {
        let characters = Array(buffer)
        guard line.start < line.end else { return line.start }
        for offset in stride(from: line.end - 1, through: line.start, by: -1) where !characters[offset].isWhitespace {
            return offset
        }
        return line.start
    }

    private func documentLineOffset(count: Int) -> Int {
        let lines = lineRanges()
        let targetLineIndex = min(max(0, count - 1), lines.index(before: lines.endIndex))
        return firstNonBlankOffset(in: lines[targetLineIndex])
    }

    private func columnOffsetInCurrentLine(column: Int) -> Int {
        let line = currentLine()
        let zeroBasedColumn = max(0, column - 1)
        return min(line.start + zeroBasedColumn, line.end)
    }

    private func wordForwardOffset(from offset: Int) -> Int {
        guard offset < buffer.count else { return buffer.count }
        let characters = Array(buffer)
        var index = min(max(0, offset), characters.count)
        if index < characters.count, isWordCharacter(characters[index]) {
            while index < characters.count, isWordCharacter(characters[index]) {
                index += 1
            }
        }
        while index < characters.count, !isWordCharacter(characters[index]) {
            index += 1
        }
        return min(index, buffer.count)
    }

    private func wordBackwardOffset(from offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        let characters = Array(buffer)
        var index = min(max(0, offset - 1), characters.count - 1)
        while index > 0, !isWordCharacter(characters[index]) {
            index -= 1
        }
        while index > 0, isWordCharacter(characters[index - 1]) {
            index -= 1
        }
        return index
    }

    private func wordEndOffset(from offset: Int) -> Int {
        guard offset < buffer.count else { return buffer.count }
        let characters = Array(buffer)
        var index = min(max(0, offset), characters.count - 1)
        if index < characters.count, isWordCharacter(characters[index]) {
            while index + 1 < characters.count, isWordCharacter(characters[index + 1]) {
                index += 1
            }
            return index
        }
        while index < characters.count, !isWordCharacter(characters[index]) {
            index += 1
        }
        while index + 1 < characters.count, isWordCharacter(characters[index + 1]) {
            index += 1
        }
        return min(index, buffer.count)
    }

    private func wordEndBackwardOffset(from offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        let characters = Array(buffer)
        var index = min(max(0, offset - 1), characters.count - 1)

        if isWordCharacter(characters[index]) {
            while index > 0, isWordCharacter(characters[index - 1]) {
                index -= 1
            }
            guard index > 0 else { return 0 }
            index -= 1
        }

        while index > 0, !isWordCharacter(characters[index]) {
            index -= 1
        }
        return index
    }

    private func bigWordForwardOffset(from offset: Int) -> Int {
        guard offset < buffer.count else { return buffer.count }
        let characters = Array(buffer)
        var index = min(max(0, offset), characters.count)
        if index < characters.count, !characters[index].isWhitespace {
            while index < characters.count, !characters[index].isWhitespace {
                index += 1
            }
        }
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
        return min(index, buffer.count)
    }

    private func bigWordBackwardOffset(from offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        let characters = Array(buffer)
        var index = min(max(0, offset - 1), characters.count - 1)
        while index > 0, characters[index].isWhitespace {
            index -= 1
        }
        while index > 0, !characters[index - 1].isWhitespace {
            index -= 1
        }
        return index
    }

    private func bigWordEndOffset(from offset: Int) -> Int {
        guard offset < buffer.count else { return buffer.count }
        let characters = Array(buffer)
        var index = min(max(0, offset), characters.count - 1)
        if index < characters.count, !characters[index].isWhitespace {
            while index + 1 < characters.count, !characters[index + 1].isWhitespace {
                index += 1
            }
            return index
        }
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
        while index + 1 < characters.count, !characters[index + 1].isWhitespace {
            index += 1
        }
        return min(index, buffer.count)
    }

    private func bigWordEndBackwardOffset(from offset: Int) -> Int {
        guard offset > 0 else { return 0 }
        let characters = Array(buffer)
        var index = min(max(0, offset - 1), characters.count - 1)

        if !characters[index].isWhitespace {
            while index > 0, !characters[index - 1].isWhitespace {
                index -= 1
            }
            guard index > 0 else { return 0 }
            index -= 1
        }

        while index > 0, characters[index].isWhitespace {
            index -= 1
        }
        return index
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func lineRanges() -> [(start: Int, end: Int)] {
        var ranges: [(start: Int, end: Int)] = []
        var start = 0
        for (offset, character) in buffer.enumerated() where character == "\n" {
            ranges.append((start: start, end: offset))
            start = offset + 1
        }
        ranges.append((start: start, end: buffer.count))
        return ranges
    }
}
