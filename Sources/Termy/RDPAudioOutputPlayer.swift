import AVFoundation
import Foundation
import TermyCore
import TermyRDP

enum RDPAudioOutputPlayerError: Error {
    case unsupportedFormat
    case invalidFrame
    case bufferAllocationFailed
}

final class RDPAudioOutputPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isConfigured = false

    func play(_ frame: RDPAudioOutputFrame) throws {
        guard frame.format == .pcmSigned16LittleEndian else {
            throw RDPAudioOutputPlayerError.unsupportedFormat
        }
        guard frame.sampleRate > 0, frame.channelCount > 0 else {
            throw RDPAudioOutputPlayerError.invalidFrame
        }
        guard frame.byteCount >= frame.channelCount * MemoryLayout<Int16>.size else {
            return
        }

        try configureIfNeeded(for: frame)
        let format = makeFormat(for: frame)
        let frameCount = UInt32(frame.byteCount / (MemoryLayout<Int16>.size * frame.channelCount))
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.int16ChannelData
        else {
            throw RDPAudioOutputPlayerError.bufferAllocationFailed
        }

        buffer.frameLength = frameCount
        frame.data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for frameIndex in 0..<Int(frameCount) {
                for channel in 0..<frame.channelCount {
                    channelData[channel][frameIndex] = samples[frameIndex * frame.channelCount + channel]
                }
            }
        }
        playerNode.scheduleBuffer(buffer)
    }

    private func configureIfNeeded(for frame: RDPAudioOutputFrame) throws {
        guard !isConfigured else {
            if !engine.isRunning {
                try engine.start()
            }
            if !playerNode.isPlaying {
                playerNode.play()
            }
            return
        }

        let format = makeFormat(for: frame)
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        try engine.start()
        playerNode.play()
        isConfigured = true
    }

    private func makeFormat(for frame: RDPAudioOutputFrame) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(frame.sampleRate),
            channels: AVAudioChannelCount(frame.channelCount),
            interleaved: false
        )!
    }
}
