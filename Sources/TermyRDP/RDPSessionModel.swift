// RDP session contract types — the public-API surface that survives engine deletion (Task 6).
// Types in this file are the seam between callers and the RDP transport; do not add engine internals here.
import Foundation
import TermyCore

public enum RDPSessionDescriptorError: Error, Equatable {
    case requiresRDPProfile
    case missingUser
}

public struct RDPResolution: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public enum RDPRedirection: Equatable, Sendable {
    case clipboard
    case folderDrive(String)
    case audioOutput
}

public enum RDPDisconnectReason: Equatable, Sendable {
    case userInitiated
    case networkFailure
    case transportError(Int32)
}

public enum RDPFramePixelFormat: Equatable, Sendable {
    case bgra8
}

public struct RDPRemoteDesktopFrame: Equatable, Sendable {
    public let sequence: Int
    public let width: Int
    public let height: Int
    public let scale: Double
    public let pixelFormat: RDPFramePixelFormat
    public let data: Data

    public init(
        sequence: Int,
        width: Int,
        height: Int,
        scale: Double,
        pixelFormat: RDPFramePixelFormat,
        data: Data
    ) {
        self.sequence = sequence
        self.width = max(0, width)
        self.height = max(0, height)
        self.scale = max(1, scale)
        self.pixelFormat = pixelFormat
        self.data = data
    }

    public var expectedByteCount: Int {
        switch pixelFormat {
        case .bgra8:
            return width * height * 4
        }
    }

    public var hasValidPayload: Bool {
        width > 0 && height > 0 && data.count == expectedByteCount
    }
}

// Task 6 deletion delta (per FreeRDPSession.swift header):
//   • RDPBitmapUpdateRectangle / RDPBitmapUpdate structs DELETED — the
//     FreeRDP gdi delivers whole-surface BGRA frames only, never partial
//     rectangles, so the rectangle-compositing path is dead.
//   • RDPFrameBuffer.apply(_ update: RDPBitmapUpdate) DELETED for the
//     same reason. RDPFrameBuffer + apply(_ frame:) are RETAINED as the
//     engine-agnostic sequence-dedup gate.
//   • RDPTransportEvent.bitmapUpdate case DELETED + every consumer site.

public struct RDPFrameBuffer: Equatable, Sendable {
    public private(set) var currentFrame: RDPRemoteDesktopFrame?
    public private(set) var lastSequence: Int?

    public init(currentFrame: RDPRemoteDesktopFrame? = nil, lastSequence: Int? = nil) {
        self.currentFrame = currentFrame
        self.lastSequence = lastSequence
    }

    public mutating func apply(_ frame: RDPRemoteDesktopFrame) -> RDPRemoteDesktopFrame? {
        guard frame.hasValidPayload, frame.sequence != lastSequence else { return nil }
        currentFrame = frame
        lastSequence = frame.sequence
        return frame
    }
}

// DORMANT post-Task-6 cutover: the FreeRDP shim never emits the
// `.clipboardExchange` / `.driveHandshake` / `.audioHandshake` events.
// FreeRDP owns the virtual-channel handshake internally (cliprdr/rdpdr/
// rdpsnd format negotiation, device-announce, audio-format-list, etc.).
// The cases + their no-op router arms below are retained as the symmetric
// reservation surface for spec §6.8 — a future revision adding Swift-side
// custom virtual-channel handling (or surfacing those events through the
// shim for inspection/policy) can wire them without re-introducing the
// enum case + breaking the existing test contract.
public enum RDPTransportEvent: Equatable, Sendable {
    case desktopFrame(RDPRemoteDesktopFrame)
    case remoteClipboard(text: String, sequence: Int)
    case clipboardExchange(RDPClipboardVirtualChannelMessage)
    case driveHandshake(RDPDriveVirtualChannelMessage)
    case driveOperation(RDPDriveOperation, payload: Data)
    case audioHandshake(RDPAudioVirtualChannelMessage)
    case audioOutput(RDPAudioOutputFrame)
    case disconnected(RDPDisconnectReason)
}

public struct RDPTransportEventResult: Equatable, Sendable {
    public let desktopFrame: RDPRemoteDesktopFrame?
    public let clipboardMessage: RDPClipboardMessage?
    public let driveResponse: RDPDriveLocalFileResponse?
    public let audioFrame: RDPAudioOutputFrame?
    public let reconnectPlan: RDPReconnectPlan?

    public init(
        desktopFrame: RDPRemoteDesktopFrame? = nil,
        clipboardMessage: RDPClipboardMessage? = nil,
        driveResponse: RDPDriveLocalFileResponse? = nil,
        audioFrame: RDPAudioOutputFrame? = nil,
        reconnectPlan: RDPReconnectPlan? = nil
    ) {
        self.desktopFrame = desktopFrame
        self.clipboardMessage = clipboardMessage
        self.driveResponse = driveResponse
        self.audioFrame = audioFrame
        self.reconnectPlan = reconnectPlan
    }
}

public struct RDPTransportEventRouter {
    public private(set) var lifecycle: RDPSessionLifecycle
    public private(set) var frameBuffer: RDPFrameBuffer
    public private(set) var clipboardSynchronizer: RDPClipboardSynchronizer
    public private(set) var audioSynchronizer: RDPAudioOutputSynchronizer

    private let driveBridge: RDPDriveBridge
    private let driveExecutor: RDPDriveLocalFileExecutor

    public init(
        descriptor: RDPSessionDescriptor,
        lifecycle: RDPSessionLifecycle? = nil,
        frameBuffer: RDPFrameBuffer = RDPFrameBuffer(),
        driveExecutor: RDPDriveLocalFileExecutor = RDPDriveLocalFileExecutor()
    ) {
        self.lifecycle = lifecycle ?? RDPSessionLifecycle(descriptor: descriptor)
        self.frameBuffer = frameBuffer
        self.clipboardSynchronizer = RDPClipboardSynchronizer(bridge: RDPClipboardBridge(descriptor: descriptor))
        self.audioSynchronizer = RDPAudioOutputSynchronizer(bridge: RDPAudioOutputBridge(descriptor: descriptor))
        self.driveBridge = RDPDriveBridge(descriptor: descriptor)
        self.driveExecutor = driveExecutor
    }

    public mutating func handle(
        _ event: RDPTransportEvent,
        writeClipboard: (String) -> Void,
        playAudio: (RDPAudioOutputFrame) -> Void
    ) throws -> RDPTransportEventResult {
        switch event {
        case .desktopFrame(let frame):
            return RDPTransportEventResult(desktopFrame: frameBuffer.apply(frame))
        case .remoteClipboard(let text, let sequence):
            return RDPTransportEventResult(
                clipboardMessage: clipboardSynchronizer.applyRemoteClipboard(
                    text: text,
                    sequence: sequence,
                    writeLocalClipboard: writeClipboard
                )
            )
        case .clipboardExchange:
            return RDPTransportEventResult() // dormant; see enum comment
        case .driveHandshake:
            return RDPTransportEventResult() // dormant; see enum comment
        case .driveOperation(let operation, let payload):
            guard let request = driveBridge.localFileRequest(for: operation) else {
                return RDPTransportEventResult()
            }
            return RDPTransportEventResult(driveResponse: try driveExecutor.execute(request, payload: payload))
        case .audioHandshake:
            return RDPTransportEventResult() // dormant; see enum comment
        case .audioOutput(let frame):
            return RDPTransportEventResult(
                audioFrame: audioSynchronizer.receiveRemoteOutputFrame(frame, play: playAudio)
            )
        case .disconnected(let reason):
            return RDPTransportEventResult(reconnectPlan: lifecycle.handleDisconnect(reason: reason))
        }
    }

    public mutating func markConnected() {
        lifecycle.markConnected()
    }

    public mutating func captureLocalClipboard(snapshot: RDPClipboardSnapshot?) -> RDPClipboardMessage? {
        clipboardSynchronizer.pollLocalClipboard(snapshot: snapshot)
    }
}

public enum RDPClipboardDirection: Equatable, Sendable {
    case localToRemote
    case remoteToLocal
}

public struct RDPClipboardMessage: Equatable, Sendable {
    public let direction: RDPClipboardDirection
    public let text: String
    public let sequence: Int

    public init(direction: RDPClipboardDirection, text: String, sequence: Int) {
        self.direction = direction
        self.text = text
        self.sequence = sequence
    }
}

public enum RDPClipboardVirtualChannelMessageError: Error, Equatable {
    case invalidMessage
    case unsupportedMessageType(UInt16)
    case unsupportedMessageFlags(UInt16)
    case unsupportedClipboardFormat(UInt32)
}

public enum RDPClipboardFormat: UInt32, Equatable, Sendable {
    case unicodeText = 13
}

public enum RDPClipboardVirtualChannelMessage: Equatable, Sendable {
    case formatList([RDPClipboardFormat])
    case formatListResponse(isSuccessful: Bool)
    case formatDataRequest(RDPClipboardFormat)
    case formatDataResponse(text: String)

    public var encoded: Data {
        switch self {
        case .formatList(let formats):
            return Self.message(type: 0x0002, flags: 0x0000) { payload in
                for format in formats {
                    payload.appendUInt32LE(format.rawValue)
                    payload.append(Data(repeating: 0, count: 32))
                }
            }
        case .formatListResponse(let isSuccessful):
            return Self.message(type: 0x0003, flags: isSuccessful ? 0x0001 : 0x0002) { _ in }
        case .formatDataRequest(let format):
            return Self.message(type: 0x0004, flags: 0x0000) { payload in
                payload.appendUInt32LE(format.rawValue)
            }
        case .formatDataResponse(let text):
            return Self.message(type: 0x0005, flags: 0x0001) { payload in
                payload.appendWindowsUTF16Terminated(text)
            }
        }
    }

    public static func parse(_ data: Data) throws -> RDPClipboardVirtualChannelMessage {
        guard data.count >= 8 else {
            throw RDPClipboardVirtualChannelMessageError.invalidMessage
        }
        let type = data.uint16LE(at: 0)
        let flags = data.uint16LE(at: 2)
        let payloadLength = Int(data.uint32LE(at: 4))
        guard payloadLength >= 0, data.count == 8 + payloadLength else {
            throw RDPClipboardVirtualChannelMessageError.invalidMessage
        }

        let payload = Data(data[8..<data.count])
        switch type {
        case 0x0002:
            guard flags == 0x0000 else {
                throw RDPClipboardVirtualChannelMessageError.unsupportedMessageFlags(flags)
            }
            guard payload.count % 36 == 0 else {
                throw RDPClipboardVirtualChannelMessageError.invalidMessage
            }
            let formats = stride(from: 0, to: payload.count, by: 36).map { offset in
                payload.uint32LE(at: offset)
            }.compactMap(RDPClipboardFormat.init(rawValue:))
            return .formatList(formats)
        case 0x0003:
            guard payload.isEmpty else {
                throw RDPClipboardVirtualChannelMessageError.invalidMessage
            }
            switch flags {
            case 0x0001:
                return .formatListResponse(isSuccessful: true)
            case 0x0002:
                return .formatListResponse(isSuccessful: false)
            default:
                throw RDPClipboardVirtualChannelMessageError.unsupportedMessageFlags(flags)
            }
        case 0x0004:
            guard flags == 0x0000 else {
                throw RDPClipboardVirtualChannelMessageError.unsupportedMessageFlags(flags)
            }
            guard payload.count == 4 else {
                throw RDPClipboardVirtualChannelMessageError.invalidMessage
            }
            let formatID = payload.uint32LE(at: 0)
            guard let format = RDPClipboardFormat(rawValue: formatID) else {
                throw RDPClipboardVirtualChannelMessageError.unsupportedClipboardFormat(formatID)
            }
            return .formatDataRequest(format)
        case 0x0005:
            guard flags == 0x0001 else {
                throw RDPClipboardVirtualChannelMessageError.unsupportedMessageFlags(flags)
            }
            return .formatDataResponse(text: Self.decodeWindowsUTF16Terminated(payload))
        default:
            throw RDPClipboardVirtualChannelMessageError.unsupportedMessageType(type)
        }
    }

    private static func message(
        type: UInt16,
        flags: UInt16,
        payloadBuilder: (inout Data) -> Void
    ) -> Data {
        var payload = Data()
        payloadBuilder(&payload)

        var data = Data()
        data.appendUInt16LE(type)
        data.appendUInt16LE(flags)
        data.appendUInt32LE(UInt32(payload.count))
        data.append(payload)
        return data
    }

    private static func decodeWindowsUTF16Terminated(_ data: Data) -> String {
        var codeUnits: [UInt16] = []
        var offset = 0
        while offset + 1 < data.count {
            let codeUnit = data.uint16LE(at: offset)
            guard codeUnit != 0 else { break }
            codeUnits.append(codeUnit)
            offset += 2
        }
        return String(decoding: codeUnits, as: UTF16.self)
    }
}

public struct RDPClipboardVirtualChannelExchange: Equatable, Sendable {
    public init() {}

    public func outboundMessages(
        for message: RDPClipboardVirtualChannelMessage,
        localClipboardText: String?
    ) -> [RDPClipboardVirtualChannelMessage] {
        switch message {
        case .formatList(let formats):
            var responses: [RDPClipboardVirtualChannelMessage] = [
                .formatListResponse(isSuccessful: true)
            ]
            if formats.contains(.unicodeText) {
                responses.append(.formatDataRequest(.unicodeText))
            }
            return responses
        case .formatDataRequest(.unicodeText):
            guard let localClipboardText else { return [] }
            return [.formatDataResponse(text: localClipboardText)]
        case .formatListResponse, .formatDataResponse:
            return []
        }
    }
}

public struct RDPClipboardBridge: Equatable, Sendable {
    public let isEnabled: Bool
    public private(set) var lastLocalChangeCount: Int?
    public private(set) var lastRemoteSequence: Int?

    public init(descriptor: RDPSessionDescriptor) {
        self.init(redirections: descriptor.redirections)
    }

    public init(redirections: [RDPRedirection]) {
        self.isEnabled = redirections.contains(.clipboard)
        self.lastLocalChangeCount = nil
        self.lastRemoteSequence = nil
    }

    public mutating func captureLocalClipboard(text: String, changeCount: Int) -> RDPClipboardMessage? {
        guard isEnabled, lastLocalChangeCount != changeCount else { return nil }
        lastLocalChangeCount = changeCount
        return RDPClipboardMessage(direction: .localToRemote, text: text, sequence: changeCount)
    }

    public mutating func receiveRemoteClipboard(text: String, sequence: Int) -> RDPClipboardMessage? {
        guard isEnabled, lastRemoteSequence != sequence else { return nil }
        lastRemoteSequence = sequence
        return RDPClipboardMessage(direction: .remoteToLocal, text: text, sequence: sequence)
    }
}

public struct RDPClipboardSnapshot: Equatable, Sendable {
    public let text: String
    public let changeCount: Int

    public init(text: String, changeCount: Int) {
        self.text = text
        self.changeCount = changeCount
    }
}

public struct RDPClipboardSynchronizer: Equatable, Sendable {
    public private(set) var bridge: RDPClipboardBridge

    public init(bridge: RDPClipboardBridge) {
        self.bridge = bridge
    }

    public mutating func pollLocalClipboard(snapshot: RDPClipboardSnapshot?) -> RDPClipboardMessage? {
        guard let snapshot else { return nil }
        return bridge.captureLocalClipboard(text: snapshot.text, changeCount: snapshot.changeCount)
    }

    public mutating func applyRemoteClipboard(
        text: String,
        sequence: Int,
        writeLocalClipboard: (String) -> Void
    ) -> RDPClipboardMessage? {
        guard let message = bridge.receiveRemoteClipboard(text: text, sequence: sequence) else { return nil }
        writeLocalClipboard(message.text)
        return message
    }
}

public enum RDPDriveVirtualChannelMessageError: Error, Equatable {
    case invalidMessage
    case unsupportedComponent(UInt16)
    case unsupportedPacketID(UInt16)
}

public struct RDPDriveDeviceAnnounce: Equatable, Sendable {
    public let deviceID: UInt32
    public let preferredDOSName: String
    public let fullName: String

    public init(deviceID: UInt32, preferredDOSName: String, fullName: String) {
        self.deviceID = deviceID
        self.preferredDOSName = preferredDOSName
        self.fullName = fullName
    }
}

public enum RDPDriveDeviceIOMajorFunction: UInt32, Equatable, Sendable {
    case create = 0x0000_0000
    case close = 0x0000_0002
    case read = 0x0000_0003
    case write = 0x0000_0004
    case queryInformation = 0x0000_0005
    case setInformation = 0x0000_0006
    case queryVolumeInformation = 0x0000_000a
    case setVolumeInformation = 0x0000_000b
    case directoryControl = 0x0000_000c
    case deviceControl = 0x0000_000e
    case unknown = 0xffff_ffff

    public init(rawProtocolValue: UInt32) {
        self = Self(rawValue: rawProtocolValue) ?? .unknown
    }
}

public struct RDPDriveDeviceIORequest: Equatable, Sendable {
    public let deviceID: UInt32
    public let fileID: UInt32
    public let completionID: UInt32
    public let majorFunction: RDPDriveDeviceIOMajorFunction
    public let rawMajorFunction: UInt32
    public let minorFunction: UInt32
    public let payload: Data

    public init(
        deviceID: UInt32,
        fileID: UInt32,
        completionID: UInt32,
        majorFunction: RDPDriveDeviceIOMajorFunction,
        rawMajorFunction: UInt32? = nil,
        minorFunction: UInt32,
        payload: Data
    ) {
        self.deviceID = deviceID
        self.fileID = fileID
        self.completionID = completionID
        self.majorFunction = majorFunction
        self.rawMajorFunction = rawMajorFunction ?? majorFunction.rawValue
        self.minorFunction = minorFunction
        self.payload = payload
    }
}

public struct RDPDriveDeviceIOCompletion: Equatable, Sendable {
    public let deviceID: UInt32
    public let completionID: UInt32
    public let ioStatus: UInt32
    public let payload: Data

    public init(deviceID: UInt32, completionID: UInt32, ioStatus: UInt32, payload: Data = Data()) {
        self.deviceID = deviceID
        self.completionID = completionID
        self.ioStatus = ioStatus
        self.payload = payload
    }
}

public enum RDPDriveDeviceIOHandlerError: Error, Equatable {
    case invalidPayload
    case offsetOutOfRange(UInt64)
}

private struct RDPDriveCreateRequest {
    var remotePath: String
    var allocationSize: UInt64
    var fileAttributes: UInt32
    var createDisposition: UInt32
    var createOptions: UInt32
}

/// Engine-agnostic IO-completion engine for the dormant drive-handshake
/// surface (see `RDPTransportEvent.driveHandshake` comment / spec §6.8 /
/// `FreeRDPSession.marshalDriveRequest`'s docstring). Kept alive
/// post-Task-6 cutover by tests + the symmetric-reservation policy; no
/// live production consumer today — FreeRDP's internal drive client owns
/// drive I/O on the configured `FreeRDP_DrivePath` when redirection is
/// enabled. Wires up if a future shim revision enqueues
/// `CTERMYRDP_EVENT_DRIVE_REQ` events for Swift-side custom handling.
public struct RDPDriveDeviceIOHandler {
    public private(set) var fileHandles: [UInt32: String]

    private let driveBridge: RDPDriveBridge
    private let driveExecutor: RDPDriveLocalFileExecutor
    private var deletePendingFileIDs: Set<UInt32>
    private var nextFileID: UInt32

    public init(
        redirections: [RDPRedirection],
        driveExecutor: RDPDriveLocalFileExecutor = RDPDriveLocalFileExecutor(),
        fileHandles: [UInt32: String] = [:],
        deletePendingFileIDs: Set<UInt32> = [],
        nextFileID: UInt32 = 1
    ) {
        self.driveBridge = RDPDriveBridge(redirections: redirections)
        self.driveExecutor = driveExecutor
        self.fileHandles = fileHandles
        self.deletePendingFileIDs = deletePendingFileIDs
        self.nextFileID = max(1, nextFileID)
    }

    public mutating func completion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        switch request.majorFunction {
        case .create:
            return try createCompletion(for: request)
        case .read:
            return try readCompletion(for: request)
        case .write:
            return try writeCompletion(for: request)
        case .close:
            closeFileHandle(request.fileID)
            return successCompletion(for: request, payload: Data(repeating: 0, count: 4))
        case .directoryControl:
            return try directoryControlCompletion(for: request)
        case .queryInformation:
            return try queryInformationCompletion(for: request)
        case .setInformation:
            return try setInformationCompletion(for: request)
        case .queryVolumeInformation:
            return try queryVolumeInformationCompletion(for: request)
        case .setVolumeInformation:
            return unsuccessfulCompletion(for: request)
        case .deviceControl,
             .unknown:
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func createCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        let create = try Self.createRequest(from: request.payload)
        guard let localURL = driveBridge.localURL(forRemotePath: create.remotePath),
              prepareLocalItem(for: create, at: localURL) else {
            return unsuccessfulCompletion(for: request)
        }

        let fileID = allocateFileID()
        fileHandles[fileID] = create.remotePath
        var payload = Data()
        payload.appendUInt32LE(fileID)
        payload.append(0x00)
        return successCompletion(for: request, payload: payload)
    }

    private func prepareLocalItem(for create: RDPDriveCreateRequest, at localURL: URL) -> Bool {
        let fileManager = FileManager.default
        var isDirectory = ObjCBool(false)
        let exists = fileManager.fileExists(atPath: localURL.path, isDirectory: &isDirectory)
        let wantsDirectory = (create.createOptions & 0x0000_0001) != 0
            || (create.fileAttributes & 0x0000_0010) != 0

        do {
            switch create.createDisposition {
            case 0x0000_0000:
                if exists {
                    try fileManager.removeItem(at: localURL)
                }
                return try createLocalItem(at: localURL, isDirectory: wantsDirectory, allocationSize: create.allocationSize)
            case 0x0000_0001:
                guard exists else { return false }
                return !wantsDirectory || isDirectory.boolValue
            case 0x0000_0002:
                guard !exists else { return false }
                return try createLocalItem(at: localURL, isDirectory: wantsDirectory, allocationSize: create.allocationSize)
            case 0x0000_0003:
                if exists {
                    return !wantsDirectory || isDirectory.boolValue
                }
                return try createLocalItem(at: localURL, isDirectory: wantsDirectory, allocationSize: create.allocationSize)
            case 0x0000_0004:
                guard exists, !isDirectory.boolValue else { return false }
                try truncateFile(at: localURL, to: create.allocationSize)
                return true
            case 0x0000_0005:
                if exists {
                    guard !isDirectory.boolValue else { return false }
                    try truncateFile(at: localURL, to: create.allocationSize)
                    return true
                }
                return try createLocalItem(at: localURL, isDirectory: wantsDirectory, allocationSize: create.allocationSize)
            default:
                return false
            }
        } catch {
            return false
        }
    }

    private func createLocalItem(at localURL: URL, isDirectory: Bool, allocationSize: UInt64) throws -> Bool {
        if isDirectory {
            try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: false)
            return true
        }
        guard FileManager.default.createFile(atPath: localURL.path, contents: Data()) else {
            return false
        }
        if allocationSize > 0 {
            try truncateFile(at: localURL, to: allocationSize)
        }
        return true
    }

    private func truncateFile(at localURL: URL, to byteCount: UInt64) throws {
        guard byteCount <= UInt64(Int.max) else {
            throw RDPDriveDeviceIOHandlerError.offsetOutOfRange(byteCount)
        }
        let handle = try FileHandle(forWritingTo: localURL)
        try handle.truncate(atOffset: byteCount)
        try handle.close()
    }

    private mutating func readCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard let remotePath = fileHandles[request.fileID] else {
            return unsuccessfulCompletion(for: request)
        }
        let transfer = try Self.readWriteTransfer(from: request.payload)
        guard let localRequest = driveBridge.localFileRequest(for: .readFile(
            remotePath: remotePath,
            byteCount: transfer.length,
            offset: transfer.offset
        )) else {
            return unsuccessfulCompletion(for: request)
        }

        do {
            let response = try driveExecutor.execute(localRequest)
            let data = response.data ?? Data()
            var payload = Data()
            payload.appendUInt32LE(UInt32(data.count))
            payload.append(data)
            return successCompletion(for: request, payload: payload)
        } catch {
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func writeCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard let remotePath = fileHandles[request.fileID] else {
            return unsuccessfulCompletion(for: request)
        }
        let transfer = try Self.readWriteTransfer(from: request.payload)
        guard request.payload.count >= 32 + transfer.length else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let writeData = Data(request.payload[32..<(32 + transfer.length)])
        guard let localRequest = driveBridge.localFileRequest(for: .writeFile(
            remotePath: remotePath,
            byteCount: transfer.length,
            offset: transfer.offset
        )) else {
            return unsuccessfulCompletion(for: request)
        }

        do {
            let response = try driveExecutor.execute(localRequest, payload: writeData)
            var payload = Data()
            payload.appendUInt32LE(UInt32(response.bytesWritten ?? 0))
            return successCompletion(for: request, payload: payload)
        } catch {
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func queryInformationCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard let remotePath = fileHandles[request.fileID],
              let localURL = driveBridge.localURL(forRemotePath: remotePath) else {
            return unsuccessfulCompletion(for: request)
        }

        let query = try Self.queryInformation(from: request.payload)
        do {
            let values = try localURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            let isDirectory = values.isDirectory == true
            let buffer: Data
            switch query.fsInformationClass {
            case 0x0000_0004:
                buffer = Self.fileBasicInformationBuffer(isDirectory: isDirectory)
            case 0x0000_0005:
                buffer = Self.fileStandardInformationBuffer(
                    byteCount: UInt64(values.fileSize ?? 0),
                    isDirectory: isDirectory
                )
            case 0x0000_0023:
                buffer = Self.fileAttributeTagInformationBuffer(isDirectory: isDirectory)
            default:
                return unsuccessfulCompletion(for: request)
            }
            var payload = Data()
            payload.appendUInt32LE(UInt32(buffer.count))
            payload.append(buffer)
            return successCompletion(for: request, payload: payload)
        } catch {
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func queryVolumeInformationCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard let remotePath = fileHandles[request.fileID],
              let localURL = driveBridge.localURL(forRemotePath: remotePath) else {
            return unsuccessfulCompletion(for: request)
        }

        let query = try Self.queryInformation(from: request.payload)
        do {
            let buffer: Data
            switch query.fsInformationClass {
            case 0x0000_0003:
                buffer = try Self.fileFsSizeInformationBuffer(for: localURL)
            case 0x0000_0005:
                buffer = Self.fileFsAttributeInformationBuffer()
            default:
                return unsuccessfulCompletion(for: request)
            }
            var payload = Data()
            payload.appendUInt32LE(UInt32(buffer.count))
            payload.append(buffer)
            return successCompletion(for: request, payload: payload)
        } catch {
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func setInformationCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard let remotePath = fileHandles[request.fileID],
              let localURL = driveBridge.localURL(forRemotePath: remotePath) else {
            return unsuccessfulCompletion(for: request)
        }

        let set = try Self.setInformation(from: request.payload)
        switch set.fsInformationClass {
        case 0x0000_000a:
            do {
                let rename = try Self.renameInformation(from: set.buffer)
                guard rename.rootDirectory == 0,
                      let destinationURL = driveBridge.localURL(forRemotePath: rename.remotePath) else {
                    return unsuccessfulCompletion(for: request)
                }
                let destinationExists = FileManager.default.fileExists(atPath: destinationURL.path)
                guard rename.replaceIfExists || !destinationExists else {
                    return unsuccessfulCompletion(for: request)
                }
                if destinationExists {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                fileHandles[request.fileID] = rename.remotePath
                var payload = Data()
                payload.appendUInt32LE(set.length)
                return successCompletion(for: request, payload: payload)
            } catch {
                return unsuccessfulCompletion(for: request)
            }
        case 0x0000_000d:
            guard set.length == 0 else {
                return unsuccessfulCompletion(for: request)
            }
            deletePendingFileIDs.insert(request.fileID)
            var payload = Data()
            payload.appendUInt32LE(set.length)
            return successCompletion(for: request, payload: payload)
        case 0x0000_0014:
            guard set.buffer.count == 8 else {
                return unsuccessfulCompletion(for: request)
            }
            let endOfFile = set.buffer.uint64LE(at: 0)
            guard endOfFile <= UInt64(Int.max) else {
                return unsuccessfulCompletion(for: request)
            }
            do {
                let values = try localURL.resourceValues(forKeys: [.isDirectoryKey])
                guard values.isDirectory != true else {
                    return unsuccessfulCompletion(for: request)
                }
                let handle = try FileHandle(forWritingTo: localURL)
                try handle.truncate(atOffset: endOfFile)
                try handle.close()
                var payload = Data()
                payload.appendUInt32LE(set.length)
                return successCompletion(for: request, payload: payload)
            } catch {
                return unsuccessfulCompletion(for: request)
            }
        default:
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func closeFileHandle(_ fileID: UInt32) {
        defer {
            fileHandles[fileID] = nil
            deletePendingFileIDs.remove(fileID)
        }
        guard deletePendingFileIDs.contains(fileID),
              let remotePath = fileHandles[fileID],
              let localURL = driveBridge.localURL(forRemotePath: remotePath) else {
            return
        }
        try? FileManager.default.removeItem(at: localURL)
    }

    private mutating func directoryControlCompletion(for request: RDPDriveDeviceIORequest) throws -> RDPDriveDeviceIOCompletion {
        guard request.minorFunction == 0x0000_0001,
              let remotePath = fileHandles[request.fileID] else {
            return unsuccessfulCompletion(for: request)
        }
        let query = try Self.queryDirectory(from: request.payload)
        guard query.initialQuery,
              let localRequest = driveBridge.localFileRequest(for: .listDirectory(remotePath: remotePath)) else {
            return unsuccessfulCompletion(for: request)
        }

        do {
            let response = try driveExecutor.execute(localRequest)
            let buffer: Data
            switch query.fsInformationClass {
            case 0x0000_0001:
                buffer = Self.fileDirectoryInformationBuffer(for: response.entries)
            case 0x0000_0002:
                buffer = Self.fileFullDirectoryInformationBuffer(for: response.entries)
            case 0x0000_0003:
                buffer = Self.fileBothDirectoryInformationBuffer(for: response.entries)
            case 0x0000_000c:
                buffer = Self.fileNamesInformationBuffer(for: response.entries)
            default:
                return unsuccessfulCompletion(for: request)
            }
            var payload = Data()
            payload.appendUInt32LE(UInt32(buffer.count))
            payload.append(buffer)
            return successCompletion(for: request, payload: payload)
        } catch {
            return unsuccessfulCompletion(for: request)
        }
    }

    private mutating func allocateFileID() -> UInt32 {
        while fileHandles[nextFileID] != nil {
            nextFileID = nextFileID == UInt32.max ? 1 : nextFileID + 1
        }
        let allocated = nextFileID
        nextFileID = nextFileID == UInt32.max ? 1 : nextFileID + 1
        return allocated
    }

    private func successCompletion(for request: RDPDriveDeviceIORequest, payload: Data) -> RDPDriveDeviceIOCompletion {
        RDPDriveDeviceIOCompletion(
            deviceID: request.deviceID,
            completionID: request.completionID,
            ioStatus: 0x0000_0000,
            payload: payload
        )
    }

    private func unsuccessfulCompletion(for request: RDPDriveDeviceIORequest) -> RDPDriveDeviceIOCompletion {
        RDPDriveDeviceIOCompletion(
            deviceID: request.deviceID,
            completionID: request.completionID,
            ioStatus: 0xc000_0001,
            payload: Data()
        )
    }

    private static func createRequest(from payload: Data) throws -> RDPDriveCreateRequest {
        guard payload.count >= 32 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let pathLength = Int(payload.uint32LE(at: 28))
        guard pathLength >= 2,
              pathLength % 2 == 0,
              payload.count >= 32 + pathLength else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }

        var units: [UInt16] = []
        var offset = 32
        let end = 32 + pathLength
        while offset + 1 < end {
            let unit = payload.uint16LE(at: offset)
            if unit == 0 { break }
            units.append(unit)
            offset += 2
        }
        return RDPDriveCreateRequest(
            remotePath: String(decoding: units, as: UTF16.self),
            allocationSize: payload.uint64LE(at: 4),
            fileAttributes: payload.uint32LE(at: 12),
            createDisposition: payload.uint32LE(at: 20),
            createOptions: payload.uint32LE(at: 24)
        )
    }

    private static func queryDirectory(from payload: Data) throws -> (
        fsInformationClass: UInt32,
        initialQuery: Bool,
        path: String
    ) {
        guard payload.count >= 32 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let pathLength = Int(payload.uint32LE(at: 5))
        guard pathLength >= 2,
              pathLength % 2 == 0,
              payload.count >= 32 + pathLength else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }

        var units: [UInt16] = []
        var offset = 32
        let end = 32 + pathLength
        while offset + 1 < end {
            let unit = payload.uint16LE(at: offset)
            if unit == 0 { break }
            units.append(unit)
            offset += 2
        }

        return (
            fsInformationClass: payload.uint32LE(at: 0),
            initialQuery: payload[4] != 0,
            path: String(decoding: units, as: UTF16.self)
        )
    }

    private static func readWriteTransfer(from payload: Data) throws -> (length: Int, offset: UInt64) {
        guard payload.count >= 32 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let length = Int(payload.uint32LE(at: 0))
        let offset = payload.uint64LE(at: 4)
        guard offset <= UInt64(Int.max) else {
            throw RDPDriveDeviceIOHandlerError.offsetOutOfRange(offset)
        }
        return (length, offset)
    }

    private static func queryInformation(from payload: Data) throws -> (fsInformationClass: UInt32, length: UInt32) {
        guard payload.count >= 32 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        return (
            fsInformationClass: payload.uint32LE(at: 0),
            length: payload.uint32LE(at: 4)
        )
    }

    private static func setInformation(from payload: Data) throws -> (
        fsInformationClass: UInt32,
        length: UInt32,
        buffer: Data
    ) {
        guard payload.count >= 32 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let length = payload.uint32LE(at: 4)
        guard let bufferLength = Int(exactly: length),
              payload.count >= 32 + bufferLength else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        return (
            fsInformationClass: payload.uint32LE(at: 0),
            length: length,
            buffer: payload.subdata(in: 32..<(32 + bufferLength))
        )
    }

    private static func renameInformation(from buffer: Data) throws -> (
        replaceIfExists: Bool,
        rootDirectory: UInt8,
        remotePath: String
    ) {
        guard buffer.count >= 6 else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }
        let nameLength = buffer.uint32LE(at: 2)
        guard let nameByteCount = Int(exactly: nameLength),
              nameByteCount > 0,
              nameByteCount % 2 == 0,
              buffer.count >= 6 + nameByteCount else {
            throw RDPDriveDeviceIOHandlerError.invalidPayload
        }

        var units: [UInt16] = []
        var offset = 6
        let end = 6 + nameByteCount
        while offset + 1 < end {
            let unit = buffer.uint16LE(at: offset)
            if unit == 0 { break }
            units.append(unit)
            offset += 2
        }
        return (
            replaceIfExists: buffer[0] != 0,
            rootDirectory: buffer[1],
            remotePath: String(decoding: units, as: UTF16.self)
        )
    }

    private static func fileBasicInformationBuffer(isDirectory: Bool) -> Data {
        var buffer = Data()
        buffer.appendUInt64LE(0)
        buffer.appendUInt64LE(0)
        buffer.appendUInt64LE(0)
        buffer.appendUInt64LE(0)
        buffer.appendUInt32LE(fileAttributes(isDirectory: isDirectory))
        return buffer
    }

    private static func fileStandardInformationBuffer(byteCount: UInt64, isDirectory: Bool) -> Data {
        var buffer = Data()
        buffer.appendUInt64LE(byteCount)
        buffer.appendUInt64LE(byteCount)
        buffer.appendUInt32LE(1)
        buffer.append(0)
        buffer.append(isDirectory ? 1 : 0)
        return buffer
    }

    private static func fileAttributeTagInformationBuffer(isDirectory: Bool) -> Data {
        var buffer = Data()
        buffer.appendUInt32LE(fileAttributes(isDirectory: isDirectory))
        buffer.appendUInt32LE(0)
        return buffer
    }

    private static func fileFsAttributeInformationBuffer() -> Data {
        var fileSystemName = Data()
        fileSystemName.appendFixedWindowsUTF16("Termy", byteCount: 10)
        var buffer = Data()
        buffer.appendUInt32LE(0x0000_0007)
        buffer.appendUInt32LE(255)
        buffer.appendUInt32LE(UInt32(fileSystemName.count))
        buffer.append(fileSystemName)
        return buffer
    }

    private static func fileFsSizeInformationBuffer(for localURL: URL) throws -> Data {
        let values = try FileManager.default.attributesOfFileSystem(forPath: localURL.path)
        let totalBytes = (values[.systemSize] as? NSNumber)?.uint64Value ?? 4096
        let availableBytes = (values[.systemFreeSize] as? NSNumber)?.uint64Value ?? 4096
        let allocationUnitBytes: UInt64 = 4096
        var buffer = Data()
        buffer.appendUInt64LE(max(1, totalBytes / allocationUnitBytes))
        buffer.appendUInt64LE(max(1, availableBytes / allocationUnitBytes))
        buffer.appendUInt32LE(8)
        buffer.appendUInt32LE(512)
        return buffer
    }

    private static func fileAttributes(isDirectory: Bool) -> UInt32 {
        isDirectory ? 0x0000_0010 : 0x0000_0020
    }

    private static func fileNamesInformationBuffer(for entries: [LocalFileItem]) -> Data {
        var buffer = Data()
        for (index, entry) in entries.enumerated() {
            var nameBytes = Data()
            for codeUnit in entry.name.utf16 {
                nameBytes.appendUInt16LE(codeUnit)
            }

            let entryStart = buffer.count
            let entryLength = 12 + nameBytes.count
            let isLast = index == entries.count - 1
            let nextEntryOffset = isLast ? 0 : alignedLength(entryLength, alignment: 8)
            buffer.appendUInt32LE(UInt32(nextEntryOffset))
            buffer.appendUInt32LE(0)
            buffer.appendUInt32LE(UInt32(nameBytes.count))
            buffer.append(nameBytes)
            if !isLast {
                let paddingCount = nextEntryOffset - (buffer.count - entryStart)
                if paddingCount > 0 {
                    buffer.append(Data(repeating: 0, count: paddingCount))
                }
            }
        }
        return buffer
    }

    private static func fileDirectoryInformationBuffer(for entries: [LocalFileItem]) -> Data {
        var buffer = Data()
        for (index, entry) in entries.enumerated() {
            var nameBytes = Data()
            for codeUnit in entry.name.utf16 {
                nameBytes.appendUInt16LE(codeUnit)
            }

            let entryStart = buffer.count
            let entryLength = 64 + nameBytes.count
            let isLast = index == entries.count - 1
            let nextEntryOffset = isLast ? 0 : alignedLength(entryLength, alignment: 8)
            let byteCount = UInt64(entry.byteCount ?? 0)
            buffer.appendUInt32LE(UInt32(nextEntryOffset))
            buffer.appendUInt32LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt32LE(entry.isDirectory ? 0x0000_0010 : 0x0000_0020)
            buffer.appendUInt32LE(UInt32(nameBytes.count))
            buffer.append(nameBytes)
            if !isLast {
                let paddingCount = nextEntryOffset - (buffer.count - entryStart)
                if paddingCount > 0 {
                    buffer.append(Data(repeating: 0, count: paddingCount))
                }
            }
        }
        return buffer
    }

    private static func fileFullDirectoryInformationBuffer(for entries: [LocalFileItem]) -> Data {
        var buffer = Data()
        for (index, entry) in entries.enumerated() {
            var nameBytes = Data()
            for codeUnit in entry.name.utf16 {
                nameBytes.appendUInt16LE(codeUnit)
            }

            let entryStart = buffer.count
            let entryLength = 68 + nameBytes.count
            let isLast = index == entries.count - 1
            let nextEntryOffset = isLast ? 0 : alignedLength(entryLength, alignment: 8)
            let byteCount = UInt64(entry.byteCount ?? 0)
            buffer.appendUInt32LE(UInt32(nextEntryOffset))
            buffer.appendUInt32LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt32LE(entry.isDirectory ? 0x0000_0010 : 0x0000_0020)
            buffer.appendUInt32LE(UInt32(nameBytes.count))
            buffer.appendUInt32LE(0)
            buffer.append(nameBytes)
            if !isLast {
                let paddingCount = nextEntryOffset - (buffer.count - entryStart)
                if paddingCount > 0 {
                    buffer.append(Data(repeating: 0, count: paddingCount))
                }
            }
        }
        return buffer
    }

    private static func fileBothDirectoryInformationBuffer(for entries: [LocalFileItem]) -> Data {
        var buffer = Data()
        for (index, entry) in entries.enumerated() {
            var nameBytes = Data()
            for codeUnit in entry.name.utf16 {
                nameBytes.appendUInt16LE(codeUnit)
            }

            let entryStart = buffer.count
            let entryLength = 94 + nameBytes.count
            let isLast = index == entries.count - 1
            let nextEntryOffset = isLast ? 0 : alignedLength(entryLength, alignment: 8)
            let byteCount = UInt64(entry.byteCount ?? 0)
            buffer.appendUInt32LE(UInt32(nextEntryOffset))
            buffer.appendUInt32LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(0)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt64LE(byteCount)
            buffer.appendUInt32LE(entry.isDirectory ? 0x0000_0010 : 0x0000_0020)
            buffer.appendUInt32LE(UInt32(nameBytes.count))
            buffer.appendUInt32LE(0)
            buffer.append(Data(repeating: 0, count: 26))
            buffer.append(nameBytes)
            if !isLast {
                let paddingCount = nextEntryOffset - (buffer.count - entryStart)
                if paddingCount > 0 {
                    buffer.append(Data(repeating: 0, count: paddingCount))
                }
            }
        }
        return buffer
    }

    private static func alignedLength(_ length: Int, alignment: Int) -> Int {
        let remainder = length % alignment
        return remainder == 0 ? length : length + (alignment - remainder)
    }
}

public enum RDPDriveVirtualChannelMessage: Equatable, Sendable {
    case serverAnnounce(versionMajor: UInt16, versionMinor: UInt16, clientID: UInt32)
    case serverClientIDConfirm(versionMajor: UInt16, versionMinor: UInt16, clientID: UInt32)
    case clientAnnounceReply(versionMinor: UInt16, clientID: UInt32)
    case clientName(String)
    case clientCoreCapabilityResponse
    case deviceListAnnounce([RDPDriveDeviceAnnounce])
    case serverDeviceAnnounceResponse(deviceID: UInt32, resultCode: UInt32)
    case deviceIORequest(RDPDriveDeviceIORequest)
    case deviceIOCompletion(RDPDriveDeviceIOCompletion)

    private static let componentCore: UInt16 = 0x4472
    private static let packetServerAnnounce: UInt16 = 0x496e
    private static let packetClientIDConfirm: UInt16 = 0x4343
    private static let packetClientName: UInt16 = 0x434e
    private static let packetClientCapability: UInt16 = 0x4350
    private static let packetDeviceListAnnounce: UInt16 = 0x4441
    private static let packetDeviceReply: UInt16 = 0x6472
    private static let packetDeviceIORequest: UInt16 = 0x4952
    private static let packetDeviceIOCompletion: UInt16 = 0x4943

    public var encoded: Data {
        switch self {
        case .serverAnnounce(let versionMajor, let versionMinor, let clientID):
            return Self.versionPacket(
                packetID: Self.packetServerAnnounce,
                versionMajor: versionMajor,
                versionMinor: versionMinor,
                clientID: clientID
            )
        case .serverClientIDConfirm(let versionMajor, let versionMinor, let clientID):
            return Self.versionPacket(
                packetID: Self.packetClientIDConfirm,
                versionMajor: versionMajor,
                versionMinor: versionMinor,
                clientID: clientID
            )
        case .clientAnnounceReply(let versionMinor, let clientID):
            return Self.versionPacket(
                packetID: Self.packetClientIDConfirm,
                versionMajor: 1,
                versionMinor: versionMinor,
                clientID: clientID
            )
        case .clientName(let name):
            var nameBytes = Data()
            nameBytes.appendWindowsUTF16Terminated(name)
            var data = Self.header(Self.packetClientName)
            data.appendUInt32LE(1)
            data.appendUInt32LE(0)
            data.appendUInt32LE(UInt32(nameBytes.count))
            data.append(nameBytes)
            return data
        case .clientCoreCapabilityResponse:
            var data = Self.header(Self.packetClientCapability)
            data.appendUInt16LE(2)
            data.appendUInt16LE(0)
            data.append(Self.generalCapabilitySet())
            data.append(Self.driveCapabilitySet())
            return data
        case .deviceListAnnounce(let devices):
            var data = Self.header(Self.packetDeviceListAnnounce)
            data.appendUInt32LE(UInt32(devices.count))
            for device in devices {
                data.appendUInt32LE(0x0000_0008)
                data.appendUInt32LE(device.deviceID)
                data.appendFixedASCII(device.preferredDOSName, byteCount: 8)
                var fullNameBytes = Data()
                fullNameBytes.appendWindowsUTF16Terminated(device.fullName)
                data.appendUInt32LE(UInt32(fullNameBytes.count))
                data.append(fullNameBytes)
            }
            return data
        case .serverDeviceAnnounceResponse(let deviceID, let resultCode):
            var data = Self.header(Self.packetDeviceReply)
            data.appendUInt32LE(deviceID)
            data.appendUInt32LE(resultCode)
            return data
        case .deviceIORequest(let request):
            var data = Self.header(Self.packetDeviceIORequest)
            data.appendUInt32LE(request.deviceID)
            data.appendUInt32LE(request.fileID)
            data.appendUInt32LE(request.completionID)
            data.appendUInt32LE(request.rawMajorFunction)
            data.appendUInt32LE(request.minorFunction)
            data.append(request.payload)
            return data
        case .deviceIOCompletion(let completion):
            var data = Self.header(Self.packetDeviceIOCompletion)
            data.appendUInt32LE(completion.deviceID)
            data.appendUInt32LE(completion.completionID)
            data.appendUInt32LE(completion.ioStatus)
            data.append(completion.payload)
            return data
        }
    }

    public static func parse(_ data: Data) throws -> RDPDriveVirtualChannelMessage {
        guard data.count >= 4 else {
            throw RDPDriveVirtualChannelMessageError.invalidMessage
        }
        let component = data.uint16LE(at: 0)
        guard component == componentCore else {
            throw RDPDriveVirtualChannelMessageError.unsupportedComponent(component)
        }
        let packetID = data.uint16LE(at: 2)
        switch packetID {
        case packetServerAnnounce:
            guard data.count == 12 else {
                throw RDPDriveVirtualChannelMessageError.invalidMessage
            }
            return .serverAnnounce(
                versionMajor: data.uint16LE(at: 4),
                versionMinor: data.uint16LE(at: 6),
                clientID: data.uint32LE(at: 8)
            )
        case packetClientIDConfirm:
            guard data.count == 12 else {
                throw RDPDriveVirtualChannelMessageError.invalidMessage
            }
            return .serverClientIDConfirm(
                versionMajor: data.uint16LE(at: 4),
                versionMinor: data.uint16LE(at: 6),
                clientID: data.uint32LE(at: 8)
            )
        case packetDeviceReply:
            guard data.count == 12 else {
                throw RDPDriveVirtualChannelMessageError.invalidMessage
            }
            return .serverDeviceAnnounceResponse(
                deviceID: data.uint32LE(at: 4),
                resultCode: data.uint32LE(at: 8)
            )
        case packetDeviceIORequest:
            guard data.count >= 24 else {
                throw RDPDriveVirtualChannelMessageError.invalidMessage
            }
            let rawMajorFunction = data.uint32LE(at: 16)
            return .deviceIORequest(RDPDriveDeviceIORequest(
                deviceID: data.uint32LE(at: 4),
                fileID: data.uint32LE(at: 8),
                completionID: data.uint32LE(at: 12),
                majorFunction: RDPDriveDeviceIOMajorFunction(rawProtocolValue: rawMajorFunction),
                rawMajorFunction: rawMajorFunction,
                minorFunction: data.uint32LE(at: 20),
                payload: Data(data.dropFirst(24))
            ))
        default:
            throw RDPDriveVirtualChannelMessageError.unsupportedPacketID(packetID)
        }
    }

    private static func header(_ packetID: UInt16) -> Data {
        var data = Data()
        data.appendUInt16LE(componentCore)
        data.appendUInt16LE(packetID)
        return data
    }

    private static func versionPacket(
        packetID: UInt16,
        versionMajor: UInt16,
        versionMinor: UInt16,
        clientID: UInt32
    ) -> Data {
        var data = header(packetID)
        data.appendUInt16LE(versionMajor)
        data.appendUInt16LE(versionMinor)
        data.appendUInt32LE(clientID)
        return data
    }

    private static func generalCapabilitySet() -> Data {
        var data = Data()
        data.appendUInt16LE(0x0001)
        data.appendUInt16LE(44)
        data.appendUInt32LE(0x0000_0002)
        data.appendUInt32LE(0x0000_0002)
        data.appendUInt32LE(0)
        data.appendUInt16LE(1)
        data.appendUInt16LE(12)
        data.appendUInt32LE(0x0000_ffff)
        data.appendUInt32LE(0)
        data.appendUInt32LE(0x0000_0007)
        data.appendUInt32LE(0)
        data.appendUInt32LE(0)
        data.appendUInt32LE(0x0000_0002)
        return data
    }

    private static func driveCapabilitySet() -> Data {
        var data = Data()
        data.appendUInt16LE(0x0004)
        data.appendUInt16LE(8)
        data.appendUInt32LE(0x0000_0002)
        return data
    }
}

public struct RDPDriveVirtualChannelExchange: Equatable, Sendable {
    public let clientName: String
    public let driveName: String
    public let deviceID: UInt32

    public init(clientName: String, driveName: String, deviceID: UInt32 = 1) {
        self.clientName = clientName
        self.driveName = driveName
        self.deviceID = deviceID
    }

    public func outboundMessages(
        for message: RDPDriveVirtualChannelMessage,
        localFolderPath: String?
    ) -> [RDPDriveVirtualChannelMessage] {
        switch message {
        case .serverAnnounce(_, let versionMinor, let clientID):
            return [
                .clientAnnounceReply(versionMinor: min(versionMinor, 12), clientID: clientID),
                .clientName(clientName)
            ]
        case .serverClientIDConfirm:
            guard localFolderPath != nil else {
                return [.clientCoreCapabilityResponse]
            }
            return [
                .clientCoreCapabilityResponse,
                .deviceListAnnounce([
                    RDPDriveDeviceAnnounce(
                        deviceID: deviceID,
                        preferredDOSName: driveName,
                        fullName: driveName
                    )
                ])
            ]
        case .clientAnnounceReply,
             .clientName,
             .clientCoreCapabilityResponse,
             .deviceListAnnounce,
             .serverDeviceAnnounceResponse,
             .deviceIORequest,
             .deviceIOCompletion:
            return []
        }
    }
}

public struct RDPDriveBridge: Equatable, Sendable {
    public let localRootPath: String?

    public var isEnabled: Bool {
        localRootPath != nil
    }

    public init(descriptor: RDPSessionDescriptor) {
        self.init(redirections: descriptor.redirections)
    }

    public init(redirections: [RDPRedirection]) {
        self.localRootPath = redirections.compactMap { redirection in
            if case .folderDrive(let path) = redirection {
                return path
            }
            return nil
        }.first
    }

    public func localURL(forRemotePath remotePath: String) -> URL? {
        guard let localRootPath else { return nil }
        let root = URL(fileURLWithPath: localRootPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()

        let segments = remotePath
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !segments.isEmpty, segments.allSatisfy({ $0 != "." && $0 != ".." }) else {
            return nil
        }

        let candidate = segments.reduce(root) { url, segment in
            url.appendingPathComponent(segment)
        }
        .standardizedFileURL
        .resolvingSymlinksInPath()

        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(rootPath) else {
            return nil
        }
        return candidate
    }

    public func localFileRequest(for operation: RDPDriveOperation) -> RDPDriveLocalFileRequest? {
        guard let localURL = localURL(forRemotePath: operation.remotePath) else { return nil }
        return RDPDriveLocalFileRequest(
            kind: operation.kind,
            localURL: localURL,
            byteCount: operation.byteCount,
            offset: operation.offset
        )
    }
}

public enum RDPDriveOperationKind: Equatable, Sendable {
    case listDirectory
    case readFile
    case writeFile
}

public enum RDPDriveOperation: Equatable, Sendable {
    case listDirectory(remotePath: String)
    case readFile(remotePath: String, byteCount: Int? = nil, offset: UInt64 = 0)
    case writeFile(remotePath: String, byteCount: Int, offset: UInt64 = 0)

    public var kind: RDPDriveOperationKind {
        switch self {
        case .listDirectory:
            return .listDirectory
        case .readFile:
            return .readFile
        case .writeFile:
            return .writeFile
        }
    }

    public var remotePath: String {
        switch self {
        case .listDirectory(let remotePath), .readFile(let remotePath, _, _):
            return remotePath
        case .writeFile(let remotePath, _, _):
            return remotePath
        }
    }

    public var byteCount: Int? {
        switch self {
        case .readFile(_, let byteCount, _):
            return byteCount.map { max(0, $0) }
        case .writeFile(_, let byteCount, _):
            return max(0, byteCount)
        case .listDirectory:
            return nil
        }
    }

    public var offset: UInt64 {
        switch self {
        case .readFile(_, _, let offset), .writeFile(_, _, let offset):
            return offset
        case .listDirectory:
            return 0
        }
    }
}

public struct RDPDriveLocalFileRequest: Equatable, Sendable {
    public let kind: RDPDriveOperationKind
    public let localURL: URL
    public let byteCount: Int?
    public let offset: UInt64

    public init(kind: RDPDriveOperationKind, localURL: URL, byteCount: Int?, offset: UInt64 = 0) {
        self.kind = kind
        self.localURL = localURL.standardizedFileURL
        self.byteCount = byteCount
        self.offset = offset
    }
}

public enum RDPDriveLocalFileExecutorError: Error, Equatable {
    case payloadSizeMismatch(expected: Int, actual: Int)
    case offsetOutOfRange(UInt64)
}

public struct RDPDriveLocalFileResponse: Equatable, Sendable {
    public let kind: RDPDriveOperationKind
    public let entries: [LocalFileItem]
    public let data: Data?
    public let bytesWritten: Int?

    public init(
        kind: RDPDriveOperationKind,
        entries: [LocalFileItem] = [],
        data: Data? = nil,
        bytesWritten: Int? = nil
    ) {
        self.kind = kind
        self.entries = entries
        self.data = data
        self.bytesWritten = bytesWritten
    }
}

public struct RDPDriveLocalFileExecutor {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func execute(
        _ request: RDPDriveLocalFileRequest,
        payload: Data = Data()
    ) throws -> RDPDriveLocalFileResponse {
        switch request.kind {
        case .listDirectory:
            return try listDirectory(request.localURL)
        case .readFile:
            return try readFile(
                request.localURL,
                byteCount: request.byteCount,
                offset: request.offset
            )
        case .writeFile:
            return try writeFile(
                request.localURL,
                expectedByteCount: request.byteCount,
                offset: request.offset,
                payload: payload
            )
        }
    }

    private func listDirectory(_ url: URL) throws -> RDPDriveLocalFileResponse {
        let urls = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        let entries = try urls
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { itemURL in
                let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return LocalFileItem(
                    name: itemURL.lastPathComponent,
                    relativePath: itemURL.lastPathComponent,
                    isDirectory: values.isDirectory == true,
                    byteCount: values.isDirectory == true ? nil : values.fileSize
                )
            }
        return RDPDriveLocalFileResponse(kind: .listDirectory, entries: entries)
    }

    private func readFile(_ url: URL, byteCount: Int?, offset: UInt64) throws -> RDPDriveLocalFileResponse {
        guard offset <= UInt64(Int.max) else {
            throw RDPDriveLocalFileExecutorError.offsetOutOfRange(offset)
        }
        let data = try Data(contentsOf: url)
        let start = min(Int(offset), data.count)
        let requestedEnd = byteCount.map { start + max(0, $0) } ?? data.count
        let end = min(requestedEnd, data.count)
        return RDPDriveLocalFileResponse(kind: .readFile, data: Data(data[start..<end]))
    }

    private func writeFile(
        _ url: URL,
        expectedByteCount: Int?,
        offset: UInt64,
        payload: Data
    ) throws -> RDPDriveLocalFileResponse {
        if let expectedByteCount, expectedByteCount != payload.count {
            throw RDPDriveLocalFileExecutorError.payloadSizeMismatch(
                expected: expectedByteCount,
                actual: payload.count
            )
        }
        guard offset <= UInt64(Int.max) else {
            throw RDPDriveLocalFileExecutorError.offsetOutOfRange(offset)
        }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = (try? Data(contentsOf: url)) ?? Data()
        let start = Int(offset)
        if data.count < start {
            data.append(Data(repeating: 0, count: start - data.count))
        }
        let end = start + payload.count
        if data.count < end {
            data.append(Data(repeating: 0, count: end - data.count))
        }
        data.replaceSubrange(start..<end, with: payload)
        try data.write(to: url, options: .atomic)
        return RDPDriveLocalFileResponse(kind: .writeFile, bytesWritten: payload.count)
    }
}

public enum RDPAudioOutputFormat: Equatable, Sendable {
    case pcmSigned16LittleEndian
}

public enum RDPAudioVirtualChannelMessageError: Error, Equatable {
    case invalidMessage
    case unsupportedMessageType(UInt8)
    case unsupportedAudioFormat(UInt16)
}

public struct RDPAudioVirtualChannelFormat: Equatable, Sendable {
    public let formatTag: UInt16
    public let channelCount: UInt16
    public let samplesPerSecond: UInt32
    public let averageBytesPerSecond: UInt32
    public let blockAlign: UInt16
    public let bitsPerSample: UInt16
    public let extraData: Data

    public var isPCM16: Bool {
        formatTag == 0x0001 && bitsPerSample == 16 && extraData.isEmpty
    }

    public init(
        formatTag: UInt16,
        channelCount: UInt16,
        samplesPerSecond: UInt32,
        averageBytesPerSecond: UInt32,
        blockAlign: UInt16,
        bitsPerSample: UInt16,
        extraData: Data
    ) {
        self.formatTag = formatTag
        self.channelCount = channelCount
        self.samplesPerSecond = samplesPerSecond
        self.averageBytesPerSecond = averageBytesPerSecond
        self.blockAlign = blockAlign
        self.bitsPerSample = bitsPerSample
        self.extraData = extraData
    }

    public static func pcmSigned16LittleEndian(
        sampleRate: Int,
        channelCount: Int
    ) -> RDPAudioVirtualChannelFormat {
        let channels = UInt16(clamping: channelCount)
        let rate = UInt32(clamping: sampleRate)
        let blockAlign = UInt16(max(1, Int(channels) * 2))
        return RDPAudioVirtualChannelFormat(
            formatTag: 0x0001,
            channelCount: channels,
            samplesPerSecond: rate,
            averageBytesPerSecond: rate * UInt32(blockAlign),
            blockAlign: blockAlign,
            bitsPerSample: 16,
            extraData: Data()
        )
    }

    public var encoded: Data {
        var data = Data()
        data.appendUInt16LE(formatTag)
        data.appendUInt16LE(channelCount)
        data.appendUInt32LE(samplesPerSecond)
        data.appendUInt32LE(averageBytesPerSecond)
        data.appendUInt16LE(blockAlign)
        data.appendUInt16LE(bitsPerSample)
        data.appendUInt16LE(UInt16(clamping: extraData.count))
        data.append(extraData.prefix(Int(UInt16.max)))
        return data
    }

    public static func parse(_ data: Data, offset: Int) throws -> (format: RDPAudioVirtualChannelFormat, nextOffset: Int) {
        guard offset + 18 <= data.count else {
            throw RDPAudioVirtualChannelMessageError.invalidMessage
        }
        let extraDataLength = Int(data.uint16LE(at: offset + 16))
        let endOffset = offset + 18 + extraDataLength
        guard endOffset <= data.count else {
            throw RDPAudioVirtualChannelMessageError.invalidMessage
        }
        return (
            RDPAudioVirtualChannelFormat(
                formatTag: data.uint16LE(at: offset),
                channelCount: data.uint16LE(at: offset + 2),
                samplesPerSecond: data.uint32LE(at: offset + 4),
                averageBytesPerSecond: data.uint32LE(at: offset + 8),
                blockAlign: data.uint16LE(at: offset + 12),
                bitsPerSample: data.uint16LE(at: offset + 14),
                extraData: Data(data[(offset + 18)..<endOffset])
            ),
            endOffset
        )
    }
}

public struct RDPAudioWaveInfo: Equatable, Sendable {
    public let timestamp: UInt16
    public let formatIndex: UInt16
    public let blockNumber: UInt8
    public let bodySize: UInt16
    public let firstAudioBytes: Data

    public init(
        timestamp: UInt16,
        formatIndex: UInt16,
        blockNumber: UInt8,
        bodySize: UInt16,
        firstAudioBytes: Data
    ) {
        self.timestamp = timestamp
        self.formatIndex = formatIndex
        self.blockNumber = blockNumber
        self.bodySize = bodySize
        self.firstAudioBytes = Data(firstAudioBytes.prefix(4))
    }
}

public enum RDPAudioVirtualChannelMessage: Equatable, Sendable {
    case serverAudioFormats(version: UInt16, lastBlockConfirmed: UInt8, formats: [RDPAudioVirtualChannelFormat])
    case clientAudioFormats(version: UInt16, lastBlockConfirmed: UInt8, formats: [RDPAudioVirtualChannelFormat])
    case waveInfo(RDPAudioWaveInfo)

    public var encoded: Data {
        switch self {
        case .serverAudioFormats(let version, let lastBlockConfirmed, let formats),
             .clientAudioFormats(let version, let lastBlockConfirmed, let formats):
            var body = Data()
            body.appendUInt32LE(0x0000_0001)
            body.appendUInt32LE(0xffff_ffff)
            body.appendUInt32LE(0)
            body.appendUInt16LE(0)
            body.appendUInt16LE(UInt16(clamping: formats.count))
            body.append(lastBlockConfirmed)
            body.appendUInt16LE(version)
            body.append(0)
            for format in formats {
                body.append(format.encoded)
            }
            return Self.message(type: 0x07, body: body)
        case .waveInfo(let info):
            var body = Data()
            body.appendUInt16LE(info.timestamp)
            body.appendUInt16LE(info.formatIndex)
            body.append(info.blockNumber)
            body.append(Data(repeating: 0, count: 3))
            body.append(info.firstAudioBytes)
            var data = Data()
            data.append(0x02)
            data.append(0)
            data.appendUInt16LE(info.bodySize)
            data.append(body)
            return data
        }
    }

    public static func parse(_ data: Data) throws -> RDPAudioVirtualChannelMessage {
        guard data.count >= 4 else {
            throw RDPAudioVirtualChannelMessageError.invalidMessage
        }
        let type = data[0]
        let bodySize = Int(data.uint16LE(at: 2))
        switch type {
        case 0x07:
            guard data.count == bodySize + 4 else {
                throw RDPAudioVirtualChannelMessageError.invalidMessage
            }
            guard bodySize >= 18 else {
                throw RDPAudioVirtualChannelMessageError.invalidMessage
            }
            let formatCount = Int(data.uint16LE(at: 18))
            let lastBlockConfirmed = data[20]
            let version = data.uint16LE(at: 21)
            var formats: [RDPAudioVirtualChannelFormat] = []
            var offset = 24
            for _ in 0..<formatCount {
                let parsed = try RDPAudioVirtualChannelFormat.parse(data, offset: offset)
                formats.append(parsed.format)
                offset = parsed.nextOffset
            }
            guard offset == data.count else {
                throw RDPAudioVirtualChannelMessageError.invalidMessage
            }
            return .serverAudioFormats(
                version: version,
                lastBlockConfirmed: lastBlockConfirmed,
                formats: formats
            )
        case 0x02:
            guard bodySize >= 12, data.count >= 16 else {
                throw RDPAudioVirtualChannelMessageError.invalidMessage
            }
            return .waveInfo(RDPAudioWaveInfo(
                timestamp: data.uint16LE(at: 4),
                formatIndex: data.uint16LE(at: 6),
                blockNumber: data[8],
                bodySize: UInt16(bodySize),
                firstAudioBytes: Data(data[12..<16])
            ))
        default:
            throw RDPAudioVirtualChannelMessageError.unsupportedMessageType(type)
        }
    }

    private static func message(type: UInt8, body: Data) -> Data {
        var data = Data()
        data.append(type)
        data.append(0)
        data.appendUInt16LE(UInt16(clamping: body.count))
        data.append(body)
        return data
    }
}

public struct RDPAudioVirtualChannelState: Equatable, Sendable {
    public var negotiatedFormats: [RDPAudioVirtualChannelFormat]
    public var pendingWaveInfo: RDPAudioWaveInfo?

    public init(
        negotiatedFormats: [RDPAudioVirtualChannelFormat] = [],
        pendingWaveInfo: RDPAudioWaveInfo? = nil
    ) {
        self.negotiatedFormats = negotiatedFormats
        self.pendingWaveInfo = pendingWaveInfo
    }
}

public struct RDPAudioVirtualChannelExchange: Equatable, Sendable {
    public init() {}

    public func clientFormatResponse(
        for message: RDPAudioVirtualChannelMessage
    ) -> RDPAudioVirtualChannelMessage? {
        guard case .serverAudioFormats(let version, let lastBlockConfirmed, let formats) = message else {
            return nil
        }
        let acceptedFormats = formats.filter(\.isPCM16)
        guard !acceptedFormats.isEmpty else { return nil }
        return .clientAudioFormats(
            version: version,
            lastBlockConfirmed: lastBlockConfirmed,
            formats: acceptedFormats
        )
    }

    public func audioFrame(
        from message: RDPAudioVirtualChannelMessage,
        waveContinuation: Data,
        negotiatedFormats: [RDPAudioVirtualChannelFormat],
        sequence: Int
    ) throws -> RDPAudioOutputFrame {
        guard case .waveInfo(let info) = message,
              Int(info.formatIndex) < negotiatedFormats.count,
              waveContinuation.count >= 4 else {
            throw RDPAudioVirtualChannelMessageError.invalidMessage
        }
        let format = negotiatedFormats[Int(info.formatIndex)]
        guard format.isPCM16 else {
            throw RDPAudioVirtualChannelMessageError.unsupportedAudioFormat(format.formatTag)
        }
        let audioData = info.firstAudioBytes + Data(waveContinuation.dropFirst(4))
        guard Int(info.bodySize) == audioData.count + 8 else {
            throw RDPAudioVirtualChannelMessageError.invalidMessage
        }
        return RDPAudioOutputFrame(
            sequence: sequence,
            sampleRate: Int(format.samplesPerSecond),
            channelCount: Int(format.channelCount),
            format: .pcmSigned16LittleEndian,
            data: audioData
        )
    }
}

public struct RDPAudioOutputFrame: Equatable, Sendable {
    public let sequence: Int
    public let sampleRate: Int
    public let channelCount: Int
    public let format: RDPAudioOutputFormat
    public let data: Data

    public var byteCount: Int {
        data.count
    }

    public init(
        sequence: Int,
        sampleRate: Int,
        channelCount: Int,
        format: RDPAudioOutputFormat,
        byteCount: Int
    ) {
        self.init(
            sequence: sequence,
            sampleRate: sampleRate,
            channelCount: channelCount,
            format: format,
            data: Data(repeating: 0, count: max(0, byteCount))
        )
    }

    public init(
        sequence: Int,
        sampleRate: Int,
        channelCount: Int,
        format: RDPAudioOutputFormat,
        data: Data
    ) {
        self.sequence = sequence
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.format = format
        self.data = data
    }
}

public struct RDPAudioOutputBridge: Equatable, Sendable {
    public let isEnabled: Bool
    public private(set) var lastRemoteSequence: Int?

    public init(descriptor: RDPSessionDescriptor) {
        self.init(redirections: descriptor.redirections)
    }

    public init(redirections: [RDPRedirection]) {
        self.isEnabled = redirections.contains(.audioOutput)
        self.lastRemoteSequence = nil
    }

    public mutating func receiveRemoteOutputFrame(_ frame: RDPAudioOutputFrame) -> RDPAudioOutputFrame? {
        guard isEnabled, lastRemoteSequence != frame.sequence else { return nil }
        lastRemoteSequence = frame.sequence
        return frame
    }

    public func captureLocalInputFrame(_: RDPAudioOutputFrame) -> RDPAudioOutputFrame? {
        nil
    }
}

public struct RDPAudioOutputSynchronizer: Equatable, Sendable {
    public private(set) var bridge: RDPAudioOutputBridge

    public init(bridge: RDPAudioOutputBridge) {
        self.bridge = bridge
    }

    public mutating func receiveRemoteOutputFrame(
        _ frame: RDPAudioOutputFrame,
        play: (RDPAudioOutputFrame) -> Void
    ) -> RDPAudioOutputFrame? {
        guard let acceptedFrame = bridge.receiveRemoteOutputFrame(frame) else { return nil }
        play(acceptedFrame)
        return acceptedFrame
    }
}

public struct RDPReconnectPolicy: Equatable, Sendable {
    public let maxAttempts: Int
    public let retryDelaySeconds: Int

    public init(maxAttempts: Int = 3, retryDelaySeconds: Int = 5) {
        self.maxAttempts = max(0, maxAttempts)
        self.retryDelaySeconds = max(0, retryDelaySeconds)
    }

    public func shouldReconnect(disconnectReason: RDPDisconnectReason, completedAttempts: Int) -> Bool {
        guard completedAttempts < maxAttempts else { return false }

        switch disconnectReason {
        case .userInitiated:
            return false
        case .networkFailure, .transportError:
            return true
        }
    }
}

public enum RDPSessionState: Equatable, Sendable {
    case prepared
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case disconnected(reason: RDPDisconnectReason)
    case failed(reason: RDPDisconnectReason)
}

public struct RDPReconnectPlan: Equatable, Sendable {
    public let attempt: Int
    public let delaySeconds: Int

    public init(attempt: Int, delaySeconds: Int) {
        self.attempt = attempt
        self.delaySeconds = delaySeconds
    }
}

public enum RDPTransportReconnectResult: Equatable, Sendable {
    case connected
    case disconnected(RDPDisconnectReason)
}

public struct RDPReconnectExecution: Equatable, Sendable {
    public let plan: RDPReconnectPlan
    public let result: RDPTransportReconnectResult
    public let followUpPlan: RDPReconnectPlan?

    public init(
        plan: RDPReconnectPlan,
        result: RDPTransportReconnectResult,
        followUpPlan: RDPReconnectPlan?
    ) {
        self.plan = plan
        self.result = result
        self.followUpPlan = followUpPlan
    }
}

public struct RDPSessionLifecycle: Equatable, Sendable {
    public let descriptor: RDPSessionDescriptor
    public private(set) var state: RDPSessionState
    public private(set) var completedReconnectAttempts: Int

    public init(
        descriptor: RDPSessionDescriptor,
        state: RDPSessionState = .prepared,
        completedReconnectAttempts: Int = 0
    ) {
        self.descriptor = descriptor
        self.state = state
        self.completedReconnectAttempts = max(0, completedReconnectAttempts)
    }

    public mutating func markConnecting() {
        state = .connecting
    }

    public mutating func markConnected() {
        state = .connected
    }

    public mutating func handleDisconnect(reason: RDPDisconnectReason) -> RDPReconnectPlan? {
        guard descriptor.reconnectPolicy.shouldReconnect(
            disconnectReason: reason,
            completedAttempts: completedReconnectAttempts
        ) else {
            state = reason == .userInitiated ? .disconnected(reason: reason) : .failed(reason: reason)
            return nil
        }

        completedReconnectAttempts += 1
        state = .reconnecting(attempt: completedReconnectAttempts)
        return RDPReconnectPlan(
            attempt: completedReconnectAttempts,
            delaySeconds: descriptor.reconnectPolicy.retryDelaySeconds
        )
    }
}

public struct RDPReconnectExecutor: Sendable {
    public init() {}

    public func execute(
        plan: RDPReconnectPlan,
        lifecycle: inout RDPSessionLifecycle,
        connect: (RDPSessionDescriptor, RDPReconnectPlan) -> RDPTransportReconnectResult
    ) -> RDPReconnectExecution {
        lifecycle.markConnecting()
        let result = connect(lifecycle.descriptor, plan)

        switch result {
        case .connected:
            lifecycle.markConnected()
            return RDPReconnectExecution(plan: plan, result: result, followUpPlan: nil)
        case .disconnected(let reason):
            let followUpPlan = lifecycle.handleDisconnect(reason: reason)
            return RDPReconnectExecution(plan: plan, result: result, followUpPlan: followUpPlan)
        }
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }

    mutating func appendUInt64LE(_ value: UInt64) {
        for shift in stride(from: 0, through: 56, by: 8) {
            append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }

    mutating func appendFixedASCII(_ value: String, byteCount: Int) {
        let bytes = Array(value.utf8.prefix(byteCount))
        append(contentsOf: bytes)
        if bytes.count < byteCount {
            append(Data(repeating: 0, count: byteCount - bytes.count))
        }
    }

    mutating func appendFixedWindowsUTF16(_ value: String, byteCount: Int) {
        var bytes = Data()
        for codeUnit in value.utf16.prefix(byteCount / 2) {
            bytes.appendUInt16LE(codeUnit)
        }
        append(bytes.prefix(byteCount))
        if bytes.count < byteCount {
            append(Data(repeating: 0, count: byteCount - bytes.count))
        }
    }

    mutating func appendWindowsUTF16Terminated(_ value: String) {
        for codeUnit in value.utf16 {
            appendUInt16LE(codeUnit)
        }
        appendUInt16LE(0)
    }

    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func uint64LE(at offset: Int) -> UInt64 {
        UInt64(self[offset])
            | (UInt64(self[offset + 1]) << 8)
            | (UInt64(self[offset + 2]) << 16)
            | (UInt64(self[offset + 3]) << 24)
            | (UInt64(self[offset + 4]) << 32)
            | (UInt64(self[offset + 5]) << 40)
            | (UInt64(self[offset + 6]) << 48)
            | (UInt64(self[offset + 7]) << 56)
    }
}
