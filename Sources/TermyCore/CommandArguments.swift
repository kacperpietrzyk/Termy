import Foundation

/// CK-S7 — inline arguments for argument-bearing ⌘K commands.
///
/// A handful of commands (ssh, grep, cd, branch, agent-prompt) are useless
/// without a parameter the user must type before running. Raycast captures that
/// parameter *inline in the search bar* — type the verb, then the argument — so
/// the user never leaves the palette. This file is the pure, dependency-free
/// core of that mechanism: the argument spec, plus a parser that recognizes a
/// leading verb and slices "verb + rest". No store, no SwiftUI — so it unit-tests
/// purely. The store layers launch dispatch on top; the view layers the
/// arg-entry affordance + completions on top.

// MARK: - Argument spec

/// One inline argument captured before an arg-bearing command runs.
public struct CommandArgument: Equatable, Sendable {
    /// How the arg-entry affordance can offer completions for this argument.
    /// `.path` and `.branch` route through the existing `CompletionEngine`;
    /// `.none` is free text (a grep pattern, an agent prompt).
    public enum Completion: String, Sendable, Equatable {
        case none
        case path
        case branch
    }

    /// Display name of the argument (e.g. "pattern", "path", "destination").
    public let name: String
    /// When true, the command cannot run until this argument has a value (the UI
    /// disables Enter). When false, an empty value falls back to `defaultValue`
    /// or the command's own no-arg behavior.
    public let isRequired: Bool
    /// Value used when the rest is empty and the argument is optional.
    public let defaultValue: String?
    /// Completion source for the arg-entry affordance.
    public let completion: Completion

    public init(
        name: String,
        isRequired: Bool,
        defaultValue: String? = nil,
        completion: Completion = .none
    ) {
        self.name = name
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.completion = completion
    }
}

// MARK: - Parsed inline command

/// The structured result of recognizing an inline-arg command in the ⌘K query.
/// Holds the matched action plus the parsed "rest" (everything after the verb),
/// and exposes the small derived facts the store + view need (completeness,
/// effective value, completion kind) so neither has to re-derive them.
public struct ParsedInlineCommand: Equatable, Sendable {
    /// The arg-bearing command the verb matched.
    public let action: CommandAction
    /// Everything after the verb, edge-trimmed. Internal whitespace is preserved
    /// (an agent prompt or grep pattern can contain spaces). Empty when only the
    /// bare verb + a trailing space was typed.
    public let rest: String

    public init(action: CommandAction, rest: String) {
        self.action = action
        self.rest = rest
    }

    /// The (single) positional argument this command captures, if any. The S7
    /// verbs each declare exactly one; the model permits more for future verbs,
    /// in which case this is the first.
    public var primaryArgument: CommandArgument? { action.arguments.first }

    /// The completion source for the active argument (`.none` when free text or
    /// when the command declares no argument).
    public var completion: CommandArgument.Completion {
        primaryArgument?.completion ?? .none
    }

    /// The value the command will run with: the typed rest when non-empty,
    /// otherwise the argument's default (if any), otherwise empty.
    public var effectiveValue: String {
        if !rest.isEmpty { return rest }
        return primaryArgument?.defaultValue ?? ""
    }

    /// The first required argument left unsatisfied — drives the UI's "disable
    /// Enter + show which arg is needed" state. `nil` when the command can run.
    public var firstRequiredMissing: CommandArgument? {
        guard let arg = primaryArgument, arg.isRequired else { return nil }
        return effectiveValue.isEmpty ? arg : nil
    }

    /// True when the command can run as typed (no required argument is missing).
    public var isComplete: Bool { firstRequiredMissing == nil }
}

// MARK: - Parser

public enum CommandArguments {
    /// Recognize an inline-arg command at the head of `query` against the set of
    /// arg-bearing `actions`. Returns `nil` (→ normal fuzzy search) unless the
    /// first whitespace-delimited token *exactly* equals a known verb AND the
    /// query has a rest or a trailing space.
    ///
    /// **Activation rule (the correctness center).** A bare verb with no trailing
    /// space ("ssh") stays normal search so typing the word "ssh" keeps finding
    /// the command. Arg mode begins only at "ssh " or "ssh host". Verb match is
    /// case-insensitive and exact (not a prefix) so "connect" never triggers
    /// "connect-ssh"'s verb "ssh". When two verbs would both match (a verb that is
    /// a prefix of the typed first token can't, since match is exact — but two
    /// actions could share spelling), the longest verb wins, so "agent-prompt"
    /// is never shadowed by a shorter "agent".
    public static func parse(_ query: String, against actions: [CommandAction]) -> ParsedInlineCommand? {
        // Trailing space is significant (it's what flips a bare verb into arg
        // mode), so detect it before trimming. Leading space is not.
        let leadingTrimmed = String(query.drop(while: { $0 == " " }))
        guard !leadingTrimmed.isEmpty else { return nil }

        let hasTrailingSpace = leadingTrimmed.last == " "
        let collapsed = leadingTrimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }

        // First token = up to the first space; rest = everything after it.
        let firstToken: String
        let afterToken: String
        if let spaceIndex = collapsed.firstIndex(of: " ") {
            firstToken = String(collapsed[collapsed.startIndex..<spaceIndex])
            afterToken = String(collapsed[collapsed.index(after: spaceIndex)...])
        } else {
            firstToken = collapsed
            afterToken = ""
        }

        // Arg mode requires either a rest or a trailing space after a bare verb.
        guard !afterToken.isEmpty || hasTrailingSpace else { return nil }

        let lowerToken = firstToken.lowercased()
        let match = actions
            .filter { ($0.verb?.lowercased()) == lowerToken && !$0.arguments.isEmpty }
            .max { ($0.verb?.count ?? 0) < ($1.verb?.count ?? 0) }
        guard let action = match else { return nil }

        let rest = afterToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedInlineCommand(action: action, rest: rest)
    }
}
