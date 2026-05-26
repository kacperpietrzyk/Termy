import Foundation
import Observation
import TermyCore

/// Cross-cutting coordinator-domain state (active overlay panel, status line,
/// interface text scale, loaded project guidance), extracted from the
/// `TermyStore` god-object as part of the strangler-facade decomposition
/// (M2c-3). `@Observable` + `@MainActor`: the future state is views observing
/// this model directly via `@Environment(AppModel.self)`; until then
/// `TermyStore` forwards to it.
@MainActor
@Observable
final class CoordinatorModel {
    var activePanel: OverlayPanel?
    var statusMessage = "Ready"
    var interfaceTextScaleRawValue = InterfaceTextScale.regular.rawValue
    var projectGuidance = ProjectGuidance(documents: [])

    init() {}
}
