import Foundation
import Observation
import TermyCore

/// File-browser-domain state, extracted from the `TermyStore` god-object as
/// part of the strangler-facade decomposition (M2c-2). `@Observable` +
/// `@MainActor`: the future state is views observing this model directly via
/// `@Environment(AppModel.self)`; until then `TermyStore` forwards to it.
@MainActor
@Observable
final class FilesModel {
    var fileItems: [LocalFileItem] = []
    var fileTreeItems: [LocalFileTreeItem] = []
    /// Relative paths of directories the user has expanded in the Files tree.
    /// Finder-lite: everything is collapsed by default; children are listed
    /// lazily only for directories in this set (see LocalFileService.visibleTree).
    var expandedFileDirectories: Set<String> = []
    var sftpRemoteItems: [SFTPRemoteItem] = []
    var sftpRemotePath = "."
    var selectedSFTPRemotePath: String?
    var selectedFilePath: String?
    var fileSearchQuery = ""
    var fileDraftName = ""
    var fileRenameName = ""
    var fileMoveDestination = ""

    init() {}
}
