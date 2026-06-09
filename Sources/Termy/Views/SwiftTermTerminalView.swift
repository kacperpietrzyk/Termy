#if canImport(AppKit)
import SwiftUI
import SwiftTerm
import TermyCore
import os

/// M3-2: SwiftTerm is the sole terminal. LocalProcessTerminalView owns the
/// pty/shell AND input/render; the M3-1 lossless byte-tap forwards a verbatim
/// copy of PTY output to SwiftTermStreamBridge -> ShellIntegrationParser so the
/// PRD §6.1 command-block layer survives. SwiftTerm's built-in encoding (Fork 2).
struct SwiftTermTerminalView: NSViewRepresentable {
    private static let log = Logger(subsystem: "Termy", category: "SwiftTermTerminalView")

    let descriptor: TerminalLaunchDescriptor
    let sessionID: UUID
    let font: NSFont
    let foreground: NSColor
    let background: NSColor
    let onEvents: ([ShellIntegrationEvent]) -> Void
    let onTitle: (String) -> Void
    let onDirectory: (String) -> Void
    let onExit: (Int32?) -> Void
    let onScreenText: (@escaping () -> String) -> Void
    let storeRef: TermyStore
    let onCaretOrigin: (@escaping () -> (x: CGFloat, y: CGFloat)?) -> Void
    let onBlockCaptureArm: (@escaping () -> Void) -> Void
    let onBlockCaptureSnapshot: (@escaping () -> String?) -> Void
    let onSendInput: (@escaping (String) -> Void) -> Void
    let initialTranscriptReplay: String?
    let onInitialTranscriptReplayed: () -> Void

    func makeNSView(context: Context) -> TappedLocalProcessTerminalView {
        let key = surfaceKey()
        let controller = context.coordinator

        // REUSE: the model already owns a live view for this session+generation.
        // Re-bind the cheap per-mount closures against it, but NEVER startProcess
        // again (that would double-spawn) and never replay the transcript.
        if let view = controller.view {
            wireViewBindings(view, controller: controller, context: context)
            controller.didFocus = false   // re-acquire first-responder on the new host
            return view
        }

        // CREATE: first mount for this session+generation.
        let view = TappedLocalProcessTerminalView(
            frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        // Create-only: the stream bridge holds a STATEFUL ShellIntegrationParser.
        // Recreating it on reuse would reset command-block parsing mid-session.
        view.streamBridge = SwiftTermStreamBridge(onEvents: onEvents)
        wireViewBindings(view, controller: controller, context: context)
        if let initialTranscriptReplay, !initialTranscriptReplay.isEmpty {
            view.feed(text: initialTranscriptReplay)
            onInitialTranscriptReplayed()
        }
        do {
            let launch = try ShellIntegrationLaunch(descriptor: descriptor, sessionID: sessionID)
            controller.launch = launch
            view.startProcess(
                executable: launch.shellPath,
                args: launch.arguments,
                environment: launch.environmentArray,
                currentDirectory: launch.workingDirectory ?? NSHomeDirectory()
            )
        } catch {
            Self.log.error(
                "ShellIntegrationLaunch failed for session \(self.sessionID, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            // No child was ever started. Surface a synthetic exit so the
            // session doesn't wedge forever waiting on output that can never
            // arrive (the store's onExit closure marks it terminated). Deferred
            // to the next runloop tick: calling it inline would publish store
            // changes during `makeNSView` (a SwiftUI view-update cycle).
            DispatchQueue.main.async { [onExit] in onExit(nil) }
        }
        controller.view = view
        storeRef.terminalSurfacePool.store(controller, forKey: key)
        return view
    }

    /// All the per-mount bindings (providers, handlers, font/colors, delegate,
    /// inline monitor). Idempotent: safe to re-run when reusing a cached view.
    /// Excludes `startProcess`, transcript replay, AND the stream bridge — those
    /// are create-only (the bridge owns a stateful parser that must not reset).
    private func wireViewBindings(_ view: TappedLocalProcessTerminalView,
                                  controller: TerminalSurfaceController,
                                  context: Context) {
        onScreenText { [weak view] in
            guard let view else { return "" }
            let t = view.getTerminal()
            return (0..<t.rows)
                .compactMap { t.getLine(row: $0)?.translateToString(trimRight: true) }
                .joined(separator: "\n")
        }
        onCaretOrigin { [weak view] in
            guard let view else { return nil }
            // Ghost starts the cell after the cursor (f.maxX). TerminalView is
            // NOT isFlipped (y=0 at bottom), so convert the caret's bottom-left
            // origin to SwiftUI top-left space. `caretFrame` is `.zero` only
            // pre-init (caretView nil) — guard returns nil there.
            let f = view.caretFrame
            guard f != .zero else { return nil }
            return (x: f.maxX, y: view.frame.height - f.maxY)
        }
        onBlockCaptureArm { [weak view] in view?.armBlockCapture() }
        onBlockCaptureSnapshot { [weak view] in view?.captureBlockSnapshotANSI() }
        onSendInput { [weak view] text in
            view?.send(txt: text)
        }
        view.inlineAcceptHandler = { [weak storeRef] in
            storeRef?.terminalCombinedGhost(for: sessionID)
        }
        view.inlineAcceptComponentHandler = { [weak storeRef] in
            storeRef?.terminalCombinedGhostNextComponent(for: sessionID)
        }
        view.inlineAcceptApply = { [weak storeRef] suffix in
            storeRef?.acceptInlineSuffix(suffix, for: sessionID)
        }
        view.menuOpenSnapshot = { [weak storeRef] in
            storeRef?.terminalMenuSnapshot(for: sessionID) != nil
        }
        view.menuHasSelectionSnapshot = { [weak storeRef] in
            (storeRef?.terminalMenuSnapshot(for: sessionID)?.selection ?? -1) >= 0
        }
        view.menuOpenHandler = { [weak storeRef] in
            storeRef?.terminalMenuOpen(for: sessionID) ?? false
        }
        view.menuMoveHandler = { [weak storeRef] delta in
            storeRef?.terminalMenuMoveSelection(for: sessionID, by: delta)
        }
        view.menuAcceptHandler = { [weak storeRef] in
            storeRef?.terminalMenuAcceptedSuffix(for: sessionID)
        }
        view.menuCancelHandler = { [weak storeRef] in
            storeRef?.terminalMenuClose(for: sessionID)
        }
        view.installInlineAcceptMonitor()   // nil-guarded internally
        view.notifyUpdateChanges = true
        view.onRenderChanged = { [weak storeRef] in
            storeRef?.terminalRenderChanged(for: sessionID)
        }
        // v3 block terminal: keep the alt-screen flag in sync so the block view
        // hands the whole area to a TUI (vim/htop) and back. Driven from
        // `dataReceived` (synchronous with the PTY bytes) rather than the render
        // callback, so the alt-exit output suppression arms before the next
        // slice is ingested (residue fix — see AltScreenTapDecision).
        view.onAltScreenChanged = { [weak storeRef] active in
            storeRef?.setTerminalAltScreen(active, for: sessionID)
        }
        // v3 block terminal: render-only clear of THIS view's emulator (NOT the PTY).
        storeRef.registerTerminalLocalClear({ [weak view] in
            view?.feed(text: "\u{1b}[3J\u{1b}[2J\u{1b}[H")
        }, for: sessionID)
        view.processDelegate = controller
        view.font = font
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        controller.callbacks = (onTitle, onDirectory, onExit)
    }

    func updateNSView(_ nsView: TappedLocalProcessTerminalView, context: Context) {
        // Acquire keyboard focus once a window exists (acceptsFirstResponder is
        // hardcoded true; becomeFirstResponder needs a window —
        // MacTerminalView.swift:719,739). Without this the user must click
        // before typing.
        if !context.coordinator.didFocus, let window = nsView.window {
            window.makeFirstResponder(nsView)
            context.coordinator.didFocus = true
        }
        if nsView.font != font { nsView.font = font }
    }

    /// The pool key for this session's current launch generation — the SAME
    /// string SwiftUI uses for `.id(...)` on the surface. `makeCoordinator` and
    /// `makeNSView` must agree on it, so derive it in one place.
    private func surfaceKey() -> String {
        "\(sessionID.uuidString)#\(storeRef.terminalLaunchGeneration(for: sessionID))"
    }

    func makeCoordinator() -> TerminalSurfaceController {
        let key = surfaceKey()
        let pooled = storeRef.terminalSurfacePool.surface(forKey: key)
        return pooled ?? TerminalSurfaceController()
    }

    static func dismantleNSView(_ nsView: TappedLocalProcessTerminalView,
                                coordinator: TerminalSurfaceController) {
        // Slice 5: detach only. The PTY is owned by `TerminalSurfacePool` and
        // outlives this mount; it is terminated explicitly (close / restart /
        // self-exit / quit), NOT here. We still drop the view-scoped inline-accept
        // key monitor (re-installed by `wireViewBindings` on the next mount).
        nsView.removeInlineAcceptMonitor()
    }
}

/// F-1: pure accept-decision for Tab/Right-Arrow, extracted from the NSView
/// so it is unit-testable without AppKit. Returns the suffix to inject or nil.
enum InlineAcceptDecision {
    static func suffix(isAltScreen: Bool, pending: String?) -> String? {
        guard isAltScreen == false, let p = pending, !p.isEmpty else { return nil }
        return p
    }
}

/// F-3: pure key-dispatch decision for the inline completion menu.
/// Inputs are AppKit value types (`UInt16` virtual keycode + `NSEvent.ModifierFlags`)
/// plus two booleans the store provides. No `NSEvent` here — the monitor maps
/// the live event to these inputs so the decision is unit-testable without
/// the responder chain.
///
/// Key codes are US ANSI virtual keycodes: Tab=48, Right=124, Up=126, Down=125,
/// Return=36, Esc=53. Virtual keycodes are physical positions, not character
/// values, so they are layout-independent (the same logic F-1's Tab/→ accept
/// relies on).
enum MenuKeyDecision: Equatable {
    case open                       // bare Tab while menu closed
    case move(by: Int)              // ↑ → -1, ↓ → +1, Shift-Tab → -1
    case accept                     // ⏎ / Tab / → while menu open
    case cancel                     // Esc while menu open
    case passthrough                // everything else — let the event reach zsh

    static func decide(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        menuOpen: Bool,
        hasSelection: Bool,
        isAltScreen: Bool
    ) -> MenuKeyDecision {
        // TUI apps never host the menu (no OSC 133 T fires in alt-screen) —
        // belt-and-braces guard.
        if isAltScreen { return .passthrough }

        let mods = modifiers.intersection(.deviceIndependentFlagsMask)
        let bare = mods.isDisjoint(with: [.command, .control, .option, .shift])
        let shiftOnly = mods == [.shift]

        if menuOpen {
            // Modal subset while menu is open.
            //
            // B4 (Warp parity): being OPEN no longer means "accept on Return".
            // The menu is "be aggressive in offering, never in hijacking": with
            // NOTHING selected (the default), Return submits the typed line
            // verbatim and → accepts the inline ghost — neither touches the
            // menu. Only after the user explicitly enters the list (↓ / Tab)
            // do Return / → accept the highlighted candidate.
            if bare {
                switch keyCode {
                case 126: return .move(by: -1)   // Up — enter list / move up
                case 125: return .move(by: 1)    // Down — enter list / move down
                case 48: return .move(by: 1)     // Tab — ENTER/advance list (never accept)
                case 124, 36:                     // Right / Return
                    // Accept ONLY when an explicit selection exists; otherwise
                    // pass through (Return → verbatim submit, → → F-1 ghost).
                    return hasSelection ? .accept : .passthrough
                case 53: return .cancel           // Esc
                default: return .passthrough     // live-narrow path
                }
            }
            if shiftOnly, keyCode == 48 {
                return .move(by: -1)             // Shift-Tab reverse
            }
            return .passthrough
        }

        // Menu closed: only bare Tab is an F-3 trigger.
        if bare, keyCode == 48 {
            return .open
        }
        return .passthrough
    }
}

/// Task-3 pinned mechanism (mechanism 1, subclass-override):
/// `LocalProcessTerminalView` is `open` and its doc-comment explicitly invites
/// subclassing to override its delegate methods. `dataReceived(slice:)` is the
/// single method every received PTY byte flows through (the view is its own
/// `LocalProcessDelegate`; LocalProcess.swift:157/280 are the only call sites).
///
/// Override contract: call `super.dataReceived(slice:)` FIRST so SwiftTerm's
/// unchanged render path (`feed(byteArray:)` -> AppleTerminalView.feed) runs
/// exactly as before, THEN forward the SAME immutable `ArraySlice<UInt8>` value
/// to the tap. `super` only reads the slice and never mutates it, so the tap
/// observes 100% of the verbatim byte stream losslessly.
///
/// Queue affinity (Task-3 carry-forward): LocalProcess invokes
/// `dataReceived(slice:)` on its dispatch queue (default DispatchQueue.main).
/// The tap call is made inline in the same call frame as `super` — no
/// DispatchQueue hop — so the bridge runs on exactly the queue super was
/// invoked on, preserving ordering with the render path.
final class TappedLocalProcessTerminalView: LocalProcessTerminalView {
    var streamBridge: SwiftTermStreamBridge?

    /// F-1: returns the pending inline-ghost-text suffix (store-computed) or
    /// nil. Set in `makeNSView`; weak-captures the store.
    var inlineAcceptHandler: (() -> String?)?

    /// F-2: returns the *next-component* suffix to inject when the user hits
    /// Ctrl-→, or nil. Wired from TermyStore in `makeNSView` below.
    var inlineAcceptComponentHandler: (() -> String?)?

    /// #4: apply an accepted inline suffix via the store (instant client-side
    /// insert + prefix-echo suppression) instead of a bare `send(txt:)`. Falls
    /// back to `send` when nil. Wired from TermyStore in `makeNSView`.
    var inlineAcceptApply: ((String) -> Void)?

    /// F-3: synchronous "is menu currently open for my session?" lookup. The
    /// monitor needs this BEFORE deciding whether to swallow keys. Wired from
    /// `makeNSView` to `store.terminalMenuSnapshot(for: sessionID) != nil`.
    var menuOpenSnapshot: (() -> Bool)?

    /// B4: synchronous "does the open menu have an EXPLICIT selection?" lookup
    /// (selection >= 0). Wired to `store.terminalMenuSnapshot(...).selection >= 0`.
    /// `decide` needs it to distinguish "nothing selected" (Return → verbatim
    /// submit) from "row N selected" (Return → accept).
    var menuHasSelectionSnapshot: (() -> Bool)?

    /// F-3: returns `true` if the menu opened (the engine had ≥1 candidate).
    /// Monitor swallows the event when `true`; passes through (zsh native Tab)
    /// when `false`.
    var menuOpenHandler: (() -> Bool)?

    /// F-3: navigate menu selection by ±1.
    var menuMoveHandler: ((Int) -> Void)?

    /// F-3: returns the bytes to inject on accept, or nil when no usable
    /// candidate. Monitor calls `send(txt:)` (when non-nil and non-empty)
    /// then closes the menu via `menuCancelHandler` (the close path is the
    /// same — accept = inject + close).
    var menuAcceptHandler: (() -> String?)?

    /// F-3: close the menu (Esc, accept-cleanup, window-resign).
    var menuCancelHandler: (() -> Void)?

    private var inlineKeyMonitor: Any?
    private var windowResignObserver: NSObjectProtocol?

    /// F-1: invoked after SwiftTerm renders a visual change (when
    /// `notifyUpdateChanges == true`). Drives the ghost-overlay refresh so
    /// it re-reads `caretFrame` only AFTER SwiftTerm updated it (no
    /// render-cycle staleness).
    var onRenderChanged: (() -> Void)?

    override func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        super.rangeChanged(source: source, startY: startY, endY: endY)
        onRenderChanged?()
    }

    /// Verified verbatim against SwiftTerm 1.13.0:
    ///   MacLocalTerminalView.swift:183
    ///     open func dataReceived(slice: ArraySlice<UInt8>) { feed (byteArray: slice) }
    /// Synchronous alt-screen state notification, wired to
    /// `store.setTerminalAltScreen`. Pushed from `dataReceived` (NOT the render
    /// callback) so the store's alt-exit output-suppression window opens in the
    /// same call that gates ingest — see `AltScreenTapDecision`.
    var onAltScreenChanged: ((Bool) -> Void)?

    /// Slice-1: accumulated scroll-invariant dirty range of the in-flight
    /// command's output, merged per slice. We sample SwiftTerm's update range
    /// AFTER `super.dataReceived` emulated this slice but never call
    /// `clearUpdateRange()` — the view's own draw cycle clears it; we only union
    /// each slice's contribution into our own range, so rendering is untouched.
    private var pendingBlockRange: (start: Int, end: Int)?

    /// Floor row set at arm time: scroll-invariant rows strictly BEFORE this
    /// value belong to pre-arm output and must be excluded from the snapshot.
    /// In the real app the draw cycle calls `clearUpdateRange()` between the
    /// pre-arm and post-arm slices, so the floor is never needed; in headless
    /// tests there is no draw cycle and the range keeps growing, so the floor is
    /// the only guard against pre-arm leakage.
    private var blockCaptureFloor: Int = 0

    /// Reset the accumulator at command start (OSC 133 C).
    /// Records a floor from the cursor's current scroll-invariant position so
    /// pre-arm rows are excluded even in headless tests where no draw cycle
    /// runs `clearUpdateRange()`. The floor is `yDisp + cursor.y` — the same
    /// coordinate scheme `updateRange` uses (`effectiveY = buffer._yDisp + y`).
    func armBlockCapture() {
        pendingBlockRange = nil
        let term = getTerminal()
        blockCaptureFloor = term.getTopVisibleRow() + term.getCursorLocation().y
    }

    /// Read the accumulated command region from the authoritative buffer as an
    /// SGR-colored string (OSC 133 D). nil if nothing was captured.
    func captureBlockSnapshotANSI() -> String? {
        guard let r = pendingBlockRange else { return nil }
        return BufferSnapshot.ansiString(getTerminal(), scrollInvariantRows: r.start...r.end)
    }

    private func accumulateBlockRange() {
        guard let r = getTerminal().getScrollInvariantUpdateRange() else { return }
        // Clamp to the floor recorded at arm time: exclude pre-arm rows.
        let clampedStart = max(r.startY, blockCaptureFloor)
        guard clampedStart <= r.endY else { return }
        if let cur = pendingBlockRange {
            pendingBlockRange = (min(cur.start, clampedStart), max(cur.end, r.endY))
        } else {
            pendingBlockRange = (clampedStart, r.endY)
        }
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        // B2/residue: never ingest ALTERNATE-SCREEN output into the Warp-style
        // block transcript. A full-screen TUI (vim/htop/`claude`) repaints the
        // same cells many times; capturing those frames produces garbled
        // overlapping lines (`787878%`) after the program exits. Sample the
        // terminal's own alt-screen flag BEFORE and AFTER `super`, then derive
        // ingest + alt-change from the SAME sample so the alt-exit suppression
        // arms synchronously with the bytes (the render callback armed it too
        // late — PRODUCT_DIAGNOSIS §9).
        let wasAlternate = getTerminal().isCurrentBufferAlternate
        super.dataReceived(slice: slice)   // SwiftTerm renders, unchanged
        let nowAlternate = getTerminal().isCurrentBufferAlternate
        let decision = AltScreenTapDecision.decide(wasAlternate: wasAlternate, nowAlternate: nowAlternate)
        // LOAD-BEARING — DO NOT DELETE as "retired re-parse scaffolding" (spec §9 predates
        // Slice 1 and is stale here). `decision.ingest` now gates the Slice-1 SNAPSHOT
        // accumulation — the rebuild's CLEAN SOURCE. Removing this gate lets a full-screen
        // TUI's (`claude`/`vim`/`htop`) alternate-buffer repaint frames into the snapshot,
        // reviving the `787878%` / mangled-picker residue (screenshot #6) the rebuild killed.
        if decision.ingest { accumulateBlockRange() }  // only non-alt output feeds the snapshot
        if decision.altScreenChanged {
            onAltScreenChanged?(nowAlternate)   // arm suppression BEFORE any later ingest (drives 3a full-reveal)
        }
        // Also gated to non-alt: keeps the RETAINED `session.lines` re-parse (still used by
        // stream/SSH render, the running-block fallback, and 3c-2 restore structure) from
        // being flooded by thousands of TUI repaint frames. Not scaffolding for a deleted
        // path — upkeep for a deliberately-kept surface.
        if decision.ingest {
            streamBridge?.ingest(slice)    // observe-only, non-alt output only
        }
    }

    /// F-1: Tab/Right-Arrow accept the inline suggestion. SwiftTerm's
    /// `doCommand(by:)`/`keyDown` are `public` (not `open`) so they cannot be
    /// overridden cross-module (Execution Finding 3). Instead a local
    /// key-down monitor intercepts a *bare* Tab (keyCode 48) / Right-Arrow
    /// (keyCode 124) before the responder chain, only while THIS view is the
    /// key window's first responder, and injects the suffix via `send(txt:)`
    /// (SwiftTerm 1.13.0 AppleTerminalView.swift:1975). Returning `nil`
    /// swallows the event so zsh's native Tab-completion / cursor move does
    /// not also fire. `isCurrentBufferAlternate` is Terminal.swift:342.
    func installInlineAcceptMonitor() {
        guard inlineKeyMonitor == nil else { return }
        inlineKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = self.window, window.isKeyWindow,
                  window.firstResponder === self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let bareKey = modifiers.isDisjoint(with: [.command, .control, .option, .shift])
            let ctrlOnly = modifiers == [.control]

            // F-2: Ctrl-→ component accept (right-arrow only) — first priority.
            if ctrlOnly, event.keyCode == 124 {
                if let suffix = InlineAcceptDecision.suffix(
                    isAltScreen: self.getTerminal().isCurrentBufferAlternate,
                    pending: self.inlineAcceptComponentHandler?()) {
                    // #4: instant client-side insert (+ echo suppression) via the
                    // store, falling back to a bare send when unwired.
                    if let apply = self.inlineAcceptApply { apply(suffix) } else { self.send(txt: suffix) }
                    return nil
                }
                // fall through to F-3 logic below — Ctrl-→ does not collide
                // with F-3 (menu accepts on bare arrows / Tab / Return).
            }

            // F-3: route through the pure MenuKeyDecision. menuOpenSnapshot is
            // wired in makeNSView to `store.terminalMenuSnapshot(for: id) != nil`.
            let isAltScreen = self.getTerminal().isCurrentBufferAlternate
            let decision = MenuKeyDecision.decide(
                keyCode: event.keyCode,
                modifiers: modifiers,
                menuOpen: self.menuOpenSnapshot?() ?? false,
                hasSelection: self.menuHasSelectionSnapshot?() ?? false,
                isAltScreen: isAltScreen
            )
            switch decision {
            case .open:
                if self.menuOpenHandler?() == true {
                    return nil   // swallow Tab — menu opened
                }
                // fall through to F-1 logic — Tab might still accept ghost text
                // PRE-F-3 behaviour, but per spec F-3 supersedes Tab-accepts-ghost.
                // We intentionally drop the F-1 Tab-accept here so Tab on a buffer
                // with ghost-text-but-no-engine-candidates passes through to zsh.
                break

            case .move(let delta):
                self.menuMoveHandler?(delta)
                return nil

            case .accept:
                // B4: `.accept` only reaches here with an EXPLICIT selection
                // (decide gates it on hasSelection). Inject the diff-suffix and
                // swallow the key so the completion doesn't also submit. When
                // the suffix is empty/nil (user selected the exact text already
                // typed), close the menu but FORWARD the event so Return still
                // runs the command verbatim — never silently eat the newline.
                if let suffix = self.menuAcceptHandler?(), !suffix.isEmpty {
                    self.send(txt: suffix)
                    self.menuCancelHandler?()
                    return nil
                }
                self.menuCancelHandler?()
                return event

            case .cancel:
                self.menuCancelHandler?()
                return nil

            case .passthrough:
                break  // continue to F-1 logic below
            }

            // F-1: bare Right-Arrow → full ghost-text accept.
            // Bare Tab no longer accepts ghost-text (F-3 §2: Tab semantics
            // change). Only → keeps the F-1 full accept.
            guard bareKey, event.keyCode == 124 else { return event }
            guard let suffix = InlineAcceptDecision.suffix(
                isAltScreen: isAltScreen,
                pending: self.inlineAcceptHandler?()) else { return event }
            // #4: instant client-side insert (+ echo suppression) via the store.
            if let apply = self.inlineAcceptApply { apply(suffix) } else { self.send(txt: suffix) }
            return nil
        }

        // F-3: close the menu when the window loses key. Installed even though
        // the monitor itself is window-gated — the user can Cmd-Tab away with
        // menu open and we want it gone on return.
        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuCancelHandler?()
        }
    }

    func removeInlineAcceptMonitor() {
        if let inlineKeyMonitor { NSEvent.removeMonitor(inlineKeyMonitor) }
        inlineKeyMonitor = nil
        if let windowResignObserver {
            NotificationCenter.default.removeObserver(windowResignObserver)
        }
        windowResignObserver = nil
    }
}
#endif
