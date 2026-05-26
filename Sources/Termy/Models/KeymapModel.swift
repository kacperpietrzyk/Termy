import Foundation
import Observation
import TermyCore

/// Keymap-binding-domain state, extracted from the `TermyStore` god-object as
/// part of the strangler-facade decomposition (M2c-3). `@Observable` +
/// `@MainActor`: the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
/// `keymapProfile` defaults to `KeymapProfile()`; the real action-derived
/// profile is written by `TermyStore.init` (see the M2c-3 init note).
@MainActor
@Observable
final class KeymapModel {
    var keymapProfile = KeymapProfile()
    var selectedKeymapActionID = "open-command-center"
    var keymapModifier = "command"
    var keymapKey = "k"

    init() {}
}
